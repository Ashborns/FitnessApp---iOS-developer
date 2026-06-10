import Foundation
import SwiftUI

/// Central navigation state manager for the app.
/// Manages tab selection, camera presentation, onboarding state, and deep link handling.
@MainActor
final class AppRouter: ObservableObject {

    // MARK: - AppTab

    /// Represents the six main tabs in the app.
    /// String raw values enable deep link URL parsing.
    enum AppTab: String, CaseIterable {
        case home
        case workout
        case camera
        case calories
        case more
        case profile   // internal deep link — tidak tampil di tab bar
        case progress
        case chat      // internal deep link — tidak tampil di tab bar
    }

    // MARK: - AppRoute

    /// Destinations pushed onto the navigation stack (`NavigationStack(path:)`).
    /// Drives `navigationDestination(for: AppRoute.self)` at the call sites.
    enum AppRoute: Hashable {
        case library
        case exerciseDetail(exerciseID: String)
        case builder(routineID: UUID?)   // nil = routine baru
        case muscleMap
        case schedule
    }

    // MARK: - Published Properties

    /// The currently selected tab. Defaults to `.home` on launch.
    @Published var selectedTab: AppTab = .home

    /// Whether the onboarding flow should be displayed.
    @Published var showOnboarding: Bool = true

    /// Whether the camera full-screen cover is presented.
    @Published var showCamera: Bool = false

    /// The tab that was selected before the camera was opened.
    @Published var previousTab: AppTab = .home

    /// If set, the camera opens with this exercise pre-selected.
    /// Consumed by CameraFeedView on appear, then cleared.
    @Published var pendingExercise: ExerciseType?

    /// The navigation stack path driving `NavigationStack(path:)`.
    /// Each element is an `AppRoute` destination pushed on top of the
    /// currently selected tab's root.
    @Published var path: [AppRoute] = []

    // MARK: - Route Navigation

    /// Pushes a new route onto the navigation stack.
    /// - Parameter route: The `AppRoute` destination to navigate to.
    func navigate(to route: AppRoute) {
        path.append(route)
    }

    /// Pops the navigation stack back to the Library screen.
    ///
    /// Behavior:
    /// - If `.library` exists in the path, removes every segment above the
    ///   first `.library` so it becomes the top of the stack.
    /// - If `.library` is not present, clears the path entirely (no-op safe).
    func popToLibrary() {
        guard let firstLibraryIndex = path.firstIndex(of: .library) else {
            path.removeAll()
            return
        }
        // Keep everything up to and including the first `.library`.
        path = Array(path.prefix(through: firstLibraryIndex))
    }

    // MARK: - Deep Link Handling

    /// Parses a deep link URL and navigates to the corresponding tab or route.
    ///
    /// Supported formats:
    /// - `fitnessapp://tab/{tabName}` — selects a tab (`{tabName}` ∈ `AppTab` raw values).
    /// - `fitnessapp://{tabName}` — selects a tab.
    /// - `fitnessapp://route/{routeName}` — pushes an `AppRoute` onto `path`.
    ///   Supported `{routeName}`: `library`, `muscleMap`, `schedule`,
    ///   `builder` (optional `routineID` query/path), `exerciseDetail`
    ///   (requires an exercise id via query `id` or trailing path component).
    ///
    /// If the URL does not contain a valid tab/route identifier, the current
    /// `selectedTab` is preserved unchanged, nothing is pushed onto `path`,
    /// and no crash occurs. (Requirement 3.6)
    ///
    /// - Parameter url: The incoming deep link URL to handle.
    func handleDeepLink(_ url: URL) {
        guard url.scheme == "fitnessapp" else { return }

        if url.host == "route" {
            // Format: fitnessapp://route/{routeName}[/{id}]?id=...&routineID=...
            handleRouteDeepLink(url)
        } else if url.host == "tab" {
            // Format: fitnessapp://tab/{tabName}
            let pathComponents = url.pathComponents.filter { $0 != "/" }
            guard let tabName = pathComponents.first,
                  let tab = AppTab(rawValue: tabName) else { return }
            selectedTab = tab
        } else if let host = url.host, let tab = AppTab(rawValue: host) {
            // Format: fitnessapp://{tabName}
            selectedTab = tab
        }
        // Any other/invalid host → no-op (no tab change, no push, no crash).
    }

    /// Parses and pushes an `AppRoute` from a `fitnessapp://route/...` deep link.
    /// Invalid or unrecognized routes are ignored (no push, no crash).
    private func handleRouteDeepLink(_ url: URL) {
        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard let routeName = pathComponents.first else { return }

        // Remaining path components after the route name (e.g. the id).
        let trailing = Array(pathComponents.dropFirst())
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        switch routeName {
        case "library":
            navigate(to: .library)
        case "muscleMap":
            navigate(to: .muscleMap)
        case "schedule":
            navigate(to: .schedule)
        case "builder":
            // Optional routineID via query (?routineID=...) or trailing path component.
            let rawID = queryItems.first(where: { $0.name == "routineID" })?.value
                ?? trailing.first
            let routineID = rawID.flatMap { UUID(uuidString: $0) }
            navigate(to: .builder(routineID: routineID))
        case "exerciseDetail":
            // Requires an id via query (?id=...) or trailing path component.
            guard let exerciseID = (queryItems.first(where: { $0.name == "id" })?.value
                ?? trailing.first),
                  !exerciseID.isEmpty else { return }
            navigate(to: .exerciseDetail(exerciseID: exerciseID))
        default:
            // Unknown route → no-op.
            return
        }
    }

    // MARK: - Camera Navigation

    /// Opens the camera full-screen cover, preserving the current tab
    /// so it can be restored on dismiss.
    func openCamera() {
        previousTab = selectedTab
        pendingExercise = nil
        showCamera = true
    }

    /// Opens the camera full-screen cover with a specific exercise pre-selected.
    /// The camera will skip the demo and start tracking immediately.
    func openCamera(with exercise: ExerciseType) {
        previousTab = selectedTab
        pendingExercise = exercise
        showCamera = true
    }

    /// Dismisses the camera full-screen cover and restores the
    /// previously selected tab.
    func dismissCamera() {
        showCamera = false
        selectedTab = previousTab
        pendingExercise = nil
    }
}
