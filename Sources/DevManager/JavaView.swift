import AppKit
import SwiftUI

struct JavaView: View {
    @ObservedObject var manager: JavaManager
    
    @State private var versionToUninstall: JavaVersion?
    @State private var showUninstallConfirmation = false
    @State private var isUninstalling = false
    @State private var uninstallingVersionId: UUID?

    private var displayedVersions: [JavaVersion] {
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
                title: "Java JDK",
                iconImage: "java",
                color: .orange,
                activeVersion: manager.activeVersion?.version,
                activeSource: manager.activeVersion?.name,
                activePath: manager.activeVersion?.homePath
            )

            // Content area
            if manager.installedVersions.isEmpty {
                ModernEmptyState(
                    iconImage: "java",
                    title: "No Java Versions Found",
                    message: "Install a JDK and click refresh.",
                    color: .orange,
                    onRefresh: { manager.refresh() }
                )
            } else {
                cardsGrid
            }

            // Config hint at bottom
            ConfigHintView(filename: "java_env.sh")
        }
        .navigationTitle("Java")
        .toolbar {
            ToolbarItemGroup {
                ManageVersionsButton(language: .java) {
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
                        source: version.name,
                        path: version.homePath,
                        isActive: manager.activeVersion?.id == version.id,
                        iconImage: "java",
                        color: .orange,
                        onUse: {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                manager.setActive(version)
                            }
                        },
                        onOpenFinder: {
                            NSWorkspace.shared.activateFileViewerSelecting(
                                [URL(fileURLWithPath: version.homePath)]
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
    
    private func performUninstall(_ version: JavaVersion) {
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
