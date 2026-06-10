import Foundation

/// Maps an `ExerciseItem` from ExerciseDB to a camera-supported `ExerciseType`.
///
/// The Camera_Coaching pipeline only supports a fixed set of body-pose exercises
/// (`ExerciseType`: jumpingJacks, squats, highKnees, armRaises, toeTouches). The
/// Detail_Screen uses this mapper to decide whether to surface the "open camera
/// coaching" control:
///
/// - When `map(_:)` returns a non-nil `ExerciseType`, the Detail_Screen shows the
///   control and pre-selects that exercise via `App_Router.openCamera(with:)` (R10.4).
/// - When `map(_:)` returns `nil`, the exercise is not supported by the camera and the
///   Detail_Screen hides the control (R10.5).
///
/// Matching is **case-insensitive keyword matching** over `item.name` (with `item.target`
/// used as a secondary signal where helpful). The keyword table is evaluated in a fixed
/// order so the result is fully deterministic for any given input.
enum CameraExerciseMapper {

    /// A keyword rule: if any keyword is found, the exercise maps to `type`.
    private struct Rule {
        let type: ExerciseType
        let keywords: [String]
    }

    /// Ordered, most-specific-first rules. Order matters so that, for example,
    /// "high knee" is matched as `.highKnees` rather than being shadowed by a
    /// more generic rule. Each keyword is lowercase and matched as a substring.
    private static let rules: [Rule] = [
        Rule(type: .jumpingJacks, keywords: ["jumping jack", "jumping-jack", "jumpingjack", "star jump"]),
        Rule(type: .highKnees,    keywords: ["high knee", "high-knee", "highknee", "knee raise", "knee-up", "knee up"]),
        Rule(type: .toeTouches,   keywords: ["toe touch", "toe-touch", "toetouch", "touch toe", "standing toe"]),
        Rule(type: .armRaises,    keywords: ["arm raise", "lateral raise", "shoulder press", "overhead press",
                                            "front raise", "shoulder raise", "arm lift", "military press"]),
        // `.squats` is intentionally last: it is the most generic single-word match
        // and must not pre-empt the more specific phrases above.
        Rule(type: .squats,       keywords: ["squat"])
    ]

    /// Returns the camera-supported `ExerciseType` for `item`, or `nil` if the exercise
    /// is not supported by Camera_Coaching.
    ///
    /// - The exercise `name` is consulted first; if no rule matches, the `target` muscle
    ///   is used as a fallback signal.
    /// - Matching is case-insensitive and whitespace-trimmed.
    static func map(_ item: ExerciseItem) -> ExerciseType? {
        let name = normalized(item.name)
        if let match = matchType(in: name) {
            return match
        }

        // Secondary signal: some sources put the movement in the target field.
        let target = normalized(item.target)
        if let match = matchType(in: target) {
            return match
        }

        return nil
    }

    // MARK: - Helpers

    /// Lowercases and trims a field for deterministic substring matching.
    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Returns the first rule (in fixed order) whose keyword appears in `haystack`.
    private static func matchType(in haystack: String) -> ExerciseType? {
        guard !haystack.isEmpty else { return nil }
        for rule in rules {
            for keyword in rule.keywords where haystack.contains(keyword) {
                return rule.type
            }
        }
        return nil
    }
}
