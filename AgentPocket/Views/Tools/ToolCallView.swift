import SwiftUI

struct ToolCallView: View {
    let content: ToolContent
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(Theme.springAnimation) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .foregroundStyle(Theme.cyanAccent)

                    Text(content.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(Theme.textPrimary)

                    Spacer()

                    statusIcon

                    Image(systemName: "chevron.right")
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .foregroundStyle(Theme.textMuted)
                        .contentTransition(.interpolate)
                }
                .padding(Theme.spacingMD)
                .background(Theme.surface)
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: Theme.spacingSM) {
                    if let input = content.input {
                        Text("Input")
                            .font(Theme.captionFont.bold())
                            .foregroundStyle(Theme.textMuted)
                        CodeBlockView(code: input, language: "json")
                    }

                    if let output = content.output {
                        Text("Output")
                            .font(Theme.captionFont.bold())
                            .foregroundStyle(Theme.textMuted)
                        CodeBlockView(code: output, language: "json")
                    }

                    if let error = content.error {
                        Text("Error")
                            .font(Theme.captionFont.bold())
                            .foregroundStyle(.red)
                        Text(error)
                            .font(Theme.captionFont)
                            .foregroundStyle(.red)
                    }
                }
                .padding(Theme.spacingMD)
                .background(Theme.background.opacity(0.5))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMD)
                .stroke(Theme.surface, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Tool: \(content.name), status: \(content.status.rawValue)")
        .accessibilityHint(isExpanded ? "Double tap to collapse details" : "Double tap to expand details")
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch content.status {
        case .pending:
            Image(systemName: "clock.fill")
                .foregroundStyle(.yellow)
        case .running:
            ProgressView()
                .controlSize(.small)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.emerald)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }
}
