# Implementation Plan: FitnessApp Orchestrated Build

## Overview

This plan implements the FitnessApp using a multi-agent orchestration pattern with AI-Pair review gates. Each phase maps to a specialist agent role with strict file ownership. After each phase, a review gate evaluates the output from two perspectives (Code Quality Auditor + Integration Architect) before the next phase begins.

**Collaboration Model:** "One Creates, Two Review" (inspired by ai-pair + A2A Protocol concepts)
- Creator Agent implements code for their domain
- Code Reviewer evaluates quality, patterns, and constraints
- Integration Reviewer evaluates cross-agent compatibility and API contracts

All code is Swift 5.7 targeting iOS 16.4+, using SwiftUI lifecycle, CoreData, Firebase Auth, and XCTest.

## Tasks

- [x] 1. Phase 1 — "The Architect" (Agent 0: Setup)
  - No dependencies. Runs first. Establishes app shell, navigation, and routing.
  - Files: `FitnessApp/App/`, `FitnessApp/Core/Navigation/`

  - [x] 1.1 Implement AppRouter with tab navigation and deep link handling
    - Create `FitnessApp/Core/Navigation/AppRouter.swift`
    - Define `AppTab` enum with cases: home, workout, camera, calories, profile
    - Implement `@Published var selectedTab`, `showOnboarding`, `showCamera`, `previousTab`
    - Implement `handleDeepLink(_:)` parsing URL scheme `fitnessapp://tab/{tabName}`
    - Implement `openCamera()` and `dismissCamera()` methods preserving previous tab
    - Annotate class with `@MainActor`
    - _Requirements: 2.1, 2.3, 2.4, 2.5, 2.6, 2.7_

  - [x] 1.2 Implement MainTabView with five tabs and camera fullScreenCover
    - Create `FitnessApp/App/MainTabView.swift`
    - Configure TabView with five tabs: Home, Workout, Camera (placeholder), Calories, Profile
    - Add `.fullScreenCover(isPresented: $router.showCamera)` for camera presentation
    - Add `.onChange(of: router.selectedTab)` to trigger camera on camera tab selection
    - Use stub views where feature views are not yet available
    - _Requirements: 2.2, 2.3, 2.4, 13.1_

  - [x] 1.3 Implement RootView with auth-based routing and animated transitions
    - Create `FitnessApp/App/RootView.swift`
    - Conditionally show OnboardingView (stub) when `!authManager.isAuthenticated`
    - Show MainTabView when `authManager.isAuthenticated`
    - Add opacity crossfade animation (0.35s) on auth state change
    - Show launch placeholder while auth state is being evaluated
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5_

  - [x] 1.4 Implement FitnessAppApp entry point with Firebase and environment injection
    - Create `FitnessApp/App/FitnessAppApp.swift`
    - Call `FirebaseApp.configure()` in init
    - Handle `onOpenURL` for Google Sign-In callback
    - Inject `AuthManager` and `AppRouter` as `@StateObject` environment objects
    - Use SwiftUI app lifecycle exclusively (no UIApplicationDelegate)
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5_

