import CoreData

@objc(DailyGoal)
public class DailyGoal: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var date: Date?
    @NSManaged public var calorieGoal: Double
    @NSManaged public var caloriesBurned: Double
    @NSManaged public var isCompleted: Bool
    @NSManaged public var userProfile: UserProfile?
}

// MARK: - Factory & Fetch Helpers

extension DailyGoal {
    static func create(
        in context: NSManagedObjectContext,
        calorieGoal: Double = 2000,
        caloriesBurned: Double = 0,
        isCompleted: Bool = false,
        userProfile: UserProfile? = nil
    ) -> DailyGoal {
        let goal = DailyGoal(context: context)
        goal.id = UUID()
        goal.date = Date()
        goal.calorieGoal = min(max(calorieGoal, 0), 99999)
        goal.caloriesBurned = min(max(caloriesBurned, 0), 99999)
        goal.isCompleted = isCompleted
        goal.userProfile = userProfile
        return goal
    }

    static func fetchByID(
        _ id: UUID,
        in context: NSManagedObjectContext
    ) -> DailyGoal? {
        let request = NSFetchRequest<DailyGoal>(entityName: "DailyGoal")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    static func fetchToday(
        for profile: UserProfile,
        in context: NSManagedObjectContext
    ) -> DailyGoal? {
        let request = NSFetchRequest<DailyGoal>(entityName: "DailyGoal")
        let startOfDay = Calendar.current.startOfDay(for: Date())
        request.predicate = NSPredicate(
            format: "userProfile == %@ AND date >= %@",
            profile,
            startOfDay as NSDate
        )
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    static func fetchByUserProfile(
        _ profile: UserProfile,
        in context: NSManagedObjectContext,
        limit: Int? = nil
    ) -> [DailyGoal] {
        let request = NSFetchRequest<DailyGoal>(entityName: "DailyGoal")
        request.predicate = NSPredicate(format: "userProfile == %@", profile)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \DailyGoal.date, ascending: false)]
        if let limit = limit {
            request.fetchLimit = limit
        }
        return (try? context.fetch(request)) ?? []
    }

    static func fetchRequest() -> NSFetchRequest<DailyGoal> {
        NSFetchRequest<DailyGoal>(entityName: "DailyGoal")
    }
}
