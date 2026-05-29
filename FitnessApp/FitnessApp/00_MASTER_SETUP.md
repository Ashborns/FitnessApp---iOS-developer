# iOS FitnessApp — Master Workspace Setup Prompt
# Paste this entire file into your AI agent (Windsurf / Antigravity / etc.)
# This will scaffold the full project structure, CLAUDE.md, AGENTS.md, and all skill files.

---

## YOUR TASK

You are setting up a new iOS project workspace from scratch. Follow every step in order.
Do not skip steps. Do not ask for confirmation between steps — execute all of them.

---

## STEP 1 — Create Xcode Project Structure

Create the following folder structure inside the project root.
If an Xcode project does not exist yet, scaffold the folder layout manually;
the developer will open Xcode and create the `.xcodeproj` targeting iOS 16.4 separately.

```
FitnessApp/
├── CLAUDE.md                        ← root AI instruction file
├── AGENTS.md                        ← root agent coordination file
├── .skills/                         ← all agent skill files live here
│   ├── swiftui-standards.md
│   ├── healthkit-privacy.md
│   ├── coredata-models.md
│   ├── firebase-auth.md
│   ├── vision-coreml.md
│   └── appstore-checklist.md
├── FitnessApp/
│   ├── App/
│   │   └── FitnessAppApp.swift
│   ├── Features/
│   │   ├── Auth/
│   │   │   ├── AuthManager.swift
│   │   │   ├── LoginView.swift
│   │   │   ├── SignUpView.swift
│   │   │   └── OnboardingView.swift
│   │   ├── Home/
│   │   │   ├── HomeView.swift
│   │   │   └── HomeViewModel.swift
│   │   ├── Calories/
│   │   │   ├── CalorieGoalView.swift
│   │   │   └── CalorieGoalViewModel.swift
│   │   ├── Workout/
│   │   │   ├── WorkoutView.swift
│   │   │   ├── WorkoutViewModel.swift
│   │   │   └── WorkoutRecommendationEngine.swift
│   │   ├── Camera/
│   │   │   ├── CameraFeedView.swift
│   │   │   ├── CameraViewModel.swift
│   │   │   └── VisionBodyPoseAnalyzer.swift
│   │   └── Profile/
│   │       ├── ProfileView.swift
│   │       └── ProfileViewModel.swift
│   ├── Core/
│   │   ├── Data/
│   │   │   ├── FitnessApp.xcdatamodeld/   ← CoreData model
│   │   │   ├── PersistenceController.swift
│   │   │   └── Models/
│   │   │       ├── UserProfile+CoreData.swift
│   │   │       ├── WorkoutLog+CoreData.swift
│   │   │       ├── DailyGoal+CoreData.swift
│   │   │       └── CalorieEntry+CoreData.swift
│   │   ├── Health/
│   │   │   └── HealthKitManager.swift
│   │   ├── Keychain/
│   │   │   └── KeychainWrapper.swift
│   │   └── Extensions/
│   │       └── Color+Theme.swift
│   ├── Resources/
│   │   ├── Assets.xcassets/
│   │   └── Info.plist
│   └── Supporting Files/
│       └── GoogleService-Info.plist   ← placeholder, fill after Firebase setup
├── FitnessAppTests/
│   ├── Auth/
│   │   └── AuthManagerTests.swift
│   ├── Calories/
│   │   └── CalorieGoalViewModelTests.swift
│   ├── Workout/
│   │   └── WorkoutRecommendationEngineTests.swift
│   └── Health/
│       └── HealthKitManagerTests.swift
└── FitnessAppUITests/
    └── OnboardingUITests.swift
```

---

## STEP 2 — Write CLAUDE.md

Create `CLAUDE.md` at the project root with the following content exactly:

