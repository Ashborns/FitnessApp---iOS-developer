import SwiftUI

/// Toggleable filter chip for the PULSE design system.
///
/// Renders a pill-shaped, tappable chip whose selected and unselected states are
/// visually distinct (fill + text color) and exposes that state to assistive
/// technology via `accessibilityValue` ("selected" / "not selected") plus the
/// `.isSelected` trait. Styling uses semantic tokens only (no hardcoded hex,
/// spacing, or radius). The conditional background is resolved through
/// `AnyShapeStyle` (a `ShapeStyle`, never `AnyView`), keeping the view tree
/// concrete and avoiding type erasure of views.
///
/// `accessibilityLabel` and `accessibilityIdentifier` are mandatory, non-optional
/// inputs so every chip is reliably describable and testable. The tap target is
/// guaranteed to be at least 44×44pt.
///
/// Requirements: 2.4 (≥44×44 tap target), 2.7 (state-reflecting accessibility value).
struct FilterChip: View {

    private let title: String
    private let isSelected: Bool
    private let accessibilityLabel: String
    private let accessibilityIdentifier: String
    private let onTap: () -> Void

    init(
        title: String,
        isSelected: Bool,
        label: String,
        identifier: String,
        onTap: @escaping () -> Void
    ) {
        self.title = title
        self.isSelected = isSelected
        self.accessibilityLabel = label
        self.accessibilityIdentifier = identifier
        self.onTap = onTap
    }

    /// Conditional fill resolved as a `ShapeStyle` via `AnyShapeStyle` so both the
    /// gradient (selected) and the flat surface (unselected) share one concrete
    /// type — no `AnyView`.
    private var backgroundStyle: AnyShapeStyle {
        isSelected
            ? AnyShapeStyle(Color.brandGradient)
            : AnyShapeStyle(Color.themeSurface)
    }

    /// Selected chips use white text on the brand gradient for contrast; unselected
    /// chips fall back to the primary label color on the surface fill.
    private var foregroundColor: Color {
        isSelected ? .white : .primary
    }

    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(foregroundColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, .spacingLarge)
                .padding(.vertical, .spacingMedium)
                .frame(minWidth: 44, minHeight: 44)
                .background(backgroundStyle, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.themeBorder, lineWidth: isSelected ? 0 : 1)
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityValue(isSelected ? "selected" : "not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#if DEBUG
struct FilterChip_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: .spacingMedium) {
            FilterChip(
                title: "Chest",
                isSelected: true,
                label: "Filter by chest",
                identifier: "filter.chip.chest",
                onTap: {}
            )
            FilterChip(
                title: "Back",
                isSelected: false,
                label: "Filter by back",
                identifier: "filter.chip.back",
                onTap: {}
            )
        }
        .padding(.spacingLarge)
        .background(Color.themeBackground)
        .preferredColorScheme(.dark)
    }
}
#endif
