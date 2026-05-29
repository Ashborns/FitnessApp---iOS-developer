import CoreData

@objc(WorkoutLog)
public class WorkoutLog: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var date: Date?
    @NSManaged public var workoutType: String?
    @NSManaged public var durationMinutes: Double
    @NSManaged public var caloriesBurned: Double
    @NSManaged public var formScore: Double
    @NSManaged public var notes: String?
    @NSManaged public var userProfile: UserProfile?
}

// MARK: - Factory & Fetch Helpers

extension WorkoutLog {
    static func create(
        in context: NSManagedObjectContext,
        workoutType: String,
        durationMinutes: Double,
        caloriesBurned: Double,
        formScore: Double = 0.0,
        notes: String? = nil,
        userProfile: UserProfile? = nil
    ) -> WorkoutLog {
        let log = WorkoutLog(context: context)
        log.id = UUID()
        log.date = Date()
        log.workoutType = workoutType
        log.durationMinutes = min(max(durationMinutes, 0), 1440)
        log.caloriesBurned = min(max(caloriesBurned, 0), 99999)
        log.formScore = min(max(formScore, 0.0), 1.0)
        log.notes = notes
        log.userProfile = userProfile
        return log
    }

    static func fetchByID(
        _ id: UUID,
        in context: NSManagedObjectContext
    ) -> WorkoutLog? {
        let request = NSFetchRequest<WorkoutLog>(entityName: "WorkoutLog")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    static func fetchByUserProfile(
        _ profile: UserProfile,
        in context: NSManagedObjectContext,
        limit: Int? = nil
    ) -> [WorkoutLog] {
        let request = NSFetchRequest<WorkoutLog>(entityName: "WorkoutLog")
        request.predicate = NSPredicate(format: "userProfile == %@", profile)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WorkoutLog.date, ascending: false)]
        if let limit = limit {
            request.fetchLimit = limit
        }
        return (try? context.fetch(request)) ?? []
    }

    static func fetchLast7Days(
        for profile: UserProfile,
        in context: NSManagedObjectContext
    ) -> [WorkoutLog] {
        let request = NSFetchRequest<WorkoutLog>(entityName: "WorkoutLog")
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        request.predicate = NSPredicate(
            format: "userProfile == %@ AND date >= %@",
            profile,
            sevenDaysAgo as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \WorkoutLog.date, ascending: false)]
        return (try? context.fetch(request)) ?? []
    }

    static func fetchRequest() -> NSFetchRequest<WorkoutLog> {
        NSFetchRequest<WorkoutLog>(entityName: "WorkoutLog")
    }
}
