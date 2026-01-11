import SwiftUI

// MARK: - Global Download Notification

struct GlobalDownloadNotification: View {
    @ObservedObject var manager: DownloadManager
    
    var body: some View {
        VStack(spacing: 0) {
            if manager.showNotification {
                NotificationBar(manager: manager)
                    .transition(.move(edge: .top).combined(with: .opacity))
                
                if manager.isExpanded {
                    ExpandedPanel(manager: manager)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: manager.showNotification)
        .animation(.easeOut(duration: 0.25), value: manager.isExpanded)
    }
}

// MARK: - Notification Bar (简洁模式)

struct NotificationBar: View {
    @ObservedObject var manager: DownloadManager
    
    var body: some View {
        HStack(spacing: 16) {
            // 左侧：语言图标 + 版本名称
            if let task = manager.currentTask {
                HStack(spacing: 12) {
                    // 图标
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(task.accentColor.opacity(0.15))
                            .frame(width: 32, height: 32)
                        
                        LanguageIconView(imageName: task.iconName, size: 20)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(task.displayName)
                            .font(.callout)
                            .fontWeight(.medium)
                        
                        Text(task.formula)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // 中间：进度条 + 阶段文本 + 百分比
            if let task = manager.currentTask {
                VStack(spacing: 4) {
                    HStack {
                        Text(task.currentStage.rawValue.isEmpty ? task.status.displayText : task.currentStage.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if let progress = task.progress {
                            Text(String(format: "%.1f%%", progress))
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 180)
                    
                    if let progress = task.progress {
                        ProgressView(value: progress, total: 100)
                            .progressViewStyle(.linear)
                            .tint(task.accentColor)
                            .frame(height: 4)
                            .frame(width: 180)
                    } else {
                        ProgressView()
                            .progressViewStyle(.linear)
                            .tint(task.accentColor)
                            .frame(height: 4)
                            .frame(width: 180)
                    }
                }
            }
            
            Spacer()
            
            // 右侧：展开/收起按钮 + 关闭按钮
            HStack(spacing: 8) {
                Button {
                    manager.toggleExpanded()
                } label: {
                    Image(systemName: manager.isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help(manager.isExpanded ? "Collapse" : "Expand")
                
                Button {
                    manager.hideNotification()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Hide (task continues in background)")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(height: 56)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

// MARK: - Expanded Panel (详细模式)

struct ExpandedPanel: View {
    @ObservedObject var manager: DownloadManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 上部：当前任务详情
            if let task = manager.currentTask {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Current Task")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button {
                            manager.cancelTask(task)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.circle")
                                Text("Cancel")
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(task.accentColor.opacity(0.15))
                                .frame(width: 40, height: 40)
                            
                            LanguageIconView(imageName: task.iconName, size: 24)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(task.displayName)
                                .font(.callout)
                                .fontWeight(.medium)
                            
                            HStack(spacing: 8) {
                                Text(task.formula)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                StatusBadge(status: task.status, color: task.accentColor)
                            }
                        }
                        
                        Spacer()
                    }
                }
                .padding(.bottom, 8)
            }
            
            Divider()
            
            // 中部：日志输出区
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Installation Log")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    if let task = manager.currentTask, !task.logs.isEmpty {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(task.logs, forType: .string)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.doc")
                                Text("Copy")
                            }
                            .font(.caption)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                if let task = manager.currentTask {
                    ScrollViewReader { proxy in
                        ScrollView {
                            Text(task.logs.isEmpty ? "Waiting for output..." : task.logs)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                                .id("logBottom")
                        }
                        .frame(height: 150)
                        .padding(12)
                        .background(Color(NSColor.textBackgroundColor).opacity(0.5))
                        .cornerRadius(8)
                        .onChange(of: task.logs) { _ in
                            withAnimation {
                                proxy.scrollTo("logBottom", anchor: .bottom)
                            }
                        }
                    }
                }
            }
            
            // 下部：任务队列列表
            if !manager.waitingTasks.isEmpty {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Waiting Queue (\(manager.waitingTasks.count))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(Array(manager.waitingTasks.prefix(3))) { task in
                                QueueTaskRow(task: task, onCancel: {
                                    manager.cancelTask(task)
                                })
                            }
                            
                            if manager.waitingTasks.count > 3 {
                                Text("+ \(manager.waitingTasks.count - 3) more tasks...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                }
            }
        }
        .padding(20)
        .frame(maxHeight: 400)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

// MARK: - Supporting Views

struct StatusBadge: View {
    let status: TaskStatus
    let color: Color
    
    var body: some View {
        Text(status.displayText)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeColor)
            .cornerRadius(4)
    }
    
    private var badgeColor: Color {
        switch status {
        case .waiting: return .gray
        case .downloading, .installing: return color
        case .completed: return .green
        case .failed: return .red
        case .cancelled: return .secondary
        }
    }
}

struct QueueTaskRow: View {
    @ObservedObject var task: DownloadTask
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(task.accentColor.opacity(0.15))
                    .frame(width: 28, height: 28)
                
                LanguageIconView(imageName: task.iconName, size: 16)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(task.formula)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            StatusBadge(status: task.status, color: task.accentColor)
            
            Button {
                onCancel()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Cancel")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
    }
}
