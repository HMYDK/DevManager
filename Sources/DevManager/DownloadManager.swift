import Foundation
import SwiftUI
import UserNotifications

// MARK: - Task Status

enum TaskStatus: String, Codable {
    case waiting = "waiting"
    case downloading = "downloading"
    case installing = "installing"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"

    var displayText: String {
        switch self {
        case .waiting: return "Waiting..."
        case .downloading: return "Downloading..."
        case .installing: return "Installing..."
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }

    var isTerminal: Bool {
        self == .completed || self == .failed || self == .cancelled
    }
}

// MARK: - Install Stage

enum InstallStage: String, Codable {
    case idle = ""
    case downloading = "Downloading..."
    case installing = "Installing..."
    case linking = "Linking..."
    case cleanup = "Cleaning up..."
}

// MARK: - Download Task

class DownloadTask: ObservableObject, Identifiable {
    let id = UUID()
    let languageType: VersionInstallViewModel.LanguageType
    let version: String
    let formula: String
    let displayName: String

    @Published var status: TaskStatus
    @Published var progress: Double?
    @Published var currentStage: InstallStage
    @Published var logs: String
    @Published var error: String?

    let createdAt: Date
    var startedAt: Date?
    var completedAt: Date?

    var accentColor: Color {
        switch languageType {
        case .node: return .green
        case .java: return .orange
        case .python: return .indigo
        case .go: return .cyan
        }
    }

    var iconName: String {
        switch languageType {
        case .node: return "node"
        case .java: return "java"
        case .python: return "python"
        case .go: return "go"
        }
    }

    init(
        languageType: VersionInstallViewModel.LanguageType,
        version: String,
        formula: String,
        displayName: String
    ) {
        self.languageType = languageType
        self.version = version
        self.formula = formula
        self.displayName = displayName
        self.status = .waiting
        self.progress = nil
        self.currentStage = .idle
        self.logs = ""
        self.error = nil
        self.createdAt = Date()
    }

    func updateProgress(_ newProgress: Double) {
        DispatchQueue.main.async {
            self.progress = newProgress
        }
    }

    func updateStage(_ stage: InstallStage) {
        DispatchQueue.main.async {
            self.currentStage = stage
        }
    }

    func appendLog(_ log: String) {
        DispatchQueue.main.async {
            self.logs += log
        }
    }

    func updateStatus(_ newStatus: TaskStatus) {
        DispatchQueue.main.async {
            self.status = newStatus
            if newStatus.isTerminal {
                self.completedAt = Date()
            }
        }
    }

    func setError(_ errorMessage: String) {
        DispatchQueue.main.async {
            self.error = errorMessage
            self.status = .failed
            self.completedAt = Date()
        }
    }
}

// MARK: - Download Manager

@MainActor
class DownloadManager: ObservableObject {
    static let shared = DownloadManager()

    @Published var currentTask: DownloadTask?
    @Published var waitingTasks: [DownloadTask] = []
    @Published var completedTasks: [DownloadTask] = []
    @Published var isDownloading = false
    @Published var showNotification = false
    @Published var isExpanded = false

    private var currentExecutingTask: Task<Void, Never>?
    private let maxCompletedTasks = 10

    // 进度更新限流
    private var lastProgressUpdate: Date = .distantPast
    private let progressUpdateInterval: TimeInterval = 0.5
    private var hasRequestedNotificationPermission = false

    private init() {}

    // MARK: - Notification Permission

    /// Check if running as a proper app bundle (not via swift run)
    private var isRunningAsApp: Bool {
        Bundle.main.bundleIdentifier != nil
    }

    private func requestNotificationPermissionIfNeeded() {
        // Skip notification setup when running via swift run (no valid bundle)
        guard isRunningAsApp else {
            print("Skipping notification permission request: not running as app bundle")
            return
        }

        guard !hasRequestedNotificationPermission else { return }
        hasRequestedNotificationPermission = true

        Task {
            do {
                let center = UNUserNotificationCenter.current()
                let granted = try await center.requestAuthorization(options: [
                    .alert, .sound, .badge,
                ])
                print("Notification permission granted: \(granted)")
            } catch {
                print("Notification permission error: \(error)")
            }
        }
    }

    // MARK: - Public Methods

    func addTask(
        languageType: VersionInstallViewModel.LanguageType,
        version: String,
        formula: String,
        displayName: String
    ) -> DownloadTask {
        let task = DownloadTask(
            languageType: languageType,
            version: version,
            formula: formula,
            displayName: displayName
        )

        waitingTasks.append(task)

        // 如果当前没有任务在执行，启动队列
        if currentTask == nil {
            processQueue()
        }

        return task
    }

    func cancelTask(_ task: DownloadTask) {
        if task.id == currentTask?.id {
            // 取消当前执行的任务
            currentExecutingTask?.cancel()
            task.updateStatus(.cancelled)
            moveToCompleted(task)
            currentTask = nil
            currentExecutingTask = nil
            isDownloading = false

            // 继续处理队列
            processQueue()
        } else {
            // 从等待队列中移除
            if let index = waitingTasks.firstIndex(where: { $0.id == task.id }) {
                waitingTasks.remove(at: index)
                task.updateStatus(.cancelled)
                moveToCompleted(task)
            }
        }
    }

