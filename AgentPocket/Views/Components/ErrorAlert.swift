import SwiftUI

struct ErrorAlertModifier: ViewModifier {
    @Binding var error: (any Error)?

    func body(content: Content) -> some View {
        content
            .alert("Error", isPresented: showAlert, presenting: error) { _ in
                Button("OK") { error = nil }
            } message: { error in
                Text(error.localizedDescription)
            }
    }

    private var showAlert: Binding<Bool> {
        Binding(get: { error != nil }, set: { if !$0 { error = nil } })
    }
}

extension View {
    func errorAlert(error: Binding<(any Error)?>) -> some View {
        modifier(ErrorAlertModifier(error: error))
    }
}
