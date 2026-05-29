# Skill: App Store Submission Checklist
# Project: FitnessCoach iOS App
# Target: iOS 16.4 / Xcode 14.0 / Swift 5.7
# Read this before starting any App Store preparation work.

---

## Phase 1 — Privacy & Entitlements Audit

Run this checklist before touching App Store Connect.

### Info.plist — required keys for this app
Check that ALL of these exist in Info.plist:

- [ ] NSHealthShareUsageDescription — HealthKit read
- [ ] NSHealthUpdateUsageDescription — HealthKit write
- [ ] NSCameraUsageDescription — camera access
- [ ] NSMotionUsageDescription — motion/activity data
- [ ] CFBundleDisplayName — "FitnessCoach" (or marketing name)
- [ ] CFBundleShortVersionString — e.g. "1.0"
- [ ] CFBundleVersion — build number, e.g. "1"
- [ ] LSMinimumSystemVersion — "16.4"
- [ ] UISupportedInterfaceOrientations — portrait at minimum
- [ ] ITSAppUsesNonExemptEncryption — false (if no custom encryption)

### Entitlements — check in Xcode Signing & Capabilities
- [ ] HealthKit capability added
- [ ] Push Notifications — add only if used
- [ ] Background Modes → check only what is actually used

### GoogleService-Info.plist
- [ ] File is present in the Xcode target
- [ ] File is in .gitignore — never in source control

---

## Phase 2 — App Store Connect Setup

1. Log in at https://appstoreconnect.apple.com
2. Apps → + New App
   - Platform: iOS
   - Name: FitnessCoach (or your marketing name)
   - Primary language: English
   - Bundle ID: (match Xcode exactly, e.g. com.yourname.FitnessCoach)
   - SKU: fitnesscoach-ios-001

---

## Phase 3 — Required Metadata

### App Information
- [ ] Name (30 chars max): FitnessCoach
- [ ] Subtitle (30 chars max): e.g. "Your AI-Powered Workout Coach"
- [ ] Category: Health & Fitness (primary), Sports (secondary)
- [ ] Content Rights: confirm you own or have rights to all content

### Version Information (for 1.0)
- [ ] Description (4000 chars max): explain all core features
- [ ] Keywords (100 chars max, comma separated): fitness,calorie,workout,healthkit,form,coaching
- [ ] Support URL: must be a live URL (e.g. your GitHub page or landing page)
- [ ] Privacy Policy URL: REQUIRED — must be live before submission
- [ ] Marketing URL: optional

### What's New in This Version
- [ ] Write for version 1.0: "Initial release — calorie tracking, workout coaching, and form feedback."

---

## Phase 4 — Screenshots

Required screenshot sizes (must be exact):

| Device | Size | Notes |
|--------|------|-------|
| iPhone 6.9" (iPhone 15 Pro Max sim) | 1320 × 2868 px | required |
| iPhone 6.7" (iPhone 14 Plus sim) | 1284 × 2778 px | required |
| iPhone 5.5" (iPhone 8 Plus sim) | 1242 × 2208 px | required if supporting older |
| iPad Pro 12.9" (6th gen) | 2048 × 2732 px | required if iPad supported |

Rules:
- 3–10 screenshots per size
- No device frames required (App Store adds them)
- Screenshots must show actual app UI — no mockups with fake content
- No pricing info or Apple branding in screenshots

Suggested screens to capture:
1. Home screen with calorie ring
2. Workout recommendations list
3. Camera form feedback (use real device)
4. Progress / history chart
5. Onboarding / login screen

---

## Phase 5 — App Privacy (Data Usage)

In App Store Connect → App Privacy:

| Data Type | Collected? | Linked to User? | Used for Tracking? |
|-----------|-----------|-----------------|-------------------|
| Email address | Yes | Yes | No |
| Health & Fitness | Yes | Yes | No |
| User ID (Firebase UID) | Yes | Yes | No |
| Camera | Yes | No | No |
| Crash data | Yes (Firebase Crashlytics if used) | No | No |

Mark "Does not track" for ATT if you are not using advertising identifiers.

---

## Phase 6 — Build & Archive

```bash
# In Xcode:
# 1. Set scheme to Release
# 2. Set device to "Any iOS Device (arm64)"
# 3. Product → Archive
# 4. Organizer → Distribute App → App Store Connect
# 5. Upload
```

Before archiving:
- [ ] All TODO comments resolved (or logged as known issues)
- [ ] No debug print statements in production code paths
- [ ] All API keys in GoogleService-Info.plist, not hardcoded
- [ ] Build number incremented from last upload
- [ ] No third-party SDKs without licenses reviewed

---

## Phase 7 — Review Notes (write this before submitting)

App Review Notes tell reviewers how to test your app. Be specific:

```
App Review Notes for FitnessCoach v1.0

Login:
- Use Google Sign-In button or create an account with email/password
- Test account: reviewer@example.com / TestPassword123! (create before submission)

HealthKit:
- App requests HealthKit access on first launch after login
- If testing on simulator, HealthKit will show 0 data (expected behavior)
- Test on real device for accurate HealthKit readings

Camera:
- Camera feature requires physical device (will not show video on simulator)
- Allow camera access when prompted
- Stand 2-3 meters from camera for body pose detection to work

Note: GoogleService-Info.plist is included in the build — Firebase backend is live.
```

---

## Phase 8 — Pre-Submission Final Check

- [ ] Tested on real device running iOS 16.4
- [ ] Tested on latest iOS (simulator)
- [ ] All permission alerts show correct, non-generic descriptions
- [ ] App works when HealthKit is denied
- [ ] App works when camera is denied
- [ ] App works with no internet connection (show appropriate error)
- [ ] Landscape orientation tested (lock to portrait if not supported)
- [ ] VoiceOver basic navigation tested
- [ ] No crashes in last 24h of testing
- [ ] TestFlight beta tested by at least one other person