- [x] 2. Phase 2 — "The Auth Engineer" (Agent 1: Auth)
  - Depends on: Phase 1 complete. Can run in parallel with Phase 3 (first pass).
  - Files: `FitnessApp/Features/Auth/`, `FitnessApp/Core/Keychain/`
  - NOTE: Google Sign-In actual Firebase console setup will be done manually later (Phase 8). Code uses placeholder/stub for Firebase config.

  - [x] 2.1 Implement KeychainWrapper for secure token storage
    - Create `FitnessApp/Core/Keychain/KeychainWrapper.swift`
    - Implement `save(key:value:)` → Bool using `kSecClassGenericPassword`
    - Implement `load(key:)` → String? for token retrieval
    - Implement `delete(key:)` → Bool for token removal
    - Use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` accessibility
    - Delete before insert pattern for save operations
    - _Requirements: 6.1, 6.2, 6.3, 6.4, 6.5_

  - [x] 2.2 Implement AuthManager with Firebase Auth and Google Sign-In
    - Create `FitnessApp/Features/Auth/AuthManager.swift`
    - Implement singleton `AuthManager.shared` with `@MainActor`
    - Implement `signIn(email:password:)` async with Firebase Auth
    - Implement `signUp(email:password:)` async with validation (email format, password >= 6 chars)
    - Implement `signInWithGoogle()` async using GoogleSignIn-iOS SDK v7.x
    - Implement `signOut()` clearing Firebase + Google sessions
    - Implement `restoreSession()` for persisted Firebase session on launch
    - Publish `isAuthenticated`, `currentUserID`, `errorMessage`, `isLoading`
    - // TODO: Firebase console setup and GoogleService-Info.plist will be configured manually
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 4.9, 5.1, 5.2, 5.3, 5.4, 5.5_

  - [x] 2.3 Implement OnboardingView with 3-screen walkthrough
    - Create `FitnessApp/Features/Auth/OnboardingView.swift`
    - Build 3-screen horizontal swipe walkthrough with TabView/PageTabViewStyle
    - Add "Next" button and "Skip" button on each screen
    - Persist onboarding completion to UserDefaults
    - Set accessibility identifiers: "onboarding-welcome", "onboarding-auth", "onboarding-profile"
    - Navigate to LoginView on final action or skip
    - _Requirements: 7.1, 7.2, 7.3, 7.5_

  - [x] 2.4 Implement LoginView with email/password and Google Sign-In button
    - Create `FitnessApp/Features/Auth/LoginView.swift`
    - Build email/password form with validation feedback
    - Add Google Sign-In button triggering `authManager.signInWithGoogle()`
    - Show error messages from `authManager.errorMessage`
    - Set accessibility identifiers: "login-email-field", "login-password-field", "login-submit-btn"
    - Add navigation to SignUpView
    - _Requirements: 4.1, 4.2, 4.3, 7.4_

  - [x] 2.5 Implement SignUpView with registration form
    - Create `FitnessApp/Features/Auth/SignUpView.swift`
    - Build registration form with email + password + confirm password
    - Validate email format and password length >= 6 before submission
    - Show inline error messages for validation failures
    - Call `authManager.signUp(email:password:)` on submit
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5_

- [x] 3. Phase 3 — "The UI Designer" First Pass (Agent 3: UI - Pass 1)
  - Depends on: Phase 1 complete. Runs in parallel with Phase 2.
  - Uses stubs/mocks where Auth or Data dependencies aren't ready.
  - Files: `FitnessApp/Core/Extensions/`, `FitnessApp/Features/Camera/`

  - [x] 3.1 Implement Color+Theme.swift design system
    - Create `FitnessApp/Core/Extensions/Color+Theme.swift`
    - Define adaptive color tokens: primary, secondary, background, surface, error, accent
    - Ensure WCAG AA contrast ratio 4.5:1 in both light/dark appearances
    - Define spacing tokens (small, medium, large, extraLarge) and corner radius tokens (small, large)
    - Use SwiftUI Color with adaptive light/dark variants
    - _Requirements: 12.1, 12.2, 12.4, 12.5_

  - [x] 3.2 Implement VisionBodyPoseAnalyzer for body pose detection
    - Create `FitnessApp/Features/Camera/VisionBodyPoseAnalyzer.swift`
    - Implement `AVCaptureVideoDataOutputSampleBufferDelegate`
    - Run `VNDetectHumanBodyPoseRequest` on every 4th frame (skip 3)
    - Filter joints with confidence >= 0.5
    - Expose `onPoseDetected` callback for detected poses
    - _Requirements: 13.2, 13.3, 13.6_

  - [x] 3.3 Implement CameraViewModel managing AVCaptureSession lifecycle
    - Create `FitnessApp/Features/Camera/CameraViewModel.swift`
    - Manage `AVCaptureSession` with rear camera at `.high` preset
    - Implement `requestPermission()`, `setupSession()`, `startSession()`, `stopSession()`
    - Publish `isAuthorized`, `isRunning`, `detectedPose`
    - Use dedicated serial DispatchQueue for camera output
    - Wire `VisionBodyPoseAnalyzer` as video output delegate
    - _Requirements: 13.1, 13.5_

  - [x] 3.4 Implement CameraFeedView with pose overlay
    - Create `FitnessApp/Features/Camera/CameraFeedView.swift`
    - Use `UIViewRepresentable` to display AVCaptureVideoPreviewLayer
    - Overlay detected joint positions on the camera preview
    - Show permission-denied message with Settings button if camera access denied
    - Hide overlay when no body detected
    - _Requirements: 13.1, 13.3, 13.4, 13.6_

- [x] 4. 🔍 Review Gate — AI-Pair Review (Phases 1–3)
  - **Code Quality Auditor**: Verify no force unwraps, all @Published on @MainActor, iOS 16.4 APIs only, proper error handling
  - **Integration Architect**: Verify AppRouter public API matches design.md contract, AuthManager exposes correct interface for Agent 2, camera fullScreenCover pattern is correct, accessibility identifiers present
  - Update SHARED_STATE.md for all completed files → ✅ STABLE
  - Fix any issues found before proceeding

- [x] 5. Phase 4 — "The Data Engineer" (Agent 2: Data)
  - Depends on: Phase 2 complete (needs `AuthManager.currentUserID`).
  - Files: `FitnessApp/Core/Data/`, `FitnessApp/Core/Health/`, `FitnessApp/Features/Calories/CalorieGoalViewModel.swift`, `FitnessApp/Features/Workout/WorkoutRecommendationEngine.swift`

  - [x] 5.1 Implement PersistenceController with CoreData stack
    - Create `FitnessApp/Core/Data/PersistenceController.swift`
    - Configure `NSPersistentContainer` with shared singleton and in-memory preview
    - Set `automaticallyMergesChangesFromParent = true` on viewContext
    - Set `mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy`
    - Implement `save()` that only persists when `hasChanges` is true
    - Handle store load failure: fatalError in DEBUG, log in release
    - _Requirements: 8.1, 8.2, 8.8, 8.9, 8.10_

  - [x] 5.2 Implement CoreData entity models
    - Create `FitnessApp/Core/Data/Models/UserProfile+CoreData.swift` with factory + fetch helpers
    - Create `FitnessApp/Core/Data/Models/WorkoutLog+CoreData.swift` with factory + fetch helpers
    - Create `FitnessApp/Core/Data/Models/DailyGoal+CoreData.swift` with factory + fetch helpers
    - Create `FitnessApp/Core/Data/Models/CalorieEntry+CoreData.swift` with factory + todayFetchRequest
    - Define all entity attributes and relationships per design ERD
    - Include validation constraints on attribute ranges
    - _Requirements: 8.3, 8.4, 8.5, 8.6, 8.7_

  - [x] 5.3 Implement HealthKitManager with authorization and energy queries
    - Create `FitnessApp/Core/Health/HealthKitManager.swift`
    - Implement `requestAuthorization()` checking device availability first
    - Implement `fetchTodayActiveEnergy()` querying cumulative active energy from start of day
    - Define `HealthKitError` enum: `.notAvailable`, `.unauthorized`, `.queryFailed(Error)`
    - Return mock 320.0 kcal on simulator via `#if targetEnvironment(simulator)`
    - Publish `activeEnergyBurned` on `@MainActor`
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5, 9.6, 9.7_

  - [x] 5.4 Implement CalorieGoalViewModel with entry persistence and HealthKit integration
    - Create `FitnessApp/Features/Calories/CalorieGoalViewModel.swift`
    - Publish `dailyGoal` (range 500–10000), `consumed`, `burned`, `errorMessage`, `entries`
    - Implement `loadTodayData()` fetching CalorieEntry records for current day
    - Compute `consumed` as sum of today's entry amounts
    - Integrate `HealthKitManager` for `burned` value
    - Implement `saveEntry(amount:label:)` with validation (amount 1–99999, label 1–100 chars)
    - Return `CalorieValidationError` for invalid inputs; don't persist invalid entries
    - Use constructor injection with defaults for testability
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7, 10.8_

  - [x] 5.5 Implement WorkoutRecommendationEngine with rule-based logic
    - Create `FitnessApp/Features/Workout/WorkoutRecommendationEngine.swift`
    - Implement `generateRecommendations(history:remainingDeficit:availableTypes:)`
    - Return 3–5 recommendations with workout type and duration
    - Rank recently completed types (last 7 days) lower
    - Scale duration to remaining deficit (max 60 min)
    - Return 3 beginner workouts (≤20 min) when no history
    - Select least-recently-performed first when all types used recently
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5_

