import CoreData

// MARK: - CachedExercise
// Requirements: 5.7
// Cache metadata for an Exercise_Item via Core Data. Array fields
// (secondaryMuscles, instructions) are stored as JSON strings; `cachedAt`
// drives the 7-day (168h) TTL refresh decision.

@objc(CachedExercise)
public class CachedExercise: NSManagedObject {
    @NSManaged public var id: String?
    @NSManaged public var name: String?
    @NSManaged public var gifUrl: String?
    @NSManaged public var target: String?
    @NSManaged public var secondaryMusclesJSON: String?
    @NSManaged public var bodyPart: String?
    @NSManaged public var equipment: String?
    @NSManaged public var instructionsJSON: String?
    @NSManaged public var cachedAt: Date?
}

// MARK: - Factory & Fetch Helpers

extension CachedExercise {
    static func create(
        in context: NSManagedObjectContext,
        id: String,
        name: String,
        gifUrl: String? = nil,
        target: String? = nil,
        secondaryMuscles: [String] = [],
        bodyPart: String? = nil,
        equipment: String? = nil,
        instructions: [String] = [],
        cachedAt: Date = Date()
    ) -> CachedExercise {
        let exercise = CachedExercise(context: context)
        exercise.id = id
        exercise.name = name
        exercise.gifUrl = gifUrl
        exercise.target = target
        exercise.secondaryMusclesJSON = encodeStringArray(secondaryMuscles)
        exercise.bodyPart = bodyPart
        exercise.equipment = equipment
        exercise.instructionsJSON = encodeStringArray(instructions)
        exercise.cachedAt = cachedAt
        return exercise
    }

    /// Decoded `secondaryMuscles` array from its JSON storage.
    var secondaryMuscles: [String] {
        Self.decodeStringArray(secondaryMusclesJSON)
    }

    /// Decoded `instructions` array from its JSON storage.
    var instructions: [String] {
        Self.decodeStringArray(instructionsJSON)
    }

    static func fetchByID(
        _ id: String,
        in context: NSManagedObjectContext
    ) -> CachedExercise? {
        let request = NSFetchRequest<CachedExercise>(entityName: "CachedExercise")
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    static func fetchAll(
        in context: NSManagedObjectContext
    ) -> [CachedExercise] {
        let request = NSFetchRequest<CachedExercise>(entityName: "CachedExercise")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CachedExercise.name, ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    static func fetchByBodyPart(
        _ bodyPart: String,
        in context: NSManagedObjectContext
    ) -> [CachedExercise] {
        let request = NSFetchRequest<CachedExercise>(entityName: "CachedExercise")
        request.predicate = NSPredicate(format: "bodyPart ==[c] %@", bodyPart)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CachedExercise.name, ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    static func fetchByTarget(
        _ target: String,
        in context: NSManagedObjectContext
    ) -> [CachedExercise] {
        let request = NSFetchRequest<CachedExercise>(entityName: "CachedExercise")
        request.predicate = NSPredicate(format: "target ==[c] %@", target)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CachedExercise.name, ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    static func fetchRequest() -> NSFetchRequest<CachedExercise> {
        NSFetchRequest<CachedExercise>(entityName: "CachedExercise")
    }
}

// MARK: - JSON Array Encoding Helpers

extension CachedExercise {
    static func encodeStringArray(_ values: [String]) -> String {
        guard let data = try? JSONEncoder().encode(values),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    static func decodeStringArray(_ json: String?) -> [String] {
        guard let json = json,
              let data = json.data(using: .utf8),
              let values = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return values
    }
}
