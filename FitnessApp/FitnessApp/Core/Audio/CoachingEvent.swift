import Foundation

/// A discrete coaching cue produced during a workout.
///
/// `CoachingEvent` is a pure value type with no audio or framework dependencies so it can be
/// unit- and property-tested in isolation. `VoiceCoach` converts these events into spoken text.
/// The associated values are formatted into spoken text capped at 60 characters (R4.6), and
/// `category` drives the queue/interrupt policy (R4.4 / R4.5).
enum CoachingEvent: Equatable {
    /// Announces the new integer rep count (e.g. "5"). Interrupts in-progress speech.
    case repAnnouncement(count: Int)
    /// Speaks a form correction message. Queued behind any in-progress utterance.
    case formCorrection(message: String)
    /// Congratulates the user on reaching a multiple-of-10 rep milestone.
    case milestone(reps: Int)
    /// Announces the start of a workout for the given exercise.
    case workoutStart(exercise: String)
    /// Announces the end of a workout and the total reps performed.
    case workoutEnd(totalReps: Int)
    /// Announces a switch to a different exercise.
    case exerciseSwitch(exercise: String)

    /// Maximum spoken length so a cue completes before the next rep is likely to occur (R4.6).
    static let maxTextLength: Int = 60

    /// Coarse categorization used by `VoiceCoach` to decide interrupt-vs-queue behavior.
    enum Category: Equatable {
        case repAnnouncement
        case formCorrection
        case milestone
        case workoutStart
        case workoutEnd
        case exerciseSwitch
    }

    /// The category this event belongs to.
    var category: Category {
        switch self {
        case .repAnnouncement: return .repAnnouncement
        case .formCorrection:  return .formCorrection
        case .milestone:       return .milestone
        case .workoutStart:    return .workoutStart
        case .workoutEnd:      return .workoutEnd
        case .exerciseSwitch:  return .exerciseSwitch
        }
    }

    /// The spoken text for this event, always at most `maxTextLength` (60) characters (R4.6).
    var text: String {
        let raw: String
        switch self {
        case .repAnnouncement(let count): raw = "\(count)"
        case .formCorrection(let message): raw = message
        case .milestone(let reps):        raw = "Great work, \(reps) reps!"
        case .workoutStart(let exercise): raw = "Starting \(exercise)"
        case .workoutEnd(let totalReps):  raw = "Workout complete, \(totalReps) reps"
        case .exerciseSwitch(let exercise): raw = "Switching to \(exercise)"
        }
        return String(raw.prefix(Self.maxTextLength))
    }

    /// `true` only for `repAnnouncement`, which interrupts in-progress speech to keep counts
    /// current (R4.4); all other categories queue behind the current utterance (R4.5).
    var interrupts: Bool {
        category == .repAnnouncement
    }
}
