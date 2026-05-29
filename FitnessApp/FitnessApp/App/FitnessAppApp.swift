// MARK: - FitnessApp Entry Point

import SwiftUI

@main
struct FitnessAppApp: App {

    @StateObject private var router = AppRouter()

    init() {
        // Pre-warm haptics so first feedback is instant
        HapticManager.shared.prepare()
        // Request HealthKit authorization (fails silently if entitlement missing)
        Task { @MainActor in
            try? await HealthKitManager.shared.requestAuthorization()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(router)
                .preferredColorScheme(.dark)
        }
    }
}
