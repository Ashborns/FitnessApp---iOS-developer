import CoreData

// MARK: - PersistenceController
// Requirements: 8.1, 8.2, 8.8, 8.9, 8.10

/// Manages the CoreData stack for the FitnessApp.
/// Uses NSPersistentContainer with shared singleton and in-memory preview configurations.
final class PersistenceController {

    // MARK: - Shared Instances

    /// Production singleton with persistent on-disk store.
    static let shared = PersistenceController()

    /// In-memory instance for SwiftUI previews and unit tests.
    static var preview: PersistenceController {
        PersistenceController(inMemory: true)
    }

    // MARK: - Properties

    /// The underlying CoreData persistent container.
    let container: NSPersistentContainer

    // MARK: - Initialization

    /// Creates a PersistenceController.
    /// - Parameter inMemory: When `true`, stores data to `/dev/null` (no persistence).
    ///   Used for testing and SwiftUI previews.
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "FitnessApp")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error = error {
                #if DEBUG
                fatalError("CoreData load failed: \(error)")
                #else
                print("CoreData load error: \(error)")
                #endif
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - Public Methods

    /// Saves the viewContext only if there are unsaved changes.
    /// Logs errors without crashing.
    func save() {
        let context = container.viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("CoreData save error: \(error)")
        }
    }

    /// Creates a new background context for off-main-thread work.
    func newBackgroundContext() -> NSManagedObjectContext {
        container.newBackgroundContext()
    }
}
