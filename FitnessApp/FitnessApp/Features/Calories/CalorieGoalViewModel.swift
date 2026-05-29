import SwiftUI
import CoreData

// MARK: - Validation Error

enum CalorieValidationError: LocalizedError, Equatable {
    case invalidAmount
    case invalidLabel
    case persistenceFailed(Error)

    var errorDescription: String? {
        switch self {
        case .invalidAmount:
            return "Calorie amount must be between 1 and 99,999 kcal."
        case .invalidLabel:
            return "Label must be between 1 and 100 characters."
        case .persistenceFailed(let error):
            return "Failed to save entry: \(error.localizedDescription)"
        }
    }

    static func == (lhs: CalorieValidationError, rhs: CalorieValidationError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidAmount, .invalidAmount):
            return true
        case (.invalidLabel, .invalidLabel):
            return true
        case (.persistenceFailed, .persistenceFailed):
            return true
        default:
            return false
        }
    }
}

// MARK: - CalorieGoalViewModel

@MainActor
final class CalorieGoalViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var dailyGoal: Double = 2000 {
        didSet {
            // Clamp to valid range 500–10000
            if dailyGoal < 500 {
                dailyGoal = 500
            } else if dailyGoal > 10000 {
                dailyGoal = 10000
            }
        }
    }

    @Published var consumed: Double = 0
    @Published var burned: Double = 0
    @Published var errorMessage: String?
    @Published var entries: [CalorieEntry] = []

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

    // MARK: - Public Methods

    /// Loads today's calorie entries and burned calories from HealthKit.
    /// Fetches CalorieEntry records for the current day (midnight to midnight local timezone),
    /// computes consumed as the sum of amounts, and fetches burned from HealthKit.
    func loadTodayData() async {
        // Fetch today's entries from CoreData
        let context = persistence.container.viewContext
        let request = CalorieEntry.todayFetchRequest()

        do {
            let todayEntries = try context.fetch(request)
            entries = todayEntries
            consumed = todayEntries.reduce(0.0) { $0 + $1.amount }
        } catch {
            errorMessage = "Failed to load today's entries: \(error.localizedDescription)"
            entries = []
            consumed = 0
        }

        // Fetch burned calories from HealthKit
        do {
            let energy = try await healthKitManager.fetchTodayActiveEnergy()
            burned = energy
        } catch {
            burned = 0
            errorMessage = "Burned calorie data is unavailable. HealthKit access may be denied."
        }
    }

    /// Saves a new calorie entry after validating the input.
    /// - Parameters:
    ///   - amount: The calorie amount (must be between 1 and 99,999)
    ///   - label: The entry label (must be 1–100 characters)
    /// - Returns: A Result indicating success or a validation error
    @discardableResult
    func saveEntry(amount: Double, label: String) -> Result<Void, CalorieValidationError> {
        // Validate amount
        guard amount >= 1, amount <= 99999 else {
            errorMessage = CalorieValidationError.invalidAmount.errorDescription
            return .failure(.invalidAmount)
        }

        // Validate label
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLabel.isEmpty, trimmedLabel.count <= 100 else {
            errorMessage = CalorieValidationError.invalidLabel.errorDescription
            return .failure(.invalidLabel)
        }

        // Create and persist the entry
        let context = persistence.container.viewContext
        _ = CalorieEntry.create(in: context, amount: amount, label: trimmedLabel, source: "manual")

        do {
            try context.save()
        } catch {
            // Rollback the unsaved entry
            context.rollback()
            let validationError = CalorieValidationError.persistenceFailed(error)
            errorMessage = validationError.errorDescription
            return .failure(validationError)
        }

        // Reload entries after successful save
        let request = CalorieEntry.todayFetchRequest()
        do {
            let todayEntries = try context.fetch(request)
            entries = todayEntries
            consumed = todayEntries.reduce(0.0) { $0 + $1.amount }
        } catch {
            errorMessage = "Failed to reload entries: \(error.localizedDescription)"
        }

        // Clear any previous error on success
        errorMessage = nil
        return .success(())
    }
}
