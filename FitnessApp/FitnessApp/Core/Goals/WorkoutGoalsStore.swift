import Foundation
import Combine

/// Tracks daily workout goal progress, streak count, and reset logic.
/// Persisted via UserDefaults — single source of truth for goals/streaks across the app.
@MainActor
final class WorkoutGoalsStore: ObservableObject {

    static let shared = WorkoutGoalsStore()

    // MARK: - Published

    /// Daily target in total reps across all exercises.
    @Published var dailyRepGoal: Int {
        didSet { UserDefaults.standard.set(dailyRepGoal, forKey: Keys.dailyRepGoal) }
    }

    /// Reps logged today (computed from `dailyProgress` map).
    @Published private(set) var todayReps: Int = 0

    /// Current consecutive-day streak.
    @Published private(set) var currentStreak: Int = 0

    /// Best streak ever achieved.
    @Published private(set) var bestStreak: Int = 0

    // MARK: - Storage

    /// Map of "yyyy-MM-dd" → reps logged on that day.
    private var dailyProgress: [String: Int] {
        get {
            UserDefaults.standard.dictionary(forKey: Keys.dailyProgress) as? [String: Int] ?? [:]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.dailyProgress)
        }
    }

    // MARK: - Init

    private init() {
        let saved = UserDefaults.standard.integer(forKey: Keys.dailyRepGoal)
        self.dailyRepGoal = saved == 0 ? 50 : saved
        self.bestStreak = UserDefaults.standard.integer(forKey: Keys.bestStreak)
        recalculate()
    }

    // MARK: - Public API

    /// Add reps to today's progress and update streak.
    func addReps(_ reps: Int) {
        guard reps > 0 else { return }
        let key = Self.dateKey(for: Date())
        var map = dailyProgress
        map[key] = (map[key] ?? 0) + reps
        dailyProgress = map
        recalculate()
    }

    /// Today's progress as 0...1 fraction toward the daily goal.
    var todayProgressFraction: Double {
        guard dailyRepGoal > 0 else { return 0 }
        return min(Double(todayReps) / Double(dailyRepGoal), 1.0)
    }

    /// Whether today's goal has been met.
    var isTodayGoalMet: Bool {
        todayReps >= dailyRepGoal
    }

    /// Last 7 days as (date, reps) tuples, oldest first. Empty days = 0.
    func last7Days() -> [(Date, Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let map = dailyProgress
        return (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else {
                return nil
            }
            let key = Self.dateKey(for: day)
            return (day, map[key] ?? 0)
        }
    }

    // MARK: - Recalculate

    private func recalculate() {
        let map = dailyProgress
        let todayKey = Self.dateKey(for: Date())
        todayReps = map[todayKey] ?? 0

        // Streak = consecutive days (going back from today) with reps > 0
        let calendar = Calendar.current
        var streak = 0
        var day = calendar.startOfDay(for: Date())

        // If today has 0 reps, streak resets — so check yesterday onward
        // But if today has reps, count today as day 1 of streak.
        for offset in 0...365 {
            let key = Self.dateKey(for: day)
            let reps = map[key] ?? 0
            if reps > 0 {
                streak += 1
            } else if offset == 0 {
                // Today: 0 reps → streak hasn't started today (still show yesterday's)
                // Skip, look at yesterday
            } else {
                break
            }
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }

        currentStreak = streak

        if streak > bestStreak {
            bestStreak = streak
            UserDefaults.standard.set(bestStreak, forKey: Keys.bestStreak)
        }
    }

    // MARK: - Helpers

    static func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    // MARK: - Keys

    private enum Keys {
        static let dailyRepGoal = "goals.dailyRepGoal"
        static let dailyProgress = "goals.dailyProgress"
        static let bestStreak = "goals.bestStreak"
    }
}
