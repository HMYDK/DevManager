import SwiftUI

enum NavigationItem: String, CaseIterable, Identifiable {
    case java
    case node
    case python
    case go
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .java: return "Java JDK"
        case .node: return "Node.js"
        case .python: return "Python"
        case .go: return "Go"
        }
    }
    
    var icon: String {
        switch self {
        case .java: return "cup.and.saucer"
        case .node: return "hexagon"
        case .python: return "p.circle"
        case .go: return "g.circle"
        }
    }
}

struct ContentView: View {
    @ObservedObject var javaManager: JavaManager
    @ObservedObject var nodeManager: NodeManager
    @ObservedObject var pythonManager: PythonManager
    @ObservedObject var goManager: GoManager
    
    @State private var selection: NavigationItem? = .java
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section(header: Text("Dev Environments")) {
                    ForEach(NavigationItem.allCases) { item in
                        NavigationLink(value: item) {
                            Label(item.title, systemImage: item.icon)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
            .navigationTitle("DevManager")
        } detail: {
            switch selection {
            case .java:
                JavaView(manager: javaManager)
            case .node:
                NodeView(manager: nodeManager)
            case .python:
                PythonView(manager: pythonManager)
            case .go:
                GoView(manager: goManager)
            case .none:
                Text("Select a language")
                    .foregroundColor(.secondary)
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
