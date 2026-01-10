import SwiftUI

// MARK: - 版本管理视图模型

@MainActor
class VersionInstallViewModel: ObservableObject {
    @Published var remoteVersions: [RemoteVersion] = []
    @Published var isLoading = false
    @Published var isInstalling = false
    @Published var installProgress: String = ""
    @Published var currentOperation: String?
    @Published var downloadProgress: Double? = nil  // 下载进度 0-100

    let language: LanguageType

    enum LanguageType {
        case node, java, python, go
    }

    init(language: LanguageType) {
        self.language = language
    }

    var accentColor: Color {
        switch language {
        case .node: return .green
        case .java: return .orange
        case .python: return .indigo
        case .go: return .cyan
        }
    }

    func fetchVersions() async {
        isLoading = true
        defer { isLoading = false }

        let brew = BrewService.shared

        switch language {
        case .node:
            remoteVersions = await brew.fetchNodeVersions()
        case .java:
            remoteVersions = await brew.fetchJavaVersions()
        case .python:
            remoteVersions = await brew.fetchPythonVersions()
        case .go:
            remoteVersions = await brew.fetchGoVersions()
        }
    }

    func install(version: RemoteVersion) async -> Bool {
        isInstalling = true
        currentOperation = "Installing \(version.displayName)..."
        installProgress = ""
        downloadProgress = nil

        let success = await BrewService.shared.install(formula: version.formula) { output in
            self.processOutput(output)
        }

        isInstalling = false
        currentOperation = nil
        downloadProgress = nil

        return success
    }

    func uninstall(version: RemoteVersion) async -> Bool {
        isInstalling = true
        currentOperation = "Uninstalling \(version.displayName)..."
        installProgress = ""
        downloadProgress = nil

        let success = await BrewService.shared.uninstall(formula: version.formula) { output in
            self.processOutput(output)
        }

        isInstalling = false
        currentOperation = nil
        downloadProgress = nil

        return success
    }

    private func processOutput(_ output: String) {
        // 解析进度百分比 (如 "3.5%", "100.0%")
        let percentPattern = #"(\d+\.?\d*)%"#
        if let regex = try? NSRegularExpression(pattern: percentPattern),
            let match = regex.firstMatch(
                in: output, range: NSRange(output.startIndex..., in: output)),
            let range = Range(match.range(at: 1), in: output),
            let percent = Double(output[range])
        {
            downloadProgress = percent
        }

        // 过滤掉进度行 (包含 # 或纯百分比的行)
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // 跳过只包含 # 符号或百分比的行
            if trimmed.isEmpty { continue }
            if trimmed.allSatisfy({ $0 == "#" || $0 == " " }) { continue }
            if trimmed.range(of: #"^\d+\.?\d*%$"#, options: .regularExpression) != nil { continue }

            // 保留有意义的输出
            if !trimmed.contains("###") {
                installProgress += line + "\n"
            }
        }
    }
}

// MARK: - 版本管理 Sheet 视图

struct VersionManagerSheet: View {
    @ObservedObject var viewModel: VersionInstallViewModel
    let onDismiss: () -> Void
    let onComplete: () -> Void

