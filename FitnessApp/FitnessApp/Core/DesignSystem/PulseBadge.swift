import SwiftUI

/// Small inline badge for the PULSE design system.
///
/// Used for compact metadata labels (e.g. equipment, body part). Renders text
/// on an elevated surface (`themeSurfaceElevated`) with `.cornerRadiusSmall`
/// corners and token-based padding. The `style` selects the foreground accent.
///
/// Requirements: 2.1 (token-only styling), 2.2 (reusable component),
/// 2.3 (heavy/clear typography in design system), 2.5 (PulseBadge uses surfaceElevated).
struct PulseBadge: View {

    /// Visual emphasis variants. Colors resolve to semantic tokens only.
    enum Style {
        /// Muted label using secondary foreground.
        case neutral
        /// Brand-accented label using `themePrimary`.
        case accent

        var foreground: Color {
            switch self {
            case .neutral: return .secondary
            case .accent:  return .themePrimary
            }
        }
    }

    private let text: String
    private let style: Style

    init(text: String, style: Style = .neutral) {
        self.text = text
        self.style = style
    }

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundColor(style.foreground)
            .lineLimit(1)
            .padding(.horizontal, .spacingMedium)
            .padding(.vertical, .spacingSmall)
            .background(
                RoundedRectangle(cornerRadius: .cornerRadiusSmall, style: .continuous)
                    .fill(Color.themeSurfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: .cornerRadiusSmall, style: .continuous)
                    .stroke(Color.themeBorder, lineWidth: 1)
            )
    }
}

#if DEBUG
struct PulseBadge_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: .spacingMedium) {
            PulseBadge(text: "Dumbbell")
            PulseBadge(text: "Chest", style: .accent)
        }
        .padding(.spacingLarge)
        .background(Color.themeBackground)
        .preferredColorScheme(.dark)
    }
}
#endif
