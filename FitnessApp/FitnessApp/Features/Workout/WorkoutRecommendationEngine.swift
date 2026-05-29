import Foundation
import CoreData

/// A pure rule-based workout recommendation engine.
/// Generates 3–5 personalized workout suggestions based on user history and calorie deficit.
struct WorkoutRecommendationEngine {

    // MARK: - Types

    struct Recommendation {
        let workoutType: String
        let suggestedDurationMinutes: Double
    }

    // MARK: - Constants

    private static let defaultAvailableTypes: [String] = [
        "Running", "Walking", "Cycling", "Yoga",
        "Strength", "HIIT", "Swimming", "Stretching"
    ]

    private static let beginnerTypes: [String] = ["Walking", "Stretching", "Yoga"]

    private static let maxDurationMinutes: Double = 60.0
    private static let beginnerMaxDuration: Double = 20.0
    private static let recentWindowDays: Int = 7

    // MARK: - Public API

    /// Generates workout recommendations based on history, calorie deficit, and available types.
    ///
    /// - Parameters:
    ///   - history: Array of WorkoutLog entries from CoreData.
    ///   - remainingDeficit: The remaining calorie deficit for the day (positive means more to burn).
    ///   - availableTypes: Workout types to choose from. Uses defaults if empty.
    /// - Returns: An array of 3–5 `Recommendation` values.
    func generateRecommendations(
        history: [WorkoutLog],
        remainingDeficit: Double,
        availableTypes: [String]
    ) -> [Recommendation] {
        let types = availableTypes.isEmpty ? Self.defaultAvailableTypes : availableTypes

        // Rule 1: No history → return 3 beginner workouts ≤20 min each
        if history.isEmpty {
            return generateBeginnerRecommendations(availableTypes: types)
        }

        // Determine which types were used in the last 7 days
        let recentCutoff = Calendar.current.date(
            byAdding: .day,
            value: -Self.recentWindowDays,
            to: Date()
        ) ?? Date()

        let recentHistory = history.filter { log in
            guard let logDate = log.date else { return false }
            return logDate >= recentCutoff
        }

        let recentTypes = Set(recentHistory.compactMap { $0.workoutType })

        // Rule 2 & 4: Separate types into not-recent (higher priority) and recent (lower priority)
        let notRecentTypes = types.filter { !recentTypes.contains($0) }
        let recentTypesList = types.filter { recentTypes.contains($0) }

        // Rule 5: If all types used recently → sort by least recently performed
        let rankedTypes: [String]
        if notRecentTypes.isEmpty {
            rankedTypes = sortByLeastRecent(types: recentTypesList, history: recentHistory)
        } else {
            // Not-recent types first, then recent types sorted by least recent
            let sortedRecent = sortByLeastRecent(types: recentTypesList, history: recentHistory)
            rankedTypes = notRecentTypes + sortedRecent
        }

        // Rule 3: Scale duration based on remaining deficit (max 60 min)
        let baseDuration = computeBaseDuration(remainingDeficit: remainingDeficit)

        // Generate 3–5 recommendations
        let count = min(max(3, rankedTypes.count), 5)
        var recommendations: [Recommendation] = []

        for i in 0..<count {
            guard i < rankedTypes.count else { break }
            let type = rankedTypes[i]
            // Slightly vary duration: first recommendations get full duration, later ones get slightly less
            let durationFactor = 1.0 - (Double(i) * 0.1)
            let duration = min(baseDuration * durationFactor, Self.maxDurationMinutes)
            let clampedDuration = max(10.0, duration) // Minimum 10 minutes

            recommendations.append(Recommendation(
                workoutType: type,
                suggestedDurationMinutes: clampedDuration.rounded()
            ))
        }

        // Ensure we have at least 3 recommendations
        while recommendations.count < 3, recommendations.count < rankedTypes.count {
            let idx = recommendations.count
            let type = rankedTypes[idx]
            let duration = min(baseDuration * 0.7, Self.maxDurationMinutes)
            recommendations.append(Recommendation(
                workoutType: type,
                suggestedDurationMinutes: max(10.0, duration).rounded()
            ))
        }

        return Array(recommendations.prefix(5))
    }

    // MARK: - Private Helpers

    /// Returns 3 beginner-friendly recommendations with durations ≤20 min.
    private func generateBeginnerRecommendations(availableTypes: [String]) -> [Recommendation] {
        // Use beginner types that are available, fall back to first 3 available types
        let beginnerAvailable = Self.beginnerTypes.filter { availableTypes.contains($0) }
        let selectedTypes: [String]

        if beginnerAvailable.count >= 3 {
            selectedTypes = Array(beginnerAvailable.prefix(3))
        } else {
            // Fill with available types that aren't already selected
            var result = beginnerAvailable
            for type in availableTypes where !result.contains(type) {
                result.append(type)
                if result.count >= 3 { break }
            }
            selectedTypes = Array(result.prefix(3))
        }

        return selectedTypes.map { type in
            let duration: Double
            switch type {
            case "Walking":
                duration = 20.0
            case "Stretching":
                duration = 15.0
            case "Yoga":
                duration = 20.0
            default:
                duration = 15.0
            }
            return Recommendation(workoutType: type, suggestedDurationMinutes: duration)
        }
    }

    /// Sorts types by their most recent usage date (least recent first).
    private func sortByLeastRecent(types: [String], history: [WorkoutLog]) -> [String] {
        // Build a map of type → most recent date
        var lastPerformed: [String: Date] = [:]

        for log in history {
            guard let type = log.workoutType, let date = log.date else { continue }
            if let existing = lastPerformed[type] {
                if date > existing {
                    lastPerformed[type] = date
                }
            } else {
                lastPerformed[type] = date
            }
        }

        // Sort: types with older (or no) last-performed date come first
        return types.sorted { typeA, typeB in
            let dateA = lastPerformed[typeA] ?? .distantPast
            let dateB = lastPerformed[typeB] ?? .distantPast
            return dateA < dateB
        }
    }

    /// Computes a base duration scaled proportionally to the remaining calorie deficit.
    /// Assumes ~8 kcal/min as a moderate burn rate for scaling purposes.
    private func computeBaseDuration(remainingDeficit: Double) -> Double {
        guard remainingDeficit > 0 else {
            // No deficit remaining → suggest shorter maintenance workouts
            return 20.0
        }

        // Scale: roughly 8 kcal/min moderate activity
        // Cap at 60 minutes
        let estimatedMinutes = remainingDeficit / 8.0
        return min(estimatedMinutes, Self.maxDurationMinutes)
    }
}
