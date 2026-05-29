import SwiftUI
import CoreData

/// ViewModel for the Workout screen.
/// Loads workout history and generates personalized recommendations.
/// Validates: Requirements 14.4, 14.7, 14.8
@MainActor
final class WorkoutViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var recommendations: [WorkoutRecommendationEngine.Recommendation] = []
    @Published var recentWorkouts: [WorkoutLog] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let engine = WorkoutRecommendationEngine()
    private let persistence: PersistenceController

    // MARK: - Initialization

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    // MARK: - Public Methods

    /// Fetches workout history from CoreData and generates recommendations.
    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        let context = persistence.container.viewContext

        do {
            // Fetch 10 most recent workouts
            let recentRequest = NSFetchRequest<WorkoutLog>(entityName: "WorkoutLog")
            recentRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \WorkoutLog.date, ascending: false)
            ]
            recentRequest.fetchLimit = 10

            let fetchedRecent = try context.fetch(recentRequest)
            recentWorkouts = fetchedRecent

            // Fetch all history for recommendation engine (last 7 days is handled internally)
            let historyRequest = NSFetchRequest<WorkoutLog>(entityName: "WorkoutLog")
            historyRequest.sortDescriptors = [
                NSSortDescriptor(keyPath: \WorkoutLog.date, ascending: false)
            ]
            let allHistory = try context.fetch(historyRequest)

            // Generate recommendations using the engine
            let availableTypes = [
                "Running", "Walking", "Cycling", "Yoga",
                "Strength", "HIIT", "Swimming", "Stretching"
            ]

            recommendations = engine.generateRecommendations(
                history: allHistory,
                remainingDeficit: 500.0,
                availableTypes: availableTypes
            )
        } catch {
            errorMessage = "Failed to load workout data."
            print("WorkoutViewModel loadData error: \(error)")
        }
    }
}
