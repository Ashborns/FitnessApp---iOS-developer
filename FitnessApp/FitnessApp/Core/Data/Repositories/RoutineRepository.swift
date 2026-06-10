import CoreData

// MARK: - RoutineRepository
// Requirements: 13.1, 13.2, 13.4, 13.5, 13.6, 12.6, 12.7
//
// Wraps Core Data create/update/delete/fetch for Routine + RoutineItem using a
// background context for writes and the viewContext for reads (mirrors the
// WorkoutLog+CoreData pattern). Reads are returned as detached value-type
// snapshots so they are safe to use across threads.
//
// Ordering guarantees:
//  - On save, RoutineItem.orderPosition is normalized to a contiguous 0..n-1
//    range following the order of the draft's items array (Requirements 12.6,
//    12.7). Because save rebuilds the full item list, removing an item and
//    re-saving renormalizes the remaining positions.
//  - loadAll returns each Routine's items sorted by orderPosition ascending
//    (Requirement 13.4).
//  - delete relies on the Routine→items Cascade delete rule so no orphaned
//    RoutineItem remains (Requirement 13.6).

// MARK: - Protocol

protocol RoutineRepositoring {
    /// Creates a new Routine when `draft.id` is nil, otherwise updates the
    /// existing record identified by the same `UUID` without creating a
    /// duplicate (Requirement 13.5). Returns the persisted Routine id.
    func save(_ draft: RoutineDraft) throws -> UUID

    /// Loads all stored Routines with their items sorted by orderPosition
    /// ascending (Requirement 13.4).
    func loadAll() -> [RoutineSnapshot]

    /// Deletes the Routine and all of its items via cascade (Requirement 13.6).
    func delete(id: UUID) throws
}

// MARK: - Errors

enum RoutineRepositoryError: LocalizedError {
    case saveFailed(underlying: Error)
    case deleteFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let underlying):
            return "Gagal menyimpan rutinitas: \(underlying.localizedDescription)"
        case .deleteFailed(let underlying):
            return "Gagal menghapus rutinitas: \(underlying.localizedDescription)"
        }
    }
}

// MARK: - Implementation

final class RoutineRepository: RoutineRepositoring {

    private let persistence: PersistenceController

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    // MARK: Save (create / update)

    func save(_ draft: RoutineDraft) throws -> UUID {
        let context = persistence.newBackgroundContext()
        var resultID = draft.id ?? UUID()
        var caughtError: Error?

        context.performAndWait {
            do {
                let routine: Routine
                if let existingID = draft.id,
                   let existing = Routine.fetchByID(existingID, in: context) {
                    // Update in place by UUID — no duplicate (Requirement 13.5).
                    routine = existing
                    // Remove old items explicitly so none are left orphaned
                    // before rebuilding the normalized list.
                    for item in routine.orderedItems {
                        context.delete(item)
                    }
                } else {
                    // Create new; preserve the provided UUID when present.
                    routine = Routine(context: context)
                    routine.id = draft.id ?? resultID
                    routine.createdAt = Date()
                }

                resultID = routine.id ?? resultID
                routine.name = draft.name

                // Rebuild items with contiguous orderPosition 0..n-1
                // following the draft order (Requirements 12.6, 12.7).
                let orderedItems = NSMutableOrderedSet()
                for (index, itemDraft) in draft.items.enumerated() {
                    let sets = Int16(clamping(itemDraft.sets, in: 1...99))
                    let reps = Int16(clamping(itemDraft.reps, in: 1...999))
                    let rest = Int32(clamping(itemDraft.restSeconds, in: 0...3600))
                    let item = RoutineItem.create(
                        in: context,
                        exerciseID: itemDraft.exerciseID,
                        sets: sets,
                        reps: reps,
                        restSeconds: rest,
                        orderPosition: Int16(index)
                    )
                    item.id = itemDraft.id
                    orderedItems.add(item)
                }
                routine.items = orderedItems

                if context.hasChanges {
                    try context.save()
                }
            } catch {
                caughtError = error
            }
        }

        if let caughtError {
            throw RoutineRepositoryError.saveFailed(underlying: caughtError)
        }
        return resultID
    }

    // MARK: Load all

    func loadAll() -> [RoutineSnapshot] {
        let context = persistence.container.viewContext
        var snapshots: [RoutineSnapshot] = []
        context.performAndWait {
            let routines = Routine.fetchAll(in: context)
            snapshots = routines.map { makeSnapshot($0, in: context) }
        }
        return snapshots
    }

    // MARK: Delete

    func delete(id: UUID) throws {
        let context = persistence.newBackgroundContext()
        var caughtError: Error?

        context.performAndWait {
            do {
                guard let routine = Routine.fetchByID(id, in: context) else {
                    return
                }
                // Cascade delete rule removes associated RoutineItems, leaving
                // no orphans (Requirement 13.6).
                context.delete(routine)
                if context.hasChanges {
                    try context.save()
                }
            } catch {
                caughtError = error
            }
        }

        if let caughtError {
            throw RoutineRepositoryError.deleteFailed(underlying: caughtError)
        }
    }

    // MARK: - Helpers

    /// Builds a detached snapshot with items sorted by orderPosition ascending
    /// (Requirement 13.4). Each item's display name is resolved from the
    /// CachedExercise cache when available, falling back to an empty string.
    private func makeSnapshot(
        _ routine: Routine,
        in context: NSManagedObjectContext
    ) -> RoutineSnapshot {
        let sortedItems = routine.orderedItems
            .sorted { $0.orderPosition < $1.orderPosition }

        let itemSnapshots: [RoutineItemSnapshot] = sortedItems.map { item in
            let exerciseID = item.exerciseID ?? ""
            let exerciseName = exerciseID.isEmpty
                ? ""
                : (CachedExercise.fetchByID(exerciseID, in: context)?.name ?? "")
            return RoutineItemSnapshot(
                id: item.id ?? UUID(),
                exerciseID: exerciseID,
                exerciseName: exerciseName,
                sets: Int(item.sets),
                reps: Int(item.reps),
                restSeconds: Int(item.restSeconds),
                orderPosition: Int(item.orderPosition)
            )
        }

        return RoutineSnapshot(
            id: routine.id ?? UUID(),
            name: routine.name ?? "",
            createdAt: routine.createdAt ?? Date(),
            items: itemSnapshots
        )
    }

    /// Clamps an `Int` into a closed range before narrowing to a fixed-width
    /// integer, avoiding overflow and matching RoutineValidator ranges.
    private func clamping(_ value: Int, in range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }
}