```markdown
# FitnessApp — AI Agent Instructions

## Constraints (NON-NEGOTIABLE)
- iOS deployment target: 16.4 minimum
- Xcode: 14.0 compatible
- Swift: 5.7 — no Swift 6 strict concurrency
- SwiftUI lifecycle only (no UIKit unless AVFoundation requires it)
- CoreData for persistence (NOT SwiftData — SwiftData requires iOS 17)
- Never use any API introduced after iOS 16.4
- Verify every new API at: https://developer.apple.com/documentation

## Skills (read before starting any task)
All skills live in `.skills/`. Read the relevant skill file BEFORE writing code.

| Task domain              | Read this skill file              |
|--------------------------|-----------------------------------|
| Any SwiftUI view         | .skills/swiftui-standards.md      |
| HealthKit / Apple Health | .skills/healthkit-privacy.md      |
| CoreData models          | .skills/coredata-models.md        |
| Auth / Firebase / Google | .skills/firebase-auth.md          |
| Camera / Vision / CoreML | .skills/vision-coreml.md          |
| App Store prep           | .skills/appstore-checklist.md     |
| SwiftUI patterns (ext.)  | .skills/swiftui-pro/ (if installed via npx) |

## Code Standards
- Naming: `FeatureNameView.swift`, `FeatureNameViewModel.swift`
- No force unwraps (`!`) in production code
- Use `Result<T, Error>` or `throws` — no silent failures
- All @Published properties on MainActor or dispatched to main thread
- HealthKit: always check authorization status before any HKQuery
- Privacy: every camera/health/motion usage must have a plist description string

## Test Requirements
- ViewModels: 80% minimum coverage
- Data layer (CoreData, HealthKit): 90% minimum
- Write tests BEFORE merging any ViewModel or data layer change
- Use XCTest — no third-party test frameworks

## Agent Handoff Protocol
- Agent 1 must commit `AuthManager.swift` as stable before Agent 2 reads user identity
- Agent 2 must commit CoreData models as stable before Agent 3 builds Progress screen
- Use `// AGENT-STABLE: <feature>` comment marker on any file declared stable
- Never modify a file marked AGENT-STABLE without announcing it in a comment at the top
```

---

## STEP 3 — Write AGENTS.md

Create `AGENTS.md` at the project root:

```markdown
# FitnessApp — Agent Coordination

## Agent Roster

### Agent 1 — Auth & Foundation
Trigger: Start here. No dependencies.
Skill files to read: .skills/firebase-auth.md, .skills/swiftui-standards.md
Owns:
  - Firebase project setup (console + GoogleService-Info.plist)
  - Google Sign-In SDK integration (GoogleSignIn-iOS, iOS 16.4 compatible)
  - Email/password auth (Firebase Auth)
  - Password reset flow
  - KeychainWrapper for token storage
  - Onboarding SwiftUI flow (3 screens: welcome, auth choice, profile setup)
  - AuthManager singleton (@Published session state)
Deliverables (mark AGENT-STABLE when done):
  - AuthManager.swift
  - LoginView.swift + SignUpView.swift
  - OnboardingView.swift
  - KeychainWrapper.swift
  - AuthManagerTests.swift (80% coverage)
Do NOT touch: HealthKit, CoreData, camera.

### Agent 2 — Health & Data Layer
Trigger: Start after AuthManager.swift is marked AGENT-STABLE.
Skill files to read: .skills/healthkit-privacy.md, .skills/coredata-models.md
Owns:
  - HealthKitManager (authorization request, HKStatisticsQuery for active energy)
  - CoreData stack (PersistenceController, all 4 models)
  - CalorieGoalViewModel
  - WorkoutRecommendationEngine (rule-based logic, no ML here)
  - DailyGoal tracking
Deliverables (mark AGENT-STABLE when done):
  - PersistenceController.swift
  - All CoreData model files (4 entities)
  - HealthKitManager.swift
  - CalorieGoalViewModel.swift
  - WorkoutRecommendationEngine.swift
  - All corresponding test files (90% data layer, 80% ViewModels)
Do NOT touch: Auth, camera, Vision framework.

### Agent 3 — Vision, ML & UI
Trigger: Start after CoreData models are marked AGENT-STABLE.
Skill files to read: .skills/vision-coreml.md, .skills/swiftui-standards.md, .skills/appstore-checklist.md
Owns:
  - CameraFeedView (AVFoundation + SwiftUI, iOS 16.4)
  - VisionBodyPoseAnalyzer (VNDetectHumanBodyPoseRequest)
  - CoreML model integration (.mlmodel placeholder if no model provided)
  - All main SwiftUI screens: Home, Workout, Progress, Profile
  - App Store readiness: privacy strings, entitlements audit, screenshot dimensions