- [x] 6. Phase 5 — "The UI Designer" Second Pass (Agent 3: UI - Pass 2)
  - Depends on: Phase 4 complete (connects real CoreData/HealthKit data).
  - Files: `FitnessApp/Features/Home/`, `FitnessApp/Features/Calories/CalorieGoalView.swift`, `FitnessApp/Features/Workout/WorkoutView.swift`, `FitnessApp/Features/Workout/WorkoutViewModel.swift`, `FitnessApp/Features/Profile/`

  - [x] 6.1 Implement HomeView and HomeViewModel with dashboard
    - Create `FitnessApp/Features/Home/HomeViewModel.swift` loading today's calorie summary and recent workouts
    - Create `FitnessApp/Features/Home/HomeView.swift` with calorie summary, 3 recent workouts, quick-action buttons
    - Add accessibility identifier "home-root"
    - Add navigation to ProgressView
    - Show empty-state message when no data available
    - Support Dynamic Type and VoiceOver
    - _Requirements: 14.1, 14.2, 14.8, 15.1, 15.2, 15.3, 15.4, 18.3_

  - [x] 6.2 Implement CalorieGoalView with circular progress indicator
    - Create `FitnessApp/Features/Calories/CalorieGoalView.swift`
    - Display circular progress ring showing consumed vs goal
    - Show numeric consumed and goal values as text
    - Add entry form to log calories (calls CalorieGoalViewModel.saveEntry)
    - Add accessibility identifier "calorie-goal-root"
    - Show empty-state when no entries exist
    - Support Dynamic Type and Reduce Motion preferences
    - _Requirements: 14.3, 14.7, 14.8, 15.1, 15.3, 15.5_

  - [x] 6.3 Implement WorkoutView and WorkoutViewModel with recommendations
    - Create `FitnessApp/Features/Workout/WorkoutViewModel.swift` integrating WorkoutRecommendationEngine
    - Create `FitnessApp/Features/Workout/WorkoutView.swift` showing recommendations and 10 recent sessions
    - Display type, duration, and date for past sessions
    - Add accessibility identifier "workout-root"
    - Show empty-state when no workout history
    - _Requirements: 14.4, 14.7, 14.8, 15.2, 15.3_

  - [x] 6.4 Implement ProfileView and ProfileViewModel with sign-out
    - Create `FitnessApp/Features/Profile/ProfileViewModel.swift` loading user profile data
    - Create `FitnessApp/Features/Profile/ProfileView.swift` showing displayName, email
    - Add sign-out button calling `AuthManager.signOut()`
    - Add navigation link to NotificationSettingsView (stub until Phase 7)
    - Add accessibility identifier "profile-root" and "profile-signout-btn"
    - _Requirements: 14.5, 14.6, 14.7, 15.2, 15.4_

