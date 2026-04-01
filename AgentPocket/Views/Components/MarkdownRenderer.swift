import SwiftUI
import MarkdownUI
import Highlightr

// MARK: - Markdown Renderer
struct MarkdownRenderer: View {
    let text: String
    
    var body: some View {
        Markdown(text)
            .markdownTheme(.agentPocket)
            .markdownCodeSyntaxHighlighter(HighlightrSyntaxHighlighter())
    }
}

// MARK: - Theme Extension
extension MarkdownUI.Theme {
    static let agentPocket = MarkdownUI.Theme()
        .text {
            ForegroundColor(Brand.textPrimary)
            FontSize(15)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(.em(0.85))
            ForegroundColor(Brand.cyan)
        }
        .strong {
            FontWeight(.semibold)
        }
        .emphasis {
            FontStyle(.italic)
        }
        .link {
            ForegroundColor(Brand.teal)
        }
        .heading1 { config in
            config.label
                .markdownMargin(top: 24, bottom: 16)
                .markdownTextStyle {
                    FontWeight(.bold)
                    FontSize(.em(1.6))
                    ForegroundColor(Brand.textPrimary)
                }
        }
        .heading2 { config in
            config.label
                .markdownMargin(top: 20, bottom: 12)
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(1.3))
                    ForegroundColor(Brand.textPrimary)
                }
        }
        .heading3 { config in
            config.label
                .markdownMargin(top: 16, bottom: 8)
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(1.1))
                    ForegroundColor(Brand.textPrimary)
                }
        }
        .paragraph { config in
            config.label
                .relativeLineSpacing(.em(0.25))
                .markdownMargin(top: 0, bottom: 12)
        }
        .codeBlock { config in
            config.label
                .padding(16)
                .background(Brand.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Brand.border, lineWidth: 1)
                )
                .markdownMargin(top: 12, bottom: 16)
        }
        .blockquote { config in
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Brand.cyan)
                    .frame(width: 4)
                
                config.label
                    .padding(.leading, 16)
                    .markdownTextStyle {
                        ForegroundColor(Brand.textSecondary)
                        FontStyle(.italic)
                    }
            }
            .padding(.vertical, 8)
        }
        .listItem { config in
            config.label.markdownMargin(top: 4, bottom: 4)
        }
        .table { config in
            config.label.markdownMargin(top: 12, bottom: 12)
        }
}

// MARK: - Syntax Highlighter
struct HighlightrSyntaxHighlighter: CodeSyntaxHighlighter {
    private let highlightr: Highlightr?
    
    init() {
        let h = Highlightr()
        h?.setTheme(to: "atom-one-dark")
        h?.theme.setCodeFont(.monospacedSystemFont(ofSize: 13, weight: .regular))
        self.highlightr = h
    }
    
    func highlightCode(_ code: String, language: String?) -> Text {
        guard let highlightr, let language else { return Text(code) }
        if let highlighted = highlightr.highlight(code, as: language) {
            return Text(AttributedString(highlighted))
        }
        return Text(code)
    }
}
