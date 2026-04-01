import SwiftUI

struct ToolCallView: View {
    let data: ToolPartData
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .foregroundColor(Brand.textSecondary)
                        .font(.caption)
                    
                    Text(data.toolName)
                        .font(Brand.monoFont.weight(.medium))
                        .foregroundColor(Brand.textPrimary)
                    
                    Spacer()
                    
                    statusIndicator
                }
                .padding(12)
                .background(Brand.surface)
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    Divider().background(Brand.border)
                    
                    if let input = data.input {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Input")
                                .font(.caption.bold())
                                .foregroundColor(Brand.textSecondary)
                            CodeBlockView(code: input, language: "json")
                        }
                    }
                    
                    if let output = data.output {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Output")
                                .font(.caption.bold())
                                .foregroundColor(Brand.textSecondary)
                            MarkdownRenderer(text: output)
                        }
                    }
                    
                    if let error = data.error {
                        Text(error)
                            .font(Brand.monoFont)
                            .foregroundColor(.red)
                            .padding(8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(4)
                    }
                }
                .padding(12)
                .background(Brand.background)
            }
        }
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Brand.border, lineWidth: 1)
        )
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var statusIndicator: some View {
        HStack(spacing: 6) {
            switch data.state {
            case .pending:
                ProgressView()
                    .controlSize(.mini)
                Text("Pending")
            case .running:
                ProgressView()
                    .controlSize(.mini)
                Text(data.title ?? "Running...")
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Brand.emerald)
                if let title = data.title {
                    Text(title)
                }
                if let duration = data.duration {
                    Text(String(format: "%.1fs", duration))
                }
            case .error:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text(data.error ?? "Failed")
            }
        }
        .font(.caption)
        .foregroundColor(Brand.textMuted)
    }
}
