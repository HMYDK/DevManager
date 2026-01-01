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

// MARK: - Legacy Version Card (kept for compatibility)

struct VersionCard: View {
    let version: String
    let path: String
    let isActive: Bool
    var badge: String? = nil
    let icon: String
    let color: Color
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isActive ? color.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isActive ? color : .gray)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(version)
                        .font(.headline)

                    if let badge = badge {
                        Text(badge)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                    }

                    if isActive {
                        Text("Current")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(color)
                            .cornerRadius(4)
                    }
                }

                Text(path)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(color)
            } else {
                Button("Use") {
                    action()
                }
                .buttonStyle(.bordered)
                .tint(color)
                .opacity(isHovered ? 1 : 0)
            }
        }
        .padding()
        .background(isActive ? color.opacity(0.05) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? color.opacity(0.5) : Color.clear, lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
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

// MARK: - Modern Header View

struct ModernHeaderView: View {
    let title: String
    let iconImage: String
    let color: Color
    let activeVersion: String?
    let activeSource: String?
    let activePath: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title with icon
            HStack(spacing: 12) {
                LanguageIconView(imageName: iconImage, size: 32)

                Text(title)
                    .font(.title)
                    .fontWeight(.bold)
            }

            // Active version card or empty state
            if let version = activeVersion, let source = activeSource, let path = activePath {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("Current Version")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(color)
                            .cornerRadius(6)

                        Text(version)
                            .font(.headline)
                            .fontWeight(.bold)
                    }

                    SourceTagView(source: source)

                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)

                        Text(path)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .padding(16)
                .frame(maxWidth: 600, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [color.opacity(0.08), color.opacity(0.12)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
                .overlay(
                    Rectangle()
                        .fill(color)
                        .frame(width: 4),
                    alignment: .leading
                )
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("No version selected")
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        Text("Choose a version to generate environment configuration")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(16)
                .frame(maxWidth: 600)
                .background(Color.secondary.opacity(0.05))
                .cornerRadius(12)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1),
            alignment: .bottom
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

// MARK: - Uninstall Confirmation Dialog

struct UninstallConfirmationDialog: View {
    let version: String
    let source: String
    let path: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon and Title
            VStack(spacing: 12) {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.red)
                
                Text("Confirm Uninstall")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            // Version Information
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Text("Version:")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Text(version)
                        .font(.callout)
                        .fontWeight(.medium)
                }
                
                HStack(spacing: 8) {
                    Text("Source:")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Text(source)
                        .font(.callout)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Path:")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Text(path)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.05))
            .cornerRadius(8)
            
            // Warning Message
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("This action cannot be undone.")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
            
            // Action Buttons
            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Text("Cancel")
                        .frame(minWidth: 100)
                }
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
                
                Button(action: onConfirm) {
                    Text("Uninstall")
                        .frame(minWidth: 100)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 400)
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
