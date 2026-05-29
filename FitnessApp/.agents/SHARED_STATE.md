# FitnessApp — Shared Agent State Board
# This is the shared whiteboard. All agents read and write here.
# To update: change ⬜/🔄/❌ to ✅ when a file is complete.
# Last updated: 2026-05-08

---

## How to Use This File (for Agents)
1. Find the file you are working on
2. Change its status to `🔄 IN PROGRESS` when you start, `✅ STABLE` when done
3. Check the dependency status of other agents before starting blocked tasks

---

## Agent 0 — Project Setup & App Shell

| File | Status | Date Stable | Notes |
|------|--------|-------------|-------|
| `FitnessApp/Core/Navigation/AppRouter.swift` | ⬜ TODO | — | Run first |
| `FitnessApp/App/FitnessAppApp.swift` | ⬜ TODO | — | |
| `FitnessApp/App/RootView.swift` | ⬜ TODO | — | |
| `FitnessApp/App/MainTabView.swift` | ⬜ TODO | — | |
| `FitnessApp/Resources/Info.plist` (URL scheme) | ⬜ TODO | — | |

**→ All other agents can start after Agent 0 is ✅ (or run in parallel with stubs)**

---

## Legend
| Symbol | Meaning |
|--------|---------|
| ⬜ TODO | Not started |
| 🔄 IN PROGRESS | An agent is actively working on this |
| ✅ STABLE | Complete, marked AGENT-STABLE, safe to depend on |
| ❌ BLOCKED | Waiting on a dependency from another agent |

---

## Agent 1 — Auth & Foundation

| File | Status | Date Stable | Notes |
|------|--------|-------------|-------|
| `FitnessApp/Features/Auth/AuthManager.swift` | ⬜ TODO | — | |
| `FitnessApp/Features/Auth/LoginView.swift` | ⬜ TODO | — | |
| `FitnessApp/Features/Auth/SignUpView.swift` | ⬜ TODO | — | |
| `FitnessApp/Features/Auth/OnboardingView.swift` | ⬜ TODO | — | |
| `FitnessApp/Core/Keychain/KeychainWrapper.swift` | ⬜ TODO | — | |
| `FitnessAppTests/Auth/AuthManagerTests.swift` | ⬜ TODO | — | |

**→ Agent 2 can start when**: `AuthManager.swift` = ✅ STABLE

---

## Agent 2 — Health & Data Layer

| File | Status | Date Stable | Notes |
|------|--------|-------------|-------|
| `FitnessApp/Core/Data/PersistenceController.swift` | ❌ BLOCKED | — | Needs AuthManager ✅ |
| `FitnessApp/Core/Data/Models/UserProfile+CoreData.swift` | ❌ BLOCKED | — | |
| `FitnessApp/Core/Data/Models/WorkoutLog+CoreData.swift` | ❌ BLOCKED | — | |
| `FitnessApp/Core/Data/Models/DailyGoal+CoreData.swift` | ❌ BLOCKED | — | |
| `FitnessApp/Core/Data/Models/CalorieEntry+CoreData.swift` | ❌ BLOCKED | — | |
| `FitnessApp/Core/Health/HealthKitManager.swift` | ❌ BLOCKED | — | |
| `FitnessApp/Features/Calories/CalorieGoalViewModel.swift` | ❌ BLOCKED | — | |
| `FitnessApp/Features/Workout/WorkoutRecommendationEngine.swift` | ❌ BLOCKED | — | |
| `FitnessAppTests/Health/HealthKitManagerTests.swift` | ❌ BLOCKED | — | |
| `FitnessAppTests/Calories/CalorieGoalViewModelTests.swift` | ❌ BLOCKED | — | |

**→ Agent 3 can connect real data when**: all CoreData Models = ✅ STABLE

---

## Agent 3 — Vision, ML & UI Screens

