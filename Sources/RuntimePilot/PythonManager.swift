import Combine
import Foundation

struct PythonVersion: LanguageVersion, Hashable {
    let id = UUID()
    let path: String
    let version: String
    let source: String
}

class PythonManager: ObservableObject, LanguageManager {
    typealias Version = PythonVersion
    @Published var installedVersions: [PythonVersion] = []
    @Published var activeVersion: PythonVersion?

    private let configDir: URL
    private let envFile: URL

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        configDir = home.appendingPathComponent(".config/devmanager")
        envFile = configDir.appendingPathComponent("python_env.sh")

        refresh()
    }

    func refresh() {
        DispatchQueue.global(qos: .userInitiated).async {
            let versions = self.findPythonVersions()
            DispatchQueue.main.async {
                self.installedVersions = versions
                self.checkActiveVersion()
            }
        }
    }

    private func findPythonVersions() -> [PythonVersion] {
        var versions: [PythonVersion] = []
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser

        // 1. Homebrew (使用公共扫描工具)
        for brew in BrewScanner.scanPython() {
            versions.append(
                PythonVersion(path: brew.path, version: brew.version, source: brew.source))
        }

        // 2. pyenv
        let pyenvPath = home.appendingPathComponent(".pyenv/versions").path
        if let items = try? fileManager.contentsOfDirectory(atPath: pyenvPath) {
            for item in items {
                let fullPath = (pyenvPath as NSString).appendingPathComponent(item)
                let binPath = (fullPath as NSString).appendingPathComponent("bin")
                if fileManager.fileExists(
                    atPath: (binPath as NSString).appendingPathComponent("python"))
                    || fileManager.fileExists(
                        atPath: (binPath as NSString).appendingPathComponent("python3"))
                {
                    versions.append(PythonVersion(path: fullPath, version: item, source: "pyenv"))
                }
            }
        }

        // 3. asdf
        let asdfPath = home.appendingPathComponent(".asdf/installs/python").path
        if let items = try? fileManager.contentsOfDirectory(atPath: asdfPath) {
            for item in items {
                let fullPath = (asdfPath as NSString).appendingPathComponent(item)
                let binPath = (fullPath as NSString).appendingPathComponent("bin")
                if fileManager.fileExists(
                    atPath: (binPath as NSString).appendingPathComponent("python"))
                    || fileManager.fileExists(
                        atPath: (binPath as NSString).appendingPathComponent("python3"))
                {
                    versions.append(PythonVersion(path: fullPath, version: item, source: "asdf"))
                }
            }
        }

        // 4. System Python
        if let systemPython = detectSystemPython() {
            if !versions.contains(where: { $0.path == systemPython.path }) {
                versions.append(systemPython)
            }
        }

        return versions
    }

    private func detectSystemPython() -> PythonVersion? {
        let versionTask = Process()
        versionTask.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        versionTask.arguments = ["python3", "--version"]

        let vPipe = Pipe()
        versionTask.standardOutput = vPipe

        do {
            try versionTask.run()
            let vData = vPipe.fileHandleForReading.readDataToEndOfFile()
            guard let vOut = String(data: vData, encoding: .utf8),
                vOut.lowercased().contains("python")
            else {
                return nil
            }

            let parts = vOut.split(separator: " ")
            guard parts.count >= 2 else { return nil }
            let ver = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)

            let whichTask = Process()
            whichTask.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            whichTask.arguments = ["which", "python3"]
            let wPipe = Pipe()
            whichTask.standardOutput = wPipe

            try whichTask.run()
            let wData = wPipe.fileHandleForReading.readDataToEndOfFile()
            guard
                let path = String(data: wData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                !path.isEmpty
            else {
                return nil
            }

            let binPath = (path as NSString).deletingLastPathComponent
            return PythonVersion(path: binPath, version: ver, source: "System")
        } catch {
            print("Error detecting system python: \(error)")
            return nil
        }
    }

    private func checkActiveVersion() {
        if FileManager.default.fileExists(atPath: envFile.path) {
            do {
                let content = try String(contentsOf: envFile)
                for version in installedVersions {
                    if content.contains(version.path) {
                        DispatchQueue.main.async {
                            self.activeVersion = version
                        }
                        return
                    }
                }
            } catch {
                print("Error reading active python version from config: \(error)")
            }
        }

        DispatchQueue.main.async {
            self.activeVersion = nil
        }
    }

    func setActive(_ version: PythonVersion) {
        do {
            if !FileManager.default.fileExists(atPath: configDir.path) {
                try FileManager.default.createDirectory(
                    at: configDir, withIntermediateDirectories: true)
            }

            let binPath = (version.path as NSString).appendingPathComponent("bin")
            let content = "export PATH=\"\(binPath):$PATH\"\n"
            try content.write(to: envFile, atomically: true, encoding: .utf8)

            DispatchQueue.main.async {
                self.activeVersion = version
            }
        } catch {
            print("Error setting active python version: \(error)")
        }
    }
    
    // MARK: - 卸载功能
    
    func canUninstall(_ version: PythonVersion) -> Bool {
        // 【核心安全约束】不能卸载当前激活的版本
        if activeVersion?.id == version.id {
            return false
        }
        
        // 系统版本不允许卸载
        if version.source.lowercased() == "system" {
            return false
        }
        
        // 判断是否为 Homebrew 安装或版本管理工具安装
        let isHomebrew = BrewService.shared.isHomebrewInstalled(path: version.path)
        let isPyenv = version.source == "pyenv" && VersionRemovalService.shared.isPathAllowedForRemoval(path: version.path, language: .python)
        let isAsdf = version.source == "asdf" && VersionRemovalService.shared.isPathAllowedForRemoval(path: version.path, language: .python)
        
        return isHomebrew || isPyenv || isAsdf
    }
    
    func uninstall(_ version: PythonVersion, onOutput: @escaping (String) -> Void) async -> Bool {
        // 【核心安全约束】验证不是当前激活版本
        guard activeVersion?.id != version.id else {
            await MainActor.run {
                onOutput("错误：无法删除当前激活版本")
            }
            return false
        }
        
        // 系统版本不允许删除
        guard version.source.lowercased() != "system" else {
            await MainActor.run {
                onOutput("错误：不允许删除系统版本")
            }
            return false
        }
        
        let success: Bool
        
        // 根据版本来源选择删除方式
        if BrewService.shared.isHomebrewInstalled(path: version.path) {
            // Homebrew 版本：使用 brew uninstall
            guard let formula = BrewService.shared.getFormulaName(from: version.path) else {
                await MainActor.run {
                    onOutput("错误：无法确定 Homebrew formula 名称")
                }
                return false
            }
            success = await BrewService.shared.uninstall(formula: formula, onOutput: onOutput)
        } else if version.source == "pyenv" || version.source == "asdf" {
            // pyenv/asdf 版本：使用目录删除
            success = await VersionRemovalService.shared.removeVersionDirectory(
                path: version.path,
                language: .python,
                onOutput: onOutput
            )
        } else {
            await MainActor.run {
                onOutput("错误：不支持的版本类型")
            }
            return false
        }
        
        if success {
            // 删除成功后刷新版本列表
            await MainActor.run {
                self.refresh()
            }
        }
        
        return success
    }
}
