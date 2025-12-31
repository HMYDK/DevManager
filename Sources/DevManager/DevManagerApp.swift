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
        .windowStyle(.hiddenTitleBar) // Modern look
        .windowResizability(.automatic)
        .commands {
            SidebarCommands() // Enable sidebar toggle
        }
    }
}
