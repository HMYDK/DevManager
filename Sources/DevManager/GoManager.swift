import Foundation
import Combine

struct GoVersion: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let version: String
    let source: String
}

class GoManager: ObservableObject {
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
        
        let brewPaths = ["/opt/homebrew/Cellar/go", "/usr/local/Cellar/go"]
        for basePath in brewPaths {
            if let items = try? fileManager.contentsOfDirectory(atPath: basePath) {
                for item in items {
                    let fullPath = (basePath as NSString).appendingPathComponent(item)
                    let libexec = (fullPath as NSString).appendingPathComponent("libexec")
                    let binPath = (libexec as NSString).appendingPathComponent("bin")
                    if fileManager.fileExists(atPath: (binPath as NSString).appendingPathComponent("go")) {
                        versions.append(GoVersion(path: libexec, version: item, source: "Homebrew"))
                    } else {
                        let fallbackBin = (fullPath as NSString).appendingPathComponent("bin")
                        if fileManager.fileExists(atPath: (fallbackBin as NSString).appendingPathComponent("go")) {
                            versions.append(GoVersion(path: fullPath, version: item, source: "Homebrew"))
                        }
                    }
                }
            }
        }
        
        let gvmPath = home.appendingPathComponent(".gvm/gos").path
        if let items = try? fileManager.contentsOfDirectory(atPath: gvmPath) {
            for item in items {
                let fullPath = (gvmPath as NSString).appendingPathComponent(item)
                let binPath = (fullPath as NSString).appendingPathComponent("bin")
                if fileManager.fileExists(atPath: (binPath as NSString).appendingPathComponent("go")) {
                    versions.append(GoVersion(path: fullPath, version: item, source: "gvm"))
                }
            }
        }
        
        let asdfPath = home.appendingPathComponent(".asdf/installs/golang").path
        if let items = try? fileManager.contentsOfDirectory(atPath: asdfPath) {
            for item in items {
                let fullPath = (asdfPath as NSString).appendingPathComponent(item)
                let binPath = (fullPath as NSString).appendingPathComponent("bin")
                if fileManager.fileExists(atPath: (binPath as NSString).appendingPathComponent("go")) {
                    versions.append(GoVersion(path: fullPath, version: item, source: "asdf"))
                } else {
                    let goSubdir = (fullPath as NSString).appendingPathComponent("go")
                    let goBin = (goSubdir as NSString).appendingPathComponent("bin")
                    if fileManager.fileExists(atPath: (goBin as NSString).appendingPathComponent("go")) {
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
                  output.hasPrefix("go version") else {
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
            guard let goroot = String(data: envData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  !goroot.isEmpty else {
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
                try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
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
}
