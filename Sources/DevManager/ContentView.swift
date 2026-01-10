import AppKit
import SwiftUI

enum NavigationItem: String, CaseIterable, Identifiable {
    case dashboard
    case java
    case node
    case python
    case go

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .java: return "Java JDK"
        case .node: return "Node.js"
        case .python: return "Python"
        case .go: return "Go"
        }
    }

    var iconImage: String {
        switch self {
        case .dashboard: return "" // Dashboard uses SF Symbol
        case .java: return "java"
        case .node: return "nodejs"
        case .python: return "python"
        case .go: return "go"
        }
    }
    
    var iconSymbol: String? {
        switch self {
        case .dashboard: return "chart.bar.horizontal.fill"
        default: return nil
        }
    }

    var color: Color {
        switch self {
        case .dashboard: return .blue
        case .java: return .orange
        case .node: return .green
        case .python: return .indigo
        case .go: return .cyan
        }
    }
}

struct ContentView: View {
    @ObservedObject var registry: LanguageRegistry
    @StateObject private var dashboardViewModel: DashboardViewModel

    enum Route: Hashable {
        case dashboard
        case language(String)
    }

    @State private var selection: Route? = .dashboard
    
    init(registry: LanguageRegistry) {
        self.registry = registry
        _dashboardViewModel = StateObject(wrappedValue: DashboardViewModel(registry: registry))
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section {
                    // Dashboard
                    NavigationLink(value: Route.dashboard) {
                        HStack(spacing: 10) {
                            Image(systemName: "chart.bar.horizontal.fill")
                                .font(.system(size: 16))
                                .frame(width: 20, height: 20)

                            Text("Dashboard")
                                .font(.body)
                                .fontWeight(.medium)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    selection == .dashboard ? Color.blue.opacity(0.15) : Color.clear)

                            if selection == .dashboard {
                                HStack {
                                    Rectangle()
                                        .fill(Color.blue)
                                        .frame(width: 3)
                                    Spacer()
                                }
                            }
                        }
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    
                    // 语言项
                    ForEach(registry.allLanguages) { language in
                        let metadata = language.metadata
                        NavigationLink(value: Route.language(metadata.id)) {
                            HStack(spacing: 10) {
                                if let url = Bundle.module.url(
                                    forResource: metadata.iconName, withExtension: "png"),
                                    let nsImage = NSImage(contentsOf: url)
                                {
                                    Image(nsImage: nsImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 20, height: 20)
                                }

                                Text(metadata.displayName)
                                    .font(.body)
                                    .fontWeight(.medium)
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowBackground(
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        selection == .language(metadata.id) ? metadata.color.opacity(0.15) : Color.clear)

                                if selection == .language(metadata.id) {
                                    HStack {
                                        Rectangle()
                                            .fill(metadata.color)
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
            if selection == .dashboard {
                DashboardView(
                    viewModel: dashboardViewModel,
                    selection: $selection
                )
            } else if case .language(let languageId) = selection,
                      let language = registry.getLanguage(for: languageId)
            {
                GenericLanguageView(
                    metadata: language.metadata,
                    manager: language.manager
                )
            } else {
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
