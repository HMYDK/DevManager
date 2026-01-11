import AppKit
import SwiftUI

struct GenericLanguageView: View {
    let metadata: LanguageMetadata
    @ObservedObject var manager: AnyLanguageManager

    @State private var versionToUninstall: AnyLanguageVersion?
    @State private var showUninstallConfirmation = false
    @State private var isUninstalling = false
    @State private var uninstallingVersionId: UUID?
    @State private var showVersionManager = false
    @StateObject private var installViewModel: VersionInstallViewModel

    init(metadata: LanguageMetadata, manager: AnyLanguageManager) {
        self.metadata = metadata
        self.manager = manager
        self._installViewModel = StateObject(
            wrappedValue: VersionInstallViewModel(language: Self.getLanguageEnum(metadata.id)))
    }

    // Static helper to convert string ID to LanguageType enum (used in init)
    private static func getLanguageEnum(_ id: String) -> VersionInstallViewModel.LanguageType {
        switch id {
        case "java": return .java
        case "node": return .node
        case "python": return .python
        case "go": return .go
        default: return .java
        }
    }

    private var displayedVersions: [AnyLanguageVersion] {
        var sorted = manager.installedVersions.sorted { lhs, rhs in
            compareVersionDescending(lhs.version, rhs.version)
        }

        if let active = manager.activeVersion {
            sorted.removeAll(where: { $0.id == active.id })
            return [active] + sorted
        }

        return sorted
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            // Content area
            if manager.installedVersions.isEmpty {
                ModernEmptyState(
                    iconImage: metadata.iconName,
                    title: "No \(metadata.displayName) Versions Found",
                    message: "Install via Homebrew or version manager, then refresh.",
                    color: metadata.color,
                    onRefresh: { manager.refresh() },
                    onInstallNew: { showVersionManager = true }
                )
            } else {
                // 操作栏
                VersionActionBar(
                    installedCount: manager.installedVersions.count,
                    color: metadata.color,
                    onInstallNew: { showVersionManager = true }
                )

                versionsTable
            }

            // Config hint at bottom
            ConfigHintView(filename: metadata.configFileName)
        }
        .navigationTitle(metadata.displayName)
        .toolbar {
            ToolbarItem {
                Button {
                    manager.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
                .accessibilityLabel("Refresh versions")
            }
        }
        .sheet(isPresented: $showVersionManager) {
            VersionManagerSheet(
                viewModel: installViewModel,
                onDismiss: { showVersionManager = false },
                onComplete: { manager.refresh() }
            )
        }
    }

    private var versionsTable: some View {
        ScrollView {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 280, maximum: 380), spacing: DMSpace.l)],
                spacing: DMSpace.l
            ) {
                ForEach(displayedVersions) { version in
                    ModernVersionCard(
                        version: version.version,
                        source: version.source,
                        path: version.path,
                        isActive: manager.activeVersion?.id == version.id,
                        iconImage: metadata.iconName,
                        color: metadata.color,
                        onUse: {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                manager.setActive(version)
                            }
                        },
                        onOpenFinder: {
                            NSWorkspace.shared.activateFileViewerSelecting(
                                [URL(fileURLWithPath: version.path)]
                            )
                        },
                        canUninstall: manager.canUninstall(version),
                        onUninstall: {
                            versionToUninstall = version
                            showUninstallConfirmation = true
                        },
                        isUninstalling: uninstallingVersionId == version.id
                    )
                }
            }
            .padding(DMSpace.l)
        }
        .confirmationDialog(
            "Confirm Uninstall",
            isPresented: $showUninstallConfirmation,
            presenting: versionToUninstall
        ) { version in
            Button("Uninstall \(version.version)", role: .destructive) {
                performUninstall(version)
            }
            Button("Cancel", role: .cancel) {}
        } message: { version in
            Text(
                "Are you sure you want to uninstall \(version.version)? This action cannot be undone."
            )
        }
    }

    private func performUninstall(_ version: AnyLanguageVersion) {
        isUninstalling = true
        uninstallingVersionId = version.id

        Task {
            let success = await manager.uninstall(version) { _ in }

            await MainActor.run {
                isUninstalling = false
                uninstallingVersionId = nil

                if success {
                    manager.refresh()
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DMSpace.l) {
            HStack(spacing: DMSpace.m) {
                LanguageIconView(imageName: metadata.iconName, size: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(metadata.displayName)
                        .font(DMTypography.title2)
                    Text("Manage installed versions and your active environment")
                        .font(DMTypography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            DMCard(accent: metadata.color, isEmphasized: manager.activeVersion != nil) {
                if let active = manager.activeVersion {
                    VStack(alignment: .leading, spacing: DMSpace.s) {
                        HStack(spacing: DMSpace.xs) {
                            DMBadge(text: "Active", accent: metadata.color)
                            Text(active.version)
                                .font(DMTypography.section)
                            Spacer()
                        }

                        DMKeyValueRow(
                            key: "Source",
                            value: active.source,
                            onCopy: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(active.source, forType: .string)
                            }
                        )

                        DMKeyValueRow(
                            key: "Path",
                            value: active.path,
                            isMonospaced: true,
                            onCopy: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(active.path, forType: .string)
                            }
                        )
                    }
                } else {
                    HStack(spacing: DMSpace.s) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("No active version")
                                .font(DMTypography.section)
                            Text("Select a version to generate environment configuration.")
                                .font(DMTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
        }
        .padding(.horizontal, DMSpace.xxl)
        .padding(.vertical, DMSpace.xl)
    }
}
