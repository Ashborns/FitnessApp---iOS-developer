import CoreData

@objc(UserProfile)
public class UserProfile: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var firebaseUID: String?
    @NSManaged public var email: String?
    @NSManaged public var displayName: String?
    @NSManaged public var dailyCalorieGoal: Double
    @NSManaged public var createdAt: Date?
    @NSManaged public var workoutLogs: NSSet?
    @NSManaged public var dailyGoals: NSSet?
    @NSManaged public var calorieEntries: NSSet?
}

// MARK: - Factory & Fetch Helpers

extension UserProfile {
    static func create(
        in context: NSManagedObjectContext,
        firebaseUID: String,
        email: String,
        displayName: String? = nil,
        dailyCalorieGoal: Double = 2000
    ) -> UserProfile {
        let profile = UserProfile(context: context)
        profile.id = UUID()
        profile.firebaseUID = firebaseUID
        profile.email = email
        profile.displayName = displayName
        profile.dailyCalorieGoal = dailyCalorieGoal
        profile.createdAt = Date()
        return profile
    }

    static func fetchByFirebaseUID(
        _ uid: String,
        in context: NSManagedObjectContext
    ) -> UserProfile? {
        let request = NSFetchRequest<UserProfile>(entityName: "UserProfile")
        request.predicate = NSPredicate(format: "firebaseUID == %@", uid)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    static func fetchByID(
        _ id: UUID,
        in context: NSManagedObjectContext
    ) -> UserProfile? {
        let request = NSFetchRequest<UserProfile>(entityName: "UserProfile")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    static func fetchRequest() -> NSFetchRequest<UserProfile> {
        NSFetchRequest<UserProfile>(entityName: "UserProfile")
    }
}

// MARK: - Relationship Accessors

extension UserProfile {
    @objc(addWorkoutLogsObject:)
    @NSManaged public func addToWorkoutLogs(_ value: WorkoutLog)

    @objc(removeWorkoutLogsObject:)
    @NSManaged public func removeFromWorkoutLogs(_ value: WorkoutLog)

    @objc(addDailyGoalsObject:)
    @NSManaged public func addToDailyGoals(_ value: DailyGoal)

    @objc(removeDailyGoalsObject:)
    @NSManaged public func removeFromDailyGoals(_ value: DailyGoal)

    @objc(addCalorieEntriesObject:)
    @NSManaged public func addToCalorieEntries(_ value: CalorieEntry)

    @objc(removeCalorieEntriesObject:)
    @NSManaged public func removeFromCalorieEntries(_ value: CalorieEntry)
}
