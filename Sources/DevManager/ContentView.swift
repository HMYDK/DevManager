import AppKit
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

    var iconImage: String {
        switch self {
        case .java: return "java"
        case .node: return "nodejs"
        case .python: return "python"
        case .go: return "go"
        }
    }

    var color: Color {
        switch self {
        case .java: return .orange
        case .node: return .green
        case .python: return .indigo
        case .go: return .cyan
        }
    }
}

struct ContentView: View {
    @ObservedObject var javaManager: JavaManager
    @ObservedObject var nodeManager: NodeManager
    @ObservedObject var pythonManager: PythonManager
    @ObservedObject var goManager: GoManager

    @State private var selection: NavigationItem? = .java
    @State private var hoveredItem: NavigationItem? = nil

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    ForEach(NavigationItem.allCases) { item in
                        NavigationLink(value: item) {
                            HStack(spacing: 10) {
                                if let url = Bundle.module.url(
                                    forResource: item.iconImage, withExtension: "png"),
                                    let nsImage = NSImage(contentsOf: url)
                                {
                                    Image(nsImage: nsImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 20, height: 20)
                                }

                                Text(item.title)
                                    .font(.body)
                                    .fontWeight(.medium)
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        selection == item ? item.color.opacity(0.15) : Color.clear)

                                if selection == item {
                                    HStack {
                                        Rectangle()
                                            .fill(item.color)
                                            .frame(width: 3)
                                        Spacer()
                                    }
                                }
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    }
                } header: {
                    Text("Dev Environments")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
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
                VStack(spacing: 16) {
                    Image(systemName: "app.dashed")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Select a language")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: 800, idealWidth: 1200, minHeight: 600, idealHeight: 800)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
