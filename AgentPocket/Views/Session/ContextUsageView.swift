import SwiftUI

struct ContextUsageView: View {
    let sessionID: String
    @Environment(AppState.self) private var appState
    @State private var isExpanded = false
    
    var body: some View {
        Button {
            isExpanded.toggle()
        } label: {
            Text(formattedCost)
                .font(Brand.monoFont.weight(.medium))
                .foregroundColor(isHighCost ? Brand.warning : Brand.textMuted)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Brand.surface)
                .cornerRadius(4)
        }
        .popover(isPresented: $isExpanded) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Context Usage")
                    .font(.headline)
                    .foregroundColor(Brand.textPrimary)
                
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    GridRow {
                        Text("Input")
                            .foregroundColor(Brand.textSecondary)
                        Text("\(totalUsage.input)")
                            .foregroundColor(Brand.textPrimary)
                            .font(Brand.monoFont)
                    }
                    GridRow {
                        Text("Output")
                            .foregroundColor(Brand.textSecondary)
                        Text("\(totalUsage.output)")
                            .foregroundColor(Brand.textPrimary)
                            .font(Brand.monoFont)
                    }
                    GridRow {
                        Text("Reasoning")
                            .foregroundColor(Brand.textSecondary)
                        Text("\(totalUsage.reasoning)")
                            .foregroundColor(Brand.textPrimary)
                            .font(Brand.monoFont)
                    }
                    GridRow {
                        Text("Cache Read")
                            .foregroundColor(Brand.textSecondary)
                        Text("\(totalUsage.cacheRead)")
                            .foregroundColor(Brand.textPrimary)
                            .font(Brand.monoFont)
                    }
                    GridRow {
                        Text("Cache Write")
                            .foregroundColor(Brand.textSecondary)
                        Text("\(totalUsage.cacheWrite)")
                            .foregroundColor(Brand.textPrimary)
                            .font(Brand.monoFont)
                    }
                }
            }
            .padding()
            .background(Brand.surface)
            .presentationCompactAdaptation(.popover)
        }
    }
    
    // MARK: - Helpers
    
    private var totalUsage: TokenUsage {
        let messages = appState.sessionStore.activeMessages[sessionID] ?? []
        return messages.reduce(TokenUsage(input: 0, output: 0, reasoning: 0, cacheRead: 0, cacheWrite: 0)) { result, msg in
            guard msg.message.role == .assistant, let usage = msg.message.tokenUsage else { return result }
            return TokenUsage(
                input: result.input + usage.input,
                output: result.output + usage.output,
                reasoning: result.reasoning + usage.reasoning,
                cacheRead: result.cacheRead + usage.cacheRead,
                cacheWrite: result.cacheWrite + usage.cacheWrite
            )
        }
    }
    
    private var formattedCost: String {
        let cost = calculateCost(usage: totalUsage)
        return String(format: "$%.3f", cost)
    }
    
    private var isHighCost: Bool {
        calculateCost(usage: totalUsage) > 1.0
    }
    
    private func calculateCost(usage: TokenUsage) -> Double {
        let inputCost = Double(usage.input) * 0.00001
        let outputCost = Double(usage.output) * 0.00003
        let cacheReadCost = Double(usage.cacheRead) * 0.000005
        let cacheWriteCost = Double(usage.cacheWrite) * 0.0000125
        return inputCost + outputCost + cacheReadCost + cacheWriteCost
    }
}
