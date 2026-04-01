import SwiftUI

struct QuestionSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    let request: QuestionRequest
    
    @State private var answerText = ""
    
    var body: some View {
        VStack(spacing: 24) {
            // MARK: - Header
            VStack(spacing: 16) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Brand.cyan)
                
                Text("Question from AI")
                    .font(.title2.bold())
                    .foregroundColor(Brand.textPrimary)
                
                Text(request.question)
                    .font(.body)
                    .foregroundColor(Brand.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 32)
            
            // MARK: - Content
            if let options = request.options, !options.isEmpty {
                VStack(spacing: 12) {
                    ForEach(options, id: \.id) { option in
                        Button(action: { submitAnswer([option.id]) }) {
                            HStack {
                                Text(option.text)
                                    .font(.headline)
                                    .foregroundColor(Brand.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundColor(Brand.textMuted)
                            }
                            .padding()
                            .background(Brand.surfaceLight)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Answer")
                        .font(.subheadline.bold())
                        .foregroundColor(Brand.textPrimary)
                    
                    TextEditor(text: $answerText)
                        .font(.body)
                        .foregroundColor(Brand.textPrimary)
                        .padding(8)
                        .background(Brand.surfaceLight)
                        .cornerRadius(8)
                        .frame(minHeight: 100)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Brand.border, lineWidth: 1)
                        )
                }
                .padding(.horizontal)
            }
            
            Spacer()
            
            // MARK: - Actions
            VStack(spacing: 12) {
                if request.options == nil || request.options!.isEmpty {
                    Button(action: { submitAnswer([answerText]) }) {
                        Text("Submit")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(answerText.isEmpty ? Brand.surfaceLight : Brand.cyan)
                            .cornerRadius(12)
                    }
                    .disabled(answerText.isEmpty)
                }
                
                Button(action: reject) {
                    Text("Reject")
                        .font(.headline)
                        .foregroundColor(Brand.error)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Brand.error, lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .background(Brand.background)
        .interactiveDismissDisabled()
    }
    
    // MARK: - Actions
    
    private func submitAnswer(_ answers: [String]) {
        Task {
            do {
                try await appState.replyToQuestion(id: request.id, answers: answers)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Failed to reply to question: \(error)")
            }
        }
    }
    
    private func reject() {
        Task {
            do {
                try await appState.rejectQuestion(id: request.id)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Failed to reject question: \(error)")
            }
        }
    }
}
