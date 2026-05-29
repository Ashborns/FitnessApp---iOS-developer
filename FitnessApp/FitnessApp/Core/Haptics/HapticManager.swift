import UIKit

/// Centralized haptic feedback manager for the workout experience.
/// Wraps UIImpactFeedbackGenerator + UINotificationFeedbackGenerator with intent-based methods.
@MainActor
final class HapticManager {

    static let shared = HapticManager()

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()

    private init() {
        prepare()
    }

    /// Pre-warms generators for lower latency on first use.
    func prepare() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        notification.prepare()
    }

    // MARK: - Workout

    /// Light tap on every rep counted.
    func repCounted() {
        lightImpact.impactOccurred()
        lightImpact.prepare()
    }

    /// Stronger pulse every 10 reps (milestone).
    func milestone() {
        mediumImpact.impactOccurred(intensity: 0.9)
        mediumImpact.prepare()
    }

    /// Success burst when a workout is saved.
    func workoutCompleted() {
        notification.notificationOccurred(.success)
        notification.prepare()
    }

    // MARK: - UI

    /// Light tap for selection (button taps, toggle changes).
    func selection() {
        lightImpact.impactOccurred(intensity: 0.6)
        lightImpact.prepare()
    }

    /// Used for warnings or destructive actions.
    func warning() {
        notification.notificationOccurred(.warning)
        notification.prepare()
    }
}
