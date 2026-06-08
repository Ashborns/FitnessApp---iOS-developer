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

    // MARK: - Deep Link Handling

    /// Parses a deep link URL and navigates to the corresponding tab.
    ///
    /// Supports URL format: `fitnessapp://tab/{tabName}`
    /// where `{tabName}` matches one of the `AppTab` raw values.
    ///
    /// If the URL does not contain a valid tab identifier,
    /// the current `selectedTab` is preserved unchanged.
    ///
    /// - Parameter url: The incoming deep link URL to handle.
    func handleDeepLink(_ url: URL) {
        guard url.scheme == "fitnessapp" else { return }

        if url.host == "tab" {
            // Format: fitnessapp://tab/{tabName}
            let pathComponents = url.pathComponents.filter { $0 != "/" }
            guard let tabName = pathComponents.first,
                  let tab = AppTab(rawValue: tabName) else { return }
            selectedTab = tab
        } else if let host = url.host, let tab = AppTab(rawValue: host) {
            // Format: fitnessapp://{tabName}
            selectedTab = tab
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
