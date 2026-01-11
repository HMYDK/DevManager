import Combine
import Foundation
import SwiftUI

// MARK: - Language Status Model

struct LanguageStatus: Identifiable {
    let id: String
    let displayName: String
    let iconName: String
    let color: Color
    let activeVersion: String?
    let activeSource: String?
    let installedCount: Int

    var isConfigured: Bool {
        activeVersion != nil
    }
}

// MARK: - Dashboard ViewModel

class DashboardViewModel: ObservableObject {
    @Published private(set) var languageStatuses: [LanguageStatus] = []

    private let registry: LanguageRegistry
    private var cancellables = Set<AnyCancellable>()
    private var managerCancellables = Set<AnyCancellable>()
    private var observedManagerIds = Set<String>()

    init(registry: LanguageRegistry) {
        self.registry = registry

        // 监听 registry 的变化，并重新设置 manager observers
        registry.$languages
            .sink { [weak self] _ in
                self?.setupManagerObservers()
                self?.updateStatuses()
            }
            .store(in: &cancellables)

        // 初始化状态
        updateStatuses()

        // 监听每个语言管理器的变化
        setupManagerObservers()
    }

    private func setupManagerObservers() {
        // 只为新增的语言管理器添加监听
        for language in registry.allLanguages {
            guard !observedManagerIds.contains(language.id) else { continue }
            observedManagerIds.insert(language.id)

            language.manager.objectWillChange
                .sink { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.updateStatuses()
                    }
                }
                .store(in: &managerCancellables)
        }
    }

    private func updateStatuses() {
        languageStatuses = registry.allLanguages.map { language in
            let metadata = language.metadata
            let manager = language.manager

            return LanguageStatus(
                id: metadata.id,
                displayName: metadata.displayName,
                iconName: metadata.iconName,
                color: metadata.color,
                activeVersion: manager.activeVersion?.version,
                activeSource: manager.activeVersion?.source,
                installedCount: manager.installedVersions.count
            )
        }
    }

    var hasAnyConfigured: Bool {
        languageStatuses.contains { $0.isConfigured }
    }
}
