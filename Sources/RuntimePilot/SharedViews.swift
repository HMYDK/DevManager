import AppKit
import SwiftUI

// MARK: - Source Tag View

struct SourceTagView: View {
    let source: String

    private var isHomebrew: Bool {
        source.lowercased().contains("homebrew")
    }

    var body: some View {
        if isHomebrew {
            HStack(spacing: 4) {
                Image(systemName: "mug.fill")
                    .font(.system(size: 10, weight: .semibold))
                Text("Homebrew")
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundColor(Color(red: 0.95, green: 0.55, blue: 0.15))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red: 0.95, green: 0.55, blue: 0.15).opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(red: 0.95, green: 0.55, blue: 0.15).opacity(0.3), lineWidth: 1)
            )
        } else {
            Text(source)
                .font(.callout)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Language Icon View

struct LanguageIconView: View {
    let imageName: String
    let size: CGFloat

    var body: some View {
        if let url = Bundle.module.url(forResource: imageName, withExtension: "png"),
            let nsImage = NSImage(contentsOf: url)
        {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size, height: size)
        } else {
            Image(systemName: "questionmark.circle")
                .font(.system(size: size * 0.8))
                .foregroundColor(.secondary)
                .frame(width: size, height: size)
        }
    }
}

// MARK: - Modern Card-based Version Display

struct ModernVersionCard: View {
    let version: String
    let source: String
    let path: String
    let isActive: Bool
    let iconImage: String
    let color: Color
    let onUse: () -> Void
    let onOpenFinder: () -> Void
    var canUninstall: Bool = false
    var onUninstall: (() -> Void)? = nil
    var isUninstalling: Bool = false

    @State private var isHovered = false
    @State private var showCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top section with icon and version
            HStack(alignment: .top, spacing: 12) {
                // Icon circle
                ZStack {
                    Circle()
                        .fill(isActive ? color.opacity(0.2) : Color.gray.opacity(0.1))
                        .frame(width: 48, height: 48)

                    LanguageIconView(imageName: iconImage, size: 28)
                }

                // Version info
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(version)
                            .font(.headline)
                            .fontWeight(.semibold)

                        if isActive {
                            Text("CURRENT")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(color)
                                .cornerRadius(4)
                        }
                    }

                    SourceTagView(source: source)
                }

                Spacer()

                // Right side: checkmark or action buttons
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(color)
                } else {
                    HStack(spacing: 8) {
                        Button(action: onUse) {
                            Text("Use")
                                .font(.callout)
                                .fontWeight(.medium)
                        }
                        .buttonStyle(.bordered)
                        .tint(color)
                        .disabled(isUninstalling)

                        Button(action: onOpenFinder) {
                            Image(systemName: "folder")
                                .font(.system(size: 14))
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.secondary)
                        .disabled(isUninstalling)
                        
                        if canUninstall, let uninstallAction = onUninstall {
                            Button(action: uninstallAction) {
                                if isUninstalling {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                        .frame(width: 14, height: 14)
                                } else {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14))
                                }
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(isUninstalling ? .secondary : .red)
                            .disabled(isUninstalling)
                            .help("Uninstall")
                        }
                    }
                    .opacity(isHovered || isUninstalling ? 1 : 0)
                }
            }
            .padding(16)

            // Divider
            Divider()
                .padding(.horizontal, 16)

            // Info section
            VStack(alignment: .leading, spacing: 8) {
                // Path info
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Text(path)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(path, forType: .string)
                        showCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showCopied = false
                        }
                    }) {
                        Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(showCopied ? color : .secondary)
                    .help("Copy path")
                }
            }
            .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isActive ? color.opacity(0.08) : Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isActive ? color.opacity(0.4) : Color.gray.opacity(0.1),
                    lineWidth: isActive ? 2 : 1)
        )
        .shadow(
            color: Color.black.opacity(isHovered || isActive ? 0.08 : 0),
            radius: isHovered ? 8 : (isActive ? 6 : 0),
            x: 0,
            y: isHovered ? 4 : (isActive ? 2 : 0)
        )
        .scaleEffect(isHovered && !isActive ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.25)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            Button("Use This Version") {
                onUse()
            }
            .disabled(isActive || isUninstalling)

            Button("Copy Path") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(path, forType: .string)
            }

            Button("Reveal in Finder") {
                onOpenFinder()
            }
            
            if canUninstall, let uninstallAction = onUninstall {
                Divider()
                
                Button("Uninstall Version") {
                    uninstallAction()
                }
                .disabled(isActive || isUninstalling)
            }
        }
    }
}

struct ConfigHintView: View {
    let filename: String
    @State private var showCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                Text("Setup Required")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
            }

            HStack(spacing: 12) {
                Text("source ~/.config/devmanager/\(filename)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(NSColor.textBackgroundColor).opacity(0.5))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                    )
                    .textSelection(.enabled)

                Button(action: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(
                        "source ~/.config/devmanager/\(filename)", forType: .string)
                    showCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showCopied = false
                    }
                }) {
                    Image(systemName: showCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .foregroundColor(showCopied ? .green : .secondary)
                .help("Copy to clipboard")
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1),
            alignment: .top
        )
    }
}

// MARK: - Modern Empty State

struct ModernEmptyState: View {
    let iconImage: String
    let title: String
    let message: String
    let color: Color
    let onRefresh: () -> Void
    var onInstallNew: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 20) {
            LanguageIconView(imageName: iconImage, size: 60)
                .opacity(0.5)

            Text(title)
                .font(.headline)
                .foregroundColor(.primary)

            Text(message)
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Button(action: onRefresh) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14))
                        Text("Refresh")
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .tint(color)
                
                if let installAction = onInstallNew {
                    Button(action: installAction) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14))
                            Text("Install New Version")
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(color)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

// MARK: - Version Action Bar

struct VersionActionBar: View {
    let installedCount: Int
    let color: Color
    let onInstallNew: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // 统计信息
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                
                Text("\(installedCount) version\(installedCount == 1 ? "" : "s") installed")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // 新增按钮
            Button(action: onInstallNew) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                    Text("Install New Version")
                        .fontWeight(.medium)
                }
                .font(.callout)
            }
            .buttonStyle(.borderedProminent)
            .tint(color)
            .help("Install new version")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .frame(height: 52)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.15))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}
