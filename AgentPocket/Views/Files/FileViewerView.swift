import SwiftUI
import Highlightr

struct FileViewerView: View {
    let filePath: String
    let fileService: FileService
    
    @Environment(\.dismiss) private var dismiss
    @State private var content: String = ""
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var highlightedText: NSAttributedString?
    
    private let highlightr = Highlightr()
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Toolbar
            HStack {
                Text((filePath as NSString).lastPathComponent)
                    .font(.headline)
                    .foregroundColor(Brand.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Brand.textMuted)
                        .font(.title3)
                }
            }
            .padding()
            .background(Brand.surface)
            
            Divider()
                .background(Brand.border)
            
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
                        Task { await loadFile() }
                    }
                    .buttonStyle(Brand.brandButton())
                }
                .padding()
                Spacer()
            } else {
                ScrollView([.vertical, .horizontal]) {
                    HStack(alignment: .top, spacing: 0) {
                        // MARK: - Line Numbers
                        VStack(alignment: .trailing, spacing: 2) {
                            ForEach(1...lineCount, id: \.self) { line in
                                Text("\(line)")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(Brand.textMuted)
                                    .frame(minWidth: 30, alignment: .trailing)
                                    .padding(.trailing, 8)
                            }
                        }
                        .padding(.vertical, 16)
                        .background(Brand.surfaceLight)
                        
                        Divider()
                            .background(Brand.border)
                        
                        // MARK: - Code Content
                        if let highlighted = highlightedText {
                            Text(AttributedString(highlighted))
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(16)
                        } else {
                            Text(content)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(Brand.textPrimary)
                                .textSelection(.enabled)
                                .padding(16)
                        }
                    }
                }
                .background(Brand.background)
            }
        }
        .background(Brand.background)
        .task {
            highlightr?.setTheme(to: "atom-one-dark")
            await loadFile()
        }
    }
    
    // MARK: - Computed Properties
    
    private var lineCount: Int {
        max(1, content.components(separatedBy: .newlines).count)
    }
    
    private var language: String {
        let ext = (filePath as NSString).pathExtension.lowercased()
        switch ext {
        case "js", "jsx": return "javascript"
        case "ts", "tsx": return "typescript"
        case "md": return "markdown"
        case "yml", "yaml": return "yaml"
        case "sh": return "bash"
        case "py": return "python"
        case "rb": return "ruby"
        case "go": return "go"
        case "rs": return "rust"
        case "java": return "java"
        case "c", "h": return "c"
        case "cpp", "hpp": return "cpp"
        case "cs": return "csharp"
        case "html": return "xml"
        case "css": return "css"
        case "json": return "json"
        case "swift": return "swift"
        default: return "plaintext"
        }
    }
    
    // MARK: - Actions
    
    private func loadFile() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fileContent = try await fileService.read(path: filePath)
            content = fileContent.content
            
            if let highlightr = highlightr {
                let highlighted = highlightr.highlight(content, as: language)
                await MainActor.run {
                    self.highlightedText = highlighted
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}
