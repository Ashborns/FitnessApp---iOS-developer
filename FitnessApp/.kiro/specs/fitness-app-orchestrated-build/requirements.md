# Requirements Document

## Introduction

This specification defines the complete requirements for the FitnessApp, an iOS fitness tracking application built with SwiftUI. The app provides authentication, workout tracking, calorie management, body pose detection via camera, health data integration, and progress visualization. The implementation is organized into six logical domains (Setup, Auth, Data, UI, Tests, Polish) that follow a defined dependency order to enable orchestrated parallel development.

## Glossary

- **App_Shell**: The top-level application structure including the entry point, root view, tab navigation, and router
- **Auth_Manager**: The singleton responsible for all authentication operations including Firebase Auth and Google Sign-In
- **Persistence_Controller**: The CoreData stack manager providing shared and in-memory container configurations
- **HealthKit_Manager**: The singleton responsible for HealthKit authorization and active energy queries
- **Calorie_Goal_ViewModel**: The view model tracking daily calorie goals, consumed calories, and burned calories
- **Workout_Recommendation_Engine**: The rule-based engine that suggests workouts based on user profile and history
- **App_Router**: The shared navigation state object managing tab selection, sheet presentation, and deep links
- **Camera_ViewModel**: The view model managing AVFoundation camera session lifecycle
- **Vision_Body_Pose_Analyzer**: The component using Vision framework to detect human body poses from camera frames
- **Notification_Manager**: The component responsible for scheduling and managing local notifications
- **Keychain_Wrapper**: The utility for securely storing and retrieving authentication tokens via iOS Keychain
- **Design_System**: The set of color tokens, typography, and spacing constants defining the app's visual identity
- **Main_Tab_View**: The primary tab-based navigation container with five tabs (Home, Workout, Camera, Calories, Profile)

## Requirements

### Requirement 1: App Entry Point and Firebase Configuration

**User Story:** As a developer, I want the app entry point to configure Firebase and handle Google Sign-In URL callbacks, so that authentication services are available from launch.

#### Acceptance Criteria

1. WHEN the app launches, THE App_Shell SHALL call `FirebaseApp.configure()` in the App struct's initializer, before the `body` property is first evaluated
2. WHEN the app receives a URL callback via the SwiftUI `onOpenURL` modifier, THE App_Shell SHALL forward the URL to `GIDSignIn.sharedInstance.handle(_:)` and return the boolean result indicating whether the URL was consumed by the Google Sign-In handler
3. IF `FirebaseApp.configure()` or Google Sign-In URL handling fails silently (returns `false` or throws), THEN THE App_Shell SHALL leave the Auth_Manager in an unauthenticated state without crashing the app
4. THE App_Shell SHALL inject Auth_Manager and App_Router as `@StateObject` environment objects into the root SwiftUI view hierarchy using `.environmentObject()` so that all child views can access them
5. THE App_Shell SHALL use the SwiftUI app lifecycle (`@main struct` conforming to `App`) exclusively, without adopting `UIApplicationDelegate` or `@UIApplicationDelegateAdaptor`

### Requirement 2: Navigation and Tab System

**User Story:** As a user, I want a tab-based navigation system with five main sections, so that I can quickly access all app features.

#### Acceptance Criteria

1. THE App_Router SHALL maintain a published `selectedTab` property of an enum type with exactly five cases: home, workout, camera, calories, profile, with a default value of home on app launch
2. THE Main_Tab_View SHALL present exactly five tabs in this order: Home, Workout, Camera, Calories, Profile
3. WHEN the user taps the Camera tab, THE Main_Tab_View SHALL present the camera view as a `.fullScreenCover` without changing the `selectedTab` value from its previous state
4. WHEN the camera `.fullScreenCover` is dismissed, THE Main_Tab_View SHALL return the user to the previously selected tab
5. THE App_Router SHALL expose a published `showOnboarding` Boolean property that is set to true when the user has not completed onboarding and false after onboarding is completed
6. WHEN a deep link is received containing a valid tab identifier matching one of the five tab cases, THE App_Router SHALL update `selectedTab` to the corresponding tab within 0.5 seconds of receiving the link
7. IF a deep link is received with an unrecognized or invalid tab identifier, THEN THE App_Router SHALL retain the current `selectedTab` value unchanged

