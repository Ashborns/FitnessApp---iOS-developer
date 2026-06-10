// PULSE Design System — Motion Tokens
// Standard animation tokens for the app redesign.
// Every transition duration is intentionally kept within the 200–400ms range
// (inclusive) per Requirement 1.7, so views reference these tokens instead of
// hardcoding durations.

import SwiftUI

// MARK: - Motion Tokens

enum Motion {

    /// Lower/upper bounds (seconds) for screen-transition durations.
    /// Exposed so callers/tests can reason about the allowed range without
    /// duplicating magic numbers. Equivalent to 200ms–400ms.
    static let minTransitionDuration: TimeInterval = 0.20
    static let maxTransitionDuration: TimeInterval = 0.40

    /// Duration (seconds) used for the standard screen transition animation.
    static let screenTransitionDuration: TimeInterval = 0.30 // 300ms

    /// Duration (seconds) used for filter-chip toggle animations.
    static let chipToggleDuration: TimeInterval = 0.20 // 200ms

    /// Response (seconds) for the spring used to emphasize state changes.
    /// Kept within the 200–400ms range to satisfy Requirement 1.7.
    static let emphasisResponse: TimeInterval = 0.35 // 350ms

    /// Spring damping fraction for the emphasis animation.
    static let emphasisDampingFraction: Double = 0.8

    /// Standard screen-to-screen transition (≈300ms, within 200–400ms).
    static let screenTransition: Animation = .easeInOut(duration: screenTransitionDuration)

    /// Filter-chip select/deselect toggle (200ms).
    static let chipToggle: Animation = .easeOut(duration: chipToggleDuration)

    /// Spring used to emphasize state changes (response ≈350ms, within 200–400ms).
    static let emphasis: Animation = .spring(
        response: emphasisResponse,
        dampingFraction: emphasisDampingFraction
    )
}
