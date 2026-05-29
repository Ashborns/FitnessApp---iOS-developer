# FitnessApp — AI Agent Instructions

## Project Identity
- **App Name**: FitnessApp
- **Bundle ID prefix**: com.yourteam.FitnessApp
- **Xcode project**: FitnessApp.xcodeproj

## Constraints (NON-NEGOTIABLE)
- iOS deployment target: **16.4 minimum**
- Xcode: 14.0 compatible
- Swift: 5.7 — **no Swift 6 strict concurrency**
- SwiftUI lifecycle only (no UIKit unless AVFoundation requires it)
- CoreData for persistence (**NOT SwiftData** — SwiftData requires iOS 17)
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

## Multi-Agent Protocol
> See `AGENTS.md` for full agent roster and SUBAGENTS_GUIDE.md for parallel workflow.

- Each agent owns a specific feature zone — **do not cross zone boundaries**
- Declare files stable with `// AGENT-STABLE: <feature>` at the top
- Never modify a file marked `AGENT-STABLE` without writing a coordination comment at the top
- Before starting any task, read `AGENTS.md` to find your assigned zone and dependencies
- Check `AGENT_STATE.md` (auto-generated) to see what other agents have completed

## File Ownership Summary
| Zone          | Owner   | Key Files                                      |
|---------------|---------|------------------------------------------------|
| Auth          | Agent 1 | AuthManager, LoginView, SignUpView, Onboarding |
| Health + Data | Agent 2 | HealthKitManager, PersistenceController, CoreData models |
| UI + Vision   | Agent 3 | All main views, CameraFeedView, VisionBodyPoseAnalyzer |
| Tests         | Agent 4 | All XCTest files across all zones              |
