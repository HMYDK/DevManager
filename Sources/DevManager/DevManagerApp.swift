import SwiftUI

@main
struct DevManagerApp: App {
    @StateObject private var javaManager = JavaManager()
    @StateObject private var nodeManager = NodeManager()
    @StateObject private var pythonManager = PythonManager()
    @StateObject private var goManager = GoManager()

    var body: some Scene {
        WindowGroup {
            ContentView(
                javaManager: javaManager,
                nodeManager: nodeManager,
                pythonManager: pythonManager,
                goManager: goManager
            )
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.automatic)
        .commands {
            SidebarCommands()

            // About 菜单
            CommandGroup(replacing: .appInfo) {
                Button("About DevManager") {
                    NSApplication.shared.orderFrontStandardAboutPanel(
                        options: [
                            .applicationName: "DevManager",
                            .applicationVersion: "1.0.0",
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
                    javaManager.refresh()
                    nodeManager.refresh()
                    pythonManager.refresh()
                    goManager.refresh()
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
