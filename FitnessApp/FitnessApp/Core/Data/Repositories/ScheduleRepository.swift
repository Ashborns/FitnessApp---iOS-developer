import CoreData

// MARK: - ScheduleRepository
// Requirements: 14.1, 14.2, 14.3, 14.4, 14.5
//
// Core Data backed repository for `ScheduledWorkout` entries. A scheduled
// workout links a `Routine` to a date via a `routineID: UUID` weak reference
// (NOT a Core Data relationship), so deleting a Routine does not delete its
// schedules. This intentionally allows a dangling reference that `resolve`
// reports as `nil` and the Schedule_Screen handles gracefully (Requirement 14.5).
//
// Reads are performed on the main `viewContext`; writes run on a dedicated
// background context (`newBackgroundContext`) and are saved safely without
// force unwraps.

// MARK: - ScheduledWorkoutSnapshot

/// An immutable, thread-safe value-type view of a persisted `ScheduledWorkout`,
/// detached from `NSManagedObject` so it can be safely passed across threads
/// and is trivial to test.
struct ScheduledWorkoutSnapshot: Equatable, Identifiable, Hashable {
    let id: UUID
    /// Weak reference to the scheduled `Routine`. May reference a Routine that
    /// has since been deleted — see `ScheduleRepositoring.resolve(_:)`.
    let routineID: UUID
    let scheduledDate: Date

    init(id: UUID, routineID: UUID, scheduledDate: Date) {
        self.id = id
        self.routineID = routineID
        self.scheduledDate = scheduledDate
    }
}

// MARK: - ScheduleRepositoryError

/// Errors surfaced by `ScheduleRepository` write operations so callers can
/// present a descriptive message and preserve user input (Requirement 14.7).
enum ScheduleRepositoryError: LocalizedError, Equatable {
    case saveFailed(String)
    case notFound

    var errorDescription: String? {
        switch self {
        case .saveFailed(let detail):
            return "Gagal menyimpan jadwal latihan. \(detail)"
        case .notFound:
            return "Jadwal latihan tidak ditemukan."
        }
    }
}

// MARK: - ScheduleRepositoring

/// Abstraction over schedule persistence so ViewModels depend on a protocol
/// rather than the concrete Core Data store.
protocol ScheduleRepositoring {
    /// Creates and persists a `ScheduledWorkout` linking `routineID` to `date`,
    /// returning the new entry's unique id (Requirement 14.2).
    func schedule(routineID: UUID, on date: Date) throws -> UUID

    /// Returns all scheduled workouts on the given calendar day, sorted by
    /// time ascending (Requirement 14.3).
    func workouts(on date: Date) -> [ScheduledWorkoutSnapshot]

    /// Returns the set of calendar-day starts within `month` that have at least
    /// one scheduled workout, for marking the calendar (Requirement 14.1).
    func datesWithWorkouts(in month: DateInterval) -> Set<Date>

    /// Deletes the scheduled workout with `id`. The referenced Routine is left
    /// intact because the link is a weak `UUID` reference (Requirement 14.4).
    func delete(id: UUID) throws

    /// Resolves the Routine referenced by `snapshot`, or `nil` when that Routine
    /// has been deleted (a dangling reference — Requirement 14.5).
    func resolve(_ snapshot: ScheduledWorkoutSnapshot) -> RoutineSnapshot?
}

// MARK: - ScheduleRepository

/// Core Data implementation of `ScheduleRepositoring`.
final class ScheduleRepository: ScheduleRepositoring {

    private let persistence: PersistenceController
    private let calendar: Calendar
    /// Used to enrich resolved RoutineItem snapshots with exercise display
    /// names; falls back to the exercise id when unavailable.
    private let metadataCache: ExerciseMetadataCaching

    /// Reads use the main `viewContext`.
    private var viewContext: NSManagedObjectContext {
        persistence.container.viewContext
    }

    // MARK: - Init

    init(
        persistence: PersistenceController = .shared,
        calendar: Calendar = .current,
        metadataCache: ExerciseMetadataCaching? = nil
    ) {
        self.persistence = persistence
        self.calendar = calendar
        self.metadataCache = metadataCache ?? ExerciseMetadataCache(persistence: persistence)
    }