    @State private var showProgress = false
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Manage Versions")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Install or uninstall via Homebrew")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    TextField("Search", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 240)
                        .disabled(viewModel.isInstalling)

                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isInstalling)
                    .accessibilityLabel("Close")
                }
            }
            .padding(20)
            .background(.ultraThinMaterial)
            .overlay(
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 1),
                alignment: .bottom
            )

            Divider()

            if !BrewService.shared.isAvailable {
                // Homebrew 未安装提示
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)

                    Text("Homebrew Not Found")
                        .font(.headline)

                    Text("Please install Homebrew first to manage versions.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Link("Install Homebrew", destination: URL(string: "https://brew.sh")!)
                        .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if viewModel.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading available versions...")
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 版本列表
                if viewModel.remoteVersions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "shippingbox")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))

                        Text("No versions available")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredVersions) { version in
                                RemoteVersionRow(
                                    version: version,
                                    isOperating: viewModel.isInstalling,
                                    accent: viewModel.accentColor,
                                    onInstall: {
                                        Task {
                                            showProgress = true
                                            let success = await viewModel.install(version: version)
                                            if success {
                                                await viewModel.fetchVersions()
                                                onComplete()
                                            }
                                        }
                                    },
                                    onUninstall: {
                                        Task {
                                            showProgress = true
                                            let success = await viewModel.uninstall(
                                                version: version)
                                            if success {
                                                await viewModel.fetchVersions()
                                                onComplete()
                                            }
                                        }
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }

                // 操作进度区域
                if viewModel.isInstalling || showProgress {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Spacer()
                            Button {
                                showProgress = false
                                viewModel.installProgress = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .disabled(viewModel.isInstalling)
                            .accessibilityLabel("Close progress")
                        }

                        if let operation = viewModel.currentOperation {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text(operation)
                                    .font(.callout)
                                    .fontWeight(.medium)
                            }
                        }

                        // 下载进度条
                        if let progress = viewModel.downloadProgress {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Downloading...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(String(format: "%.1f%%", progress))
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                }

                                ProgressView(value: progress, total: 100)
                                    .progressViewStyle(.linear)
                                    .tint(viewModel.accentColor)
                                    .frame(height: 6)
                            }
                        }

                        // 日志输出
                        if !viewModel.installProgress.isEmpty {
                            ScrollViewReader { proxy in
                                ScrollView {
                                    Text(viewModel.installProgress)
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .id("bottom")
                                }
                                .onChange(of: viewModel.installProgress) { _ in
                                    withAnimation {
                                        proxy.scrollTo("bottom", anchor: .bottom)
                                    }
                                }
                            }
                            .frame(minHeight: 60, maxHeight: 120)
                            .padding(12)
                            .background(Color(NSColor.textBackgroundColor).opacity(0.5))
                            .cornerRadius(8)
                        }
                    }
                    .padding(20)
                    .frame(minHeight: 120, maxHeight: 200)
                    .background(.ultraThinMaterial)
                    .overlay(
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 1),
                        alignment: .top
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .frame(minWidth: 750, idealWidth: 800, minHeight: 550, idealHeight: 650)
        .animation(.easeInOut(duration: 0.3), value: viewModel.isInstalling)
        .animation(.easeInOut(duration: 0.3), value: showProgress)
        .task {
            await viewModel.fetchVersions()
        }
    }

    private var filteredVersions: [RemoteVersion] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return viewModel.remoteVersions }

        return viewModel.remoteVersions.filter { version in
            version.displayName.localizedCaseInsensitiveContains(trimmed)
                || version.formula.localizedCaseInsensitiveContains(trimmed)
        }
    }
}

// MARK: - 远程版本行

struct RemoteVersionRow: View {
    let version: RemoteVersion
    let isOperating: Bool
    let accent: Color
    let onInstall: () -> Void
    let onUninstall: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 16) {
            // 图标区域
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(accent.opacity(0.12))
                    .frame(width: 48, height: 48)

                Image(systemName: "cube.box.fill")
                    .font(.system(size: 24))
                    .foregroundColor(accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(version.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)

                Text(version.formula)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)

                // 描述信息
                if !version.formula.isEmpty {
                    Text("Homebrew formula")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if version.isInstalled {
                HStack(spacing: 8) {
                    Text("Installed")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(accent)
                        .cornerRadius(6)

                    Button(action: onUninstall) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderless)
                    .disabled(isOperating)
                    .help("Uninstall")
                }
            } else {
                Button(action: onInstall) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle")
                        Text("Install")
                    }
                    .font(.callout)
                }
                .buttonStyle(.bordered)
                .fixedSize()
                .disabled(isOperating)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    isHovered
                        ? Color(NSColor.controlBackgroundColor).opacity(1.2)
                        : Color(NSColor.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isHovered ? Color.gray.opacity(0.4) : Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: isHovered ? Color.black.opacity(0.1) : Color.clear, radius: 6, y: 3)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.25)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - 管理按钮组件

struct ManageVersionsButton: View {
    let language: VersionInstallViewModel.LanguageType
    let onRefresh: () -> Void

    @State private var showSheet = false
    @StateObject private var viewModel: VersionInstallViewModel

    init(language: VersionInstallViewModel.LanguageType, onRefresh: @escaping () -> Void) {
        self.language = language
        self.onRefresh = onRefresh
        self._viewModel = StateObject(wrappedValue: VersionInstallViewModel(language: language))
    }

    var body: some View {
        Button {
            showSheet = true
        } label: {
            Image(systemName: "plus.circle")
        }
        .help("Install/Uninstall Versions")
        .sheet(isPresented: $showSheet) {
            VersionManagerSheet(
                viewModel: viewModel,
                onDismiss: { showSheet = false },
                onComplete: { onRefresh() }
            )
        }
    }
}
