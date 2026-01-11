import Foundation

/// Homebrew 服务 - 处理版本安装、卸载和远程版本查询
class BrewService {
    static let shared = BrewService()

    private let brewPath: String?

    private init() {
        brewPath = Self.resolveBrewPath()
    }

    /// 检查 Homebrew 是否可用
    var isAvailable: Bool {
        brewPath != nil
    }

    // MARK: - 远程版本获取

    /// 搜索 Homebrew 中匹配的 formula
    /// 注意：brew search 不支持正则表达式，所以我们需要使用不同的策略
    private func searchFormulae(pattern: String) async -> [String] {
        guard let brewPath else { return [] }
        let brewExecutable = brewPath

        return await Task.detached(priority: .userInitiated) {
            // 由于 brew search 不支持正则表达式，我们使用简单的文本搜索
            // 然后手动过滤结果
            let searchTerm: String
            if pattern.hasPrefix("^") && pattern.hasSuffix("$") {
                // 提取模式中的主要搜索词
                // 去掉 ^ 和 $ 后，找到第一个非字母数字字符的位置，截取之前的部分
                var cleanPattern =
                    pattern
                    .replacingOccurrences(of: "^", with: "")
                    .replacingOccurrences(of: "$", with: "")

                // 对于 "node(@[0-9]+)?" -> "node"
                // 对于 "openjdk(@[0-9]+)?" -> "openjdk"
                // 对于 "python@3\\.[0-9]+" -> "python"
                // 对于 "go(@[0-9.]+)?" -> "go"
                if let firstSpecialIndex = cleanPattern.firstIndex(where: {
                    $0 == "@" || $0 == "(" || $0 == "\\"
                }) {
                    cleanPattern = String(cleanPattern[..<firstSpecialIndex])
                }

                searchTerm = cleanPattern.isEmpty ? pattern : cleanPattern
            } else {
                searchTerm = pattern
            }

            let task = Process()
            task.executableURL = URL(fileURLWithPath: brewExecutable)
            task.arguments = ["search", searchTerm]

            let pipe = Pipe()
            let errorPipe = Pipe()
            task.standardOutput = pipe
            task.standardError = errorPipe

            do {
                try task.run()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                task.waitUntilExit()

                // 检查错误输出
                if let errorOutput = String(data: errorData, encoding: .utf8), !errorOutput.isEmpty
                {
                    print("Brew search error: \(errorOutput)")
                }

                guard task.terminationStatus == 0,
                    let output = String(data: data, encoding: .utf8)
                else {
                    print("Brew search failed with status: \(task.terminationStatus)")
                    return []
                }

                let lines = output.components(separatedBy: .newlines)
                var results: [String] = []

                // 编译正则表达式用于过滤
                guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                    print("Invalid regex pattern: \(pattern)")
                    return []
                }

                for line in lines {
                    let trimmedLine = line.trimmingCharacters(in: .whitespaces)
                    if trimmedLine.isEmpty || trimmedLine.contains("==>") { continue }

                    let parts = line.components(separatedBy: .whitespaces)
                    for part in parts {
                        let cleanPart = part.trimmingCharacters(in: .whitespaces)
                        if !cleanPart.isEmpty && cleanPart != "✔" {
                            // 使用正则表达式过滤结果
                            let range = NSRange(cleanPart.startIndex..., in: cleanPart)
                            if regex.firstMatch(in: cleanPart, options: [], range: range) != nil {
                                results.append(cleanPart)
                            }
                        }
                    }
                }

                var seen = Set<String>()
                let filtered = results.filter { seen.insert($0).inserted }

                if filtered.isEmpty {
                    print(
                        "No formulae found matching pattern: \(pattern) (searched for: \(searchTerm))"
                    )
                } else {
                    print("Found \(filtered.count) formulae matching pattern: \(pattern)")
                }

                return filtered
            } catch {
                print("Error searching formulae: \(error)")
                return []
            }
        }.value
    }

    /// 获取 Node.js 可用版本（动态查询）
    func fetchNodeVersions() async -> [RemoteVersion] {
        var versions: [RemoteVersion] = []

        // 搜索所有 node 相关的 formula: node, node@xx
        let formulae = await searchFormulae(pattern: "^node(@[0-9]+)?$")
        let infos = await getBatchFormulaeInfo(formulae)

        for formula in formulae {
            if let info = infos[formula] {
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

        let limit = 6
        return Array(
            versions.sorted { v1, v2 in
                if v1.formula == "node" { return v2.formula != "node" }
                if v2.formula == "node" { return false }
                return v1.version.compare(v2.version, options: .numeric) == .orderedDescending
            }
            .prefix(limit)
        )
    }

    /// 获取 Java 可用版本（动态查询）
    func fetchJavaVersions() async -> [RemoteVersion] {
        var versions: [RemoteVersion] = []

        // 搜索所有 openjdk 相关的 formula
        let formulae = await searchFormulae(pattern: "^openjdk(@[0-9]+)?$")
        let infos = await getBatchFormulaeInfo(formulae)

        for formula in formulae {
            if let info = infos[formula] {
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

        let limit = 6
        return Array(
            versions.sorted { v1, v2 in
                if v1.formula == "openjdk" { return v2.formula != "openjdk" }
                if v2.formula == "openjdk" { return false }
                return v1.version.compare(v2.version, options: .numeric) == .orderedDescending
            }
            .prefix(limit)
        )
    }

    /// 获取 Python 可用版本（动态查询）
    func fetchPythonVersions() async -> [RemoteVersion] {
        var versions: [RemoteVersion] = []

        // 搜索所有 python@x.x 的 formula
        let formulae = await searchFormulae(pattern: "^python@3\\.[0-9]+$")
        let infos = await getBatchFormulaeInfo(formulae)

        for formula in formulae {
            if let info = infos[formula] {
                versions.append(
                    RemoteVersion(
                        version: info.version,
                        formula: formula,
                        isInstalled: info.isInstalled,
                        displayName: "Python \(info.version)"
                    ))
            }
        }

        let limit = 6
        return Array(
            versions.sorted { v1, v2 in
                v1.version.compare(v2.version, options: .numeric) == .orderedDescending
            }
            .prefix(limit)
        )
    }

    /// 获取 Go 可用版本（动态查询）
    func fetchGoVersions() async -> [RemoteVersion] {
        var versions: [RemoteVersion] = []

        // 搜索 go 和 go@x.x
        let formulae = await searchFormulae(pattern: "^go(@[0-9.]+)?$")
        let infos = await getBatchFormulaeInfo(formulae)

        for formula in formulae {
            if let info = infos[formula] {
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

        let limit = 6
        return Array(
            versions.sorted { v1, v2 in
                if v1.formula == "go" { return v2.formula != "go" }
                if v2.formula == "go" { return false }
                return v1.version.compare(v2.version, options: .numeric) == .orderedDescending
            }
            .prefix(limit)
        )
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

    private func getBatchFormulaeInfo(_ formulae: [String]) async -> [String: FormulaInfo] {
        guard !formulae.isEmpty else { return [:] }

        // 尝试批量获取
        let result = await executeBrewInfo(formulae)

        // 如果批量获取成功（有数据），直接返回
        if !result.isEmpty {
            return result
        }

        // 如果批量失败且有多个 formula，尝试逐个获取（Fallback 机制）
        // 这可以防止因单个 formula 报错导致整个列表失败，也能规避某些极端的大数据量问题
        if formulae.count > 1 {
            var fallbackResult: [String: FormulaInfo] = [:]
            for formula in formulae {
                let singleResult = await executeBrewInfo([formula])
                fallbackResult.merge(singleResult) { (current, _) in current }
            }
            return fallbackResult
        }

        return [:]
    }

    private func executeBrewInfo(_ formulae: [String]) async -> [String: FormulaInfo] {
        guard let brewPath else {
            print("Brew path not found")
            return [:]
        }
        let brewExecutable = brewPath
        let input = formulae

        return await Task.detached(priority: .userInitiated) {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: brewExecutable)
            task.arguments = ["info", "--json=v2"] + input

            let pipe = Pipe()
            let errorPipe = Pipe()
            task.standardOutput = pipe
            task.standardError = errorPipe

            do {
                try task.run()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                task.waitUntilExit()

                // 检查错误输出
                if let errorOutput = String(data: errorData, encoding: .utf8), !errorOutput.isEmpty
                {
                    print("Brew info error for formulae \(formulae): \(errorOutput)")
                }

                guard task.terminationStatus == 0 else {
                    print(
                        "Brew info failed with status \(task.terminationStatus) for formulae: \(formulae)"
                    )
                    return [:]
                }

                guard !data.isEmpty else {
                    print("Brew info returned empty data for formulae: \(formulae)")
                    return [:]
                }

                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                else {
                    print("Failed to parse JSON from brew info for formulae: \(formulae)")
                    if let output = String(data: data, encoding: .utf8) {
                        print("Raw output: \(output.prefix(500))")
                    }
                    return [:]
                }

                guard let formulaeList = json["formulae"] as? [[String: Any]] else {
                    print("JSON does not contain 'formulae' key for: \(formulae)")
                    print("JSON keys: \(json.keys)")
                    return [:]
                }

                var result: [String: FormulaInfo] = [:]

                for formulaData in formulaeList {
                    if let name = formulaData["name"] as? String {
                        let versions = formulaData["versions"] as? [String: Any]
                        let stable = versions?["stable"] as? String ?? "unknown"
                        let installed = formulaData["installed"] as? [[String: Any]] ?? []

                        result[name] = FormulaInfo(version: stable, isInstalled: !installed.isEmpty)

                        if let fullName = formulaData["full_name"] as? String, fullName != name {
                            result[fullName] = FormulaInfo(
                                version: stable, isInstalled: !installed.isEmpty)
                        }
                    }
                }

                if result.isEmpty {
                    print("No formula info extracted from brew info for: \(formulae)")
                } else {
                    print(
                        "Successfully extracted info for \(result.count) formulae: \(result.keys.joined(separator: ", "))"
                    )
                }

                return result
            } catch {
                print("Error executing brew info: \(error)")
                return [:]
            }
        }.value
    }

    private func getFormulaInfo(_ formula: String) async -> FormulaInfo? {
        let batch = await getBatchFormulaeInfo([formula])
        return batch[formula] ?? batch.values.first
    }

    private func runBrewCommand(_ arguments: [String], onOutput: @escaping (String) -> Void) async
        -> Bool
    {
        guard let brewPath else {
            await MainActor.run {
                onOutput("Error: Homebrew not found")
            }
            return false
        }
        let brewExecutable = brewPath

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

    private static func resolveBrewPath() -> String? {
        let fileManager = FileManager.default

        let candidates = [
            "/opt/homebrew/bin/brew",
            "/usr/local/bin/brew",
        ]

        for path in candidates where fileManager.fileExists(atPath: path) {
            return path
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = ["brew"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            task.waitUntilExit()

            guard task.terminationStatus == 0,
                let output = String(data: data, encoding: .utf8)
            else {
                return nil
            }

            let resolved = output.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !resolved.isEmpty, fileManager.fileExists(atPath: resolved) else { return nil }
            return resolved
        } catch {
            return nil
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
