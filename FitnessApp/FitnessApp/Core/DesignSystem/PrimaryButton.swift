// PULSE Design System — PrimaryButton
// Reusable primary call-to-action button built entirely on Design_System tokens.
// Filled with `brandGradient`; disabled state dims the surface, disables hit
// testing, and never triggers its action.

import SwiftUI

/// A primary call-to-action button rendered with the brand gradient.
///
/// The component is built only on semantic `Color`, spacing, and corner-radius
/// tokens from `Color+Theme.swift` — no hardcoded hex, spacing, or radius. It
/// renders a tap target of at least 44×44 points and requires non-optional
/// accessibility `label` and `identifier` parameters.
///
/// Disabled behavior (Requirement 2.6): when `isEnabled == false` the button
/// renders with a visually distinct (dimmed) appearance, disables hit testing,
/// and guards its `action` so the closure is never invoked.
///
/// Conditional composition uses `@ViewBuilder`; `AnyView` is never used.
///
/// _Requirements: 2.1, 2.2, 2.4, 2.6_
struct PrimaryButton: View {

    // MARK: Stored properties

    let title: String
    let isEnabled: Bool
    let accessibilityLabel: String
    let accessibilityIdentifier: String
    let action: () -> Void

    // MARK: Tuning constants (visual-only, not brand/spacing/radius tokens)

    /// Minimum tap target per Requirement 2.4 / HIG (≥44×44 points).
    private let minimumTapTarget: CGFloat = 44

    /// Opacity applied to the enabled gradient surface.
    private let enabledOpacity: Double = 1.0

    /// Reduced opacity used to visually distinguish the disabled state.
    private let disabledOpacity: Double = 0.4

    // MARK: Init

    init(
        title: String,
        isEnabled: Bool = true,
        label: String,
        identifier: String,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isEnabled = isEnabled
        self.accessibilityLabel = label
        self.accessibilityIdentifier = identifier
        self.action = action
    }

    // MARK: Body

    var body: some View {
        Button(action: guardedAction) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, .spacingLarge)
                .padding(.vertical, .spacingMedium)
                .frame(minWidth: minimumTapTarget, minHeight: minimumTapTarget)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusLarge, style: .continuous))
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? enabledOpacity : disabledOpacity)
        .allowsHitTesting(isEnabled)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Subviews / helpers

    /// Brand gradient fill from the Design_System. Kept in a `@ViewBuilder`
    /// helper so conditional styling never relies on `AnyView`.
    @ViewBuilder
    private var background: some View {
        Color.brandGradient
    }

    /// Wraps the supplied `action` so it is never invoked while disabled, even
    /// if the button is activated programmatically (Requirement 2.6).
    private func guardedAction() {
        guard isEnabled else { return }
        action()
    }
}

#if DEBUG
struct PrimaryButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: .spacingLarge) {
            PrimaryButton(
                title: "Start Workout",
                isEnabled: true,
                label: "Start workout",
                identifier: "primaryButton.start",
                action: {}
            )
            PrimaryButton(
                title: "Start Workout",
                isEnabled: false,
                label: "Start workout",
                identifier: "primaryButton.startDisabled",
                action: {}
            )
        }
        .padding(.spacingLarge)
        .background(Color.themeBackground)
        .preferredColorScheme(.dark)
    }
}
#endif
