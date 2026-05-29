# Skill: HealthKit & Privacy Rules
# Project: FitnessCoach iOS App
# Target: iOS 16.4 / Xcode 14.0 / Swift 5.7
# Read this before writing any HealthKit code in this project.

---

## Required Setup (must exist before any HealthKit code runs)

### 1. Entitlement
In Xcode: Signing & Capabilities → + Capability → HealthKit
This adds `com.apple.developer.healthkit` to the entitlement file.
Do not write this manually — Xcode manages the entitlement file.

### 2. Info.plist keys (must both be present)
```xml
<key>NSHealthShareUsageDescription</key>
<string>FitnessCoach reads your active energy and workout data to track your daily calorie progress.</string>

<key>NSHealthUpdateUsageDescription</key>
<string>FitnessCoach saves workout sessions to Apple Health to keep your data in sync.</string>
```

If either key is missing, the app will crash on first HealthKit call — no exception, just a crash.

---

## HealthKitManager (singleton pattern for this project)

```swift
import HealthKit

final class HealthKitManager {
    static let shared = HealthKitManager()
    private let store = HKHealthStore()

    private init() {}

    // Types this app reads
    private let readTypes: Set<HKObjectType> = [
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,
        HKObjectType.workoutType()
    ]

    // Types this app writes
    private let writeTypes: Set<HKSampleType> = [
        HKObjectType.workoutType()
    ]
}
```

---

## Authorization — ALWAYS check before querying

```swift
extension HealthKitManager {

    // Call this once on app launch (from AuthManager after login)
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
    }

    // Check status before every query — never assume auth is granted
    func authorizationStatus(for type: HKObjectType) -> HKAuthorizationStatus {
        return store.authorizationStatus(for: type)
    }

    var isAuthorized: Bool {
        guard let activeEnergyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return false
        }
        return store.authorizationStatus(for: activeEnergyType) == .sharingAuthorized
    }
}

enum HealthKitError: LocalizedError {
    case notAvailable
    case unauthorized
    case queryFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notAvailable: return "Health data is not available on this device."
        case .unauthorized: return "Please grant HealthKit access in Settings > Privacy > Health."
        case .queryFailed(let e): return "Health query failed: \(e.localizedDescription)"
        }
    }
}
```

---

## Querying Active Energy (today)

```swift
extension HealthKitManager {

    func fetchTodayActiveEnergy() async throws -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            throw HealthKitError.unauthorized
        }

        // Always guard auth before querying
        guard authorizationStatus(for: type) != .notDetermined else {
            throw HealthKitError.unauthorized
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay,
                                                     end: Date(),
                                                     options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error = error {
                    continuation.resume(throwing: HealthKitError.queryFailed(error))
                    return
                }
                let kcal = statistics?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                continuation.resume(returning: kcal)
            }
            store.execute(query)
        }
    }
}
```

---

## Privacy Rules

1. Never access health data before authorization is confirmed — always call `requestAuthorization()` first.
2. Never store raw HKSample data in CoreData or UserDefaults — only store computed values (e.g. Double kcal).
3. Never log health data to the console in production builds.
4. Health data must never leave the device to any backend. This app stores health data locally only.
5. If the user denies HealthKit access, the app must remain fully functional with manual entry fallback.
6. When authorization is denied, show a Settings deep-link button — never block the UI.

```swift
// Deep link to Health settings when denied
Button("Open Health Settings") {
    if let url = URL(string: "x-apple-health://") {
        UIApplication.shared.open(url)
    }
}
```

---

## Simulator Note

HealthKit does NOT work in the iOS Simulator for most query types.
Always test HealthKit features on a real device.
Use mock data in debug builds:

```swift
#if targetEnvironment(simulator)
func fetchTodayActiveEnergy() async throws -> Double {
    return 320.0 // mock value for simulator
}
#endif
```
