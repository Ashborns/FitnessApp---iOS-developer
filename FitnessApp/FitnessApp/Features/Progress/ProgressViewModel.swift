import Foundation
import CoreData

// MARK: - Supporting Types

/// Time range options for progress chart display.
enum TimeRange: Int, CaseIterable {
    case week = 7
    case month = 30
    case quarter = 90

    var displayName: String {
        switch self {
        case .week: return "7 Days"
        case .month: return "30 Days"
        case .quarter: return "90 Days"
        }
    }
}

/// Aggregated daily calorie data for chart display.
struct DailyCalorieData: Identifiable {
    let id = UUID()
    let date: Date
    let total: Double
}

// MARK: - ProgressViewModel

@MainActor
final class ProgressViewModel: ObservableObject {

    @Published var selectedRange: TimeRange = .week
    @Published var calorieData: [DailyCalorieData] = []
    @Published var workoutHistory: [WorkoutLog] = []
    @Published var isLoading: Bool = false

    private let persistence: PersistenceController

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    /// Fetches CalorieEntry aggregated by day and WorkoutLog for the selected time range.
    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        let context = persistence.container.viewContext
        let calendar = Calendar.current
        let now = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -selectedRange.rawValue, to: now) else {
            return
        }

        // Fetch calorie entries in range
        let calorieRequest = NSFetchRequest<CalorieEntry>(entityName: "CalorieEntry")
        calorieRequest.predicate = NSPredicate(
            format: "date >= %@",
            startDate as NSDate
        )
        calorieRequest.sortDescriptors = [NSSortDescriptor(keyPath: \CalorieEntry.date, ascending: true)]

        let entries = (try? context.fetch(calorieRequest)) ?? []

        // Aggregate by day
        var dailyTotals: [Date: Double] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.wrappedDate)
            dailyTotals[day, default: 0] += entry.amount
        }

        calorieData = dailyTotals
            .map { DailyCalorieData(date: $0.key, total: $0.value) }
            .sorted { $0.date < $1.date }

        // Fetch workout logs in range (up to 50 most recent)
        let workoutRequest = NSFetchRequest<WorkoutLog>(entityName: "WorkoutLog")
        workoutRequest.predicate = NSPredicate(
            format: "date >= %@",
            startDate as NSDate
        )
        workoutRequest.sortDescriptors = [NSSortDescriptor(keyPath: \WorkoutLog.date, ascending: false)]
        workoutRequest.fetchLimit = 50

        workoutHistory = (try? context.fetch(workoutRequest)) ?? []
    }
}
