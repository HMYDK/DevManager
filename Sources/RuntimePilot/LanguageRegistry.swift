import Combine
import Foundation
import SwiftUI

// MARK: - Registered Language

/// 注册语言的包装结构
struct RegisteredLanguage: Identifiable {
    let metadata: LanguageMetadata
    let manager: AnyLanguageManager
    
    var id: String { metadata.id }
}

// MARK: - Language Registry

/// 语言注册中心 - 管理所有支持的语言
class LanguageRegistry: ObservableObject {
    @Published private(set) var languages: [RegisteredLanguage] = []
    
    private var languageDict: [String: RegisteredLanguage] = [:]
    
    /// 注册新语言
    func register<M: LanguageManager>(
        metadata: LanguageMetadata,
        manager: M
    ) {
        let anyManager = AnyLanguageManager(manager)
        let registered = RegisteredLanguage(metadata: metadata, manager: anyManager)
        
        languageDict[metadata.id] = registered
        updateLanguages()
    }
    
    /// 获取所有已注册语言（按order排序）
    var allLanguages: [RegisteredLanguage] {
        languages
    }
    
    /// 按ID获取管理器
    func getManager(for id: String) -> AnyLanguageManager? {
        languageDict[id]?.manager
    }
    
    /// 按ID获取元数据
    func getMetadata(for id: String) -> LanguageMetadata? {
        languageDict[id]?.metadata
    }
    
    /// 按ID获取注册语言
    func getLanguage(for id: String) -> RegisteredLanguage? {
        languageDict[id]
    }
    
    private func updateLanguages() {
        languages = languageDict.values
            .sorted { $0.metadata.order < $1.metadata.order }
    }
}