Deliverables:
  - CameraFeedView.swift + CameraViewModel.swift
  - VisionBodyPoseAnalyzer.swift
  - All main screen views + viewmodels
  - Info.plist privacy strings (complete)
  - App Store submission checklist (filled out)
Do NOT touch: AuthManager, CoreData schema.

## Handoff Markers
When a file is stable and ready for other agents to depend on, add this comment at the top:
// AGENT-STABLE: AuthManager — do not modify without coordination
```

---

## STEP 4 — Install External Skill

Run this in terminal from the project root:

```bash
# Ensure Node is installed
brew install node

# Install twostraws SwiftUI Pro skill
npx skills add https://github.com/twostraws/swiftui-agent-skill --skill swiftui-pro

# This installs into .skills/swiftui-pro/
# NOTE: This skill targets iOS 26+. Use as pattern reference only.
# Always verify iOS 16.4 availability before applying any suggestion from it.
```

---

## STEP 5 — Create all 6 custom skill files

Read and create each file from the `/skills/` folder provided alongside this prompt.
File list:
- `.skills/swiftui-standards.md`
- `.skills/healthkit-privacy.md`
- `.skills/coredata-models.md`
- `.skills/firebase-auth.md`
- `.skills/vision-coreml.md`
- `.skills/appstore-checklist.md`

---

## STEP 6 — Create stub Swift files

Create the following stub files so Xcode compiles with no errors from day one.
Each file should contain only: import statement + empty struct/class with a TODO comment.

Files to stub:
- FitnessApp/App/FitnessAppApp.swift
- FitnessApp/Core/Data/PersistenceController.swift
- FitnessApp/Core/Health/HealthKitManager.swift
- FitnessApp/Core/Keychain/KeychainWrapper.swift
- FitnessApp/Features/Auth/AuthManager.swift
- FitnessApp/Features/Auth/LoginView.swift
- FitnessApp/Features/Auth/SignUpView.swift
- FitnessApp/Features/Auth/OnboardingView.swift
- FitnessApp/Features/Home/HomeView.swift
- FitnessApp/Features/Home/HomeViewModel.swift
- FitnessApp/Features/Calories/CalorieGoalView.swift
- FitnessApp/Features/Calories/CalorieGoalViewModel.swift
- FitnessApp/Features/Workout/WorkoutView.swift
- FitnessApp/Features/Workout/WorkoutViewModel.swift
- FitnessApp/Features/Workout/WorkoutRecommendationEngine.swift
- FitnessApp/Features/Camera/CameraFeedView.swift
- FitnessApp/Features/Camera/CameraViewModel.swift
- FitnessApp/Features/Camera/VisionBodyPoseAnalyzer.swift
- FitnessApp/Features/Profile/ProfileView.swift
- FitnessApp/Features/Profile/ProfileViewModel.swift

---

## STEP 7 — Info.plist Privacy Strings

Add the following keys to `FitnessApp/Resources/Info.plist`.
Do not remove any existing keys.

```xml
<key>NSHealthShareUsageDescription</key>
<string>FitnessApp reads your active energy and workout data to track your daily calorie progress.</string>

<key>NSHealthUpdateUsageDescription</key>
<string>FitnessApp saves workout sessions to Apple Health to keep your data in sync.</string>

<key>NSCameraUsageDescription</key>
<string>FitnessApp uses your camera to analyze your exercise form and provide real-time feedback.</string>

<key>NSMotionUsageDescription</key>
<string>FitnessApp uses motion data to improve workout detection accuracy.</string>
```

---

## STEP 8 — Confirm Setup

After completing all steps, output a checklist confirming:
- [ ] Folder structure created
- [ ] CLAUDE.md written
- [ ] AGENTS.md written
- [ ] 6 skill files created in .skills/
- [ ] External swiftui-pro skill installed (or installation command printed if Node unavailable)
- [ ] All stub Swift files created
- [ ] Info.plist privacy strings added

If any step failed, explain why and what the developer needs to do manually.
