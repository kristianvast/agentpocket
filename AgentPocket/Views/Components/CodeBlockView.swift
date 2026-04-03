import SwiftUI
import Highlightr

struct CodeBlockView: View {
    let code: String
    let language: String
    
    @State private var highlightedCode: AttributedString?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            if let highlightedCode {
                Text(highlightedCode)
                    .font(.system(.caption, design: .monospaced))
                    .padding(8)
            } else {
                Text(code)
                    .font(.system(.caption, design: .monospaced))
                    .padding(8)
            }
        }
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))
        .accessibilityLabel("Code block in \(language)")
        .accessibilityValue(code)
        .onAppear {
            highlight()
        }
    }
    
    private func highlight() {
        let codeToHighlight = code
        let lang = language
        DispatchQueue.global(qos: .userInitiated).async {
            guard let highlightr = Highlightr() else { return }
            highlightr.setTheme(to: "dracula")
            guard let result = highlightr.highlight(codeToHighlight, as: lang) else { return }
            let attributed = AttributedString(result)
            DispatchQueue.main.async {
                self.highlightedCode = attributed
            }
        }
    }
}
