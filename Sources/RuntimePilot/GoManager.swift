import Combine
import Foundation

struct GoVersion: LanguageVersion, Hashable {
    let id = UUID()
    let path: String
    let version: String
    let source: String
}

class GoManager: ObservableObject, LanguageManager {
    typealias Version = GoVersion
    @Published var installedVersions: [GoVersion] = []
    @Published var activeVersion: GoVersion?

    private let configDir: URL
    private let envFile: URL

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        configDir = home.appendingPathComponent(".config/devmanager")
        envFile = configDir.appendingPathComponent("go_env.sh")

        refresh()
    }

    func refresh() {
        DispatchQueue.global(qos: .userInitiated).async {
            let versions = self.findGoVersions()
            DispatchQueue.main.async {
                self.installedVersions = versions
                self.checkActiveVersion()
            }
        }
    }

    private func findGoVersions() -> [GoVersion] {
        var versions: [GoVersion] = []
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser

        // 1. Homebrew (使用公共扫描工具)
        for brew in BrewScanner.scanGo() {
            versions.append(GoVersion(path: brew.path, version: brew.version, source: brew.source))
        }

        // 2. gvm
        let gvmPath = home.appendingPathComponent(".gvm/gos").path
        if let items = try? fileManager.contentsOfDirectory(atPath: gvmPath) {
            for item in items {
                let fullPath = (gvmPath as NSString).appendingPathComponent(item)
                let binPath = (fullPath as NSString).appendingPathComponent("bin")
                if fileManager.fileExists(
                    atPath: (binPath as NSString).appendingPathComponent("go"))
                {
                    versions.append(GoVersion(path: fullPath, version: item, source: "gvm"))
                }
            }
        }

        let asdfPath = home.appendingPathComponent(".asdf/installs/golang").path
        if let items = try? fileManager.contentsOfDirectory(atPath: asdfPath) {
            for item in items {
                let fullPath = (asdfPath as NSString).appendingPathComponent(item)
                let binPath = (fullPath as NSString).appendingPathComponent("bin")
                if fileManager.fileExists(
                    atPath: (binPath as NSString).appendingPathComponent("go"))
                {
                    versions.append(GoVersion(path: fullPath, version: item, source: "asdf"))
                } else {
                    let goSubdir = (fullPath as NSString).appendingPathComponent("go")
                    let goBin = (goSubdir as NSString).appendingPathComponent("bin")
                    if fileManager.fileExists(
                        atPath: (goBin as NSString).appendingPathComponent("go"))
                    {
                        versions.append(GoVersion(path: goSubdir, version: item, source: "asdf"))
                    }
                }
            }
        }

        if let systemGo = detectSystemGo() {
            if !versions.contains(where: { $0.path == systemGo.path }) {
                versions.append(systemGo)
            }
        }

        return versions
    }

    private func detectSystemGo() -> GoVersion? {
        let whichTask = Process()
        whichTask.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        whichTask.arguments = ["go", "version"]

        let pipe = Pipe()
        whichTask.standardOutput = pipe

        do {
            try whichTask.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8),
                output.hasPrefix("go version")
            else {
                return nil
            }

            let parts = output.split(separator: " ")
            guard parts.count >= 3 else { return nil }
            let rawVersion = String(parts[2])
            let cleaned = rawVersion.replacingOccurrences(of: "go", with: "")

            let envTask = Process()
            envTask.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            envTask.arguments = ["go", "env", "GOROOT"]
            let envPipe = Pipe()
            envTask.standardOutput = envPipe

            try envTask.run()
            let envData = envPipe.fileHandleForReading.readDataToEndOfFile()
            guard
                let goroot = String(data: envData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                !goroot.isEmpty
            else {
                return nil
            }

            return GoVersion(path: goroot, version: cleaned, source: "System")
        } catch {
            print("Error detecting system go: \(error)")
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
                print("Error reading active go version from config: \(error)")
            }
        }

        DispatchQueue.main.async {
            self.activeVersion = nil
        }
    }

    func setActive(_ version: GoVersion) {
        do {
            if !FileManager.default.fileExists(atPath: configDir.path) {
                try FileManager.default.createDirectory(
                    at: configDir, withIntermediateDirectories: true)
            }

            let content = "export GOROOT=\"\(version.path)\"\nexport PATH=\"$GOROOT/bin:$PATH\"\n"
            try content.write(to: envFile, atomically: true, encoding: .utf8)

            DispatchQueue.main.async {
                self.activeVersion = version
            }
        } catch {
            print("Error setting active go version: \(error)")
        }
    }
    
    // MARK: - 卸载功能
    
    func canUninstall(_ version: GoVersion) -> Bool {
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
        let isGvm = version.source == "gvm" && VersionRemovalService.shared.isPathAllowedForRemoval(path: version.path, language: .go)
        let isAsdf = version.source == "asdf" && VersionRemovalService.shared.isPathAllowedForRemoval(path: version.path, language: .go)
        
        return isHomebrew || isGvm || isAsdf
    }
    
    func uninstall(_ version: GoVersion, onOutput: @escaping (String) -> Void) async -> Bool {
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
        } else if version.source == "gvm" || version.source == "asdf" {
            // gvm/asdf 版本：使用目录删除
            success = await VersionRemovalService.shared.removeVersionDirectory(
                path: version.path,
                language: .go,
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
