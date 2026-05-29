---
inclusion: auto
---

# AI-Pair Review Protocol — FitnessApp

## Overview

This project uses a multi-agent orchestration pattern inspired by the ai-pair collaboration model
and A2A (Agent-to-Agent) protocol concepts. After each implementation phase, a review gate
evaluates the output from multiple perspectives before the next phase begins.

## Review Pattern: "One Creates, Two Review"

Each phase follows this cycle:
1. **Creator Agent** — Implements the code for their domain
2. **Code Reviewer** — Evaluates code quality, patterns, and constraints compliance
3. **Integration Reviewer** — Evaluates how the output connects with other agents' work

## Review Gates Between Phases

### Gate 1: After "The Architect" (Phase 1)
**Review Focus:**
- Does AppRouter expose the correct public API for all downstream agents?
- Does MainTabView structure match the 5-tab requirement?
- Is the camera fullScreenCover pattern correct?
- Are environment objects properly injected?
- No force unwraps, all @Published on @MainActor?

### Gate 2: After "The Auth Engineer" (Phase 2)
**Review Focus:**
- Does AuthManager.shared expose the exact API contract (signIn, signUp, signInWithGoogle, signOut)?
- Is `currentUserID` accessible for Agent 2 (Data) to use?
- Are error states properly published?
- Is KeychainWrapper using correct accessibility level?
- Does OnboardingView have all required accessibility identifiers?

### Gate 3: After "The UI Designer" Pass 1 (Phase 3)
**Review Focus:**
- Does Color+Theme.swift define all required semantic tokens?
- Is VisionBodyPoseAnalyzer processing every 4th frame?
- Does CameraViewModel properly manage session lifecycle?
- Are all views using theme tokens (no hardcoded colors)?

### Gate 4: After "The Data Engineer" (Phase 4)
**Review Focus:**
- Does PersistenceController match the singleton pattern with in-memory preview?
- Do all CoreData entities match the ERD in design.md?
- Does HealthKitManager check authorization before every query?
- Does CalorieGoalViewModel validate inputs before persistence?
- Does WorkoutRecommendationEngine return 3-5 results?
- Is test coverage achievable (90% data layer)?

### Gate 5: After "The UI Designer" Pass 2 (Phase 5)
**Review Focus:**
- Are all views connected to real ViewModels (no more stubs)?
- Do all views have accessibility identifiers matching the naming pattern?
- Are empty states handled for all data-dependent views?
- Does ProfileView sign-out button call AuthManager.signOut()?

### Gate 6: After "The QA Engineer" (Phase 6)
**Review Focus:**
- Do all tests use in-memory CoreData?
- Are HealthKit calls properly mocked?
- Is each test independent (no shared mutable state)?
- Do property-based tests cover the correctness properties from design.md?
- Are coverage thresholds achievable?

### Gate 7: After "The Polish Master" (Phase 7)
**Review Focus:**
- Does ProgressView use Swift Charts correctly?
- Are notifications scheduled/cancelled properly?
- Is the app icon present and correctly sized?
- Are all Info.plist keys present?
- Does the app compile with zero warnings?

## Review Checklist Template

For each gate, verify:
- [ ] **Constraints**: No `!`, all `@Published` on `@MainActor`, iOS 16.4 APIs only
- [ ] **API Contract**: Public interfaces match what downstream agents expect
- [ ] **Error Handling**: All fallible operations use throws/Result, errors published to UI
- [ ] **Accessibility**: All interactive elements have identifiers and labels
- [ ] **Integration**: Files don't touch other agents' scope (no cross-boundary edits)
- [ ] **Tests**: Code is structured for testability (DI via init params)

## A2A Concepts Applied

| A2A Concept | Our Implementation |
|-------------|-------------------|
| Agent Card | Each phase has a defined scope (SCOPE.md) and public API |
| Task | Each numbered task in tasks.md |
| Message | SHARED_STATE.md status updates (TODO → IN PROGRESS → STABLE) |
| Skill | Each agent's domain expertise (Auth, Data, UI, Tests, Polish) |
| Discovery | Dependency graph in tasks.md defines which agents can start |
