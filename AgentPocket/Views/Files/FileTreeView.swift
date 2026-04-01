import SwiftUI

struct FileTreeView: View {
    let path: String
    let fileService: FileService
    let onFileSelected: (String) -> Void
    
    @Environment(AppState.self) private var appState
    @State private var nodes: [FileNode] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Brand.textMuted)
                TextField("Search files...", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundColor(Brand.textPrimary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Brand.textMuted)
                    }
                }
            }
            .padding(8)
            .background(Brand.surfaceLight)
            .cornerRadius(8)
            .padding()
            
            // MARK: - Content
            if isLoading {
                Spacer()
                ProgressView()
                    .tint(Brand.cyan)
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(Brand.error)
                    Text(error)
                        .foregroundColor(Brand.textSecondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task { await loadFiles() }
                    }
                    .buttonStyle(Brand.brandButton())
                }
                .padding()
                Spacer()
            } else {
                List {
                    ForEach(filteredNodes, id: \.path) { node in
                        FileNodeRow(
                            node: node,
                            fileService: fileService,
                            onFileSelected: onFileSelected,
                            fileStatuses: appState.fileStatuses
                        )
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Brand.background)
            }
        }
        .background(Brand.background)
        .task {
            await loadFiles()
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredNodes: [FileNode] {
        if searchText.isEmpty {
            return nodes
        }
        return nodes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    // MARK: - Actions
    
    private func loadFiles() async {
        isLoading = true
        errorMessage = nil
        
        do {
            nodes = try await fileService.list(path: path)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

struct FileNodeRow: View {
    let node: FileNode
    let fileService: FileService
    let onFileSelected: (String) -> Void
    let fileStatuses: [String: FileChangeStatus]
    
    @State private var isExpanded = false
    @State private var children: [FileNode]?
    @State private var isLoadingChildren = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                // MARK: - Expand/Collapse Icon
                if node.isDirectory {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption)
                        .foregroundColor(Brand.textMuted)
                        .frame(width: 12)
                } else {
                    Spacer().frame(width: 12)
                }
                
                // MARK: - File/Folder Icon
                Image(systemName: node.isDirectory ? "folder.fill" : "doc.text")
                    .foregroundColor(iconColor)
                
                // MARK: - Name
                Text(node.name)
                    .foregroundColor(Brand.textPrimary)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                
                Spacer()
                
                // MARK: - Diff Indicator
                if let status = fileStatuses[node.path] {
                    Circle()
                        .fill(statusColor(for: status))
                        .frame(width: 8, height: 8)
                }
                
                if isLoadingChildren {
                    ProgressView()
                        .scaleEffect(0.5)
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                if node.isDirectory {
                    toggleExpansion()
                } else {
                    onFileSelected(node.path)
                }
            }
            
            // MARK: - Children
            if isExpanded, let children = children {
                ForEach(children, id: \.path) { child in
                    FileNodeRow(
                        node: child,
                        fileService: fileService,
                        onFileSelected: onFileSelected,
                        fileStatuses: fileStatuses
                    )
                    .padding(.leading, 24)
                }
            }
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
    
    // MARK: - Computed Properties
    
    private var iconColor: Color {
        if node.isDirectory {
            return Brand.cyan
        }
        
        let ext = (node.name as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return .orange
        case "js", "ts", "jsx", "tsx": return .yellow
        case "json": return .green
        case "md": return .blue
        case "html", "css": return .purple
        default: return Brand.textSecondary
        }
    }
    
    // MARK: - Actions
    
    private func toggleExpansion() {
        isExpanded.toggle()
        
        if isExpanded && children == nil {
            Task {
                isLoadingChildren = true
                do {
                    children = try await fileService.list(path: node.path)
                } catch {
                    print("Failed to load children: \(error)")
                }
                isLoadingChildren = false
            }
        }
    }
    
    private func statusColor(for status: FileChangeStatus) -> Color {
        switch status {
        case .added: return Brand.success
        case .modified: return Brand.warning
        case .deleted: return Brand.error
        }
    }
}
