import Foundation

// MARK: - WorkoutBuilderViewModel
// Requirements: 12.1, 12.2, 12.5, 12.6, 12.7, 13.1, 13.7, 15.3, 15.4
//
// Single ViewModel for Builder_Screen (design section 6.4). Manages a
// value-type `RoutineDraft` (name + ordered items) that is freely mutated on
// the main actor, validated via `RoutineValidator` before persistence, and
// saved through `RoutineRepository` (≤2s, Requirement 13.1). On save failure
// the input is preserved and an error message is surfaced so the user can
// retry (Requirement 13.7). Also assembles an AI Coach seed prompt with the
// current routine context (Requirements 15.3, 15.4).
//
// iOS 16.4 / Swift 5.7: `ObservableObject` + `@Published`, no iOS 17+ APIs.

@MainActor
final class WorkoutBuilderViewModel: ObservableObject {

    // MARK: Published state

    /// The routine being created or edited. Order of `items` is the persisted
    /// order (Requirements 12.1, 12.2, 12.6).
    @Published var draft: RoutineDraft

    /// Validation errors from the most recent `save()` attempt. Empty when the
    /// draft is valid or no save has been attempted (Requirement 12.5).
    @Published private(set) var validationErrors: [RoutineValidator.ValidationError] = []

    /// User-facing message describing a persistence failure. `nil` when there
    /// is no outstanding error (Requirement 13.7).
    @Published private(set) var errorMessage: String?

    /// `true` while a save is in flight (drives UI affordances).
    @Published private(set) var isSaving: Bool = false

    /// Set to the persisted Routine id after a successful save. Lets the View
    /// react to a completed save (e.g. dismiss or update navigation).
    @Published private(set) var savedRoutineID: UUID?

    // MARK: Dependencies

    private let repository: RoutineRepositoring

    // MARK: Init

    /// Creates a builder for a new Routine, or loads an existing Routine by id
    /// when `routineID` is provided and found in the repository.
    init(routineID: UUID? = nil, repository: RoutineRepositoring = RoutineRepository()) {
        self.repository = repository
        if let routineID,
           let snapshot = repository.loadAll().first(where: { $0.id == routineID }) {
            self.draft = Self.makeDraft(from: snapshot)
        } else {
            self.draft = RoutineDraft()
        }
    }

    /// Creates a builder seeded with an explicit draft (e.g. handed off from
    /// another screen that already started building a Routine).
    init(draft: RoutineDraft, repository: RoutineRepositoring = RoutineRepository()) {
        self.repository = repository
        self.draft = draft
    }

    // MARK: - Editing (Requirement 12.2, 12.6, 12.7)

    /// Appends a new `RoutineItemDraft` referencing the given exercise with
    /// editable default sets/reps/rest (Requirement 12.2).
    func addItem(for exercise: ExerciseItem) {
        let item = RoutineItemDraft(
            exerciseID: exercise.id,
            exerciseName: exercise.name
        )
        draft.items.append(item)
        clearTransientErrors()
    }

    /// Updates the editable sets/reps/rest of the item identified by `id`.
    /// Only the provided fields are changed; the rest are left untouched. No
    /// range clamping is applied here — out-of-range values are surfaced by
    /// `RoutineValidator` at save time so the user keeps their input
    /// (Requirements 12.2, 12.5).
    func updateItem(id: UUID, sets: Int? = nil, reps: Int? = nil, restSeconds: Int? = nil) {
        guard let index = draft.items.firstIndex(where: { $0.id == id }) else { return }
        if let sets { draft.items[index].sets = sets }
        if let reps { draft.items[index].reps = reps }
        if let restSeconds { draft.items[index].restSeconds = restSeconds }
        clearTransientErrors()
    }

    /// Reorders items, preserving the new order on the saved Routine
    /// (Requirement 12.6). Designed for SwiftUI `.onMove`.
    func moveItems(from source: IndexSet, to destination: Int) {
        draft.items.move(fromOffsets: source, toOffset: destination)
        clearTransientErrors()
    }

