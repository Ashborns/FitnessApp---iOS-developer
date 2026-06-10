import SwiftUI

/// Resolves accessibility labels so that no interactive element on the new
/// screens (Library / Detail / Builder / MuscleMap / Schedule) or the redesigned
/// camera overlay is ever rendered with an empty VoiceOver label.
///
/// Requirement 17.1 requires a non-empty accessibility label for every
/// interactive element on the new screens; Requirement 17.6 requires that, when
/// a candidate label would otherwise be empty, a descriptive fallback that names
/// the element's function is used instead of leaving the label blank.
///
/// `resolve(_:fallback:)` is a pure function: it trims the candidate and returns
/// it when non-empty, otherwise returns the trimmed (descriptive) fallback, and
/// as a last resort a generic non-empty default — guaranteeing the result is
/// always a non-empty string.
enum AccessibilityLabel {

    /// Generic, non-empty default used only when both the candidate and the
    /// fallback resolve to empty strings. Keeps VoiceOver from announcing an
    /// unlabeled element (R17.6).
    static let genericDefault = "Elemen"

    /// Returns a guaranteed non-empty accessibility label.
    ///
    /// Resolution order (R17.1 / R17.6):
    /// 1. The trimmed `candidate`, when it contains non-whitespace text.
    /// 2. Otherwise the trimmed `fallback`, which should describe the element's
    ///    function (e.g. "Latihan", "Buka latihan").
    /// 3. Otherwise ``genericDefault`` so the label is never empty.
    ///
    /// - Parameters:
    ///   - candidate: The dynamic label that may be `nil` or empty.
    ///   - fallback: A descriptive, function-naming label used when `candidate`
    ///     is empty.
    /// - Returns: A non-empty label string.
    static func resolve(_ candidate: String?, fallback: String) -> String {
        if let candidate = candidate?.trimmingCharacters(in: .whitespacesAndNewlines),
           !candidate.isEmpty {
            return candidate
        }

        let trimmedFallback = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedFallback.isEmpty {
            return trimmedFallback
        }

        return genericDefault
    }
}

// MARK: - View convenience

extension View {

    /// Applies a guaranteed non-empty accessibility label, resolving an empty or
    /// `nil` `candidate` to the descriptive `fallback` (R17.1 / R17.6).
    ///
    /// - Parameters:
    ///   - candidate: The dynamic label that may be `nil` or empty.
    ///   - fallback: A descriptive, function-naming label used when `candidate`
    ///     is empty.
    func accessibleLabel(_ candidate: String?, fallback: String) -> some View {
        accessibilityLabel(AccessibilityLabel.resolve(candidate, fallback: fallback))
    }
}
