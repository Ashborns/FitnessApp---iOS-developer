import Foundation
import CoreData

/// ViewModel for the Profile screen.
/// Syncs the calculated calorie goal from UserProfileStore into CoreData DailyGoal.
@MainActor
final class ProfileViewModel: ObservableObject {

    @Published var isSaved: Bool = false

    private let persistence: PersistenceController

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    /// Writes the calculated daily calorie goal into today's DailyGoal CoreData record.
    /// Called when user taps Save Profile.
    func syncCalorieGoal(_ goal: Double) {
        let context = persistence.container.viewContext
        let startOfDay = Calendar.current.startOfDay(for: Date())

        let request = NSFetchRequest<NSManagedObject>(entityName: "DailyGoal")
        request.predicate = NSPredicate(format: "date >= %@", startOfDay as NSDate)
        request.fetchLimit = 1

        if let existing = try? context.fetch(request).first {
            existing.setValue(goal, forKey: "calorieGoal")
        } else {
            let newGoal = NSEntityDescription.insertNewObject(forEntityName: "DailyGoal", into: context)
            newGoal.setValue(UUID(), forKey: "id")
            newGoal.setValue(Date(), forKey: "date")
            newGoal.setValue(goal, forKey: "calorieGoal")
        }

        persistence.save()
        isSaved = true
    }

    /// Legacy: loads profile name/email (kept for compatibility).
    func loadProfile() {}
}
