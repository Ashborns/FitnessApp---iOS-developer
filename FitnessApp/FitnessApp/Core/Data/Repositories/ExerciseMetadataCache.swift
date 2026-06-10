import CoreData

// MARK: - ExerciseMetadataCache
// Requirements: 5.7, 4.6
//
// Core Data backed cache for `ExerciseItem` metadata. Each record is stored as
// a `CachedExercise` whose array fields (`secondaryMuscles`, `instructions`) are
// serialized to JSON strings, with `cachedAt` driving the 7-day (168h) TTL
// refresh decision made by callers (e.g. `ExerciseDBService`).
//
// Reads are performed on the `viewContext`; writes run on a dedicated background
// context (`newBackgroundContext`) and are saved safely without force unwraps.

// MARK: - CachedExerciseRecord

/// A cached `ExerciseItem` paired with the timestamp it was stored at.
///
/// Callers use `cachedAt` to apply their own TTL policy (serve fresh entries
/// without networking, refresh stale ones when online) without coupling the
/// cache to a specific expiry duration.
struct CachedExerciseRecord: Equatable {
    let item: ExerciseItem
    let cachedAt: Date
}

// MARK: - ExerciseMetadataCaching

/// Abstraction over the exercise metadata cache so consumers such as
/// `ExerciseDBService` can depend on a protocol rather than the concrete store.
protocol ExerciseMetadataCaching {
    /// Inserts or updates the given items, refreshing their `cachedAt` to now.
    func upsert(_ items: [ExerciseItem])

    /// Returns the cached item for `id`, or `nil` when absent.
    func load(id: String) -> ExerciseItem?

    /// Returns the cached item for `id` together with its `cachedAt` timestamp,
    /// enabling TTL decisions by the caller.
    func loadRecord(id: String) -> CachedExerciseRecord?

    /// Returns all cached records (item + `cachedAt`) so callers can apply TTL
    /// decisions over bulk loads.
    func loadAllRecords() -> [CachedExerciseRecord]

    /// Returns cached records matching `bodyPart` (case-insensitive), paired
    /// with their `cachedAt` timestamps for TTL evaluation.
    func loadRecordsByBodyPart(_ bodyPart: String) -> [CachedExerciseRecord]

    /// Returns cached records matching `target` (case-insensitive), paired with
    /// their `cachedAt` timestamps for TTL evaluation.
    func loadRecordsByTarget(_ target: String) -> [CachedExerciseRecord]

    /// Returns all cached items sorted by name.
    func loadAll() -> [ExerciseItem]

    /// Returns cached items matching `bodyPart` (case-insensitive).
    func loadByBodyPart(_ bodyPart: String) -> [ExerciseItem]

    /// Returns cached items matching `target` (case-insensitive).
    func loadByTarget(_ target: String) -> [ExerciseItem]

    /// Removes entries whose `cachedAt` is older than `ttl` relative to `now`.
    func evictExpired(now: Date, ttl: TimeInterval)
}

extension ExerciseMetadataCaching {
    /// Convenience using the default 7-day (168h) TTL.
    func evictExpired(now: Date) {
        evictExpired(now: now, ttl: ExerciseMetadataCache.defaultTTL)
    }
}

// MARK: - ExerciseMetadataCache

/// Core Data implementation of `ExerciseMetadataCaching`.
final class ExerciseMetadataCache: ExerciseMetadataCaching {

    /// Default time-to-live: 7 days (168 hours).
    static let defaultTTL: TimeInterval = 168 * 3600

    private let persistence: PersistenceController

    /// Reads use the main `viewContext`.
    private var viewContext: NSManagedObjectContext {
        persistence.container.viewContext
    }

    // MARK: - Init

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    // MARK: - Writes (background context)

    func upsert(_ items: [ExerciseItem]) {
        guard !items.isEmpty else { return }

        let context = persistence.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        context.performAndWait {
            let now = Date()
            for item in items {
                let existing = CachedExercise.fetchByID(item.id, in: context)
                let entity = existing ?? CachedExercise(context: context)
                entity.id = item.id
                entity.name = item.name
                entity.gifUrl = item.gifUrl
                entity.target = item.target
                entity.secondaryMusclesJSON = CachedExercise.encodeStringArray(item.secondaryMuscles)
                entity.bodyPart = item.bodyPart
                entity.equipment = item.equipment
                entity.instructionsJSON = CachedExercise.encodeStringArray(item.instructions)
                entity.cachedAt = now
            }
            save(context)
        }
    }

    func evictExpired(now: Date, ttl: TimeInterval) {
        let context = persistence.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        context.performAndWait {
            let cutoff = now.addingTimeInterval(-ttl)
            let request = NSFetchRequest<CachedExercise>(entityName: "CachedExercise")
            request.predicate = NSPredicate(format: "cachedAt < %@", cutoff as NSDate)

            guard let expired = try? context.fetch(request), !expired.isEmpty else { return }
            for entity in expired {
                context.delete(entity)
            }
            save(context)
        }
    }

    // MARK: - Reads (viewContext)

    func load(id: String) -> ExerciseItem? {
        loadRecord(id: id)?.item
    }

    func loadRecord(id: String) -> CachedExerciseRecord? {
        guard let entity = CachedExercise.fetchByID(id, in: viewContext) else { return nil }
        return Self.record(from: entity)
    }

    func loadAll() -> [ExerciseItem] {
        CachedExercise.fetchAll(in: viewContext).compactMap(Self.item(from:))
    }

    func loadByBodyPart(_ bodyPart: String) -> [ExerciseItem] {
        CachedExercise.fetchByBodyPart(bodyPart, in: viewContext).compactMap(Self.item(from:))
    }

    func loadByTarget(_ target: String) -> [ExerciseItem] {
        CachedExercise.fetchByTarget(target, in: viewContext).compactMap(Self.item(from:))
    }

    func loadAllRecords() -> [CachedExerciseRecord] {
        CachedExercise.fetchAll(in: viewContext).compactMap(Self.record(from:))
    }

    func loadRecordsByBodyPart(_ bodyPart: String) -> [CachedExerciseRecord] {
        CachedExercise.fetchByBodyPart(bodyPart, in: viewContext).compactMap(Self.record(from:))
    }

    func loadRecordsByTarget(_ target: String) -> [CachedExerciseRecord] {
        CachedExercise.fetchByTarget(target, in: viewContext).compactMap(Self.record(from:))
    }

    // MARK: - Mapping

    private static func item(from entity: CachedExercise) -> ExerciseItem? {
        guard let id = entity.id, let name = entity.name else { return nil }
        return ExerciseItem(
            id: id,
            name: name,
            gifUrl: entity.gifUrl ?? "",
            target: entity.target ?? "",
            secondaryMuscles: entity.secondaryMuscles,
            bodyPart: entity.bodyPart ?? "",
            equipment: entity.equipment ?? "",
            instructions: entity.instructions
        )
    }

    private static func record(from entity: CachedExercise) -> CachedExerciseRecord? {
        guard let item = item(from: entity), let cachedAt = entity.cachedAt else { return nil }
        return CachedExerciseRecord(item: item, cachedAt: cachedAt)
    }

    // MARK: - Saving

    private func save(_ context: NSManagedObjectContext) {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("ExerciseMetadataCache save error: \(error)")
        }
    }
}
