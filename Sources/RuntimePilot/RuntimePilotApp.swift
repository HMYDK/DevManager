import SwiftUI

// MARK: - App Version

enum AppInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    static var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
}

@main
struct RuntimePilotApp: App {
    @StateObject private var javaManager = JavaManager()
    @StateObject private var nodeManager = NodeManager()
    @StateObject private var pythonManager = PythonManager()
    @StateObject private var goManager = GoManager()
    @StateObject private var registry = LanguageRegistry()

    init() {
        // 注册所有语言
        setupRegistry()
    }

    private func setupRegistry() {
        // 注意:这里在init中调用,需要延迟到body中执行
    }

    var body: some Scene {
        WindowGroup {
            ContentView(registry: registry)
                .onAppear {
                    // 在视图出现时注册语言
                    registry.register(metadata: .java, manager: javaManager)
                    registry.register(metadata: .node, manager: nodeManager)
                    registry.register(metadata: .python, manager: pythonManager)
                    registry.register(metadata: .go, manager: goManager)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.automatic)
        .commands {
            SidebarCommands()

            // About 菜单
            CommandGroup(replacing: .appInfo) {
                Button("About RuntimePilot") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            .applicationName: "RuntimePilot",
                            .applicationVersion: AppInfo.version,
                            .credits: NSAttributedString(string: "Development Environment Manager"),
                        ]
                    )
                }
            }

            // 移除不需要的菜单项
            CommandGroup(replacing: .newItem) {}

            // Tools 菜单
            CommandMenu("Tools") {
                Button("Refresh All") {
                    // 刷新所有已注册的语言
                    for language in registry.allLanguages {
                        language.manager.refresh()
                    }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
