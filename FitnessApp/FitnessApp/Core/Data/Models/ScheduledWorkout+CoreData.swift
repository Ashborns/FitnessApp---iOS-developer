import CoreData

// MARK: - ScheduledWorkout
// Requirements: 14.2
// Links a Routine to a date. `routineID` is stored as a UUID weak reference
// (NOT a Core Data relationship) so deleting a Routine does not delete the
// schedule; this intentionally allows a dangling reference that the
// Schedule_Screen handles gracefully (Requirement 14.5).

@objc(ScheduledWorkout)
public class ScheduledWorkout: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var routineID: UUID?
    @NSManaged public var scheduledDate: Date?
}

// MARK: - Factory & Fetch Helpers

extension ScheduledWorkout {
    static func create(
        in context: NSManagedObjectContext,
        routineID: UUID,
        scheduledDate: Date
    ) -> ScheduledWorkout {
        let workout = ScheduledWorkout(context: context)
        workout.id = UUID()
        workout.routineID = routineID
        workout.scheduledDate = scheduledDate
        return workout
    }

    static func fetchByID(
        _ id: UUID,
        in context: NSManagedObjectContext
    ) -> ScheduledWorkout? {
        let request = NSFetchRequest<ScheduledWorkout>(entityName: "ScheduledWorkout")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    /// All scheduled workouts on the given calendar day, sorted by time ascending.
    static func fetchByDay(
        _ date: Date,
        in context: NSManagedObjectContext,
        calendar: Calendar = .current
    ) -> [ScheduledWorkout] {
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }
        let request = NSFetchRequest<ScheduledWorkout>(entityName: "ScheduledWorkout")
        request.predicate = NSPredicate(
            format: "scheduledDate >= %@ AND scheduledDate < %@",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ScheduledWorkout.scheduledDate, ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    /// All scheduled workouts whose date falls within the given interval.
    static func fetchByInterval(
        from start: Date,
        to end: Date,
        in context: NSManagedObjectContext
    ) -> [ScheduledWorkout] {
        let request = NSFetchRequest<ScheduledWorkout>(entityName: "ScheduledWorkout")
        request.predicate = NSPredicate(
            format: "scheduledDate >= %@ AND scheduledDate < %@",
            start as NSDate,
            end as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \ScheduledWorkout.scheduledDate, ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    static func fetchRequest() -> NSFetchRequest<ScheduledWorkout> {
        NSFetchRequest<ScheduledWorkout>(entityName: "ScheduledWorkout")
    }
}
