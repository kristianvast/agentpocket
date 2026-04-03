import SwiftUI

struct StreamingTextView: View {
    let text: String
    @State private var showCursor = true
    
    var body: some View {
        HStack(spacing: 2) {
            Text(text)
                .foregroundStyle(Theme.textPrimary)
            
            Rectangle()
                .fill(Theme.cyanAccent)
                .frame(width: 8, height: 16)
                .opacity(showCursor ? 1 : 0)
                .animation(.easeInOut(duration: 0.5).repeatForever(), value: showCursor)
        }
        .accessibilityLabel(text)
        .accessibilityAddTraits(.updatesFrequently)
        .onAppear {
            showCursor.toggle()
        }
    }
}
