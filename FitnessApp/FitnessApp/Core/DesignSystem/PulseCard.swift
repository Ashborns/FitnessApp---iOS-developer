import SwiftUI

/// Container card for the PULSE design system.
///
/// Wraps arbitrary content in an elevated surface using semantic tokens only:
/// `themeSurface` fill, `themeBorder` stroke, `.cornerRadiusLarge` corners, and
/// `.spacingLarge` interior padding. Composition is done via `@ViewBuilder`
/// (no `AnyView`) so callers can pass any view hierarchy without type erasure.
///
/// Requirements: 2.1 (token-only styling), 2.2 (reusable component), 2.5 (PulseCard surface).
struct PulseCard<Content: View>: View {

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.spacingLarge)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: .cornerRadiusLarge, style: .continuous)
                    .fill(Color.themeSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: .cornerRadiusLarge, style: .continuous)
                    .stroke(Color.themeBorder, lineWidth: 1)
            )
    }
}

#if DEBUG
struct PulseCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: .spacingLarge) {
            PulseCard {
                VStack(alignment: .leading, spacing: .spacingMedium) {
                    Text("Push Up")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("Chest • Bodyweight")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            PulseCard {
                Text("Single line content")
                    .foregroundColor(.primary)
            }
        }
        .padding(.spacingLarge)
        .background(Color.themeBackground)
        .preferredColorScheme(.dark)
    }
}
#endif
