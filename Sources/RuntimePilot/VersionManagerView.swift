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
    @Published var errorMessage: String? = nil  // 错误信息
    @Published var operationResult: OperationResult? = nil  // 操作结果
    @Published var installingFormula: String? = nil  // 正在安装的formula
    @Published var currentStage: InstallStage = .idle  // 当前安装阶段

    enum OperationResult {
        case success(String)  // 成功消息
        case failure(String)  // 失败消息
    }

    enum InstallStage: String {
        case idle = ""
        case downloading = "Downloading..."
        case installing = "Installing..."
        case linking = "Linking..."
        case cleanup = "Cleaning up..."
    }

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
        errorMessage = nil
        defer { isLoading = false }

        let brew = BrewService.shared

        guard brew.isAvailable else {
            errorMessage =
                "Homebrew is not installed or not found in PATH. Please install Homebrew first."
            remoteVersions = []
            return
        }

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

        // 如果获取到空数组，设置错误信息
        if remoteVersions.isEmpty && errorMessage == nil {
            errorMessage =
                "No versions found. This might be due to:\n• Network connectivity issues\n• Homebrew formula repository not updated\n• No matching formulae available\n\nTry running 'brew update' in Terminal."
        }
    }

    func install(version: RemoteVersion) {
        // 使用 DownloadManager 处理安装
        _ = DownloadManager.shared.addTask(
            languageType: language,
            version: version.version,
            formula: version.formula,
            displayName: version.displayName
        )
        operationResult = .success("Added to download queue")
    }

    func uninstall(version: RemoteVersion) async -> Bool {
        isInstalling = true
        installingFormula = version.formula
        currentOperation = "Uninstalling \(version.displayName)..."
        installProgress = ""
        downloadProgress = nil
        operationResult = nil
        currentStage = .cleanup

        let success = await BrewService.shared.uninstall(formula: version.formula) { output in
            self.processOutput(output)
        }

        isInstalling = false
        installingFormula = nil
        currentOperation = nil
        currentStage = .idle

        if success {
            operationResult = .success("\(version.displayName) uninstalled successfully")
        } else {
            operationResult = .failure(
                "Failed to uninstall \(version.displayName). Check the log for details.")
        }

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

        // 检测安装阶段
        let lowerOutput = output.lowercased()
        if lowerOutput.contains("downloading") || lowerOutput.contains("fetching") {
            currentStage = .downloading
        } else if lowerOutput.contains("pouring") || lowerOutput.contains("installing") {
            currentStage = .installing
        } else if lowerOutput.contains("linking") || lowerOutput.contains("symlink") {
            currentStage = .linking
        } else if lowerOutput.contains("cleaning") || lowerOutput.contains("removing") {
            currentStage = .cleanup
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

    func clearResult() {
        operationResult = nil
        downloadProgress = nil
    }
}

// MARK: - 版本管理 Sheet 视图

struct VersionManagerSheet: View {
    @ObservedObject var viewModel: VersionInstallViewModel
    let onDismiss: () -> Void
    let onComplete: () -> Void

    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastIsSuccess = true
    @State private var refreshId = UUID()

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
                        .focused($isSearchFocused)
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

                        if let errorMessage = viewModel.errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }

                        Button("Retry") {
                            Task {
                                await viewModel.fetchVersions()
                            }
                        }
                        .buttonStyle(.bordered)
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredVersions) { version in
                                RemoteVersionRow(
                                    version: version,
                                    isOperating: viewModel.isInstalling,
                                    isCurrentlyInstalling: viewModel.installingFormula
                                        == version.formula,
                                    accent: viewModel.accentColor,
                                    onInstall: {
                                        viewModel.install(version: version)
                                        showToast = true
                                        toastMessage = "Added to download queue"
                                        toastIsSuccess = true

                                        // Auto hide toast
                                        Task {
                                            try? await Task.sleep(nanoseconds: 3_000_000_000)
                                            showToast = false
                                        }

                                        // Refresh versions
                                        Task {
                                            await viewModel.fetchVersions()
                                            onComplete()
                                        }
                                    },
                                    onUninstall: {
                                        Task {
                                            let success = await viewModel.uninstall(
                                                version: version)
                                            if success {
                                                showToast = true
                                                toastMessage =
                                                    "\(version.displayName) uninstalled successfully"
                                                toastIsSuccess = true
                                                await viewModel.fetchVersions()
                                                onComplete()
                                            } else {
                                                showToast = true
                                                toastMessage =
                                                    "Failed to uninstall \(version.displayName)"
                                                toastIsSuccess = false
                                            }

                                            // Auto hide toast
                                            Task {
                                                try? await Task.sleep(nanoseconds: 3_000_000_000)
                                                showToast = false
                                            }
                                        }
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }

            }
        }
        .frame(minWidth: 750, idealWidth: 800, minHeight: 550, idealHeight: 650)
        .overlay(
            // Toast notification
            Group {
                if showToast {
                    ToastView(
                        message: toastMessage,
                        isSuccess: toastIsSuccess,
                        isShowing: $showToast
                    )
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showToast),
            alignment: .bottom
        )
        .onAppear {
            DispatchQueue.main.async {
                isSearchFocused = true
            }
            // 每次 sheet 打开时生成新的 refreshId，强制重新获取版本
            refreshId = UUID()
        }
        .task(id: refreshId) {
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
    let isCurrentlyInstalling: Bool  // 是否正在安装此版本
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

                if isCurrentlyInstalling {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "cube.box.fill")
                        .font(.system(size: 24))
                        .foregroundColor(accent)
                }
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

            if isCurrentlyInstalling {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Installing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if version.isInstalled {
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

// MARK: - Toast View

struct ToastView: View {
    let message: String
    let isSuccess: Bool
    @Binding var isShowing: Bool

    var body: some View {
        if isShowing {
            HStack(spacing: 12) {
                Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(isSuccess ? .green : .red)
                    .font(.system(size: 20))

                Text(message)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(isSuccess ? .green : .red)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.1), radius: 10, y: 4)
            .padding(.bottom, 20)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
