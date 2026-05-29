// Agent 4 owns this file
// XCTest for CalorieGoalViewModel (80% coverage minimum)

import XCTest
import CoreData
@testable import FitnessApp

@MainActor
final class CalorieGoalViewModelTests: XCTestCase {

    // MARK: - Properties

    private var persistence: PersistenceController!
    private var healthKitManager: HealthKitManager!
    private var viewModel: CalorieGoalViewModel!

    // MARK: - Setup / Teardown

    override func setUp() {
        super.setUp()
        persistence = PersistenceController(inMemory: true)
        healthKitManager = HealthKitManager.shared
        viewModel = CalorieGoalViewModel(
            persistence: persistence,
            healthKitManager: healthKitManager
        )
    }

    override func tearDown() {
        viewModel = nil
        healthKitManager = nil
        persistence = nil
        super.tearDown()
    }

    // MARK: - Tests

    /// Verify entry persists to CoreData with valid amount and label.
    func testSaveEntryValidInput() {
        let result = viewModel.saveEntry(amount: 500, label: "Lunch")

        switch result {
        case .success:
            // Verify entry was persisted
            let context = persistence.container.viewContext
            let request = CalorieEntry.todayFetchRequest()
            let entries = try? context.fetch(request)

            XCTAssertNotNil(entries)
            XCTAssertEqual(entries?.count, 1)

            let entry = entries?.first
            XCTAssertEqual(entry?.amount, 500)
            XCTAssertEqual(entry?.label, "Lunch")
            XCTAssertEqual(entry?.source, "manual")
            XCTAssertNotNil(entry?.date)
            XCTAssertNotNil(entry?.id)
        case .failure(let error):
            XCTFail("Expected success but got error: \(error)")
        }
    }

    /// Verify .invalidAmount error for amount outside 1-99999.
    func testSaveEntryInvalidAmount() {
        // Test amount below range
        let resultZero = viewModel.saveEntry(amount: 0, label: "Snack")
        XCTAssertEqual(resultZero, .failure(.invalidAmount))

        // Test negative amount
        let resultNegative = viewModel.saveEntry(amount: -10, label: "Snack")
        XCTAssertEqual(resultNegative, .failure(.invalidAmount))

        // Test amount above range
        let resultOver = viewModel.saveEntry(amount: 100000, label: "Snack")
        XCTAssertEqual(resultOver, .failure(.invalidAmount))

        // Verify error message is set
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.errorMessage, CalorieValidationError.invalidAmount.errorDescription)
    }

    /// Verify .invalidLabel error for empty or >100 char label.
    func testSaveEntryInvalidLabel() {
        // Test empty label
        let resultEmpty = viewModel.saveEntry(amount: 200, label: "")
        XCTAssertEqual(resultEmpty, .failure(.invalidLabel))

        // Test whitespace-only label
        let resultWhitespace = viewModel.saveEntry(amount: 200, label: "   ")
        XCTAssertEqual(resultWhitespace, .failure(.invalidLabel))

        // Test label exceeding 100 characters
        let longLabel = String(repeating: "a", count: 101)
        let resultLong = viewModel.saveEntry(amount: 200, label: longLabel)
        XCTAssertEqual(resultLong, .failure(.invalidLabel))

        // Verify error message is set
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.errorMessage, CalorieValidationError.invalidLabel.errorDescription)
    }

    /// Verify consumed equals sum of today's entries.
    func testConsumedComputedFromTodayEntries() {
        // Save multiple entries
        viewModel.saveEntry(amount: 300, label: "Breakfast")
        viewModel.saveEntry(amount: 600, label: "Lunch")
        viewModel.saveEntry(amount: 450, label: "Dinner")

        // The consumed property should reflect the sum of today's entries
        XCTAssertEqual(viewModel.consumed, 1350, accuracy: 0.01)
    }

    /// Verify burned value comes from HealthKit (simulator mock returns 320.0).
    func testBurnedIntegratesWithHealthKit() async {
        await viewModel.loadTodayData()

        // On simulator, HealthKitManager.fetchTodayActiveEnergy() returns 320.0
        XCTAssertEqual(viewModel.burned, 320.0, accuracy: 0.01)
    }

    /// Verify no CoreData entry created on invalid input.
    func testSaveEntryDoesNotPersistOnValidationFailure() {
        // Attempt to save with invalid amount
        viewModel.saveEntry(amount: 0, label: "Invalid")

        // Attempt to save with invalid label
        viewModel.saveEntry(amount: 100, label: "")

        // Verify no entries were persisted
        let context = persistence.container.viewContext
        let request = CalorieEntry.todayFetchRequest()
        let entries = try? context.fetch(request)

        XCTAssertNotNil(entries)
        XCTAssertEqual(entries?.count, 0)
    }

    /// Verify dailyGoal stays within 500-10000.
    func testDailyGoalClampedToRange() {
        // Test below minimum
        viewModel.dailyGoal = 100
        XCTAssertEqual(viewModel.dailyGoal, 500)

        // Test above maximum
        viewModel.dailyGoal = 15000
        XCTAssertEqual(viewModel.dailyGoal, 10000)

        // Test at minimum boundary
        viewModel.dailyGoal = 500
        XCTAssertEqual(viewModel.dailyGoal, 500)

        // Test at maximum boundary
        viewModel.dailyGoal = 10000
        XCTAssertEqual(viewModel.dailyGoal, 10000)

        // Test within valid range
        viewModel.dailyGoal = 2500
        XCTAssertEqual(viewModel.dailyGoal, 2500)
    }
}