- [x] 7. 🔍 Review Gate — AI-Pair Review (Phases 4–5)
  - **Code Quality Auditor**: Verify CoreData entities match ERD, HealthKit checks auth before queries, CalorieGoalViewModel validates inputs, no stubs remaining in UI views
  - **Integration Architect**: Verify PersistenceController.shared accessible by all ViewModels, HealthKitManager.shared used correctly, all views connected to real data (no mock data remaining), empty states handled
  - Update SHARED_STATE.md for all completed files → ✅ STABLE
  - Fix any issues found before proceeding

- [x] 8. Phase 6 — "The QA Engineer" (Agent 4: Tests)
  - Depends on: Phases 2, 4, and 5 complete (tests stable code).
  - Files: `FitnessAppTests/`, `FitnessAppUITests/`

  - [x] 8.1 Implement AuthManagerTests
    - Create `FitnessAppTests/Auth/AuthManagerTests.swift`
    - Test signIn success and failure paths
    - Test signUp success, invalid email, short password
    - Test signInWithGoogle success and cancellation
    - Test signOut clears state
    - Test restoreSession
    - Use mocked Firebase Auth
    - _Requirements: 16.1, 16.5, 16.6, 16.7, 16.8_

  - [ ]* 8.2 Write property tests for AppRouter navigation
    - **Property 1: Camera dismiss restores previous tab**
    - **Property 2: Valid deep link sets correct tab**
    - **Property 3: Invalid deep link preserves tab state**
    - **Validates: Requirements 2.4, 2.6, 2.7**

  - [ ]* 8.3 Write property tests for KeychainWrapper
    - **Property 6: Keychain CRUD round-trip**
    - **Validates: Requirements 6.2, 6.3, 6.4**

  - [ ]* 8.4 Write property tests for AuthManager error handling
    - **Property 4: Auth failure preserves authentication state**
    - **Property 5: Invalid credentials rejected on sign-up**
    - **Validates: Requirements 4.2, 5.3, 5.4**

  - [x] 8.5 Implement HealthKitManagerTests
    - Create `FitnessAppTests/Health/HealthKitManagerTests.swift`
    - Test authorization granted and denied paths
    - Test fetchTodayActiveEnergy with mocked HKStatisticsQuery
    - Test error handling for unavailable and query failures
    - Use MockHealthKitManager protocol-based mock
    - _Requirements: 16.2, 16.5, 16.7_

  - [x] 8.6 Implement CalorieGoalViewModelTests
    - Create `FitnessAppTests/Calories/CalorieGoalViewModelTests.swift`
    - Test saveEntry with valid and invalid inputs
    - Test consumed computation from today's entries
    - Test burned value integration with mocked HealthKit
    - Use in-memory PersistenceController
    - _Requirements: 16.3, 16.5, 16.8_

  - [ ]* 8.7 Write property tests for CalorieGoalViewModel
    - **Property 9: Valid calorie entries persist successfully**
    - **Property 10: Invalid calorie entries are rejected**
    - **Property 11: Consumed equals sum of today's entries**
    - **Validates: Requirements 10.2, 10.3, 10.4**

  - [x] 8.8 Implement WorkoutRecommendationEngineTests
    - Create `FitnessAppTests/Workout/WorkoutRecommendationEngineTests.swift`
    - Test recommendation count invariant (3–5)
    - Test recent types ranked lower
    - Test duration cap at 60 minutes
    - Test empty history returns beginner defaults
    - Test all-recent-types scenario
    - _Requirements: 16.4, 16.5, 16.8_

  - [ ]* 8.9 Write property tests for WorkoutRecommendationEngine
    - **Property 12: Recommendation count invariant**
    - **Property 13: Recent workout types ranked lower**
    - **Property 14: Recommendation duration cap**
    - **Property 15: Empty history produces beginner defaults**
    - **Validates: Requirements 11.1, 11.2, 11.3, 11.4**

  - [ ]* 8.10 Write property tests for CoreData and PersistenceController
    - **Property 7: CoreData entity persistence round-trip**
    - **Property 8: Save is idempotent without changes**
    - **Validates: Requirements 8.4, 8.5, 8.6, 8.7, 8.9**

  - [ ]* 8.11 Write property tests for VisionBodyPoseAnalyzer
    - **Property 16: Frame skip ratio**
    - **Property 17: Joint confidence threshold filter**
    - **Validates: Requirements 13.2, 13.3**

  - [x] 8.12 Implement OnboardingUITests
    - Create `FitnessAppUITests/OnboardingUITests.swift`
    - Test happy path: welcome → auth → home
    - Verify accessibility identifiers: "onboarding-welcome", "onboarding-auth", "home-root"
    - Test skip button navigation
    - _Requirements: 17.3_

