import SwiftUI

/// Section header for the PULSE design system.
///
/// Renders a heavy-weight title with an optional subtitle below it, using
/// semantic foreground colors and token-based spacing only. The subtitle row
/// is composed via `@ViewBuilder` (no `AnyView`) so it is omitted entirely when
/// `subtitle` is `nil`.
///
/// Requirements: 2.1 (token-only styling), 2.2 (reusable component),
/// 2.3 (heavy typography for section headers), 2.5 (design-system component).
struct SectionHeader: View {

    private let title: String
    private let subtitle: String?

    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingSmall) {
            Text(title)
                .font(.title3.weight(.heavy))
                .foregroundColor(.primary)

            subtitleView
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var subtitleView: some View {
        if let subtitle, !subtitle.isEmpty {
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

#if DEBUG
struct SectionHeader_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: .spacingExtraLarge) {
            SectionHeader(title: "Exercises")
            SectionHeader(title: "Recommended", subtitle: "Based on your recent workouts")
        }
        .padding(.spacingLarge)
        .background(Color.themeBackground)
        .preferredColorScheme(.dark)
    }
}
#endif
