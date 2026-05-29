import Foundation
import CoreData

// MARK: - HomeViewModel
// Requirements: 14.1, 14.2, 14.8

/// ViewModel for the Home dashboard screen.
/// Fetches today's calorie summary and recent workouts from CoreData.
@MainActor
final class HomeViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var calorieGoal: Double = 2000
    @Published var consumed: Double = 0
    @Published var burned: Double = 0
    @Published var recentWorkouts: [WorkoutLog] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    // MARK: - Dependencies

    private let persistence: PersistenceController
    private let healthKitManager: HealthKitManager

    // MARK: - Initialization

    init(
        persistence: PersistenceController = .shared,
        healthKitManager: HealthKitManager = .shared
    ) {
        self.persistence = persistence
        self.healthKitManager = healthKitManager
    }

    // MARK: - Data Loading

    /// Fetches today's calorie data and the 3 most recent workouts from CoreData.
    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        await loadCalorieData()
        await loadBurnedCalories()
        loadRecentWorkouts()
    }

    // MARK: - Private Helpers

    private func loadCalorieData() async {
        let context = persistence.container.viewContext
        let request = CalorieEntry.todayFetchRequest()

        do {
            let entries = try context.fetch(request)
            consumed = entries.reduce(0) { $0 + $1.amount }
        } catch {
            errorMessage = "Unable to load calorie data."
        }

        // Use profile-calculated goal from UserDefaults (set by UserProfileStore)
        let profileGoal = UserDefaults.standard.double(forKey: "profile.dailyCalorieGoal")
        if profileGoal > 0 {
            calorieGoal = profileGoal
            return
        }

        // Fallback: load from CoreData DailyGoal
        let goalRequest = NSFetchRequest<NSManagedObject>(entityName: "DailyGoal")
        let startOfDay = Calendar.current.startOfDay(for: Date())
        goalRequest.predicate = NSPredicate(format: "date >= %@", startOfDay as NSDate)
        goalRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]
        goalRequest.fetchLimit = 1

        if let goal = try? context.fetch(goalRequest).first,
           let goalValue = goal.value(forKey: "calorieGoal") as? Double {
            calorieGoal = goalValue
        }
    }

    private func loadBurnedCalories() async {
        // 1. Sum calories burned from workouts logged today (CoreData)
        let context = persistence.container.viewContext
        let request = WorkoutLog.fetchRequest()
        let startOfDay = Calendar.current.startOfDay(for: Date())
        request.predicate = NSPredicate(format: "date >= %@", startOfDay as NSDate)

        var fromWorkouts: Double = 0
        if let workouts = try? context.fetch(request) {
            fromWorkouts = workouts.reduce(0) { $0 + $1.caloriesBurned }
        }

        // 2. Try HealthKit (gracefully degrades if unavailable / not authorized)
        var fromHealthKit: Double = 0
        do {
            fromHealthKit = try await healthKitManager.fetchTodayActiveEnergy()
        } catch {
            fromHealthKit = 0
        }

        // Use the larger of the two — HealthKit reflects all activity (walking, etc.)
        // but if it's unavailable, our CoreData log still shows progress.
        burned = max(fromWorkouts, fromHealthKit)
    }

    private func loadRecentWorkouts() {
        let context = persistence.container.viewContext
        let request = WorkoutLog.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WorkoutLog.date, ascending: false)]
        request.fetchLimit = 3

        do {
            recentWorkouts = try context.fetch(request)
        } catch {
            errorMessage = "Unable to load recent workouts."
        }
    }

    /// Fetch a single workout by its CoreData object ID.
    /// Used when navigating from Home → WorkoutDetailView.
    func fetchWorkout(by id: NSManagedObjectID) throws -> WorkoutLog? {
        let context = persistence.container.viewContext
        return try context.existingObject(with: id) as? WorkoutLog
    }
}
