import CoreData

// MARK: - RoutineItem
// Requirements: 13.3
// One entry in a Routine referencing an Exercise_Item by id, with editable
// sets (1–99), reps (1–999), restSeconds (0–3600), and orderPosition
// (integer starting at 0, unique & contiguous within a Routine).
// Back relationship `routine` uses Delete Rule = Nullify.

@objc(RoutineItem)
public class RoutineItem: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var exerciseID: String?
    @NSManaged public var sets: Int16
    @NSManaged public var reps: Int16
    @NSManaged public var restSeconds: Int32
    @NSManaged public var orderPosition: Int16
    @NSManaged public var routine: Routine?
}

// MARK: - Factory & Fetch Helpers

extension RoutineItem {
    static func create(
        in context: NSManagedObjectContext,
        exerciseID: String,
        sets: Int16,
        reps: Int16,
        restSeconds: Int32,
        orderPosition: Int16,
        routine: Routine? = nil
    ) -> RoutineItem {
        let item = RoutineItem(context: context)
        item.id = UUID()
        item.exerciseID = exerciseID
        item.sets = min(max(sets, 1), 99)
        item.reps = min(max(reps, 1), 999)
        item.restSeconds = min(max(restSeconds, 0), 3600)
        item.orderPosition = max(orderPosition, 0)
        item.routine = routine
        return item
    }

    static func fetchByID(
        _ id: UUID,
        in context: NSManagedObjectContext
    ) -> RoutineItem? {
        let request = NSFetchRequest<RoutineItem>(entityName: "RoutineItem")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    static func fetchByRoutine(
        _ routine: Routine,
        in context: NSManagedObjectContext
    ) -> [RoutineItem] {
        let request = NSFetchRequest<RoutineItem>(entityName: "RoutineItem")
        request.predicate = NSPredicate(format: "routine == %@", routine)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \RoutineItem.orderPosition, ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    static func fetchRequest() -> NSFetchRequest<RoutineItem> {
        NSFetchRequest<RoutineItem>(entityName: "RoutineItem")
    }
}