- [x] 9. 🔍 Review Gate — AI-Pair Review (Phase 6: Tests)
  - **Code Quality Auditor**: Verify all tests use in-memory CoreData, HealthKit properly mocked, each test independent, XCTest only (no third-party)
  - **Integration Architect**: Verify property-based tests cover correctness properties from design.md, coverage thresholds achievable (80% ViewModels, 90% data layer), UI tests use accessibility identifiers
  - Fix any failing tests before proceeding

- [x] 10. Phase 7 — "The Polish Master" (Agent 5: Polish)
  - Depends on: ALL previous phases complete.
  - Files: `FitnessApp/Features/Progress/`, `FitnessApp/Features/Notifications/`

  - [x] 10.1 Implement ProgressViewModel and ProgressView with Swift Charts
    - Create `FitnessApp/Features/Progress/ProgressViewModel.swift` loading calorie/workout history
    - Create `FitnessApp/Features/Progress/ProgressView.swift` with calorie trend chart
    - Support time range selection: 7, 30, 90 days (default 7)
    - Display workout history list (up to 50 sessions)
    - Show empty state when no data exists
    - Reload data within 1 second on range change
    - _Requirements: 18.1, 18.2, 18.3, 18.4, 18.5_

  - [x] 10.2 Implement NotificationManager with local notifications
    - Create `FitnessApp/Features/Notifications/NotificationManager.swift`
    - Schedule daily workout reminder (default 08:00)
    - Schedule daily goal reminder (default 20:00)
    - Implement `requestPermission()`, `scheduleWorkoutReminder()`, `scheduleGoalReminder()`
    - Implement `cancelReminders(category:)` removing pending notifications
    - Handle permission denied state gracefully
    - _Requirements: 19.1, 19.2, 19.3, 19.4, 19.6_

  - [x] 10.3 Implement NotificationSettingsView with toggles
    - Create `FitnessApp/Features/Notifications/NotificationSettingsView.swift`
    - Add toggles for workout and goal reminders (default disabled)
    - Add time pickers for reminder times
    - Show prompt to open Settings if notification permission denied
    - Wire toggles to NotificationManager schedule/cancel
    - _Requirements: 19.5, 19.6, 19.7_

  - [x] 10.4 Add Progress tab to MainTabView and App Store assets
    - Modify `FitnessApp/App/MainTabView.swift` to add Progress tab
    - Add 1024×1024 PNG app icon to Assets.xcassets/AppIcon.appiconset
    - Verify all Info.plist privacy strings are present
    - Verify CFBundleDisplayName, version strings, and ITSAppUsesNonExemptEncryption
    - _Requirements: 20.1, 20.2, 20.3, 20.4, 20.5, 20.6_

