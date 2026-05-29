import XCTest
import CoreData
@testable import FitnessApp

final class WorkoutRecommendationEngineTests: XCTestCase {

    // MARK: - Properties

    private var persistence: PersistenceController!
    private var context: NSManagedObjectContext!
    private var engine: WorkoutRecommendationEngine!

    private let allTypes = [
        "Running", "Walking", "Cycling", "Yoga",
        "Strength", "HIIT", "Swimming", "Stretching"
    ]

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        persistence = PersistenceController(inMemory: true)
        context = persistence.container.viewContext
        engine = WorkoutRecommendationEngine()
    }

    override func tearDown() {
        engine = nil
        context = nil
        persistence = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    /// Creates a WorkoutLog entry with a specific type and date.
    @discardableResult
    private func createWorkoutLog(
        type: String,
        date: Date,
        durationMinutes: Double = 30.0,
        caloriesBurned: Double = 200.0
    ) -> WorkoutLog {
        let log = WorkoutLog(context: context)
        log.id = UUID()
        log.workoutType = type
        log.date = date
        log.durationMinutes = durationMinutes
        log.caloriesBurned = caloriesBurned
        log.formScore = 0.8
        return log
    }

    /// Returns a date that is `daysAgo` days before now.
    private func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date())!
    }

    /// Fetches all WorkoutLog entries from the in-memory context.
    private func fetchAllLogs() -> [WorkoutLog] {
        let request = NSFetchRequest<WorkoutLog>(entityName: "WorkoutLog")
        return (try? context.fetch(request)) ?? []
    }

    // MARK: - Tests

    /// Verify that generateRecommendations always returns between 3 and 5 results.
    func testRecommendationCountInvariant() {
        // Test with some history
        createWorkoutLog(type: "Running", date: daysAgo(2))
        createWorkoutLog(type: "Cycling", date: daysAgo(3))
        try? context.save()

        let history = fetchAllLogs()
        let recommendations = engine.generateRecommendations(
            history: history,
            remainingDeficit: 400.0,
            availableTypes: allTypes
        )

        XCTAssertGreaterThanOrEqual(recommendations.count, 3,
            "Should return at least 3 recommendations")
        XCTAssertLessThanOrEqual(recommendations.count, 5,
            "Should return at most 5 recommendations")
    }

    /// Verify that when no history exists, 3 beginner workouts ≤20 min are returned.
    func testEmptyHistoryReturnsBeginnerDefaults() {
        let recommendations = engine.generateRecommendations(
            history: [],
            remainingDeficit: 500.0,
            availableTypes: allTypes
        )

        XCTAssertEqual(recommendations.count, 3,
            "Empty history should produce exactly 3 beginner recommendations")

        for recommendation in recommendations {
            XCTAssertLessThanOrEqual(recommendation.suggestedDurationMinutes, 20.0,
                "Beginner recommendations should be ≤20 minutes, got \(recommendation.suggestedDurationMinutes) for \(recommendation.workoutType)")
        }
    }

    /// Verify that workout types used in the last 7 days appear after unused types.
    func testRecentTypesRankedLower() {
        // Create recent history for Running and Cycling (within last 7 days)
        createWorkoutLog(type: "Running", date: daysAgo(1))
        createWorkoutLog(type: "Cycling", date: daysAgo(3))
        try? context.save()

        let history = fetchAllLogs()
        let recommendations = engine.generateRecommendations(
            history: history,
            remainingDeficit: 400.0,
            availableTypes: allTypes
        )

        let recommendedTypes = recommendations.map { $0.workoutType }
        let recentTypes: Set<String> = ["Running", "Cycling"]
        let unusedTypes = allTypes.filter { !recentTypes.contains($0) }

        // Find the highest index of any unused type and lowest index of any recent type
        for unusedType in unusedTypes {
            guard let unusedIndex = recommendedTypes.firstIndex(of: unusedType) else { continue }
            for recentType in recentTypes {
                guard let recentIndex = recommendedTypes.firstIndex(of: recentType) else { continue }
                XCTAssertLessThan(unusedIndex, recentIndex,
                    "Unused type '\(unusedType)' (index \(unusedIndex)) should appear before recent type '\(recentType)' (index \(recentIndex))")
            }
        }
    }

    /// Verify that no recommendation exceeds 60 minutes duration.
    func testDurationCapAt60Minutes() {
        // Use a very large deficit that would otherwise produce long durations
        createWorkoutLog(type: "Running", date: daysAgo(10))
        try? context.save()

        let history = fetchAllLogs()
        let recommendations = engine.generateRecommendations(
            history: history,
            remainingDeficit: 5000.0, // Very large deficit
            availableTypes: allTypes
        )

        for recommendation in recommendations {
            XCTAssertLessThanOrEqual(recommendation.suggestedDurationMinutes, 60.0,
                "Duration should never exceed 60 minutes, got \(recommendation.suggestedDurationMinutes) for \(recommendation.workoutType)")
        }
    }

    /// Verify that results are still returned when all available types were used recently.
    func testAllRecentTypesStillReturnsResults() {
        // Create recent history for ALL types
        for type in allTypes {
            createWorkoutLog(type: type, date: daysAgo(Int.random(in: 1...6)))
        }
        try? context.save()

        let history = fetchAllLogs()
        let recommendations = engine.generateRecommendations(
            history: history,
            remainingDeficit: 300.0,
            availableTypes: allTypes
        )

        XCTAssertGreaterThanOrEqual(recommendations.count, 3,
            "Should still return at least 3 recommendations even when all types used recently")
        XCTAssertLessThanOrEqual(recommendations.count, 5,
            "Should return at most 5 recommendations")
    }

    /// Verify that when there is no calorie deficit, shorter durations are suggested.
    func testZeroDeficitShortDurations() {
        // Create some history so we don't get beginner defaults
        createWorkoutLog(type: "Running", date: daysAgo(10))
        createWorkoutLog(type: "Walking", date: daysAgo(12))
        try? context.save()

        let history = fetchAllLogs()

        // Zero deficit
        let zeroDeficitRecs = engine.generateRecommendations(
            history: history,
            remainingDeficit: 0.0,
            availableTypes: allTypes
        )

        // Positive deficit for comparison
        let highDeficitRecs = engine.generateRecommendations(
            history: history,
            remainingDeficit: 400.0,
            availableTypes: allTypes
        )

        // Zero deficit should produce shorter durations than a high deficit
        let zeroAvgDuration = zeroDeficitRecs.map(\.suggestedDurationMinutes).reduce(0, +) / Double(zeroDeficitRecs.count)
        let highAvgDuration = highDeficitRecs.map(\.suggestedDurationMinutes).reduce(0, +) / Double(highDeficitRecs.count)

        XCTAssertLessThan(zeroAvgDuration, highAvgDuration,
            "Zero deficit average duration (\(zeroAvgDuration)) should be less than high deficit average (\(highAvgDuration))")

        // Additionally verify zero deficit durations are short (based on engine's 20 min base for zero deficit)
        for recommendation in zeroDeficitRecs {
            XCTAssertLessThanOrEqual(recommendation.suggestedDurationMinutes, 20.0,
                "Zero deficit should produce durations ≤20 min, got \(recommendation.suggestedDurationMinutes)")
        }
    }
}