    /// Removes items at the given offsets without altering the values or
    /// relative order of the remaining items (Requirement 12.7). Designed for
    /// SwiftUI `.onDelete`.
    func deleteItems(at offsets: IndexSet) {
        draft.items.remove(atOffsets: offsets)
        clearTransientErrors()
    }

    /// Removes a single item by id without altering the remaining items
    /// (Requirement 12.7).
    func deleteItem(id: UUID) {
        draft.items.removeAll { $0.id == id }
        clearTransientErrors()
    }

    // MARK: - Save (Requirements 12.5, 13.1, 13.7)

    /// Validates the draft and, when valid, persists it via `RoutineRepository`.
    ///
    /// - If validation fails, `validationErrors` is populated, nothing is
    ///   saved, and the user input is preserved (Requirement 12.5).
    /// - If the repository throws, `errorMessage` is set and the input is
    ///   preserved so the user can retry (Requirement 13.7).
    /// - On success, `savedRoutineID` is set and `draft.id` is updated so a
    ///   subsequent save updates the same record rather than duplicating it.
    ///
    /// - Returns: `true` when the Routine was persisted, otherwise `false`.
    @discardableResult
    func save() async -> Bool {
        errorMessage = nil

        let errors = RoutineValidator.validate(draft)
        guard errors.isEmpty else {
            validationErrors = errors
            return false
        }
        validationErrors = []

        isSaving = true
        defer { isSaving = false }

        let draftToSave = draft
        do {
            // The repository performs its Core Data write on a background
            // context; run it off the main actor to keep the UI responsive
            // while still completing within the ≤2s budget (Requirement 13.1).
            let savedID = try await persistedID(for: draftToSave)
            draft.id = savedID
            savedRoutineID = savedID
            return true
        } catch {
            // Preserve input + surface a retryable error (Requirement 13.7).
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - AI Coach context (Requirements 15.3, 15.4)

    /// Builds an AI Coach seed prompt that includes the Routine name and the
    /// list of exercise names in the current draft (Requirements 15.3, 15.4).
    func chatSeed() -> ChatSeed {
        ChatSeed(userVisiblePrompt: ExerciseContextSeeder.prompt(for: snapshotForContext()))
    }

    // MARK: - Helpers

    /// Bridges the synchronous repository save onto a background executor so
    /// the main actor is not blocked during persistence.
    private nonisolated func persistedID(for draft: RoutineDraft) async throws -> UUID {
        try await Task.detached(priority: .userInitiated) { [repository] in
            try repository.save(draft)
        }.value
    }

    /// Maps the in-progress draft to a `RoutineSnapshot` for the AI Coach
    /// seeder. `orderPosition` follows the current array order.
    private func snapshotForContext() -> RoutineSnapshot {
        let items = draft.items.enumerated().map { index, item in
            RoutineItemSnapshot(
                id: item.id,
                exerciseID: item.exerciseID,
                exerciseName: item.exerciseName,
                sets: item.sets,
                reps: item.reps,
                restSeconds: item.restSeconds,
                orderPosition: index
            )
        }
        return RoutineSnapshot(
            id: draft.id ?? UUID(),
            name: draft.name,
            createdAt: Date(),
            items: items
        )
    }

    /// Clears stale save-time errors when the user edits the draft, so the UI
    /// does not show outdated validation/error messages.
    private func clearTransientErrors() {
        if !validationErrors.isEmpty { validationErrors = [] }
        if errorMessage != nil { errorMessage = nil }
    }

    /// Converts a persisted snapshot back into an editable draft, preserving
    /// the Routine id so a re-save updates the same record (Requirement 13.5).
    private static func makeDraft(from snapshot: RoutineSnapshot) -> RoutineDraft {
        let items = snapshot.items.map { item in
            RoutineItemDraft(
                id: item.id,
                exerciseID: item.exerciseID,
                exerciseName: item.exerciseName,
                sets: item.sets,
                reps: item.reps,
                restSeconds: item.restSeconds
            )
        }
        return RoutineDraft(id: snapshot.id, name: snapshot.name, items: items)
    }
}
