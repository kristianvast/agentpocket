import SwiftUI

struct PermissionSheet: View {
    @Environment(AppState.self) private var appState
    @State private var error: (any Error)?

    var body: some View {
        if let request = appState.pendingPermissions.first {
            VStack(spacing: Theme.spacingLG) {
                Image(systemName: "shield.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.yellow)

                Text("Permission Requested")
                    .font(Theme.titleFont)
                    .foregroundStyle(Theme.textPrimary)

                Text("The agent wants to use the tool:")
                    .foregroundStyle(Theme.textMuted)

                Text(request.toolName)
                    .font(Theme.headlineFont)
                    .padding()
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))

                if !request.description.isEmpty {
                    Text(request.description)
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.textMuted)
                        .multilineTextAlignment(.center)
                }

                if let input = request.input {
                    ScrollView {
                        Text(input)
                            .font(Theme.monoFont)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))
                    }
                    .frame(maxHeight: 200)
                }

                HStack(spacing: Theme.spacingMD) {
                    Button("Deny") {
                        Task {
                            do {
                                try await appState.replyToPermission(id: request.id, allow: false)
                                HapticManager.notification(.warning)
                            } catch {
                                self.error = error
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)

                    Button("Allow") {
                        Task {
                            do {
                                try await appState.replyToPermission(id: request.id, allow: true)
                                HapticManager.notification(.success)
                            } catch {
                                self.error = error
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.emerald)
                }
            }
            .padding(Theme.spacingLG)
            .background(Theme.background)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLG))
            .shadow(radius: 20)
            .padding()
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .errorAlert(error: $error)
        }
    }
}
