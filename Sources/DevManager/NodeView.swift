import AppKit
import SwiftUI

struct NodeView: View {
    @ObservedObject var manager: NodeManager
    
    @State private var versionToUninstall: NodeVersion?
    @State private var showUninstallConfirmation = false
    @State private var isUninstalling = false
    @State private var uninstallingVersionId: UUID?

    private var displayedVersions: [NodeVersion] {
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
                title: "Node.js",
                iconImage: "nodejs",
                color: .green,
                activeVersion: manager.activeVersion?.version,
                activeSource: manager.activeVersion?.source,
                activePath: manager.activeVersion?.path
            )

            // Content area
            if manager.installedVersions.isEmpty {
                ModernEmptyState(
                    iconImage: "nodejs",
                    title: "No Node.js Versions Found",
                    message: "Install via Homebrew or NVM, then refresh.",
                    color: .green,
                    onRefresh: { manager.refresh() }
                )
            } else {
                cardsGrid
            }

            // Config hint at bottom
            ConfigHintView(filename: "node_env.sh")
        }
        .navigationTitle("Node.js")
        .toolbar {
            ToolbarItemGroup {
                ManageVersionsButton(language: .node) {
                    manager.refresh()
                }

                Button {
                    manager.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh")
            }
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
                        iconImage: "nodejs",
                        color: .green,
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
    
    private func performUninstall(_ version: NodeVersion) {
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