### Requirement 3: Root View Routing

**User Story:** As a user, I want the app to show me onboarding when I first launch and the main interface after I authenticate, so that I have a guided first experience.

#### Acceptance Criteria

1. WHILE `Auth_Manager.isAuthenticated` is false, THE Root_View SHALL display the Onboarding flow and SHALL NOT display the Main_Tab_View
2. WHILE `Auth_Manager.isAuthenticated` is true, THE Root_View SHALL display the Main_Tab_View and SHALL NOT display the Onboarding flow
3. WHEN the authentication state changes from false to true, THE Root_View SHALL transition from the Onboarding flow to the Main_Tab_View using an opacity crossfade animation lasting no longer than 0.35 seconds
4. WHEN the authentication state changes from true to false, THE Root_View SHALL transition from the Main_Tab_View to the Onboarding flow using an opacity crossfade animation lasting no longer than 0.35 seconds
5. WHILE `Auth_Manager` is evaluating the persisted authentication state at app launch, THE Root_View SHALL display a launch screen placeholder and SHALL NOT display the Onboarding flow or Main_Tab_View until the evaluation completes within 2 seconds

### Requirement 4: Firebase Authentication

**User Story:** As a user, I want to sign in with email/password or Google, so that my fitness data is securely linked to my account.

#### Acceptance Criteria

1. WHEN a user submits an email address that conforms to RFC 5322 format and a password of 6 to 128 characters, THE Auth_Manager SHALL authenticate the user via Firebase Auth and set `isAuthenticated` to true within 10 seconds
2. IF authentication fails due to invalid credentials, non-existent account, or network unavailability, THEN THE Auth_Manager SHALL set `errorMessage` to the Firebase-provided localized error description without modifying `isAuthenticated`
3. WHEN the user initiates Google Sign-In, THE Auth_Manager SHALL complete the OAuth flow using GoogleSignIn-iOS SDK v7.x and set `isAuthenticated` to true within 15 seconds
4. IF the user cancels the Google Sign-In flow or the OAuth token exchange fails, THEN THE Auth_Manager SHALL set `isAuthenticated` to false and set `errorMessage` to a non-nil error description indicating the failure reason
5. WHEN `signOut()` is called, THE Auth_Manager SHALL sign out from both Firebase Auth and Google Sign-In, set `isAuthenticated` to false, and set `currentUserID` to nil
6. THE Auth_Manager SHALL expose a `currentUserID` property containing the Firebase UID of the authenticated user, returning nil when no user is authenticated
7. THE Auth_Manager SHALL be a singleton accessible via `AuthManager.shared`
8. THE Auth_Manager SHALL publish `isAuthenticated`, `currentUserID`, and `errorMessage` on the `@MainActor`
9. WHEN the app launches and a previously authenticated Firebase session exists, THE Auth_Manager SHALL restore the session and set `isAuthenticated` to true without requiring user interaction

### Requirement 5: User Registration

**User Story:** As a new user, I want to create an account with email and password, so that I can start tracking my fitness.

#### Acceptance Criteria

1. WHEN a well-formed email address (conforming to standard email format with local part, "@", and domain) and a password of at least 6 characters are provided to `signUp`, THE Auth_Manager SHALL create a new Firebase Auth account, set `isAuthenticated` to true, and set `errorMessage` to nil
2. IF the email is already registered, THEN THE Auth_Manager SHALL set `isAuthenticated` to false and set `errorMessage` to a value indicating the account already exists
3. IF the password is fewer than 6 characters, THEN THE Auth_Manager SHALL set `isAuthenticated` to false and set `errorMessage` to a value indicating the minimum password length requirement
4. IF the email format is invalid (missing "@" symbol or domain), THEN THE Auth_Manager SHALL set `isAuthenticated` to false and set `errorMessage` to a value indicating the email format is not accepted
5. IF the Firebase service is unreachable during sign-up, THEN THE Auth_Manager SHALL set `isAuthenticated` to false and set `errorMessage` to a value indicating a network or service error

### Requirement 6: Secure Token Storage

**User Story:** As a user, I want my authentication tokens stored securely, so that my account cannot be compromised by other apps.

#### Acceptance Criteria

