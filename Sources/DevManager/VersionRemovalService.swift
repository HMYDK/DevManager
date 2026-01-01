import Foundation

/// 版本删除服务 - 处理非 Homebrew 版本的删除逻辑
class VersionRemovalService {
    static let shared = VersionRemovalService()

    private init() {}

    /// 语言类型枚举
    enum LanguageType {
        case node
        case python
        case go
        case java
    }

    /// 验证路径是否在允许的删除范围内
    /// - Parameters:
    ///   - path: 待删除版本的路径
    ///   - language: 语言类型
    /// - Returns: 是否允许删除
    func isPathAllowedForRemoval(path: String, language: LanguageType) -> Bool {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        let expandedPath = (path as NSString).expandingTildeInPath

        let allowedPrefixes: [String]
        switch language {
        case .node:
            allowedPrefixes = [
                "\(homeDir)/.nvm/versions/node/",
                "/opt/homebrew/Cellar/node",
                "/usr/local/Cellar/node",
            ]
        case .python:
            allowedPrefixes = [
                "\(homeDir)/.pyenv/versions/",
                "\(homeDir)/.asdf/installs/python/",
                "/opt/homebrew/Cellar/python",
                "/usr/local/Cellar/python",
            ]
        case .go:
            allowedPrefixes = [
                "\(homeDir)/.gvm/gos/",
                "\(homeDir)/.asdf/installs/golang/",
                "/opt/homebrew/Cellar/go",
                "/usr/local/Cellar/go",
            ]
        case .java:
            allowedPrefixes = [
                "/opt/homebrew/Cellar/openjdk",
                "/usr/local/Cellar/openjdk",
            ]
        }

        return allowedPrefixes.contains { expandedPath.hasPrefix($0) }
    }

    /// 删除指定路径的版本目录
    /// - Parameters:
    ///   - path: 版本路径
    ///   - language: 语言类型
    ///   - onOutput: 输出回调
    /// - Returns: 是否删除成功
    func removeVersionDirectory(
        path: String, language: LanguageType, onOutput: @escaping (String) -> Void
    ) async -> Bool {
        // 1. 路径白名单验证
        guard isPathAllowedForRemoval(path: path, language: language) else {
            await MainActor.run {
                onOutput("无法删除：版本路径不在允许的范围内")
            }
            return false
        }

        let expandedPath = (path as NSString).expandingTildeInPath
        let fileManager = FileManager.default

        // 2. 检查目录存在性
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: expandedPath, isDirectory: &isDirectory) else {
            await MainActor.run {
                onOutput("版本已不存在，已从列表移除")
            }
            return true  // 目录不存在视为删除成功
        }

        guard isDirectory.boolValue else {
            await MainActor.run {
                onOutput("错误：路径不是目录")
            }
            return false
        }

        // 3. 执行删除操作
        await MainActor.run {
            onOutput("正在删除版本...")
        }

        do {
            try fileManager.removeItem(atPath: expandedPath)
            await MainActor.run {
                onOutput("删除成功")
            }
            return true
        } catch let error as NSError {
            let errorMessage: String

            // 根据错误类型提供具体的反馈
            if error.domain == NSCocoaErrorDomain {
                switch error.code {
                case NSFileWriteNoPermissionError, NSFileReadNoPermissionError:
                    errorMessage = "删除失败：权限不足，请检查文件权限"
                case NSFileNoSuchFileError:
                    errorMessage = "删除失败：文件不存在"
                case NSFileWriteVolumeReadOnlyError:
                    errorMessage = "删除失败：目标位置为只读"
                default:
                    errorMessage = "删除失败：" + error.localizedDescription
                }
            } else {
                errorMessage = "删除失败：" + error.localizedDescription
            }

            await MainActor.run {
                onOutput(errorMessage)
            }
            return false
        }
    }
}
