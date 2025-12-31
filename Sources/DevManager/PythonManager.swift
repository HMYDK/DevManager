import Foundation
import Combine

struct PythonVersion: Identifiable, Hashable {
    let id = UUID()
    let path: String
    let version: String
    let source: String
}

class PythonManager: ObservableObject {
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
        
        let brewRoots = [
            "/opt/homebrew/Cellar/python@",
            "/usr/local/Cellar/python@"
        ]
        
        for root in brewRoots {
            let parent = (root as NSString).deletingLastPathComponent
            guard let items = try? fileManager.contentsOfDirectory(atPath: parent) else { continue }
            
            for item in items where item.hasPrefix("python@") {
                let basePath = (parent as NSString).appendingPathComponent(item)
                guard let versionsInFormula = try? fileManager.contentsOfDirectory(atPath: basePath) else { continue }
                
                for v in versionsInFormula {
                    let fullPath = (basePath as NSString).appendingPathComponent(v)
                    let binPath = (fullPath as NSString).appendingPathComponent("bin")
                    if fileManager.fileExists(atPath: (binPath as NSString).appendingPathComponent("python3")) {
                        let displayVersion = v
                        versions.append(PythonVersion(path: fullPath, version: displayVersion, source: "Homebrew"))
                    }
                }
            }
        }
        
        let pyenvPath = home.appendingPathComponent(".pyenv/versions").path
        if let items = try? fileManager.contentsOfDirectory(atPath: pyenvPath) {
            for item in items {
                let fullPath = (pyenvPath as NSString).appendingPathComponent(item)
                let binPath = (fullPath as NSString).appendingPathComponent("bin")
                if fileManager.fileExists(atPath: (binPath as NSString).appendingPathComponent("python")) ||
                    fileManager.fileExists(atPath: (binPath as NSString).appendingPathComponent("python3")) {
                    versions.append(PythonVersion(path: fullPath, version: item, source: "pyenv"))
                }
            }
        }
        
        let asdfPath = home.appendingPathComponent(".asdf/installs/python").path
        if let items = try? fileManager.contentsOfDirectory(atPath: asdfPath) {
            for item in items {
                let fullPath = (asdfPath as NSString).appendingPathComponent(item)
                let binPath = (fullPath as NSString).appendingPathComponent("bin")
                if fileManager.fileExists(atPath: (binPath as NSString).appendingPathComponent("python")) ||
                    fileManager.fileExists(atPath: (binPath as NSString).appendingPathComponent("python3")) {
                    versions.append(PythonVersion(path: fullPath, version: item, source: "asdf"))
                }
            }
        }
        
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
                  vOut.lowercased().contains("python") else {
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
            guard let path = String(data: wData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                  !path.isEmpty else {
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
                try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
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
}
