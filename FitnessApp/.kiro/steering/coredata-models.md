---
inclusion: fileMatch
fileMatchPattern: "**/Core/Data/**,**+CoreData.swift,**/PersistenceController.swift"
---

# CoreData Model Structure — FitnessApp

## Why CoreData, not SwiftData

SwiftData requires iOS 17. This project targets iOS 16.4. All persistence uses CoreData.

## PersistenceController

```swift
final class PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        PersistenceController(inMemory: true)
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "FitnessApp")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error = error {
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
        do { try context.save() }
        catch { print("CoreData save error: \(error)") }
    }
}
```

## Entity Definitions

### UserProfile
| Attribute | Type | Notes |
|-----------|------|-------|
| id | UUID | required |
| firebaseUID | String | from Firebase Auth |
| email | String | max 254 chars |
| displayName | String | optional, max 100 chars |
| dailyCalorieGoal | Double | default 2000 |
| createdAt | Date | set on creation |

### WorkoutLog
| Attribute | Type | Notes |
|-----------|------|-------|
| id | UUID | |
| date | Date | |
| workoutType | String | max 50 chars |
| durationMinutes | Double | 0–1440 |
| caloriesBurned | Double | 0–99999 |
| formScore | Double | 0.0–1.0 |
| notes | String | optional, max 500 chars |

Relationship: WorkoutLog → UserProfile (many-to-one)

### DailyGoal
| Attribute | Type | Notes |
|-----------|------|-------|
| id | UUID | |
| date | Date | |
| calorieGoal | Double | 0–99999 |
| caloriesBurned | Double | cached from HealthKit |
| isCompleted | Boolean | |

Relationship: DailyGoal → UserProfile (many-to-one)

### CalorieEntry
| Attribute | Type | Notes |
|-----------|------|-------|
| id | UUID | |
| date | Date | |
| amount | Double | 0–99999 |
| source | String | "manual" or "healthkit" |
| label | String | max 100 chars |

Relationship: CalorieEntry → UserProfile (many-to-one)

## Extension Pattern

```swift
extension UserProfile {
    static func create(in context: NSManagedObjectContext,
                       firebaseUID: String, email: String) -> UserProfile {
        let profile = UserProfile(context: context)
        profile.id = UUID()
        profile.firebaseUID = firebaseUID
        profile.email = email
        profile.dailyCalorieGoal = 2000
        profile.createdAt = Date()
        return profile
    }
}
```

## Testing CoreData

Always use in-memory store:
```swift
let context = PersistenceController.preview.container.viewContext
```
