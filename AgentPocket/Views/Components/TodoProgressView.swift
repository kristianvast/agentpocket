import SwiftUI

// MARK: - Todo Progress View
struct TodoProgressView: View {
    let todos: [Todo]
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            
            if isExpanded {
                todoList
            }
        }
        .padding(16)
        .background(Brand.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Brand.border, lineWidth: 1)
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isExpanded)
    }
    
    // MARK: - Subviews
    private var header: some View {
        Button(action: toggleExpanded) {
            HStack(spacing: 12) {
                Image(systemName: "checklist")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Brand.cyan)
                
                Text("\(completedCount)/\(totalCount)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Brand.textPrimary)
                    .contentTransition(.numericText())
                
                progressBar
                
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Brand.textMuted)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Tasks: \(completedCount) of \(totalCount) completed")
    }
    
    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Brand.surfaceLight)
                    .frame(height: 6)
                
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Brand.gradient)
                    .frame(width: max(0, geo.size.width * progress), height: 6)
            }
        }
        .frame(height: 6)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: progress)
    }
    
    private var todoList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
                .background(Brand.border)
                .padding(.bottom, 4)
            
            ForEach(todos) { todo in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: statusIcon(todo.status))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(statusColor(todo.status))
                        .frame(width: 16, alignment: .center)
                        .padding(.top, 2)
                    
                    Text(todo.content)
                        .font(.subheadline)
                        .foregroundStyle(todo.status == .completed ? Brand.textMuted : Brand.textSecondary)
                        .strikethrough(todo.status == .completed)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.top, 4)
    }
    
    // MARK: - Helpers
    private var completedCount: Int {
        todos.filter { $0.status == .completed }.count
    }
    
    private var totalCount: Int {
        todos.count
    }
    
    private var progress: Double {
        totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0
    }
    
    private func toggleExpanded() {
        isExpanded.toggle()
    }
    
    private func statusIcon(_ status: TodoStatus) -> String {
        switch status {
        case .pending: return "circle"
        case .in_progress: return "circle.dotted"
        case .completed: return "checkmark.circle.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }
    
    private func statusColor(_ status: TodoStatus) -> Color {
        switch status {
        case .pending: return Brand.textMuted
        case .in_progress: return Brand.warning
        case .completed: return Brand.success
        case .cancelled: return Brand.error
        }
    }
}
