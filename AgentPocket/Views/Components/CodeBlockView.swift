import SwiftUI
import Highlightr

// MARK: - Code Block View
struct CodeBlockView: View {
    let code: String
    let language: String?
    
    @State private var highlighted: NSAttributedString?
    @State private var copied = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().background(Brand.border)
            content
        }
        .background(Brand.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Brand.border, lineWidth: 1)
        )
        .task {
            await highlightCode()
        }
    }
    
    // MARK: - Subviews
    private var header: some View {
        HStack {
            Text(language?.uppercased() ?? "CODE")
                .font(.caption2.weight(.bold))
                .foregroundStyle(Brand.textMuted)
                .tracking(1.0)
            
            Spacer()
            
            Button(action: copyCode) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.caption)
                    .foregroundStyle(copied ? Brand.success : Brand.textMuted)
                    .contentTransition(.symbolEffect(.replace))
            }
            .accessibilityLabel(copied ? "Copied to clipboard" : "Copy code")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Brand.surfaceLight)
    }
    
    private var content: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 0) {
                lineNumbers
                Divider().background(Brand.border)
                codeText
            }
            .padding(.vertical, 16)
        }
    }
    
    private var lineNumbers: some View {
        VStack(alignment: .trailing, spacing: 4) {
            let lineCount = max(1, code.components(separatedBy: "\n").count)
            ForEach(1...lineCount, id: \.self) { line in
                Text("\(line)")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Brand.textSubtle)
                    .frame(minWidth: 32, alignment: .trailing)
            }
        }
        .padding(.trailing, 12)
        .padding(.leading, 12)
    }
    
    @ViewBuilder
    private var codeText: some View {
        if let highlighted {
            Text(AttributedString(highlighted))
                .font(.system(size: 13, design: .monospaced))
                .padding(.horizontal, 16)
                .textSelection(.enabled)
        } else {
            Text(code)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Brand.textPrimary)
                .padding(.horizontal, 16)
                .textSelection(.enabled)
        }
    }
    
    // MARK: - Actions
    private func highlightCode() async {
        let lang = language
        let src = code
        let result = await Task.detached {
            let h = Highlightr()
            h?.setTheme(to: "atom-one-dark")
            return h?.highlight(src, as: lang)
        }.value
        
        await MainActor.run {
            self.highlighted = result
        }
    }
    
    private func copyCode() {
        UIPasteboard.general.string = code
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            copied = true
        }
        
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    copied = false
                }
            }
        }
    }
}
