import Combine
import Foundation

struct JavaVersion: LanguageVersion, Hashable {
    let id = UUID()
    let homePath: String
    let name: String
    let version: String
    
    // LanguageVersion 协议要求
    var path: String { homePath }
    var source: String { name }
}

class JavaManager: ObservableObject, LanguageManager {
    typealias Version = JavaVersion
    @Published var installedVersions: [JavaVersion] = []
    @Published var activeVersion: JavaVersion?

    private let configDir: URL
    private let envFile: URL

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        configDir = home.appendingPathComponent(".config/devmanager")
        envFile = configDir.appendingPathComponent("java_env.sh")

        refresh()
    }

    func refresh() {
        DispatchQueue.global(qos: .userInitiated).async {
            var versions = self.fetchFromJavaHome()
            let brewVersions = self.fetchFromHomebrew()

            // 合并，避免重复
            for brewVersion in brewVersions {
                if !versions.contains(where: { $0.homePath == brewVersion.homePath }) {
                    versions.append(brewVersion)
                }
            }

            DispatchQueue.main.async {
                self.installedVersions = versions
                self.checkActiveVersion()
            }
        }
    }

    private func fetchFromJavaHome() -> [JavaVersion] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/libexec/java_home")
        task.arguments = ["-X"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()

            // Parse Plist
            if let plist = try PropertyListSerialization.propertyList(
                from: data, options: [], format: nil) as? [[String: Any]]
            {
                return plist.compactMap { dict -> JavaVersion? in
                    guard let home = dict["JVMHomePath"] as? String,
                        let name = dict["JVMName"] as? String,
                        let version = dict["JVMVersion"] as? String
                    else {
                        return nil
                    }
                    return JavaVersion(homePath: home, name: name, version: version)
                }
            }
        } catch {
            print("Error finding java versions via java_home: \(error)")
        }
        return []
    }

    private func fetchFromHomebrew() -> [JavaVersion] {
        // 使用公共扫描工具
        return BrewScanner.scanJava().map { brew in
            JavaVersion(homePath: brew.homePath, name: brew.name, version: brew.version)
        }
    }

    private func checkActiveVersion() {
        if FileManager.default.fileExists(atPath: envFile.path) {
            do {
                let content = try String(contentsOf: envFile)
                if let range = content.range(of: "export JAVA_HOME=\"") {
                    let suffix = content[range.upperBound...]
                    if let endRange = suffix.range(of: "\"") {
                        let path = String(suffix[..<endRange.lowerBound])
                        DispatchQueue.main.async {
                            self.activeVersion = self.installedVersions.first {
                                $0.homePath == path
                            }
                        }
                        return
                    }
                }
            } catch {
                print("Error reading selected version from config: \(error)")
            }
        }

        DispatchQueue.main.async {
            self.activeVersion = nil
        }
    }

    func setActive(_ version: JavaVersion) {
        do {
            if !FileManager.default.fileExists(atPath: configDir.path) {
                try FileManager.default.createDirectory(
                    at: configDir, withIntermediateDirectories: true)
            }

            let content =
                "export JAVA_HOME=\"\(version.homePath)\"\nexport PATH=\"$JAVA_HOME/bin:$PATH\"\n"
            try content.write(to: envFile, atomically: true, encoding: .utf8)

            DispatchQueue.main.async {
                self.activeVersion = version
            }
        } catch {
            print("Error setting active version: \(error)")
        }
    }
    
    // MARK: - 卸载功能
    
    func canUninstall(_ version: JavaVersion) -> Bool {
        // 【核心安全约束】不能卸载当前激活的版本
        if activeVersion?.id == version.id {
            return false
        }
        
        // 系统路径不允许删除（/Library/Java/JavaVirtualMachines/）
        if version.homePath.contains("/Library/Java/JavaVirtualMachines/") {
            return false
        }
        
        // 判断是否为 Homebrew 安装
        return BrewService.shared.isHomebrewInstalled(path: version.homePath)
    }
    
    func uninstall(_ version: JavaVersion, onOutput: @escaping (String) -> Void) async -> Bool {
        // 【核心安全约束】验证不是当前激活版本
        guard activeVersion?.id != version.id else {
            await MainActor.run {
                onOutput("错误：无法删除当前激活版本")
            }
            return false
        }
        
        // 系统路径不允许删除
        if version.homePath.contains("/Library/Java/JavaVirtualMachines/") {
            await MainActor.run {
                onOutput("错误：不允许删除系统路径下的 Java 版本")
            }
            return false
        }
        
        let success: Bool
        
        // 根据版本来源选择删除方式
        if BrewService.shared.isHomebrewInstalled(path: version.homePath) {
            // Homebrew 版本：使用 brew uninstall
            guard let formula = BrewService.shared.getFormulaName(from: version.homePath) else {
                await MainActor.run {
                    onOutput("错误：无法确定 Homebrew formula 名称")
                }
                return false
            }
            success = await BrewService.shared.uninstall(formula: formula, onOutput: onOutput)
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
