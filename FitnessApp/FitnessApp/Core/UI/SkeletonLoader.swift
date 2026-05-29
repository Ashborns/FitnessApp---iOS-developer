import SwiftUI

/// Animated shimmer skeleton placeholder for loading states.
/// Use as a background fill or overlay while content is loading.
struct SkeletonLoader: View {
    @State private var phase: CGFloat = -1

    let cornerRadius: CGFloat

    init(cornerRadius: CGFloat = 12) {
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.themeSurface)
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.0),
                            Color.white.opacity(0.08),
                            Color.white.opacity(0.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width)
                    .offset(x: phase * geo.size.width)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            )
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

#if DEBUG
struct SkeletonLoader_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            SkeletonLoader().frame(height: 80)
            SkeletonLoader(cornerRadius: 20).frame(height: 120)
        }
        .padding()
        .background(Color.themeBackground)
        .preferredColorScheme(.dark)
    }
}
#endif
