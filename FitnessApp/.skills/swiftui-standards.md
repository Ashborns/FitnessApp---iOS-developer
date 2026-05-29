# Skill: SwiftUI Screen Standards
# Project: FitnessCoach iOS App
# Target: iOS 16.4 / Xcode 14.0 / Swift 5.7
# Read this before writing any SwiftUI view in this project.

---

## iOS 16.4 Availability Rules

These APIs are AVAILABLE on iOS 16.4 — use freely:
- NavigationStack, NavigationLink (value:), navigationDestination(for:)
- Charts framework (Swift Charts — iOS 16+)
- @StateObject, @ObservedObject, @EnvironmentObject
- .searchable(), .refreshable(), .task {}
- ShareLink, PhotosPicker
- AnyLayout, ViewThatFits

These APIs are NOT available on iOS 16.4 — DO NOT USE:
- @Observable macro (iOS 17+)
- @Bindable (iOS 17+)
- SwiftData / @Model (iOS 17+)
- TipKit (iOS 17+)
- MapKit SwiftUI v2 / Map(initialPosition:) (iOS 17+)
- .onChange(of:initial:) two-parameter form (iOS 17+) — use .onChange(of:perform:) instead
- NavigationSplitView with full new API surface — partial support only
- ScrollView(axes:showsIndicators:content:) with new parameters (iOS 17+)

When in doubt: check https://developer.apple.com/documentation before using.

---

## ViewModel Pattern (this project standard)

Every screen has exactly one ViewModel. Use ObservableObject + @Published:

```swift
// CORRECT for iOS 16.4
final class HomeViewModel: ObservableObject {
    @Published var calorieProgress: Double = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let healthKitManager: HealthKitManager

    init(healthKitManager: HealthKitManager = .shared) {
        self.healthKitManager = healthKitManager
    }

    @MainActor
    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        do {
            calorieProgress = try await healthKitManager.fetchTodayActiveEnergy()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

Never put business logic directly in a View body.
Never put network or data calls directly in a View's .onAppear without a ViewModel.

---

## View Structure Template

```swift
struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        content
            .task { await viewModel.loadData() }
            .alert("Error", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView()
        } else {
            mainContent
        }
    }

    private var mainContent: some View {
        // actual view body here
        Text("Home")
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } })
    }
}
```

---

## Navigation

Use NavigationStack (iOS 16+) with a path binding for programmatic navigation:

```swift
struct AppRootView: View {
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            HomeView()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .workout: WorkoutView()
                    case .camera: CameraFeedView()
                    case .profile: ProfileView()
                    }
                }
        }
        .environmentObject(...)
    }
}

enum AppRoute: Hashable {
    case workout, camera, profile
}
```

Do NOT use NavigationView — it is deprecated as of iOS 16.

---

## Color & Theme

All colors come from `Color+Theme.swift` extension. Never use hardcoded hex in views.

```swift
extension Color {
    static let fcPrimary = Color("Primary", bundle: nil)       // from Assets
    static let fcBackground = Color("Background", bundle: nil)
    static let fcAccent = Color("Accent", bundle: nil)
    static let fcSuccess = Color.green
    static let fcWarning = Color.orange
    static let fcDanger = Color.red
}
```

---

## Accessibility

Every interactive element must have an accessibility label:

```swift
Button(action: { ... }) {
    Image(systemName: "plus")
}
.accessibilityLabel("Add workout")

// Progress bars need value and label:
ProgressView(value: progress)
    .accessibilityLabel("Calorie progress")
    .accessibilityValue("\(Int(progress * 100)) percent")
```

---

## Performance Rules

- Never use AnyView unless absolutely required (breaks type inference, hurts diffs)
- Prefer @ViewBuilder over AnyView for conditional content
- Avoid heavy computation in `body` — move to ViewModel
- Use .equatable() on views with expensive renders where content rarely changes
- LazyVStack / LazyHStack for lists longer than ~20 items

---

## File Naming

| File | Naming convention |
|------|-------------------|
| View | `FeatureNameView.swift` |
| ViewModel | `FeatureNameViewModel.swift` |
| Supporting view | `FeatureNameComponentName.swift` (e.g. `HomeCalorieRingView.swift`) |
| Extension | `TypeName+Context.swift` (e.g. `Color+Theme.swift`) |
