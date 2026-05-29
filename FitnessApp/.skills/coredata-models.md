# Skill: CoreData Model Structure
# Project: FitnessCoach iOS App
# Target: iOS 16.4 / Xcode 14.0 / Swift 5.7
# Read this before creating or modifying any CoreData entity in this project.

---

## Why CoreData, not SwiftData

SwiftData requires iOS 17. This project targets iOS 16.4.
All persistence uses CoreData. Do not introduce SwiftData under any circumstance.

---

## PersistenceController (singleton)

```swift
import CoreData

final class PersistenceController {
    static let shared = PersistenceController()

    // In-memory store for tests and previews
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        // Seed preview data here if needed
        return controller
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "FitnessCoach")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error = error {
                // In production, log and show error — never fatalError in release
                #if DEBUG
                fatalError("CoreData load failed: \(error)")
                #endif
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func save() {
        let context = container.viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            // Log error — do not fatalError in production
            print("CoreData save error: \(error)")
        }
    }
}
```

---

## Entity Definitions

### Entity 1: UserProfile
| Attribute | Type | Notes |
|-----------|------|-------|
| id | UUID | required, set on creation |
| firebaseUID | String | from Firebase Auth |
| email | String | |
| displayName | String | optional |
| dailyCalorieGoal | Double | kcal, default 2000 |
| createdAt | Date | set on creation |

### Entity 2: DailyGoal
| Attribute | Type | Notes |
|-----------|------|-------|
| id | UUID | |
| date | Date | start of day |
| calorieGoal | Double | kcal |
| caloriesBurned | Double | fetched from HealthKit, cached |
| isCompleted | Boolean | |

Relationship: DailyGoal → UserProfile (many-to-one)

### Entity 3: WorkoutLog
| Attribute | Type | Notes |
|-----------|------|-------|
| id | UUID | |
| date | Date | |
| workoutType | String | e.g. "running", "squats" |
| durationMinutes | Double | |
| caloriesBurned | Double | estimate |
| formScore | Double | 0.0–1.0, from Vision analysis |
| notes | String | optional |

Relationship: WorkoutLog → UserProfile (many-to-one)

### Entity 4: CalorieEntry
| Attribute | Type | Notes |
|-----------|------|-------|
| id | UUID | |
| date | Date | |
| amount | Double | kcal |
| source | String | "manual" or "healthkit" |
| label | String | e.g. "Lunch", "Post-workout snack" |

Relationship: CalorieEntry → UserProfile (many-to-one)

---

## CoreData Extensions Pattern

For each entity, create a Swift extension for convenience init and fetch:

```swift
// UserProfile+CoreData.swift
extension UserProfile {

    static func create(in context: NSManagedObjectContext,
                       firebaseUID: String,
                       email: String) -> UserProfile {
        let profile = UserProfile(context: context)
        profile.id = UUID()
        profile.firebaseUID = firebaseUID
        profile.email = email
        profile.dailyCalorieGoal = 2000
        profile.createdAt = Date()
        return profile
    }

    static func fetch(firebaseUID: String,
                      context: NSManagedObjectContext) throws -> UserProfile? {
        let request = UserProfile.fetchRequest()
        request.predicate = NSPredicate(format: "firebaseUID == %@", firebaseUID)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
}
```

Apply this same pattern to DailyGoal, WorkoutLog, CalorieEntry.

---

## Background Context for Writes

Never write to `viewContext` from a background thread. Use a background context:

```swift
func saveWorkoutLog(type: String, duration: Double, calories: Double) {
    let context = PersistenceController.shared.container.newBackgroundContext()
    context.perform {
        let log = WorkoutLog(context: context)
        log.id = UUID()
        log.date = Date()
        log.workoutType = type
        log.durationMinutes = duration
        log.caloriesBurned = calories
        try? context.save()
    }
}
```

---

## Migration Policy

If the CoreData model schema changes after the first TestFlight build:
1. Create a new model version in Xcode (Editor → Add Model Version)
2. Set the current version to the new one
3. Enable lightweight migration in PersistenceController:

```swift
let description = container.persistentStoreDescriptions.first
description?.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
description?.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
```

---

## Testing CoreData

Always use the in-memory store for tests:

```swift
class WorkoutLogTests: XCTestCase {
    var context: NSManagedObjectContext!

    override func setUp() {
        context = PersistenceController.preview.container.viewContext
    }

    func testCreateWorkoutLog() {
        let log = WorkoutLog(context: context)
        log.id = UUID()
        log.workoutType = "running"
        XCTAssertNoThrow(try context.save())
        XCTAssertNotNil(log.id)
    }
}
```
