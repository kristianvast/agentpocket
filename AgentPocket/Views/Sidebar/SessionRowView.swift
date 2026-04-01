import SwiftUI

struct SessionRowView: View {
    @Environment(AppState.self) private var appState
    let session: Session

    var body: some View {
        HStack(spacing: 12) {
            StatusIndicator(status: appState.sessionStatuses[session.id] ?? .unknown)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(session.title)
                        .font(.headline)
                        .foregroundColor(Brand.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    if session.time.archived != nil {
                        Image(systemName: "archivebox.fill")
                            .font(.caption)
                            .foregroundColor(Brand.textMuted)
                    }

                    Text(timeAgo(from: session.time.updated))
                        .font(.caption)
                        .foregroundColor(Brand.textMuted)
                }

                HStack {
                    if let model = session.model {
                        Text(model)
                            .font(.caption)
                            .foregroundColor(Brand.cyan)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Brand.cyan.opacity(0.1))
                            .clipShape(Capsule())
                    }

                    Spacer()

                    if let count = session.messageCount {
                        Text("\(count) msgs")
                            .font(.caption)
                            .foregroundColor(Brand.textSecondary)
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(isActive ? Brand.surfaceLight : Brand.surface)
        .overlay(
            HStack {
                if isActive {
                    Rectangle()
                        .fill(Brand.gradient)
                        .frame(width: 4)
                }
                Spacer()
            }
        )
        .contentShape(Rectangle())
        .contextMenu {
            Button {
            } label: {
                Label("Fork Session", systemImage: "arrow.branch")
            }

            Button {
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            Button {
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            Button {
            } label: {
                Label("Archive", systemImage: "archivebox")
            }

            Divider()

            Button(role: .destructive) {
                appState.deleteSession(session.id)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .animation(.default, value: isActive)
    }

    // MARK: - Computed Properties

    private var isActive: Bool {
        appState.sessionStore.activeSessionID == session.id
    }

    // MARK: - Helpers

    private func timeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