| File | Status | Date Stable | Notes |
|------|--------|-------------|-------|
| `FitnessApp/Core/Extensions/Color+Theme.swift` | ⬜ TODO | — | Can start immediately |
| `FitnessApp/Features/Camera/CameraFeedView.swift` | ⬜ TODO | — | Can start immediately |
| `FitnessApp/Features/Camera/CameraViewModel.swift` | ⬜ TODO | — | |
| `FitnessApp/Features/Camera/VisionBodyPoseAnalyzer.swift` | ⬜ TODO | — | |
| `FitnessApp/Features/Home/HomeView.swift` | ⬜ TODO | — | Use mock data until Agent 2 ✅ |
| `FitnessApp/Features/Home/HomeViewModel.swift` | ⬜ TODO | — | |
| `FitnessApp/Features/Calories/CalorieGoalView.swift` | ⬜ TODO | — | Use mock data until Agent 2 ✅ |
| `FitnessApp/Features/Workout/WorkoutView.swift` | ⬜ TODO | — | |
| `FitnessApp/Features/Workout/WorkoutViewModel.swift` | ⬜ TODO | — | |
| `FitnessApp/Features/Profile/ProfileView.swift` | ⬜ TODO | — | |
| `FitnessApp/Features/Profile/ProfileViewModel.swift` | ⬜ TODO | — | |
| `FitnessApp/Resources/Info.plist` | ⬜ TODO | — | |
| `FitnessAppUITests/OnboardingUITests.swift` | ❌ BLOCKED | — | Needs Auth ✅ |

---

## Agent 4 — Tests & QA

| File | Status | Date Stable | Notes |
|------|--------|-------------|-------|
| `FitnessAppTests/Auth/AuthManagerTests.swift` | ❌ BLOCKED | — | Needs AuthManager ✅ |
| `FitnessAppTests/Workout/WorkoutRecommendationEngineTests.swift` | ❌ BLOCKED | — | Needs Agent 2 ✅ |
| `FitnessAppTests/Health/HealthKitManagerTests.swift` | ❌ BLOCKED | — | Needs Agent 2 ✅ |
| `FitnessAppUITests/OnboardingUITests.swift` | ❌ BLOCKED | — | Needs Auth + UI ✅ |

---

## Agent 5 — Polish & App Store

| File | Status | Date Stable | Notes |
|------|--------|-------------|-------|
| `FitnessApp/Features/Progress/ProgressViewModel.swift` | ❌ BLOCKED | — | Needs all Agent 2 ✅ |
| `FitnessApp/Features/Progress/ProgressView.swift` | ❌ BLOCKED | — | Needs ProgressViewModel ✅ |
| `FitnessApp/Features/Notifications/NotificationManager.swift` | ❌ BLOCKED | — | Needs all agents ✅ |
| `FitnessApp/Features/Notifications/NotificationSettingsView.swift` | ❌ BLOCKED | — | |
| `FitnessApp/App/MainTabView.swift` (Progress tab) | ❌ BLOCKED | — | Cross-agent edit, needs Agent 0 ✅ |
| `.agents/APPSTORE_CHECKLIST.md` | ❌ BLOCKED | — | Final deliverable |

**→ Agent 5 starts when**: all Agent 0, 1, 2, 3 files = ✅ STABLE

---

## Dependency Graph

```
You (manual) ──▶ BEFORE_YOU_START.md steps (SPM, Firebase, CoreData model, URL scheme)
     ↓
Agent 0 (Setup)     ──▶ AppRouter, MainTabView, RootView, FitnessAppApp
     ↓
Agent 1 (Auth)  ┐
Agent 3 (UI)    ├──▶ run in parallel (Agent 3 uses stubs where Agent 1 isn't done)
                ┘
     ↓ (wait for Agent 1 AuthManager ✅)
Agent 2 (Data)      ──▶ CoreData + HealthKit + ViewModels
     ↓ (wait for Agent 2 CoreData models ✅)
Agent 3 (UI)        ──▶ second session: connect real data to all views
Agent 4 (Tests)     ──▶ starts whenever any file reaches ✅ STABLE
     ↓ (all files ✅)
Agent 5 (Polish)    ──▶ Progress screen, notifications, App Store prep
```

---

## Overall Progress

- Agent 0: 0 / 5 files stable
- Agent 1: 0 / 6 files stable
- Agent 2: 0 / 10 files stable
- Agent 3: 0 / 13 files stable
- Agent 4: 0 / 4 files stable
- Agent 5: 0 / 6 files stable

**Total**: 0 / 44 files stable

**Recommended first launch**: Agent 0 (no dependencies). Then Agent 1 + Agent 3 in parallel.
