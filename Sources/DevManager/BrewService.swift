import Foundation

/// Homebrew 服务 - 处理版本安装、卸载和远程版本查询
class BrewService {
    static let shared = BrewService()

    private let brewPath: String

    private init() {
        // 检测 Homebrew 路径
        if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/brew") {
            brewPath = "/opt/homebrew/bin/brew"
        } else if FileManager.default.fileExists(atPath: "/usr/local/bin/brew") {
            brewPath = "/usr/local/bin/brew"
        } else {
            brewPath = "brew"
        }
    }

    /// 检查 Homebrew 是否可用
    var isAvailable: Bool {
        FileManager.default.fileExists(atPath: brewPath)
    }

    // MARK: - 远程版本获取

    /// 搜索 Homebrew 中匹配的 formula
    private func searchFormulae(pattern: String) async -> [String] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: brewPath)
        task.arguments = ["search", "/\(pattern)/"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else {
                return []
            }

            // 解析输出，每行一个 formula
            return
                output
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && !$0.contains("==>") }
        } catch {
            print("Error searching formulae: \(error)")
            return []
        }
    }

    /// 获取 Node.js 可用版本（动态查询）
    func fetchNodeVersions() async -> [RemoteVersion] {
        var versions: [RemoteVersion] = []

        // 搜索所有 node 相关的 formula: node, node@xx
        let formulae = await searchFormulae(pattern: "^node(@[0-9]+)?$")

        for formula in formulae {
            if let info = await getFormulaInfo(formula) {
                let isLatest = formula == "node"
                versions.append(
                    RemoteVersion(
                        version: info.version,
                        formula: formula,
                        isInstalled: info.isInstalled,
                        displayName: isLatest
                            ? "Node.js \(info.version) (Latest)" : "Node.js \(info.version)"
                    ))
            }
        }

        // 按版本号排序（Latest 排最前）
        return versions.sorted { v1, v2 in
            if v1.formula == "node" { return true }
            if v2.formula == "node" { return false }
            return v1.formula > v2.formula
        }
    }

    /// 获取 Java 可用版本（动态查询）
    func fetchJavaVersions() async -> [RemoteVersion] {
        var versions: [RemoteVersion] = []

        // 搜索所有 openjdk 相关的 formula
        let formulae = await searchFormulae(pattern: "^openjdk(@[0-9]+)?$")

        for formula in formulae {
            if let info = await getFormulaInfo(formula) {
                let isLatest = formula == "openjdk"
                versions.append(
                    RemoteVersion(
                        version: info.version,
                        formula: formula,
                        isInstalled: info.isInstalled,
                        displayName: isLatest
                            ? "OpenJDK \(info.version) (Latest)" : "OpenJDK \(info.version)"
                    ))
            }
        }

        return versions.sorted { v1, v2 in
            if v1.formula == "openjdk" { return true }
            if v2.formula == "openjdk" { return false }
            return v1.formula > v2.formula
        }
    }

    /// 获取 Python 可用版本（动态查询）
    func fetchPythonVersions() async -> [RemoteVersion] {
        var versions: [RemoteVersion] = []

        // 搜索所有 python@x.x 的 formula
        let formulae = await searchFormulae(pattern: "^python@3\\.[0-9]+$")

        for formula in formulae {
            if let info = await getFormulaInfo(formula) {
                versions.append(
                    RemoteVersion(
                        version: info.version,
                        formula: formula,
                        isInstalled: info.isInstalled,
                        displayName: "Python \(info.version)"
                    ))
            }
        }

        // 按版本号降序排序
        return versions.sorted { $0.formula > $1.formula }
    }

    /// 获取 Go 可用版本（动态查询）
    func fetchGoVersions() async -> [RemoteVersion] {
        var versions: [RemoteVersion] = []

        // 搜索 go 和 go@x.x
        let formulae = await searchFormulae(pattern: "^go(@[0-9.]+)?$")

        for formula in formulae {
            if let info = await getFormulaInfo(formula) {
                let isLatest = formula == "go"
                versions.append(
                    RemoteVersion(
                        version: info.version,
                        formula: formula,
                        isInstalled: info.isInstalled,
                        displayName: isLatest ? "Go \(info.version) (Latest)" : "Go \(info.version)"
                    ))
            }
        }

        return versions.sorted { v1, v2 in
            if v1.formula == "go" { return true }
            if v2.formula == "go" { return false }
            return v1.formula > v2.formula
        }
    }

    // MARK: - 安装/卸载

    /// 安装指定 formula
    func install(formula: String, onOutput: @escaping (String) -> Void) async -> Bool {
        await runBrewCommand(["install", formula], onOutput: onOutput)
    }

    /// 卸载指定 formula
    func uninstall(formula: String, onOutput: @escaping (String) -> Void) async -> Bool {
        // 使用 --ignore-dependencies 避免因依赖关系导致卸载失败
        await runBrewCommand(["uninstall", "--ignore-dependencies", formula], onOutput: onOutput)
    }

    /// 获取通过路径推断的 formula 名称
    func getFormulaName(from path: String) -> String? {
        // 从路径中提取 formula 名称
        // 例如: /opt/homebrew/Cellar/node@20/20.x.x -> node@20
        //      /opt/homebrew/Cellar/openjdk@17/17.x.x -> openjdk@17
        if path.contains("/Cellar/") {
            let components = path.components(separatedBy: "/Cellar/")
            if components.count > 1 {
                let formulaPath = components[1]
                let formulaName = formulaPath.components(separatedBy: "/").first
                return formulaName
            }
        }
        return nil
    }

    /// 判断指定路径是否为 Homebrew 安装
    func isHomebrewInstalled(path: String) -> Bool {
        return path.contains("/opt/homebrew/") || path.contains("/usr/local/Cellar/")
    }

    // MARK: - 私有方法

    private struct FormulaInfo {
        let version: String
        let isInstalled: Bool
    }

    private func getFormulaInfo(_ formula: String) async -> FormulaInfo? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: brewPath)
        task.arguments = ["info", "--json=v2", formula]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let formulae = json["formulae"] as? [[String: Any]],
                let first = formulae.first
            else {
                return nil
            }

            let versions = first["versions"] as? [String: Any]
            let stable = versions?["stable"] as? String ?? "unknown"
            let installed = first["installed"] as? [[String: Any]] ?? []

            return FormulaInfo(version: stable, isInstalled: !installed.isEmpty)
        } catch {
            print("Error getting formula info for \(formula): \(error)")
            return nil
        }
    }

    private func runBrewCommand(_ arguments: [String], onOutput: @escaping (String) -> Void) async
        -> Bool
    {
        let brewExecutable = self.brewPath  // 捕获为局部变量避免 Sendable 警告

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: brewExecutable)
                task.arguments = arguments

                let pipe = Pipe()
                task.standardOutput = pipe
                task.standardError = pipe

                pipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if !data.isEmpty, let output = String(data: data, encoding: .utf8) {
                        DispatchQueue.main.async {
                            onOutput(output)
                        }
                    }
                }

                do {
                    try task.run()
                    task.waitUntilExit()

                    pipe.fileHandleForReading.readabilityHandler = nil

                    continuation.resume(returning: task.terminationStatus == 0)
                } catch {
                    DispatchQueue.main.async {
                        onOutput("Error: \(error.localizedDescription)")
                    }
                    continuation.resume(returning: false)
                }
            }
        }
    }
}

// MARK: - 远程版本模型

struct RemoteVersion: Identifiable, Hashable {
    let id = UUID()
    let version: String
    let formula: String
    let isInstalled: Bool
    let displayName: String
}
