import SwiftUI

/// Root view routing flow:
/// 1. Onboarding tutorial (first time only)
/// 2. Profile setup (must fill physical info before using the app)
/// 3. MainTabView (main app)
struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("profile.hasCompletedProfile") private var hasCompletedProfile: Bool = false

    var body: some View {
        ZStack {
            Color.themeBackground.ignoresSafeArea()

            Group {
                if !hasCompletedOnboarding {
                    OnboardingView()
                } else if !hasCompletedProfile {
                    ProfileSetupView()
                } else {
                    MainTabView()
                }
            }
            .animation(.easeInOut(duration: 0.35), value: hasCompletedOnboarding)
            .animation(.easeInOut(duration: 0.35), value: hasCompletedProfile)
        }
    }
}

#if DEBUG
struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
            .environmentObject(AppRouter())
    }
}
#endif
