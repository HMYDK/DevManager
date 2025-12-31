import Foundation
import Combine

struct JavaVersion: Identifiable, Hashable {
    let id = UUID()
    let homePath: String
    let name: String
    let version: String
}

class JavaManager: ObservableObject {
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
        fetchInstalledVersions()
    }
    
    private func fetchInstalledVersions() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/libexec/java_home")
        task.arguments = ["-X"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            
            // Parse Plist
            if let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [[String: Any]] {
                let versions = plist.compactMap { dict -> JavaVersion? in
                    guard let home = dict["JVMHomePath"] as? String,
                          let name = dict["JVMName"] as? String,
                          let version = dict["JVMVersion"] as? String else {
                        return nil
                    }
                    return JavaVersion(homePath: home, name: name, version: version)
                }
                
                DispatchQueue.main.async {
                    self.installedVersions = versions
                    self.checkActiveVersion()
                }
            }
        } catch {
            print("Error finding java versions: \(error)")
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
                            self.activeVersion = self.installedVersions.first { $0.homePath == path }
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
                try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
            }
            
            let content = "export JAVA_HOME=\"\(version.homePath)\"\nexport PATH=\"$JAVA_HOME/bin:$PATH\"\n"
            try content.write(to: envFile, atomically: true, encoding: .utf8)
            
            DispatchQueue.main.async {
                self.activeVersion = version
            }
        } catch {
            print("Error setting active version: \(error)")
        }
    }
}
