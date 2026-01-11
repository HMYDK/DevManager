import SwiftUI

// MARK: - Language Metadata

/// 语言元数据，包含UI配置和语言特性信息
struct LanguageMetadata: Identifiable {
    let id: String
    let displayName: String
    let iconName: String
    let color: Color
    let configFileName: String
    let order: Int
    
    init(
        id: String,
        displayName: String,
        iconName: String,
        color: Color,
        configFileName: String,
        order: Int = 0
    ) {
        self.id = id
        self.displayName = displayName
        self.iconName = iconName
        self.color = color
        self.configFileName = configFileName
        self.order = order
    }
}

// MARK: - Predefined Language Metadata

extension LanguageMetadata {
    static let java = LanguageMetadata(
        id: "java",
        displayName: "Java JDK",
        iconName: "java",
        color: .orange,
        configFileName: "java_env.sh",
        order: 1
    )
    
    static let node = LanguageMetadata(
        id: "node",
        displayName: "Node.js",
        iconName: "nodejs",
        color: .green,
        configFileName: "node_env.sh",
        order: 2
    )
    
    static let python = LanguageMetadata(
        id: "python",
        displayName: "Python",
        iconName: "python",
        color: .indigo,
        configFileName: "python_env.sh",
        order: 3
    )
    
    static let go = LanguageMetadata(
        id: "go",
        displayName: "Go",
        iconName: "go",
        color: .cyan,
        configFileName: "go_env.sh",
        order: 4
    )
}