1. THE Keychain_Wrapper SHALL store authentication tokens in the iOS Keychain using `kSecClassGenericPassword` with the accessibility level `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
2. WHEN a token is saved, THE Keychain_Wrapper SHALL delete any existing token for the same key before inserting the new value and return a Boolean indicating whether the save succeeded
3. WHEN a token is requested, THE Keychain_Wrapper SHALL return the stored String value, or nil if no token exists for the given key or if the Keychain read operation fails
4. WHEN `delete` is called, THE Keychain_Wrapper SHALL remove the token for the given key from the Keychain and return a Boolean where true indicates the item was removed or did not exist
5. IF a save operation fails due to a Keychain error, THEN THE Keychain_Wrapper SHALL return false and leave the Keychain state unchanged for that key

### Requirement 7: Onboarding Flow

**User Story:** As a new user, I want a guided onboarding experience, so that I understand the app's features before signing in.

#### Acceptance Criteria

1. THE Onboarding_View SHALL present a 3-screen walkthrough where the user can swipe horizontally or tap a "Next" button to advance between screens
2. WHEN the user taps the action button on the final onboarding screen, THE Onboarding_View SHALL navigate to the Login view and persist onboarding completion so the walkthrough is not shown on subsequent app launches
3. THE Onboarding_View SHALL include accessibility identifiers: "onboarding-welcome", "onboarding-auth", "onboarding-profile"
4. THE Login_View SHALL include accessibility identifiers: "login-email-field", "login-password-field", "login-submit-btn"
5. THE Onboarding_View SHALL display a "Skip" button on each screen that navigates directly to the Login view and persists onboarding completion

### Requirement 8: CoreData Persistence Stack

**User Story:** As a developer, I want a CoreData stack with defined entities, so that user fitness data persists across sessions.

#### Acceptance Criteria

1. THE Persistence_Controller SHALL provide a shared singleton instance with a persistent `NSPersistentContainer` that loads persistent stores on initialization and sets `automaticallyMergesChangesFromParent` to true on the viewContext
2. THE Persistence_Controller SHALL provide an in-memory configuration via a static `preview` property that stores data to `/dev/null` for unit testing and SwiftUI previews
3. THE Persistence_Controller SHALL define four entities: UserProfile, WorkoutLog, DailyGoal, CalorieEntry
4. THE UserProfile entity SHALL store: id (UUID, required), firebaseUID (String, max 128 characters), email (String, max 254 characters), displayName (String, optional, max 100 characters), dailyCalorieGoal (Double, default 2000), createdAt (Date, set on creation)
5. THE WorkoutLog entity SHALL store: id (UUID), date (Date), workoutType (String, max 50 characters), durationMinutes (Double, range 0.0 to 1440.0), caloriesBurned (Double, range 0.0 to 99999.0), formScore (Double, range 0.0 to 1.0), notes (String, optional, max 500 characters), and a many-to-one relationship to UserProfile
6. THE DailyGoal entity SHALL store: id (UUID), date (Date), calorieGoal (Double, range 0.0 to 99999.0), caloriesBurned (Double, range 0.0 to 99999.0), isCompleted (Boolean), and a many-to-one relationship to UserProfile
7. THE CalorieEntry entity SHALL store: id (UUID), date (Date), amount (Double, range 0.0 to 99999.0), source (String, constrained to "manual" or "healthkit"), label (String, max 100 characters), and a many-to-one relationship to UserProfile
8. IF the persistent store fails to load, THEN THE Persistence_Controller SHALL trigger a fatalError in DEBUG builds and log the error without crashing in release builds
9. WHEN the Persistence_Controller `save()` method is called, THE Persistence_Controller SHALL persist changes to the viewContext only if the context has unsaved changes, and SHALL log an error without crashing if the save operation fails
10. THE Persistence_Controller SHALL set the viewContext mergePolicy to `NSMergeByPropertyObjectTrumpMergePolicy` to resolve conflicts when merging changes from background contexts

### Requirement 9: HealthKit Integration

**User Story:** As a user, I want the app to read my active energy data from Apple Health, so that burned calories are tracked automatically.

#### Acceptance Criteria

1. WHEN `requestAuthorization` is called, THE HealthKit_Manager SHALL verify that HealthKit is available on the device and request read access to active energy burned from HealthKit
2. IF HealthKit is not available on the device, THEN THE HealthKit_Manager SHALL throw a `notAvailable` error without requesting authorization
3. IF HealthKit authorization is denied, THEN THE HealthKit_Manager SHALL throw an `unauthorized` error and not attempt data queries
4. WHEN `fetchTodayActiveEnergy` is called, THE HealthKit_Manager SHALL query HealthKit for today's cumulative active energy burned in kilocalories from the start of the current calendar day to the current time and return the result as a Double value defaulting to 0 when no samples exist
5. IF the HealthKit query fails, THEN THE HealthKit_Manager SHALL throw a `queryFailed` error containing the underlying error
6. WHEN `fetchTodayActiveEnergy` completes successfully, THE HealthKit_Manager SHALL update the published `activeEnergyBurned` property on the `@MainActor`
7. WHILE HealthKit authorization status is not determined, THE HealthKit_Manager SHALL not execute any health data queries and SHALL throw an `unauthorized` error if a query is attempted

### Requirement 10: Calorie Goal Tracking

**User Story:** As a user, I want to set daily calorie goals and log food entries, so that I can monitor my nutrition.

#### Acceptance Criteria

1. THE Calorie_Goal_ViewModel SHALL expose published properties: `dailyGoal` (valid range: 500 to 10,000 kcal), `consumed`, `burned`
2. WHEN `saveEntry` is called with a calorie amount between 1 and 99,999 kcal and a label of 1 to 100 characters, THE Calorie_Goal_ViewModel SHALL persist a new CalorieEntry to CoreData with the current date and source set to "manual"
3. IF `saveEntry` is called with a calorie amount outside 1–99,999 kcal or a label that is empty or exceeds 100 characters, THEN THE Calorie_Goal_ViewModel SHALL not persist the entry and SHALL publish a validation error message indicating the invalid field
4. WHEN the view appears, THE Calorie_Goal_ViewModel SHALL load all CalorieEntry records with a date within the current calendar day (midnight to midnight in the device's local timezone) and compute `consumed` as the sum of their amounts
5. THE Calorie_Goal_ViewModel SHALL integrate with HealthKit_Manager to populate the `burned` value with today's active energy total
6. IF HealthKit authorization is denied or HealthKit data is unavailable, THEN THE Calorie_Goal_ViewModel SHALL set `burned` to 0 and SHALL publish an informational message indicating that burned calorie data is unavailable
7. IF CoreData persistence fails when saving an entry, THEN THE Calorie_Goal_ViewModel SHALL publish an error message indicating the save failure and SHALL not update the `consumed` total
8. THE Calorie_Goal_ViewModel SHALL publish all properties on the `@MainActor`

### Requirement 11: Workout Recommendation Engine

**User Story:** As a user, I want personalized workout suggestions based on my history, so that I stay motivated with varied routines.

#### Acceptance Criteria

1. THE Workout_Recommendation_Engine SHALL generate a list of 3 to 5 workout suggestions using rule-based logic (no machine learning), where each suggestion includes a workout type and a suggested duration in minutes
2. WHEN the user has completed a workout type within the last 7 days, THE Workout_Recommendation_Engine SHALL rank that type lower than types not completed in the last 7 days
3. IF the user's remaining calorie deficit for the day is greater than zero, THEN THE Workout_Recommendation_Engine SHALL suggest workouts with durations scaled proportionally to the remaining deficit, up to a maximum of 60 minutes per suggestion
4. WHEN no workout history exists for the user, THE Workout_Recommendation_Engine SHALL return a default set of 3 beginner-friendly workouts each with a suggested duration of 20 minutes or less
5. IF all available workout types have been completed within the last 7 days, THEN THE Workout_Recommendation_Engine SHALL still return suggestions by selecting the least recently performed types first

### Requirement 12: Premium Dark-Mode Design System

**User Story:** As a user, I want a visually polished dark-mode interface, so that the app is comfortable to use during workouts in any lighting.

#### Acceptance Criteria

1. THE Design_System SHALL define color tokens in `Color+Theme.swift` as adaptive SwiftUI `Color` values that resolve to distinct light and dark appearance variants
2. THE Design_System SHALL provide semantic colors for: primary, secondary, background, surface, error, and accent, where each semantic color meets a minimum WCAG AA contrast ratio of 4.5:1 against its intended background color in both appearances
3. THE Design_System SHALL use built-in SwiftUI text styles (e.g., `.body`, `.headline`, `.caption`) for all text elements so that text scales with the user's Dynamic Type setting without truncation or clipping at sizes up to AX5
4. THE Design_System SHALL define a named set of at least 4 spacing tokens (e.g., small, medium, large, extraLarge) and at least 2 corner radius tokens, each with fixed point values, used consistently across all feature views
5. IF the system appearance changes at runtime, THEN THE Design_System SHALL update all rendered colors without requiring an app restart or manual view refresh

### Requirement 13: Camera Feed with Body Pose Detection

**User Story:** As a user, I want to see my body pose overlaid on the camera feed, so that I can check my exercise form in real time.

#### Acceptance Criteria

1. WHEN the camera tab is activated, THE Camera_ViewModel SHALL request camera permission if not yet determined, and upon authorization start an AVCaptureSession with the rear camera at `.high` session preset
2. WHEN camera frames are received, THE Vision_Body_Pose_Analyzer SHALL run `VNDetectHumanBodyPoseRequest` on every 4th frame to maintain real-time performance
3. WHEN body pose points are detected with a confidence of 0.5 or higher, THE Camera_Feed_View SHALL overlay the recognized joint positions on the live camera preview
4. IF camera permission is denied or restricted, THEN THE Camera_Feed_View SHALL display a message indicating camera access is required and provide a button that opens the iOS Settings app
5. WHEN the camera view is dismissed, THE Camera_ViewModel SHALL stop the AVCaptureSession and release the capture inputs and outputs
6. IF no human body is detected in the current processed frame, THEN THE Camera_Feed_View SHALL hide any previously displayed joint overlay

### Requirement 14: Feature Screens

**User Story:** As a user, I want dedicated screens for Home, Calories, Workouts, and Profile, so that I can manage all aspects of my fitness.

#### Acceptance Criteria

1. THE Home_View SHALL display a dashboard with today's calorie summary (consumed and goal values), the 3 most recent workouts, and quick-action buttons for logging a calorie entry and starting a workout
2. THE Home_View SHALL include the accessibility identifier "home-root"
3. THE Calorie_Goal_View SHALL display a circular progress indicator showing consumed vs. goal calories, with the numeric consumed and goal values visible as text
4. THE Workout_View SHALL display recommended workouts from the Workout_Recommendation_Engine and a scrollable log of the 10 most recent past sessions showing type, duration, and date
5. THE Profile_View SHALL display the user's displayName and email, a navigation link to Notification_Settings_View, and a sign-out button
6. WHEN the sign-out button is tapped in Profile_View, THE Profile_View SHALL call `Auth_Manager.signOut()`
7. THE Calorie_Goal_View SHALL include the accessibility identifier "calorie-goal-root", THE Workout_View SHALL include "workout-root", and THE Profile_View SHALL include "profile-root"
8. IF no data is available for a screen section (no workouts logged, no calorie entries, or no goal set), THEN THE respective view SHALL display an empty-state message indicating how to add data

### Requirement 15: UI Animations and Accessibility

**User Story:** As a user, I want smooth micro-animations and full accessibility support, so that the app feels polished and is usable by everyone.

#### Acceptance Criteria

1. WHEN a Feature_Screen transitions between loading, success, or error states, THE Feature_Screen SHALL animate the transition using opacity or scale effects with a duration between 200 and 400 milliseconds
2. THE Feature_Screens SHALL include accessibility identifiers on all interactive elements for UI testing, following the naming pattern "{screen}-{element}" (e.g., "home-calorie-ring", "profile-signout-btn")
3. THE Feature_Screens SHALL support Dynamic Type scaling from xSmall through AX5 sizes without text truncation, overlapping elements, or content clipped outside the visible area
4. THE Feature_Screens SHALL support VoiceOver by providing accessibility labels on all controls that describe the control's purpose or action (e.g., "Add calorie entry" not "Plus button")
5. IF the user has enabled Reduce Motion in iOS accessibility settings, THEN THE Feature_Screens SHALL replace animated transitions with immediate state changes or simple cross-dissolves

### Requirement 16: Unit Test Coverage

**User Story:** As a developer, I want comprehensive unit tests for core logic, so that regressions are caught before release.

#### Acceptance Criteria

1. THE Test_Suite SHALL include unit tests for Auth_Manager covering both success and failure paths for: signIn, signUp, signInWithGoogle, signOut, with a minimum of 2 test cases per method (one success, one failure)
2. THE Test_Suite SHALL include unit tests for HealthKit_Manager covering: authorization granted, authorization denied, and energy query returning cumulative kilocalories, with mocked HealthKit store
3. THE Test_Suite SHALL include unit tests for Calorie_Goal_ViewModel covering: persisting a new CalorieEntry, computing the consumed total from today's entries, and verifying burned value integrates with HealthKit_Manager
4. THE Test_Suite SHALL include unit tests for Workout_Recommendation_Engine covering: deprioritization of recently completed workout types, calorie-deficit-based intensity selection, and returning default beginner-friendly workouts when no history exists
5. THE Test_Suite SHALL use in-memory CoreData configurations for all data layer tests to ensure no persistent side effects between test runs
6. THE Test_Suite SHALL use XCTest exclusively with no third-party test frameworks
7. WHILE running tests, THE Test_Suite SHALL use mocked HealthKit responses instead of live HealthKit queries
8. THE Test_Suite SHALL ensure each test case is independent and does not rely on execution order or shared mutable state from other tests

### Requirement 17: Test Coverage Thresholds

**User Story:** As a developer, I want defined coverage thresholds, so that critical code paths are verified.

#### Acceptance Criteria

1. THE Test_Suite SHALL achieve a minimum of 80% line coverage for all ViewModel classes (Calorie_Goal_ViewModel, Camera_ViewModel, Home_ViewModel)
2. THE Test_Suite SHALL achieve a minimum of 90% line coverage for the data layer classes (Persistence_Controller, HealthKit_Manager)
3. THE Test_Suite SHALL include UI tests covering the onboarding happy path flow from the welcome screen through authentication to the Home screen, verifying navigation through each screen identified by accessibility identifiers "onboarding-welcome", "onboarding-auth", and "home-root"
4. THE Test_Suite SHALL measure code coverage using Xcode's built-in code coverage tool with results verified per target after each test run

### Requirement 18: Progress and History Visualization

**User Story:** As a user, I want to see my calorie trends and workout history in charts, so that I can track my progress over time.

#### Acceptance Criteria

1. THE Progress_View SHALL display calorie intake trends using Swift Charts, aggregated as daily totals, over a user-selectable time range of 7 days, 30 days, or 90 days (defaulting to 7 days)
2. THE Progress_View SHALL display workout history as a list showing duration and calories burned per session for up to 50 most recent sessions within the selected time range
3. THE Progress_View SHALL be accessible from within the Home tab as a navigation destination
4. WHEN no history data exists for the selected time range, THE Progress_View SHALL display an empty state message explaining that data will appear after the user logs calorie entries or workouts
5. WHEN the user changes the selected time range, THE Progress_View SHALL reload and display chart data corresponding to the newly selected range within 1 second

### Requirement 19: Local Notification System

**User Story:** As a user, I want workout and goal reminders, so that I stay consistent with my fitness routine.

#### Acceptance Criteria

1. THE Notification_Manager SHALL schedule a daily local notification for workout reminders at the user-configured time, defaulting to 08:00 local time if no time is configured
2. THE Notification_Manager SHALL schedule a daily local notification for goal reminders at the user-configured time, defaulting to 20:00 local time if no time is configured
3. WHEN the user disables a reminder category, THE Notification_Manager SHALL cancel all pending notifications of that category within 1 second
4. IF notification permission is not granted, THEN THE Notification_Manager SHALL request permission and, upon denial, disable reminder scheduling and display a message indicating that notifications are unavailable until permission is granted in Settings
5. THE Notification_Settings_View SHALL provide toggles for enabling/disabling workout reminders and goal reminders, with both toggles defaulting to disabled on first launch
6. WHEN the user changes a reminder time, THE Notification_Manager SHALL cancel the existing scheduled notification for that category and schedule a new notification at the updated time
7. IF notification permission has been previously denied at the system level, THEN THE Notification_Settings_View SHALL display a prompt directing the user to the iOS Settings app to enable notifications

### Requirement 20: App Store Readiness

**User Story:** As a developer, I want the app to meet App Store submission requirements, so that it can be published without rejection.

#### Acceptance Criteria

1. THE App SHALL include a 1024×1024 pixel PNG app icon assigned in Assets.xcassets/AppIcon.appiconset with no transparency and no alpha channel
2. THE App SHALL include a launch screen defined via a LaunchScreen storyboard or Info.plist launch screen configuration that displays the app name or logo
3. THE App SHALL include the following Info.plist privacy usage description strings, each containing a non-generic sentence explaining why the permission is needed: NSCameraUsageDescription, NSHealthShareUsageDescription, NSHealthUpdateUsageDescription, NSMotionUsageDescription
4. THE App SHALL compile with zero warnings in project-owned source files using Xcode 14.x or later with iOS 16.4 deployment target
5. THE App SHALL define CFBundleDisplayName, CFBundleShortVersionString (format: major.minor.patch), and CFBundleVersion (integer build number) in Info.plist
6. IF the ITSAppUsesNonExemptEncryption key is not set, THEN THE App SHALL set ITSAppUsesNonExemptEncryption to false in Info.plist to avoid export compliance prompts during review

### Requirement 21: Technical Constraints Compliance

**User Story:** As a developer, I want all code to follow strict technical constraints, so that the codebase is safe, consistent, and maintainable.

#### Acceptance Criteria

1. THE App SHALL target iOS 16.4 as the minimum deployment version and not use APIs introduced after iOS 16.4
2. THE App SHALL use SwiftUI app lifecycle exclusively without UIApplicationDelegate, except that UIViewRepresentable or UIViewControllerRepresentable wrappers are permitted solely for AVFoundation camera integration
3. THE App SHALL use CoreData for persistence and not use SwiftData
4. THE App SHALL contain zero force unwraps (`!`) in production code (all Swift files in the main app target, excluding test targets)
5. THE App SHALL annotate all `@Published` properties with `@MainActor` at the enclosing class level or use `DispatchQueue.main` dispatch for every published property mutation
6. THE App SHALL use Swift 5.7 language features only and set the Swift language version to 5.7 in the Xcode project build settings
7. THE App SHALL use Firebase Auth with GoogleSignIn-iOS SDK v7.x for authentication
8. THE App SHALL use `Result<T, Error>` or `throws` for all fallible operations and not silently discard errors

### Requirement 22: Orchestrated Build Order

**User Story:** As a developer, I want a defined dependency order between implementation domains, so that parallel work proceeds without conflicts.

#### Acceptance Criteria

1. THE Build_Orchestration SHALL execute domain 0 (Setup) first with no dependencies
2. WHEN all files owned by domain 0 (Setup) are marked ✅ STABLE in SHARED_STATE.md, THE Build_Orchestration SHALL execute domain 1 (Auth) and domain 3 (UI first pass) in parallel
3. WHEN AuthManager.swift from domain 1 is marked ✅ STABLE in SHARED_STATE.md, THE Build_Orchestration SHALL execute domain 2 (Data)
4. WHEN all 4 CoreData model files (UserProfile+CoreData, WorkoutLog+CoreData, DailyGoal+CoreData, CalorieEntry+CoreData) from domain 2 are marked ✅ STABLE in SHARED_STATE.md, THE Build_Orchestration SHALL execute domain 3 (UI second pass) to connect real data to views
5. WHEN any individual file is marked ✅ STABLE in SHARED_STATE.md, THE Build_Orchestration SHALL permit domain 4 (Tests) to execute tests targeting that specific file
6. WHEN all files owned by domains 0, 1, 2, and 3 are marked ✅ STABLE in SHARED_STATE.md, THE Build_Orchestration SHALL execute domain 5 (Polish)
7. IF a domain attempts to execute before all of its required dependencies are marked ✅ STABLE, THEN THE Build_Orchestration SHALL block that domain's execution and set its files to ❌ BLOCKED status in SHARED_STATE.md
8. THE Build_Orchestration SHALL treat a file as ✅ STABLE only when both conditions are met: the AGENT-STABLE marker comment is present at the top of the Swift file, and the corresponding row in SHARED_STATE.md shows ✅ STABLE
