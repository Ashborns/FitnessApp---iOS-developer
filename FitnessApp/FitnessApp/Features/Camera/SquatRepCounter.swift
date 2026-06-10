import Foundation

// MARK: - SquatRepCounter

/// A pure-logic value type that derives an integer squat rep count from a stream
/// of FlexFitClassifier `(label, confidence)` predictions. It does no Core ML
/// work — it only interprets the predictions by tracking `SquatPhase` transitions,
/// which makes it trivially unit- and property-testable.
struct SquatRepCounter {

    /// Minimum confidence required for a prediction to update counter state.
    /// Predictions below this threshold are ignored for counting purposes.
    static let confidenceThreshold: Double = 0.6

    /// The number of completed squat repetitions observed so far.
    private(set) var repCount: Int = 0

    /// Tracks the current squat phase to detect down → up/rest transitions.
    private var phase: SquatPhase = .unknown

    /// Consumes a single FlexFitClassifier prediction and returns the rep delta
    /// (0 or 1) it produced.
    ///
    /// - A prediction with `confidence` below `confidenceThreshold` is ignored
    ///   entirely: neither `repCount` nor the stored phase changes.
    /// - A recognized label advances the stored phase; an `.unknown` label never
    ///   advances it.
    /// - A rep is counted exactly once when the phase transitions from `.down`
    ///   to a resting phase (`.up` or `.resting`).
    ///
    /// - Parameters:
    ///   - label: The FlexFitClassifier output label for this prediction.
    ///   - confidence: The probability (0.0–1.0) assigned to the label.
    /// - Returns: `1` when this prediction completes a rep, otherwise `0`.
    mutating func consume(label: String, confidence: Double) -> Int {
        guard confidence >= Self.confidenceThreshold else { return 0 }

        let incoming = SquatPhase(modelLabel: label)
        defer { if incoming != .unknown { phase = incoming } }

        if phase == .down && incoming.isResting {
            repCount += 1
            return 1
        }
        return 0
    }

    /// Resets phase tracking to `.unknown` while preserving the committed `repCount`.
    mutating func resetPhase() {
        phase = .unknown
    }

    /// Resets both the phase and `repCount` to their initial values.
    mutating func resetAll() {
        phase = .unknown
        repCount = 0
    }
}