- [x] 11. 🔍 Review Gate — AI-Pair Final Review (All Phases)
  - **Code Quality Auditor**: Full codebase scan — zero force unwraps, zero compile warnings, all @Published on @MainActor, no iOS 17+ APIs, no SwiftData usage
  - **Integration Architect**: All 44 files in SHARED_STATE.md marked ✅ STABLE, all agent scopes respected (no cross-boundary edits without CROSS-AGENT EDIT comment), all accessibility identifiers present, App Store checklist complete
  - Generate final report of review findings

- [x] 12. Phase 8 — "The Guide" (Manual Firebase Setup Documentation)
  - This is a DOCUMENTATION task only — no code changes.
  - Depends on: All previous phases complete.

  - [x] 12.1 Create Firebase and Google Sign-In manual setup guide
    - Document steps for Firebase console project creation
    - Document adding iOS app to Firebase project with bundle ID
    - Document downloading and adding `GoogleService-Info.plist` to Xcode project
    - Document adding URL scheme from `REVERSED_CLIENT_ID` in GoogleService-Info.plist
    - Document enabling Email/Password and Google sign-in methods in Firebase console
    - Document verifying the app builds and auth flow works end-to-end
    - Save guide as `.agents/FIREBASE_SETUP_GUIDE.md`
    - _Requirements: 1.1, 1.2, 4.3_

## Notes

- Tasks marked with `*` are optional property-based tests and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation between phases
- Property tests validate universal correctness properties from the design document
- Unit tests validate specific examples and edge cases
- Phases 2 and 3 can run in parallel (no shared file dependencies)
- Phase 4 blocks on Phase 2 (AuthManager.currentUserID needed for CoreData user linking)
- Phase 6 (Tests) requires stable production code to test against
- Phase 7 (Polish) starts only after all feature code is stable
- Google Sign-In Firebase console setup is a manual step documented in Phase 8

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2", "1.3", "1.4"] },
    { "id": 1, "tasks": ["2.1", "2.2", "2.3", "2.4", "2.5", "3.1", "3.2", "3.3", "3.4"] },
    { "id": 2, "tasks": ["5.1", "5.2", "5.3", "5.4", "5.5"] },
    { "id": 3, "tasks": ["6.1", "6.2", "6.3", "6.4"] },
    { "id": 4, "tasks": ["8.1", "8.2", "8.3", "8.4", "8.5", "8.6", "8.7", "8.8", "8.9", "8.10", "8.11", "8.12"] },
    { "id": 5, "tasks": ["10.1", "10.2", "10.3", "10.4"] },
    { "id": 6, "tasks": ["12.1"] }
  ]
}
```
