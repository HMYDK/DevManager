import AppKit
import SwiftUI

struct GoView: View {
    @ObservedObject var manager: GoManager
    
    @State private var versionToUninstall: GoVersion?
    @State private var showUninstallConfirmation = false
    @State private var isUninstalling = false
    @State private var uninstallingVersionId: UUID?
    @State private var showVersionManager = false

    private var displayedVersions: [GoVersion] {
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
            // Modern header
            ModernHeaderView(
                title: "Go",
                iconImage: "go",
                color: .cyan,
                activeVersion: manager.activeVersion?.version,
                activeSource: manager.activeVersion?.source,
                activePath: manager.activeVersion?.path
            )

            // Content area
            if manager.installedVersions.isEmpty {
                ModernEmptyState(
                    iconImage: "go",
                    title: "No Go Versions Found",
                    message: "Install via Homebrew, gvm, or asdf, then refresh.",
                    color: .cyan,
                    onRefresh: { manager.refresh() },
                    onInstallNew: { showVersionManager = true }
                )
            } else {
                // 操作栏
                VersionActionBar(
                    installedCount: manager.installedVersions.count,
                    color: .cyan,
                    onInstallNew: { showVersionManager = true }
                )
                
                cardsGrid
            }

            // Config hint at bottom
            ConfigHintView(filename: "go_env.sh")
        }
        .navigationTitle("Go")
        .toolbar {
            ToolbarItem {
                Button {
                    manager.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }
        }
        .sheet(isPresented: $showVersionManager) {
            VersionManagerSheet(
                viewModel: VersionInstallViewModel(language: .go),
                onDismiss: { showVersionManager = false },
                onComplete: { manager.refresh() }
            )
        }
    }

    private var cardsGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 280, maximum: 420), spacing: 20)
                ],
                spacing: 16
            ) {
                ForEach(displayedVersions) { version in
                    ModernVersionCard(
                        version: version.version,
                        source: version.source,
                        path: version.path,
                        isActive: manager.activeVersion?.id == version.id,
                        iconImage: "go",
                        color: .cyan,
                        onUse: {
                            withAnimation(.easeInOut(duration: 0.4)) {
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
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert(isPresented: $showUninstallConfirmation) {
            Alert(
                title: Text("Confirm Uninstall"),
                message: Text("Are you sure you want to uninstall \(versionToUninstall?.version ?? "this version")? This action cannot be undone."),
                primaryButton: .destructive(Text("Uninstall")) {
                    if let version = versionToUninstall {
                        performUninstall(version)
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }
    
    private func performUninstall(_ version: GoVersion) {
        isUninstalling = true
        uninstallingVersionId = version.id
        
        Task {
            let success = await manager.uninstall(version) { output in
                print("Uninstall output: \(output)")
            }
            
            await MainActor.run {
                isUninstalling = false
                uninstallingVersionId = nil
                
                if success {
                    manager.refresh()
                }
            }
        }
    }
}
