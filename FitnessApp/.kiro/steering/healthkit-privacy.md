---
inclusion: fileMatch
fileMatchPattern: "**/Health/**,**/HealthKit*"
---

# HealthKit & Privacy Rules — FitnessApp

## Required Setup

1. Xcode: Signing & Capabilities → + HealthKit
2. Info.plist keys (BOTH required or app crashes):
   - `NSHealthShareUsageDescription`
   - `NSHealthUpdateUsageDescription`

## HealthKitManager Pattern

```swift
import HealthKit

@MainActor
final class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    private let store = HKHealthStore()

    @Published var activeEnergyBurned: Double = 0

    private let readTypes: Set<HKObjectType> = [
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.workoutType()
    ]

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        try await store.requestAuthorization(toShare: [], read: readTypes)
    }

    func fetchTodayActiveEnergy() async throws -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            throw HealthKitError.unauthorized
        }
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error))
                    return
                }
                let kcal = statistics?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                continuation.resume(returning: kcal)
            }
            self.store.execute(query)
        }
    }
}

enum HealthKitError: LocalizedError {
    case notAvailable
    case unauthorized
    case queryFailed(Error)
}
```

## Privacy Rules

- Never access health data before authorization is confirmed
- Never store raw HKSample data in CoreData — only computed values
- Never log health data in production builds
- Health data must never leave the device
- If user denies HealthKit, app must remain functional with manual entry
- When denied, show Settings deep-link button

## Simulator Note

HealthKit does NOT work in iOS Simulator. Use mock data in debug:
```swift
#if targetEnvironment(simulator)
func fetchTodayActiveEnergy() async throws -> Double { return 320.0 }
#endif
```