    // MARK: - Writes (background context)

    func schedule(routineID: UUID, on date: Date) throws -> UUID {
        let context = persistence.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        var newID: UUID?
        var caughtError: Error?

        context.performAndWait {
            let workout = ScheduledWorkout.create(
                in: context,
                routineID: routineID,
                scheduledDate: date
            )
            newID = workout.id
            do {
                if context.hasChanges {
                    try context.save()
                }
            } catch {
                caughtError = error
            }
        }

        if let caughtError {
            throw ScheduleRepositoryError.saveFailed(caughtError.localizedDescription)
        }
        guard let id = newID else {
            throw ScheduleRepositoryError.saveFailed("Identitas jadwal tidak tersedia.")
        }
        return id
    }

    func delete(id: UUID) throws {
        let context = persistence.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        var caughtError: Error?

        context.performAndWait {
            guard let workout = ScheduledWorkout.fetchByID(id, in: context) else { return }
            // Delete only the schedule entry. `routineID` is a weak UUID
            // reference, so the referenced Routine is unaffected (Requirement 14.4).
            context.delete(workout)
            do {
                if context.hasChanges {
                    try context.save()
                }
            } catch {
                caughtError = error
            }
        }

        if let caughtError {
            throw ScheduleRepositoryError.saveFailed(caughtError.localizedDescription)
        }
    }

    // MARK: - Reads (viewContext)

    func workouts(on date: Date) -> [ScheduledWorkoutSnapshot] {
        // fetchByDay already sorts by scheduledDate ascending (Requirement 14.3).
        ScheduledWorkout
            .fetchByDay(date, in: viewContext, calendar: calendar)
            .compactMap(Self.snapshot(from:))
    }

    func datesWithWorkouts(in month: DateInterval) -> Set<Date> {
        let workouts = ScheduledWorkout.fetchByInterval(
            from: month.start,
            to: month.end,
            in: viewContext
        )
        // Normalize each scheduled date to its calendar-day start so the
        // calendar can mark days regardless of the time component (Requirement 14.1).
        var days: Set<Date> = []
        for workout in workouts {
            guard let scheduledDate = workout.scheduledDate else { continue }
            days.insert(calendar.startOfDay(for: scheduledDate))
        }
        return days
    }

    func resolve(_ snapshot: ScheduledWorkoutSnapshot) -> RoutineSnapshot? {
        guard let routine = Routine.fetchByID(snapshot.routineID, in: viewContext) else {
            // Dangling reference: the Routine was deleted (Requirement 14.5).
            return nil
        }
        return routineSnapshot(from: routine)
    }

    // MARK: - Mapping

    private static func snapshot(from entity: ScheduledWorkout) -> ScheduledWorkoutSnapshot? {
        guard
            let id = entity.id,
            let routineID = entity.routineID,
            let scheduledDate = entity.scheduledDate
        else { return nil }
        return ScheduledWorkoutSnapshot(
            id: id,
            routineID: routineID,
            scheduledDate: scheduledDate
        )
    }

    /// Maps a persisted `Routine` to an immutable `RoutineSnapshot`, with items
    /// ordered by `orderPosition` ascending (Requirement 13.4). Exercise display
    /// names are sourced from the metadata cache, falling back to the exercise id.
    private func routineSnapshot(from routine: Routine) -> RoutineSnapshot? {
        guard let id = routine.id else { return nil }

        let items = routine.orderedItems
            .sorted { $0.orderPosition < $1.orderPosition }
            .compactMap { item -> RoutineItemSnapshot? in
                guard let itemID = item.id, let exerciseID = item.exerciseID else { return nil }
                let exerciseName = metadataCache.load(id: exerciseID)?.name ?? exerciseID
                return RoutineItemSnapshot(
                    id: itemID,
                    exerciseID: exerciseID,
                    exerciseName: exerciseName,
                    sets: Int(item.sets),
                    reps: Int(item.reps),
                    restSeconds: Int(item.restSeconds),
                    orderPosition: Int(item.orderPosition)
                )
            }

        return RoutineSnapshot(
            id: id,
            name: routine.name ?? "",
            createdAt: routine.createdAt ?? Date(),
            items: items
        )
    }
}
