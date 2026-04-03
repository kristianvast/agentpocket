import SwiftUI
import MarkdownUI

struct MarkdownRenderer: View {
    let text: String
    
    var body: some View {
        Markdown(text)
            .markdownTheme(.gitHub)
            .foregroundStyle(Theme.textPrimary)
    }
}
