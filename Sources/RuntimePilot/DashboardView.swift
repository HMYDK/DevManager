import AppKit
import SwiftUI

struct DashboardView: View {
    @ObservedObject var viewModel: DashboardViewModel
    @Binding var selection: ContentView.Route?

    @State private var isQuickStartExpanded: Bool

    init(viewModel: DashboardViewModel, selection: Binding<ContentView.Route?>) {
        self.viewModel = viewModel
        self._selection = selection
        _isQuickStartExpanded = State(initialValue: !viewModel.hasAnyConfigured)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DMSpace.xxl) {
                header

                if !viewModel.hasAnyConfigured {
                    DMCard(accent: .blue, isEmphasized: true) {
                        HStack(alignment: .top, spacing: DMSpace.m) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.blue)
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Welcome to RuntimePilot")
                                    .font(DMTypography.section)
                                Text("Pick a language below, then select or install a version.")
                                    .font(DMTypography.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                DMSection(
                    title: "Environments",
                    subtitle: "Select a language to manage versions"
                ) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 240, maximum: 300), spacing: DMSpace.l)], spacing: DMSpace.l) {
                        ForEach(sortedStatuses) { status in
                            EnvironmentCard(status: status) {
                                withAnimation(.easeOut(duration: 0.18)) {
                                    selection = .language(status.id)
                                }
                            }
                        }
                    }
                }

                DMSection(
                    title: "Quick Start",
                    subtitle: "One-time shell setup"
                ) {
                    DMCard {
                        DisclosureGroup(isExpanded: $isQuickStartExpanded) {
                            VStack(alignment: .leading, spacing: DMSpace.l) {
                                QuickStartStep(
                                    symbol: "hand.tap.fill",
                                    accent: .blue,
                                    title: "Select a version",
                                    detail: "Open a language on the left and press Use on the version you want."
                                )

                                QuickStartStep(
                                    symbol: "terminal.fill",
                                    accent: .purple,
                                    title: "Configure your shell",
                                    detail: "Add the snippet below to your shell config file (for example ~/.zshrc)."
                                ) {
                                    DMCodeBlock(
                                        text: shellConfig,
                                        onCopy: {
                                            NSPasteboard.general.clearContents()
                                            NSPasteboard.general.setString(shellConfig, forType: .string)
                                        }
                                    )
                                }

                                QuickStartStep(
                                    symbol: "bolt.fill",
                                    accent: .orange,
                                    title: "Activate",
                                    detail: "Restart your terminal or run source ~/.zshrc."
                                )
                            }
                            .padding(.top, DMSpace.m)
                        } label: {
                            HStack(spacing: DMSpace.s) {
                                Image(systemName: "wand.and.stars")
                                    .foregroundStyle(.secondary)
                                Text("Set up in 3 steps")
                                    .font(DMTypography.section)
                                Spacer()
                                Text("~2 min")
                                    .font(DMTypography.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, DMSpace.xxl)
            .padding(.vertical, DMSpace.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DMColor.windowBackground)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: DMSpace.m) {
            ZStack {
                RoundedRectangle(cornerRadius: DMRadius.container)
                    .fill(Color.blue.opacity(0.12))
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.blue)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text("Dashboard")
                    .font(DMTypography.title2)
                Text("Overview of your development environments")
                    .font(DMTypography.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private var sortedStatuses: [LanguageStatus] {
        viewModel.languageStatuses.sorted { lhs, rhs in
            if lhs.isConfigured != rhs.isConfigured {
                return lhs.isConfigured && !rhs.isConfigured
            }
            if lhs.installedCount != rhs.installedCount {
                return lhs.installedCount > rhs.installedCount
            }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
    }

    private let shellConfig = """
    # RuntimePilot - Development Environment Manager
    for env_file in ~/.config/devmanager/*_env.sh; do
        [ -f "$env_file" ] && source "$env_file"
    done
    """
}

private struct QuickStartStep<Content: View>: View {
    let symbol: String
    let accent: Color
    let title: String
    let detail: String
    let content: Content

    init(
        symbol: String,
        accent: Color,
        title: String,
        detail: String,
        @ViewBuilder content: () -> Content
    ) {
        self.symbol = symbol
        self.accent = accent
        self.title = title
        self.detail = detail
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .top, spacing: DMSpace.m) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(DMTypography.section)
                Text(detail)
                    .font(DMTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                content
            }
        }
    }
}

private struct EnvironmentCard: View {
    let status: LanguageStatus
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DMSpace.m) {
                // Header
                HStack(spacing: DMSpace.s) {
                    ZStack {
                        Circle()
                            .fill(status.color.opacity(status.isConfigured ? 0.16 : 0.08))
                            .frame(width: 32, height: 32)
                        LanguageIconView(imageName: status.iconName, size: 18)
                            .opacity(status.installedCount == 0 ? 0.55 : 1)
                    }

                    Text(status.displayName)
                        .font(DMTypography.section)
                        .foregroundStyle(.primary)

                    Spacer()

                    if status.isConfigured {
                        DMBadge(text: "Active", accent: status.color)
                    } else if status.installedCount > 0 {
                        DMBadge(text: "Select", accent: .orange)
                    } else {
                        DMBadge(text: "Install", accent: .secondary)
                    }
                }

                Divider()
                    .overlay(Color.primary.opacity(0.05))

                // Details
                VStack(spacing: DMSpace.s) {
                    HStack {
                        Text("Version")
                            .font(DMTypography.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(status.activeVersion ?? "—")
                            .font(DMTypography.monospaceCaption)
                            .foregroundStyle(status.activeVersion == nil ? .secondary : .primary)
                    }

                    HStack {
                        Text("Source")
                            .font(DMTypography.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let source = status.activeSource {
                            SourceTagView(source: source)
                        } else {
                            Text("—")
                                .font(DMTypography.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    HStack {
                        Text("Installed")
                            .font(DMTypography.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(status.installedCount)")
                            .font(DMTypography.monospaceCaption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(DMSpace.m)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(DMRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: DMRadius.card)
                    .stroke(isHovered ? status.color.opacity(0.5) : Color.primary.opacity(0.06), lineWidth: isHovered ? 2 : 1)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeOut(duration: 0.2), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

extension QuickStartStep where Content == EmptyView {
    init(symbol: String, accent: Color, title: String, detail: String) {
        self.init(symbol: symbol, accent: accent, title: title, detail: detail) { EmptyView() }
    }
}
