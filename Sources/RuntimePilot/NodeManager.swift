import Combine
import Foundation

struct NodeVersion: LanguageVersion, Hashable {
    let id = UUID()
    let path: String
    let version: String  // e.g., "v18.16.0"
    let source: String  // e.g., "Homebrew", "NVM"
}

class NodeManager: ObservableObject, LanguageManager {
    typealias Version = NodeVersion
    @Published var installedVersions: [NodeVersion] = []
    @Published var activeVersion: NodeVersion?

    private let configDir: URL
    private let envFile: URL

    init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        configDir = home.appendingPathComponent(".config/devmanager")
        envFile = configDir.appendingPathComponent("node_env.sh")

        refresh()
    }

    func refresh() {
        DispatchQueue.global(qos: .userInitiated).async {
            let versions = self.findNodeVersions()
            DispatchQueue.main.async {
                self.installedVersions = versions.sorted {
                    $0.version.compare($1.version, options: .numeric) == .orderedDescending
                }
                self.checkActiveVersion()
            }
        }
    }

    private func findNodeVersions() -> [NodeVersion] {
        var versions: [NodeVersion] = []
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser

        // 1. Homebrew (使用公共扫描工具)
        for brew in BrewScanner.scanNode() {
            versions.append(
                NodeVersion(path: brew.path, version: brew.version, source: brew.source))
        }

        // 2. NVM (~/.nvm/versions/node)
        let nvmPath = home.appendingPathComponent(".nvm/versions/node").path
        if let items = try? fileManager.contentsOfDirectory(atPath: nvmPath) {
            for item in items {
                let fullPath = (nvmPath as NSString).appendingPathComponent(item)
                let binPath = (fullPath as NSString).appendingPathComponent("bin")
                if fileManager.fileExists(
                    atPath: (binPath as NSString).appendingPathComponent("node"))
                {
                    versions.append(NodeVersion(path: fullPath, version: item, source: "NVM"))
                }
            }
        }

        return versions
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
                print("Error reading active node version from config: \(error)")
            }
        }

        DispatchQueue.main.async {
            self.activeVersion = nil
        }
    }

    func setActive(_ version: NodeVersion) {
        do {
            if !FileManager.default.fileExists(atPath: configDir.path) {
                try FileManager.default.createDirectory(
                    at: configDir, withIntermediateDirectories: true)
            }

            // We prepend the bin directory to PATH
            let binPath = (version.path as NSString).appendingPathComponent("bin")
            let content = "export PATH=\"\(binPath):$PATH\"\n"
            try content.write(to: envFile, atomically: true, encoding: .utf8)

            DispatchQueue.main.async {
                self.activeVersion = version
            }
        } catch {
            print("Error setting active node version: \(error)")
        }
    }
    
    // MARK: - 卸载功能
    
    func canUninstall(_ version: NodeVersion) -> Bool {
        // 【核心安全约束】不能卸载当前激活的版本
        if activeVersion?.id == version.id {
            return false
        }
        
        // 判断是否为 Homebrew 安装或版本管理工具安装
        let isHomebrew = BrewService.shared.isHomebrewInstalled(path: version.path)
        let isNVM = version.source == "NVM" && VersionRemovalService.shared.isPathAllowedForRemoval(path: version.path, language: .node)
        
        return isHomebrew || isNVM
    }
    
    func uninstall(_ version: NodeVersion, onOutput: @escaping (String) -> Void) async -> Bool {
        // 【核心安全约束】验证不是当前激活版本
        guard activeVersion?.id != version.id else {
            await MainActor.run {
                onOutput("错误：无法删除当前激活版本")
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
        } else if version.source == "NVM" {
            // NVM 版本：使用目录删除
            success = await VersionRemovalService.shared.removeVersionDirectory(
                path: version.path,
                language: .node,
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
