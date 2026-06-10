import Foundation

// MARK: - SquatPhase

/// Maps runtime FlexFitClassifier output strings to a small phase enum so the
/// rep counter never hardcodes the training vocabulary. Label classification is
/// tolerant (case-insensitive substring matching) because the exact strings come
/// from FlexFitClassifier's training labels.
enum SquatPhase: Equatable {
    case down            // squatted / bottom phase
    case up              // standing / top phase
    case resting         // idle between reps
    case unknown         // below-threshold or unrecognized label

    /// Either an `up` or `resting` phase completes a rep when transitioning from `down`.
    var isResting: Bool {
        self == .up || self == .resting
    }

    /// Tolerant mapping from a model output label to a phase.
    /// Unknown labels never advance phase tracking.
    init(modelLabel: String) {
        let label = modelLabel.lowercased()
        if label.contains("down") || label.contains("squat") {
            self = .down
        } else if label.contains("up") || label.contains("stand") {
            self = .up
        } else if label.contains("rest") || label.contains("idle") {
            self = .resting
        } else {
            self = .unknown
        }
    }
}
