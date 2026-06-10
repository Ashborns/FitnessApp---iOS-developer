import Foundation

// MARK: - RoutineSnapshot
// Requirements: 13.4, 15.3, 15.4
// Thread-safe, value-type reads of a persisted Routine, detached from
// NSManagedObject so they can be safely used across threads (e.g. handed to
// the AI Coach context seeder) and are trivial to test.

/// An immutable snapshot of a stored Routine and its ordered items.
struct RoutineSnapshot: Equatable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let createdAt: Date
    /// Items ordered by their stored position ascending (Requirement 13.4).
    let items: [RoutineItemSnapshot]

    init(id: UUID, name: String, createdAt: Date, items: [RoutineItemSnapshot]) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.items = items
    }
}

// MARK: - RoutineItemSnapshot

/// An immutable snapshot of a single Routine_Item.
///
/// Includes `exerciseName` so downstream consumers (notably the AI Coach
/// context seeder) can render meaningful context without an extra lookup
/// (Requirement 15.4).
struct RoutineItemSnapshot: Equatable, Identifiable, Hashable {
    let id: UUID
    let exerciseID: String
    /// Display name of the referenced Exercise_Item, for AI Coach context.
    let exerciseName: String
    let sets: Int
    let reps: Int
    let restSeconds: Int
    /// Position within the Routine (integer starting at 0).
    let orderPosition: Int

    init(
        id: UUID,
        exerciseID: String,
        exerciseName: String,
        sets: Int,
        reps: Int,
        restSeconds: Int,
        orderPosition: Int
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.exerciseName = exerciseName
        self.sets = sets
        self.reps = reps
        self.restSeconds = restSeconds
        self.orderPosition = orderPosition
    }
}
