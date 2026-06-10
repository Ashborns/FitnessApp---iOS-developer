import Foundation

// MARK: - RoutineDraft
// Requirements: 12.1, 12.2, 13.2, 13.3
// Value-type inputs used when creating or editing a Routine on the
// Builder_Screen. Drafts are detached from Core Data (NSManagedObject) so they
// can be freely mutated, validated, and passed across threads before being
// persisted via RoutineRepository.save(_:).

/// A user-editable description of a Routine to be created or updated.
///
/// `id == nil` denotes a brand-new Routine; a non-nil `id` denotes an edit to
/// an existing Routine identified by the same `UUID` (Requirement 13.5).
struct RoutineDraft: Equatable {
    /// Existing Routine id when editing; `nil` when creating a new Routine.
    var id: UUID?
    /// Routine name. Validated to RoutineValidator.nameLength after trimming.
    var name: String
    /// Ordered list of items. Order in the array is the persisted order.
    var items: [RoutineItemDraft]

    init(id: UUID? = nil, name: String = "", items: [RoutineItemDraft] = []) {
        self.id = id
        self.name = name
        self.items = items
    }
}

// MARK: - RoutineItemDraft

/// A user-editable description of a single Routine_Item.
///
/// References an Exercise_Item by `exerciseID` and carries the editable
/// `sets`, `reps`, and `restSeconds` values. Ranges are enforced by
/// RoutineValidator before persistence (Requirements 12.3, 12.4, 13.3, 13.9).
struct RoutineItemDraft: Equatable, Identifiable {
    /// Stable identity for SwiftUI list editing (reorder/delete). Defaults to a
    /// fresh UUID; preserved across edits to keep diffs stable.
    var id: UUID
    /// Referenced Exercise_Item id.
    var exerciseID: String
    /// Human-readable exercise name (carried for display / AI Coach context).
    var exerciseName: String
    /// Number of sets. Valid range: RoutineValidator.setsRange (1...99).
    var sets: Int
    /// Number of reps. Valid range: RoutineValidator.repsRange (1...999).
    var reps: Int
    /// Rest in seconds. Valid range: RoutineValidator.restRange (0...3600).
    var restSeconds: Int

    init(
        id: UUID = UUID(),
        exerciseID: String,
        exerciseName: String = "",
        sets: Int = 3,
        reps: Int = 10,
        restSeconds: Int = 60
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.exerciseName = exerciseName
        self.sets = sets
        self.reps = reps
        self.restSeconds = restSeconds
    }
}
