# FitnessApp — Global Agent Rules
# Every agent MUST read this file before writing a single line of code.

---

## Project Identity
- **App Name**: FitnessApp
- **Platform**: iOS 16.4+
- **Language**: Swift 5.7 (not Swift 6)
- **UI Framework**: SwiftUI lifecycle only
- **Persistence**: CoreData (NOT SwiftData — SwiftData requires iOS 17)
- **Auth**: Firebase Auth + Google Sign-In (GoogleSignIn-iOS SDK v7.x)
- **Project path**: `/Users/a12/Documents/fathi/FitnessApp/`

---

## Technical Constraints (NON-NEGOTIABLE)

| Rule | Detail |
|------|--------|
| iOS minimum | 16.4 — never use APIs introduced after this version |
| No force unwrap | Never use `!` in production code |
| Error handling | Use `Result<T, Error>` or `throws` — no silent failures |
| Thread safety | All `@Published` properties must be on `@MainActor` or dispatched to main thread |
| HealthKit | Always check `authorizationStatus` before any query |
| Privacy strings | Every camera/health/motion access needs a corresponding Info.plist key |
| Test framework | XCTest only — no third-party testing libraries |

---

## Multi-Agent Coordination Rules (MOST IMPORTANT)

### Rule 1 — Each agent only touches files in their own SCOPE
Every agent has a `SCOPE.md` file that lists exactly what they own.
If a file is NOT in your OWNED FILES list → **do not touch it, not even a comment**.

### Rule 2 — How to check what other agents are doing
Open: `/Users/a12/Documents/fathi/FitnessApp/.agents/SHARED_STATE.md`
This is the single source of truth for what has been completed.

### Rule 3 — How to mark a file as stable
When a file is done:

**A. Add this marker at the very top of the Swift file:**
```swift
// AGENT-STABLE: <FeatureName> — do not modify without coordination
// Stable since: YYYY-MM-DD
// Stabilized by: Agent <N> — <AgentName>
```

**B. Update `SHARED_STATE.md`:**
Change that file's status from `⬜ TODO` or `🔄 IN PROGRESS` to `✅ STABLE`.

### Rule 4 — Never edit another agent's STABLE file
If you genuinely must change a STABLE file owned by another agent:
- Write a comment above your change: `// CROSS-AGENT EDIT by Agent N — reason: ...`
- Update `SHARED_STATE.md` to flag this

### Rule 5 — If your dependency is not yet STABLE
Don't wait. Create a local stub/mock and continue.
Mark it: `// TODO: connect to real Agent X output when STABLE`

---

## Skill Files
All skill files are in `.skills/`. Read the relevant one before writing code.

| Domain | File |
|--------|------|
| SwiftUI views | `.skills/swiftui-standards.md` |
| HealthKit | `.skills/healthkit-privacy.md` |
| CoreData | `.skills/coredata-models.md` |
| Firebase / Auth | `.skills/firebase-auth.md` |
| Camera / Vision | `.skills/vision-coreml.md` |
| App Store | `.skills/appstore-checklist.md` |
