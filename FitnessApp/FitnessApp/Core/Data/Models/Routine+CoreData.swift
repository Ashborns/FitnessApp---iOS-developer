import CoreData

// MARK: - Routine
// Requirements: 13.2, 13.6
// A user-built workout routine. Owns an ordered to-many relationship to
// RoutineItem with Delete Rule = Cascade (no orphaned items remain).

@objc(Routine)
public class Routine: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var items: NSOrderedSet?
}

// MARK: - Factory & Fetch Helpers

extension Routine {
    static func create(
        in context: NSManagedObjectContext,
        name: String,
        createdAt: Date = Date()
    ) -> Routine {
        let routine = Routine(context: context)
        routine.id = UUID()
        routine.name = name
        routine.createdAt = createdAt
        return routine
    }

    /// RoutineItems ordered by their stored position (relationship is ordered).
    var orderedItems: [RoutineItem] {
        (items?.array as? [RoutineItem]) ?? []
    }

    static func fetchByID(
        _ id: UUID,
        in context: NSManagedObjectContext
    ) -> Routine? {
        let request = NSFetchRequest<Routine>(entityName: "Routine")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    static func fetchAll(
        in context: NSManagedObjectContext
    ) -> [Routine] {
        let request = NSFetchRequest<Routine>(entityName: "Routine")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Routine.createdAt, ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    static func fetchRequest() -> NSFetchRequest<Routine> {
        NSFetchRequest<Routine>(entityName: "Routine")
    }
}

// MARK: - Relationship Accessors

extension Routine {
    @objc(insertObject:inItemsAtIndex:)
    @NSManaged public func insertIntoItems(_ value: RoutineItem, at idx: Int)

    @objc(removeObjectFromItemsAtIndex:)
    @NSManaged public func removeFromItems(at idx: Int)

    @objc(addItemsObject:)
    @NSManaged public func addToItems(_ value: RoutineItem)

    @objc(removeItemsObject:)
    @NSManaged public func removeFromItems(_ value: RoutineItem)

    @objc(addItems:)
    @NSManaged public func addToItems(_ values: NSOrderedSet)

    @objc(removeItems:)
    @NSManaged public func removeFromItems(_ values: NSOrderedSet)
}
