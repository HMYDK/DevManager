import Foundation

/// Homebrew 扫描到的版本信息
struct BrewInstalledVersion {
    let formulaName: String  // e.g., "node", "node@18", "python@3.13"
    let version: String  // e.g., "24.9.0", "3.13.11"
    let cellarPath: String  // e.g., "/opt/homebrew/Cellar/node/24.9.0"

    /// 清理后的版本号（去掉 _1 等修订后缀）
    var cleanVersion: String {
        version.components(separatedBy: "_").first ?? version
    }

    /// 显示用的来源名称
    var sourceDisplay: String {
        if formulaName.contains("@") {
            return "Homebrew (\(formulaName))"
        }
        return "Homebrew"
    }
}

/// Homebrew Cellar 目录扫描工具
enum BrewScanner {

    /// Homebrew Cellar 根目录（支持 Apple Silicon 和 Intel Mac）
    static let cellarRoots = ["/opt/homebrew/Cellar", "/usr/local/Cellar"]

    // MARK: - 通用扫描

    /// 扫描指定前缀的 Homebrew formula
    /// - Parameters:
    ///   - prefix: formula 名称前缀，如 "node", "python@", "openjdk"
    ///   - exactMatch: 是否精确匹配（仅匹配 prefix 本身）
    /// - Returns: 找到的版本列表
    static func scanFormulae(prefix: String, exactMatch: Bool = false) -> [BrewInstalledVersion] {
        var results: [BrewInstalledVersion] = []
        let fileManager = FileManager.default

        for root in cellarRoots {
            guard let items = try? fileManager.contentsOfDirectory(atPath: root) else { continue }

            for item in items {
                let matches: Bool
                if exactMatch {
                    matches = item == prefix
                } else {
                    matches = item == prefix || item.hasPrefix("\(prefix)@")
                }

                guard matches else { continue }

                let formulaPath = (root as NSString).appendingPathComponent(item)
                guard let versionDirs = try? fileManager.contentsOfDirectory(atPath: formulaPath)
                else { continue }

                for versionDir in versionDirs {
                    // 跳过隐藏文件和符号链接
                    if versionDir.hasPrefix(".") { continue }

                    let versionPath = (formulaPath as NSString).appendingPathComponent(versionDir)
                    var isDirectory: ObjCBool = false

                    if fileManager.fileExists(atPath: versionPath, isDirectory: &isDirectory),
                        isDirectory.boolValue
                    {
                        results.append(
                            BrewInstalledVersion(
                                formulaName: item,
                                version: versionDir,
                                cellarPath: versionPath
                            ))
                    }
                }
            }
        }

        return results
    }

    // MARK: - Node.js

    /// 扫描 Node.js Homebrew 安装
    /// - Returns: (path, version, source) 元组数组
    static func scanNode() -> [(path: String, version: String, source: String)] {
        let fileManager = FileManager.default
        var results: [(String, String, String)] = []

        for installed in scanFormulae(prefix: "node") {
            let binPath = (installed.cellarPath as NSString).appendingPathComponent("bin/node")
            if fileManager.fileExists(atPath: binPath) {
                results.append(
                    (installed.cellarPath, installed.cleanVersion, installed.sourceDisplay))
            }
        }

        return results
    }

    // MARK: - Python

    /// 扫描 Python Homebrew 安装
    /// - Returns: (path, version, source) 元组数组
    static func scanPython() -> [(path: String, version: String, source: String)] {
        let fileManager = FileManager.default
        var results: [(String, String, String)] = []

        for installed in scanFormulae(prefix: "python") {
            // 只处理带版本号的 python，如 python@3.13，跳过纯 python
            guard installed.formulaName.contains("@") else { continue }
            let binPath = (installed.cellarPath as NSString).appendingPathComponent("bin")

            // Python 的可执行文件可能是 python3, python3.x, 或 python
            let possibleNames = ["python3", "python"]
            // 也检查版本化的名称如 python3.13
            let versionedName =
                "python\(installed.formulaName.replacingOccurrences(of: "python@", with: ""))"
            let allNames = [versionedName] + possibleNames

            for name in allNames {
                let pythonPath = (binPath as NSString).appendingPathComponent(name)
                if fileManager.fileExists(atPath: pythonPath) {
                    results.append(
                        (installed.cellarPath, installed.cleanVersion, installed.sourceDisplay))
                    break
                }
            }
        }

        return results
    }

    // MARK: - Go

    /// 扫描 Go Homebrew 安装
    /// - Returns: (path, version, source) 元组数组，path 是 GOROOT
    static func scanGo() -> [(path: String, version: String, source: String)] {
        let fileManager = FileManager.default
        var results: [(String, String, String)] = []

        for installed in scanFormulae(prefix: "go") {
            // Go 的 GOROOT 在 libexec 目录
            let libexecPath = (installed.cellarPath as NSString).appendingPathComponent("libexec")
            let libexecBin = (libexecPath as NSString).appendingPathComponent("bin/go")

            if fileManager.fileExists(atPath: libexecBin) {
                results.append((libexecPath, installed.cleanVersion, installed.sourceDisplay))
            } else {
                // 备选：直接在 bin 目录
                let directBin = (installed.cellarPath as NSString).appendingPathComponent("bin/go")
                if fileManager.fileExists(atPath: directBin) {
                    results.append(
                        (installed.cellarPath, installed.cleanVersion, installed.sourceDisplay))
                }
            }
        }

        return results
    }

    // MARK: - Java (OpenJDK)

    /// 扫描 OpenJDK Homebrew 安装
    /// - Returns: (homePath, name, version) 元组数组
    static func scanJava() -> [(homePath: String, name: String, version: String)] {
        let fileManager = FileManager.default
        var results: [(String, String, String)] = []

        for installed in scanFormulae(prefix: "openjdk") {
            // OpenJDK 的 JAVA_HOME 在 libexec/openjdk.jdk/Contents/Home
            let jdkPath = (installed.cellarPath as NSString).appendingPathComponent(
                "libexec/openjdk.jdk/Contents/Home")

            guard fileManager.fileExists(atPath: jdkPath) else { continue }

            // 从 release 文件读取实际版本
            var javaVersion = installed.cleanVersion
            let releasePath = (jdkPath as NSString).appendingPathComponent("release")

            if let releaseContent = try? String(contentsOfFile: releasePath, encoding: .utf8),
                let range = releaseContent.range(of: "JAVA_VERSION=\"")
            {
                let suffix = releaseContent[range.upperBound...]
                if let endRange = suffix.range(of: "\"") {
                    javaVersion = String(suffix[..<endRange.lowerBound])
                }
            }

            let displayName =
                installed.formulaName == "openjdk"
                ? "OpenJDK (Homebrew)"
                : "\(installed.formulaName) (Homebrew)"

            results.append((jdkPath, displayName, javaVersion))
        }

        return results
    }
}
