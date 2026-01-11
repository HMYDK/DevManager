import Combine
import Foundation
import SwiftUI

// MARK: - Language Version Protocol

/// 定义版本对象的最小契约
protocol LanguageVersion: Identifiable {
    var id: UUID { get }
    var version: String { get }
    var source: String { get }
    var path: String { get }
}

// MARK: - Language Manager Protocol

/// 定义所有语言管理器必须遵循的契约
protocol LanguageManager: AnyObject, ObservableObject {
    associatedtype Version: LanguageVersion
    
    var installedVersions: [Version] { get }
    var activeVersion: Version? { get }
    
    func refresh()
    func setActive(_ version: Version)
    func canUninstall(_ version: Version) -> Bool
    func uninstall(_ version: Version, onOutput: @escaping (String) -> Void) async -> Bool
}

// MARK: - Type Erased Language Version

/// 类型擦除的版本包装器
struct AnyLanguageVersion: LanguageVersion {
    let id: UUID
    let version: String
    let source: String
    let path: String
    
    init<V: LanguageVersion>(_ version: V) {
        self.id = version.id
        self.version = version.version
        self.source = version.source
        self.path = version.path
    }
}

// MARK: - Type Erased Language Manager

/// 类型擦除的管理器包装器
class AnyLanguageManager: ObservableObject {
    @Published private(set) var installedVersions: [AnyLanguageVersion] = []
    @Published private(set) var activeVersion: AnyLanguageVersion?
    
    private let _refresh: () -> Void
    private let _setActive: (AnyLanguageVersion) -> Void
    private let _canUninstall: (AnyLanguageVersion) -> Bool
    private let _uninstall: (AnyLanguageVersion, @escaping (String) -> Void) async -> Bool
    
    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?
    
    init<M: LanguageManager>(_ manager: M) {
        // 初始化版本列表
        self.installedVersions = manager.installedVersions.map { AnyLanguageVersion($0) }
        self.activeVersion = manager.activeVersion.map { AnyLanguageVersion($0) }
        
        // 保存闭包引用
        _refresh = { [weak manager] in
            manager?.refresh()
        }
        
        _setActive = { [weak manager] anyVersion in
            guard let manager = manager else { return }
            // 从原始版本列表中找到对应的版本
            if let originalVersion = manager.installedVersions.first(where: { $0.id == anyVersion.id }) {
                manager.setActive(originalVersion)
            }
        }
        
        _canUninstall = { [weak manager] anyVersion in
            guard let manager = manager else { return false }
            if let originalVersion = manager.installedVersions.first(where: { $0.id == anyVersion.id }) {
                return manager.canUninstall(originalVersion)
            }
            return false
        }
        
        _uninstall = { [weak manager] anyVersion, onOutput in
            guard let manager = manager else { return false }
            if let originalVersion = manager.installedVersions.first(where: { $0.id == anyVersion.id }) {
                return await manager.uninstall(originalVersion, onOutput: onOutput)
            }
            return false
        }
        
        // 订阅原始 Manager 的变化
        manager.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }.store(in: &cancellables)
        
        // 设置定时更新（使用轮询方式）
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self, weak manager] _ in
            guard let self = self, let manager = manager else { return }
            DispatchQueue.main.async {
                self.installedVersions = manager.installedVersions.map { AnyLanguageVersion($0) }
                self.activeVersion = manager.activeVersion.map { AnyLanguageVersion($0) }
            }
        }
    }
    
    deinit {
        updateTimer?.invalidate()
    }
    
    func refresh() {
        _refresh()
    }
    
    func setActive(_ version: AnyLanguageVersion) {
        _setActive(version)
    }
    
    func canUninstall(_ version: AnyLanguageVersion) -> Bool {
        _canUninstall(version)
    }
    
    func uninstall(_ version: AnyLanguageVersion, onOutput: @escaping (String) -> Void) async -> Bool {
        await _uninstall(version, onOutput)
    }
}
