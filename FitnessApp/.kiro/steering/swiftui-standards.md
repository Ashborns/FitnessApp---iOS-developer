---
inclusion: fileMatch
fileMatchPattern: "**/*.swift"
---

# SwiftUI Screen Standards — FitnessApp

## iOS 16.4 Availability Rules

**AVAILABLE — use freely:**
- NavigationStack, NavigationLink(value:), navigationDestination(for:)
- Charts framework (Swift Charts — iOS 16+)
- @StateObject, @ObservedObject, @EnvironmentObject
- .searchable(), .refreshable(), .task {}
- ShareLink, PhotosPicker
- AnyLayout, ViewThatFits

**NOT AVAILABLE — DO NOT USE:**
- @Observable macro (iOS 17+)
- @Bindable (iOS 17+)
- SwiftData / @Model (iOS 17+)
- TipKit (iOS 17+)
- .onChange(of:initial:) two-parameter form (iOS 17+) — use .onChange(of:perform:) instead
- ScrollView new parameters (iOS 17+)

## ViewModel Pattern

Every screen has exactly one ViewModel using ObservableObject + @Published:

```swift
@MainActor
final class HomeViewModel: ObservableObject {
    @Published var calorieProgress: Double = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let healthKitManager: HealthKitManager

    init(healthKitManager: HealthKitManager = .shared) {
        self.healthKitManager = healthKitManager
    }

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
}
```

## Navigation

Use NavigationStack (iOS 16+). Do NOT use NavigationView (deprecated).

## Color & Theme

All colors come from `Color+Theme.swift`. Never use hardcoded hex in views.

## Accessibility

Every interactive element must have an accessibility label and identifier.

## Performance Rules

- Never use AnyView — use @ViewBuilder
- Avoid heavy computation in `body`
- Use LazyVStack/LazyHStack for lists > 20 items

## File Naming

| Type | Convention |
|------|-----------|
| View | `FeatureNameView.swift` |
| ViewModel | `FeatureNameViewModel.swift` |
| Extension | `TypeName+Context.swift` |
