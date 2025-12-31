import Foundation
import Combine

struct NodeVersion: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let version: String // e.g., "v18.16.0"
    let source: String // e.g., "Homebrew", "NVM"
}

class NodeManager: ObservableObject {
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
                self.installedVersions = versions.sorted { $0.version.compare($1.version, options: .numeric) == .orderedDescending }
                self.checkActiveVersion()
            }
        }
    }
    
    private func findNodeVersions() -> [NodeVersion] {
        var versions: [NodeVersion] = []
        let fileManager = FileManager.default
        let home = fileManager.homeDirectoryForCurrentUser
        
        // 1. Homebrew (/opt/homebrew/Cellar/node)
        // Also check /usr/local/Cellar/node for Intel macs
        let brewPaths = ["/opt/homebrew/Cellar/node", "/usr/local/Cellar/node"]
        
        for basePath in brewPaths {
            if let items = try? fileManager.contentsOfDirectory(atPath: basePath) {
                for item in items {
                    // item is usually the version number like "20.5.1"
                    let fullPath = (basePath as NSString).appendingPathComponent(item)
                    // Check if bin/node exists
                    let binPath = (fullPath as NSString).appendingPathComponent("bin")
                    if fileManager.fileExists(atPath: (binPath as NSString).appendingPathComponent("node")) {
                        versions.append(NodeVersion(path: fullPath, version: item, source: "Homebrew"))
                    }
                }
            }
        }
        
        // 2. NVM (~/.nvm/versions/node)
        let nvmPath = home.appendingPathComponent(".nvm/versions/node").path
        if let items = try? fileManager.contentsOfDirectory(atPath: nvmPath) {
            for item in items {
                // item is usually "v18.16.0"
                let fullPath = (nvmPath as NSString).appendingPathComponent(item)
                let binPath = (fullPath as NSString).appendingPathComponent("bin")
                if fileManager.fileExists(atPath: (binPath as NSString).appendingPathComponent("node")) {
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
                try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
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
}
