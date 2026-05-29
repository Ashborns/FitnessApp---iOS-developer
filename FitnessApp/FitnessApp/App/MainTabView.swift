import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var router: AppRouter

    init() {
        // Tab bar: pure black with orange tint accent
        let tabBg = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0.00, green: 0.00, blue: 0.00, alpha: 1.0)
                : UIColor(red: 0.97, green: 0.96, blue: 0.95, alpha: 1.0)
        }
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = tabBg
        appearance.shadowColor = UIColor(white: 1.0, alpha: 0.10)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance

        // Navigation bar: matches background
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = tabBg
        navAppearance.shadowColor = .clear
        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 17, weight: .bold)
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.label,
            .font: UIFont.systemFont(ofSize: 32, weight: .heavy)
        ]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
    }

    var body: some View {
        ZStack {
            Color.themeBackground.ignoresSafeArea()

            TabView(selection: $router.selectedTab) {
                homeTab
                workoutTab
                cameraPlaceholder
                caloriesTab
                profileTab
            }
            .tint(Color.themePrimary)
        }
        .fullScreenCover(isPresented: $router.showCamera) {
            CameraFeedView()
        }
        .onChange(of: router.selectedTab) { newValue in
            if newValue == .camera {
                router.openCamera()
            }
        }
    }

    // MARK: - Tabs

    private var homeTab: some View {
        HomeView()
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }
            .tag(AppRouter.AppTab.home)
    }

    private var workoutTab: some View {
        WorkoutView()
            .tabItem {
                Label("Workout", systemImage: "figure.run")
            }
            .tag(AppRouter.AppTab.workout)
    }

    private var cameraPlaceholder: some View {
        Color.clear
            .tabItem {
                Label("Camera", systemImage: "camera.viewfinder")
            }
            .tag(AppRouter.AppTab.camera)
    }

    private var caloriesTab: some View {
        CalorieGoalView()
            .tabItem {
                Label("Calories", systemImage: "flame.fill")
            }
            .tag(AppRouter.AppTab.calories)
    }

    private var profileTab: some View {
        NavigationStack {
            SettingsView()
        }
        .tabItem {
            Label("Profile", systemImage: "person.circle.fill")
        }
        .tag(AppRouter.AppTab.profile)
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(AppRouter())
    }
}
