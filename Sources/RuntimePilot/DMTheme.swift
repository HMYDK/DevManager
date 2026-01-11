import AppKit
import SwiftUI

enum DMSpace {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let s: CGFloat = 12
    static let m: CGFloat = 16
    static let l: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum DMRadius {
    static let control: CGFloat = 8
    static let card: CGFloat = 12
    static let container: CGFloat = 16
}

enum DMTypography {
    static let title = Font.title
    static let title2 = Font.title2.weight(.bold)
    static let section = Font.headline
    static let body = Font.body
    static let caption = Font.caption
    static let monospaceCaption = Font.system(.caption, design: .monospaced)
}

enum DMColor {
    static let windowBackground = Color(NSColor.windowBackgroundColor)
    static let controlBackground = Color(NSColor.controlBackgroundColor)
    static let textBackground = Color(NSColor.textBackgroundColor)
    static let separator = Color(NSColor.separatorColor)
    static let tertiaryLabel = Color(NSColor.tertiaryLabelColor)
}

struct DMCard<Content: View>: View {
    let accent: Color?
    let isEmphasized: Bool
    let content: Content

    @State private var isHovered = false

    init(accent: Color? = nil, isEmphasized: Bool = false, @ViewBuilder content: () -> Content) {
        self.accent = accent
        self.isEmphasized = isEmphasized
        self.content = content()
    }

    var body: some View {
        content
            .padding(DMSpace.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .overlay(border)
            .shadow(color: shadowColor, radius: isHovered ? 10 : 0, x: 0, y: isHovered ? 4 : 0)
            .scaleEffect(isHovered ? 1.01 : 1)
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.18)) {
                    isHovered = hovering
                }
            }
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: DMRadius.container)
            .fill(backgroundColor)
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: DMRadius.container)
            .stroke(borderColor, lineWidth: 1)
    }

    private var backgroundColor: Color {
        guard let accent else { return DMColor.controlBackground }
        if isEmphasized {
            return accent.opacity(0.10)
        }
        return DMColor.controlBackground
    }

    private var borderColor: Color {
        guard let accent else { return DMColor.separator.opacity(0.8) }
        if isEmphasized {
            return accent.opacity(0.35)
        }
        return DMColor.separator.opacity(0.8)
    }

    private var shadowColor: Color {
        Color.black.opacity(isHovered ? 0.08 : 0)
    }
}

struct DMSection<Content: View>: View {
    let title: String
    let subtitle: String?
    let trailing: AnyView?
    let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        trailing: AnyView? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DMSpace.m) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(DMTypography.section)
                    if let subtitle {
                        Text(subtitle)
                            .font(DMTypography.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if let trailing {
                    trailing
                }
            }

            content
        }
    }
}

struct DMBadge: View {
    let text: String
    let accent: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: DMRadius.control)
                    .fill(accent.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DMRadius.control)
                    .stroke(accent.opacity(0.25), lineWidth: 1)
            )
    }
}

struct DMKeyValueRow: View {
    let key: String
    let value: String
    let isMonospaced: Bool
    let onCopy: (() -> Void)?

    @State private var justCopied = false

    init(key: String, value: String, isMonospaced: Bool = false, onCopy: (() -> Void)? = nil) {
        self.key = key
        self.value = value
        self.isMonospaced = isMonospaced
        self.onCopy = onCopy
    }

    var body: some View {
        HStack(spacing: DMSpace.xs) {
            Text(key)
                .font(DMTypography.caption)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)

            Text(value)
                .font(isMonospaced ? DMTypography.monospaceCaption : DMTypography.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)

            Spacer()

            if let onCopy {
                Button {
                    onCopy()
                    withAnimation(.easeOut(duration: 0.12)) {
                        justCopied = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        withAnimation(.easeOut(duration: 0.12)) {
                            justCopied = false
                        }
                    }
                } label: {
                    Image(systemName: justCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(justCopied ? .green : .secondary)
                .help("Copy")
                .accessibilityLabel("Copy")
            }
        }
    }
}

struct DMCodeBlock: View {
    let text: String
    let onCopy: (() -> Void)?

    @State private var copied = false

    init(text: String, onCopy: (() -> Void)? = nil) {
        self.text = text
        self.onCopy = onCopy
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Text(text)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(.primary)
                .lineSpacing(3)
                .textSelection(.enabled)
                .padding(DMSpace.m)

            Spacer(minLength: 0)

            if let onCopy {
                Button {
                    onCopy()
                    withAnimation(.easeOut(duration: 0.15)) {
                        copied = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        withAnimation(.easeOut(duration: 0.15)) {
                            copied = false
                        }
                    }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: DMRadius.control)
                            .fill((copied ? Color.green : Color.secondary).opacity(0.15))
                            .frame(width: 32, height: 32)

                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(copied ? .green : .secondary)
                    }
                }
                .buttonStyle(.plain)
                .padding(DMSpace.s)
                .help("Copy")
                .accessibilityLabel("Copy")
            }
        }
        .background(
            RoundedRectangle(cornerRadius: DMRadius.container)
                .fill(DMColor.textBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DMRadius.container)
                .stroke(DMColor.separator.opacity(0.9), lineWidth: 1)
        )
    }
}
