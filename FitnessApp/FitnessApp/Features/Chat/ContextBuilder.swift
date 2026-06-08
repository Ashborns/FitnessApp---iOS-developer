import Foundation
import CoreData

/// Pure struct that assembles the FitnessContext snapshot string from all live data sources.
/// All data-source errors are caught internally; fallback values are substituted so the
/// caller always receives a valid, non-throwing string.
struct ContextBuilder {

    /// Assembles a FitnessContext snapshot string.
    @MainActor
    func buildContext() async -> String {
        // MARK: Goals & Streaks
        let goals = WorkoutGoalsStore.shared
        let dailyRepGoal = goals.dailyRepGoal
        let todayReps = goals.todayReps
        let currentStreak = goals.currentStreak
        let bestStreak = goals.bestStreak
        let last7 = goals.last7Days()

        // MARK: Calories
        let calorieVM = CalorieGoalViewModel()
        await calorieVM.loadTodayData()
        let dailyGoal = calorieVM.dailyGoal
        let consumed = calorieVM.consumed

        // MARK: Burned (HealthKit, with fallback)
        var burned: Double = 0
        var healthKitUnavailable = false
        do {
            burned = try await HealthKitManager.shared.fetchTodayActiveEnergy()
        } catch {
            burned = 0
            healthKitUnavailable = true
        }

        // MARK: Recent Workouts (CoreData, with fallback)
        var workoutNote = ""
        var recentWorkouts: [WorkoutLog] = []
        let context = PersistenceController.shared.container.viewContext
        let request = WorkoutLog.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WorkoutLog.date, ascending: false)]
        request.fetchLimit = 5
        do {
            recentWorkouts = try context.fetch(request)
            if recentWorkouts.isEmpty {
                workoutNote = "No workout history recorded."
            } else {
                workoutNote = "\(recentWorkouts.count) recent workout entries found."
            }
        } catch {
            workoutNote = "Workout history unavailable."
        }

        // MARK: Recommendations
        let engine = WorkoutRecommendationEngine()
        let remainingDeficit = max(dailyGoal - consumed, 0)
        let recommendations = engine.generateRecommendations(
            history: recentWorkouts,
            remainingDeficit: remainingDeficit,
            availableTypes: []
        )

        // MARK: Assemble
        return assemble(
            dailyRepGoal: dailyRepGoal,
            todayReps: todayReps,
            currentStreak: currentStreak,
            bestStreak: bestStreak,
            last7: last7,
            dailyGoal: dailyGoal,
            consumed: consumed,
            burned: burned,
            healthKitUnavailable: healthKitUnavailable,
            recommendations: recommendations,
            recentWorkouts: recentWorkouts,
            workoutNote: workoutNote
        )
    }

    // MARK: - String Assembly

    private func assemble(
        dailyRepGoal: Int,
        todayReps: Int,
        currentStreak: Int,
        bestStreak: Int,
        last7: [(Date, Int)],
        dailyGoal: Double,
        consumed: Double,
        burned: Double,
        healthKitUnavailable: Bool,
        recommendations: [WorkoutRecommendationEngine.Recommendation],
        recentWorkouts: [WorkoutLog],
        workoutNote: String
    ) -> String {
        var lines: [String] = []

        lines.append("You are PULSE AI, a personal fitness coach. Reference the data below when answering.")
        lines.append("Keep responses to 150 words or fewer unless the user explicitly asks for more detail.")
        lines.append("")
        lines.append("=== EXERCISE INTEGRATION RULES ===")
        lines.append("The app has a camera mode with real-time rep tracking for these exercises:")
        lines.append("- jumpingJacks (Jumping Jacks)")
        lines.append("- squats (Squats)")
        lines.append("- highKnees (High Knees)")
        lines.append("- armRaises (Arm Raises)")
        lines.append("- toeTouches (Toe Touches)")
        lines.append("")
        lines.append("When you recommend one of these exercises, you MUST include a special tag")
        lines.append("at the END of your response on its own line. The tag format is:")
        lines.append("[EXERCISE:rawValue]")
        lines.append("")
        lines.append("Examples:")
        lines.append("- If recommending squats, add: [EXERCISE:squats]")
        lines.append("- If recommending jumping jacks, add: [EXERCISE:jumpingJacks]")
        lines.append("- If recommending high knees, add: [EXERCISE:highKnees]")
        lines.append("- If recommending arm raises, add: [EXERCISE:armRaises]")
        lines.append("- If recommending toe touches, add: [EXERCISE:toeTouches]")
        lines.append("")
        lines.append("Only include the tag when the user asks to do an exercise or you suggest one.")
        lines.append("DO NOT include the tag for general fitness advice without a specific exercise.")
        lines.append("Place the tag on its OWN LINE at the very end of your response.")
        lines.append("")
        lines.append("=== FITNESS SNAPSHOT ===")
        lines.append("Date: \(dateString(Date(), format: "yyyy-MM-dd"))")
        lines.append("")

        // Goals & Streaks
        lines.append("[GOALS & STREAKS]")
        lines.append("Daily rep goal: \(dailyRepGoal) reps")
        lines.append("Today's reps: \(todayReps)")
        lines.append("Current streak: \(currentStreak) days")
        lines.append("Best streak: \(bestStreak) days")
        lines.append("")

        // Last 7 days
        lines.append("[LAST 7 DAYS — REPS]")
        for (date, reps) in last7 {
            lines.append("\(dateString(date, format: "EEE dd/MM")): \(reps) reps")
        }
        lines.append("")

        // Calories
        let burnedLine: String
        if healthKitUnavailable {
            burnedLine = "Burned today: 0 kcal — HealthKit data unavailable"
        } else {
            burnedLine = "Burned today: \(Int(burned)) kcal"
        }
        lines.append("[CALORIES]")
        lines.append("Daily goal: \(Int(dailyGoal)) kcal")
        lines.append("Consumed today: \(Int(consumed)) kcal")
        lines.append(burnedLine)
        lines.append("Net: \(Int(consumed - burned)) kcal")
        lines.append("")

        // Recommendations
        lines.append("[WORKOUT RECOMMENDATIONS]")
        if recommendations.isEmpty {
            lines.append("1. Walking — 20 min")
        } else {
            for (index, rec) in recommendations.prefix(3).enumerated() {
                lines.append("\(index + 1). \(rec.workoutType) — \(Int(rec.suggestedDurationMinutes)) min")
            }
        }
        lines.append("")

        // Recent workouts
        lines.append("[RECENT WORKOUTS]")
        lines.append(workoutNote)
        for (index, workout) in recentWorkouts.prefix(5).enumerated() {
            let type = workout.workoutType ?? "Workout"
            let duration = Int(workout.durationMinutes)
            let date = dateString(workout.date ?? Date(), format: "yyyy-MM-dd")
            lines.append("\(index + 1). \(type) — \(duration) min on \(date)")
        }
        lines.append("========================")

        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private func dateString(_ date: Date, format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