    func clearCompleted() {
        completedTasks.removeAll()
    }

    func hideNotification() {
        showNotification = false
        isExpanded = false
    }

    func toggleExpanded() {
        isExpanded.toggle()
    }

    // MARK: - Private Methods

    private func processQueue() {
        guard currentTask == nil, !waitingTasks.isEmpty else {
            // 队列为空且无任务执行，自动隐藏通知（延迟5秒）
            if currentTask == nil && waitingTasks.isEmpty {
                Task {
                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                    if self.currentTask == nil && self.waitingTasks.isEmpty {
                        self.showNotification = false
                        self.isExpanded = false
                    }
                }
            }
            return
        }

        // 请求通知权限（第一次执行任务时）
        requestNotificationPermissionIfNeeded()

        let task = waitingTasks.removeFirst()
        currentTask = task
        isDownloading = true
        showNotification = true

        task.startedAt = Date()
        task.updateStatus(.downloading)
        task.updateStage(.downloading)

        // 执行任务
        currentExecutingTask = Task {
            await executeTask(task)
        }
    }

    private func executeTask(_ task: DownloadTask) async {
        let success = await BrewService.shared.install(formula: task.formula) {
            [weak self, weak task] output in
            guard let self = self, let task = task else { return }

            Task { @MainActor in
                self.processOutput(output, for: task)
            }
        }

        await MainActor.run {
            if success {
                task.updateStatus(.completed)
                sendSystemNotification(task: task, success: true)
            } else {
                task.setError("Installation failed. Check logs for details.")
                sendSystemNotification(task: task, success: false)
            }

            moveToCompleted(task)
            currentTask = nil
            currentExecutingTask = nil
            isDownloading = false

            // 继续处理队列
            processQueue()
        }
    }

    private func processOutput(_ output: String, for task: DownloadTask) {
        // 解析进度百分比
        let percentPattern = #"(\d+\.?\d*)%"#
        if let regex = try? NSRegularExpression(pattern: percentPattern),
            let match = regex.firstMatch(
                in: output, range: NSRange(output.startIndex..., in: output)),
            let range = Range(match.range(at: 1), in: output),
            let percent = Double(output[range])
        {

            // 限流：每0.5秒最多更新一次
            let now = Date()
            if now.timeIntervalSince(lastProgressUpdate) >= progressUpdateInterval {
                task.updateProgress(percent)
                lastProgressUpdate = now
            }
        }

        // 检测安装阶段
        let lowerOutput = output.lowercased()
        if lowerOutput.contains("downloading") || lowerOutput.contains("fetching") {
            task.updateStage(.downloading)
            if task.status != .downloading {
                task.updateStatus(.downloading)
            }
        } else if lowerOutput.contains("pouring") || lowerOutput.contains("installing") {
            task.updateStage(.installing)
            if task.status != .installing {
                task.updateStatus(.installing)
            }
        } else if lowerOutput.contains("linking") || lowerOutput.contains("symlink") {
            task.updateStage(.linking)
        } else if lowerOutput.contains("cleaning") || lowerOutput.contains("removing") {
            task.updateStage(.cleanup)
        }

        // 过滤并添加日志
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if trimmed.allSatisfy({ $0 == "#" || $0 == " " }) { continue }
            if trimmed.range(of: #"^\d+\.?\d*%$"#, options: .regularExpression) != nil { continue }

            if !trimmed.contains("###") {
                task.appendLog(line + "\n")
            }
        }
    }

    private func moveToCompleted(_ task: DownloadTask) {
        completedTasks.insert(task, at: 0)

        // 保持最多10个已完成任务
        if completedTasks.count > maxCompletedTasks {
            completedTasks = Array(completedTasks.prefix(maxCompletedTasks))
        }
    }

    private func sendSystemNotification(task: DownloadTask, success: Bool) {
        // Skip notification when running via swift run (no valid bundle)
        guard isRunningAsApp else {
            let status = success ? "completed" : "failed"
            print("[Notification skipped] \(task.displayName) installation \(status)")
            return
        }

        let content = UNMutableNotificationContent()

        if success {
            content.title = "Installation Complete"
            content.body = "\(task.displayName) has been successfully installed."
            content.sound = .default
        } else {
            content.title = "Installation Failed"
            content.body =
                "Failed to install \(task.displayName). \(task.error ?? "Check logs for details.")"
            content.sound = .defaultCritical
        }

        // 添加用户信息，用于点击通知时的处理
        let languageTypeString: String
        switch task.languageType {
        case .node: languageTypeString = "node"
        case .java: languageTypeString = "java"
        case .python: languageTypeString = "python"
        case .go: languageTypeString = "go"
        }

        content.userInfo = [
            "languageType": languageTypeString,
            "taskId": task.id.uuidString,
        ]

        let request = UNNotificationRequest(
            identifier: task.id.uuidString,
            content: content,
            trigger: nil  // 立即显示
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error)")
            }
        }
    }
}
