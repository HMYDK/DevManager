import SwiftUI
import AppKit

struct NodeView: View {
    @ObservedObject var manager: NodeManager
    
    @State private var selection = Set<NodeVersion.ID>()
    
    private var displayedVersions: [NodeVersion] {
        var sorted = manager.installedVersions.sorted { lhs, rhs in
            compareVersionDescending(lhs.version, rhs.version)
        }
        
        if let active = manager.activeVersion {
            sorted.removeAll(where: { $0.id == active.id })
            return [active] + sorted
        }
        
        return sorted
    }
    
    private var selectedRow: NodeVersion? {
        guard let id = selection.first else { return nil }
        return manager.installedVersions.first(where: { $0.id == id })
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            if manager.installedVersions.isEmpty {
                emptyState
            } else {
                table
            }
            
            ConfigHintView(filename: "node_env.sh")
        }
        .navigationTitle("Node.js")
        .toolbar {
            ToolbarItemGroup {
                Button {
                    manager.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                
                Button {
                    if let version = selectedRow {
                        manager.setActive(version)
                    }
                } label: {
                    Text("Use")
                }
                .disabled(selectedRow == nil || selectedRow?.id == manager.activeVersion?.id)
            }
        }
        .onChange(of: selection) { newValue in
            if newValue.count > 1, let first = newValue.first {
                selection = [first]
            }
        }
        .onChange(of: manager.activeVersion?.id) { _ in
            if let id = manager.activeVersion?.id {
                selection = [id]
            } else if let first = displayedVersions.first?.id {
                selection = [first]
            }
        }
        .onAppear {
            if let id = manager.activeVersion?.id {
                selection = [id]
            } else if let first = displayedVersions.first?.id {
                selection = [first]
            }
        }
    }
    
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Node.js")
                    .font(.title2.weight(.semibold))
                
                if let active = manager.activeVersion {
                    HStack(spacing: 8) {
                        Text("Current")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.green)
                            .cornerRadius(6)
                        
                        Text(active.version)
                            .font(.callout.weight(.semibold))
                        
                        Text(active.source)
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    Text(active.path)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text("No selection. Pick a version to generate node_env.sh.")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
    
    private var table: some View {
        Table(displayedVersions, selection: $selection) {
            TableColumn("") { version in
                if manager.activeVersion?.id == version.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary.opacity(0.25))
                }
            }
            .width(28)
            
            TableColumn("Version") { version in
                Text(version.version)
                    .font(.callout.weight(.semibold))
                    .onTapGesture(count: 2) {
                        manager.setActive(version)
                    }
            }
            .width(min: 120, ideal: 140)
            
            TableColumn("Source") { version in
                Text(version.source)
                    .foregroundColor(.secondary)
            }
            .width(min: 90, ideal: 110)
            
            TableColumn("Path") { version in
                Text(version.path)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            TableColumn("Actions") { version in
                HStack(spacing: 8) {
                    Button("Use") {
                        manager.setActive(version)
                    }
                    .buttonStyle(.borderless)
                    .disabled(manager.activeVersion?.id == version.id)
                    
                    Button {
                        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: version.path)])
                    } label: {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.borderless)
                    .help("Open in Finder")
                }
            }
            .width(min: 140, ideal: 160)
        }
        .contextMenu(forSelectionType: NodeVersion.ID.self) { ids in
            if let id = ids.first, let version = manager.installedVersions.first(where: { $0.id == id }) {
                Button("Use This Version") {
                    manager.setActive(version)
                }
                
                Button("Copy Path") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(version.path, forType: .string)
                }
                
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: version.path)])
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "hexagon")
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            Text("No Node.js versions found")
                .font(.headline)
            Text("Install via Homebrew or NVM, then refresh.")
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
