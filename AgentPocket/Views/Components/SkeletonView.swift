import SwiftUI

struct SkeletonView: View {
    var width: CGFloat? = nil
    var height: CGFloat = 16
    @State private var shimmerOffset: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: Theme.radiusSM)
            .fill(Theme.surface)
            .frame(width: width, height: height)
            .overlay(
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: Theme.radiusSM)
                        .fill(
                            LinearGradient(
                                colors: [.clear, Theme.surface.opacity(0.6), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * 0.6)
                        .offset(x: shimmerOffset * geo.size.width)
                }
                .clipped()
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    shimmerOffset = 1.5
                }
            }
    }
}

struct SkeletonMessageRow: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            SkeletonView(width: 80, height: 12)
            SkeletonView(height: 14)
            SkeletonView(width: 200, height: 14)
        }
        .padding(Theme.spacingMD)
        .background(Theme.surface.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
    }
}

struct SkeletonConversationRow: View {
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Theme.spacingXS) {
                SkeletonView(width: 140, height: 16)
                SkeletonView(width: 80, height: 12)
            }
            Spacer()
        }
        .padding(.vertical, Theme.spacingSM)
    }
}
