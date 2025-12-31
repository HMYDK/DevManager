import AppKit
import SwiftUI

struct PythonView: View {
    @ObservedObject var manager: PythonManager

    private var displayedVersions: [PythonVersion] {
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
                title: "Python",
                iconImage: "python",
                color: .indigo,
                activeVersion: manager.activeVersion?.version,
                activeSource: manager.activeVersion?.source,
                activePath: manager.activeVersion?.path
            )

            // Content area
            if manager.installedVersions.isEmpty {
                ModernEmptyState(
                    iconImage: "python",
                    title: "No Python Versions Found",
                    message: "Install via Homebrew, pyenv, or asdf, then refresh.",
                    color: .indigo,
                    onRefresh: { manager.refresh() }
                )
            } else {
                cardsGrid
            }

            // Config hint at bottom
            ConfigHintView(filename: "python_env.sh")
        }
        .navigationTitle("Python")
        .toolbar {
            ToolbarItemGroup {
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
                        iconImage: "python",
                        color: .indigo,
                        onUse: {
                            withAnimation(.easeInOut(duration: 0.4)) {
                                manager.setActive(version)
                            }
                        },
                        onOpenFinder: {
                            NSWorkspace.shared.activateFileViewerSelecting(
                                [URL(fileURLWithPath: version.path)]
                            )
                        }
                    )
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
