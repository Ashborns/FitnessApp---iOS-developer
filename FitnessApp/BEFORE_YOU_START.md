# FitnessApp — Before You Start
# Manual steps YOU must complete before launching any AI agent.
# These cannot be automated — they require clicking inside Xcode.

---

## Estimated time: ~20–30 minutes

---

## STEP 1 — Add Swift Packages in Xcode (SPM)

Open `FitnessApp.xcodeproj` in Xcode, then:

`File → Add Package Dependencies…`

Add these two packages:

### Package 1 — Firebase iOS SDK
```
URL: https://github.com/firebase/firebase-ios-sdk
Version: Up to Next Major from 10.0.0
Products to add:
  ✅ FirebaseAuth
  ✅ FirebaseFirestore   (optional, only if you want Firestore later)
  ✅ FirebaseCrashlytics (optional but recommended)
```

### Package 2 — Google Sign-In iOS
```
URL: https://github.com/google/GoogleSignIn-iOS
Version: Up to Next Major from 7.0.0
Products to add:
  ✅ GoogleSignIn
  ✅ GoogleSignInSwift
```

---

## STEP 2 — Get GoogleService-Info.plist from Firebase Console

1. Go to https://console.firebase.google.com
2. Create a new project → name it `FitnessApp`
3. Add an iOS app:
   - Bundle ID: check yours in Xcode → Project → Targets → Signing & Capabilities
4. Download `GoogleService-Info.plist`
5. Drag it into Xcode under `FitnessApp/SupportingFiles/`
   - ✅ Check "Copy items if needed"
   - ✅ Add to target: FitnessApp

> **Note**: The placeholder file at that path will be replaced. That's fine.

---

## STEP 3 — Add URL Scheme for Google Sign-In

1. In Xcode, select your project in the navigator
2. Select the **FitnessApp** target
3. Go to **Info** tab → **URL Types** section
4. Click `+`
5. Open the `GoogleService-Info.plist` you just downloaded
6. Find the key `REVERSED_CLIENT_ID` — copy its value (looks like `com.googleusercontent.apps.XXXXXX`)
7. Paste it into **URL Schemes** field in Xcode

---

## STEP 4 — Enable HealthKit Capability

1. In Xcode → select FitnessApp target
2. Go to **Signing & Capabilities** tab
3. Click `+ Capability`
4. Add **HealthKit**
5. Check both:
   - ✅ Health Records (Clinical Data) — optional
   - ✅ Background Delivery — for background updates

---

## STEP 5 — Create the CoreData Model File (.xcdatamodeld)

This file CANNOT be created by an AI agent — it must be done in Xcode.

1. In Xcode → `File → New → File`
2. Choose **Data Model** (under Core Data section)
3. Name it exactly: `FitnessApp`
4. Save it to: `FitnessApp/Core/Data/`
5. Open the `.xcdatamodeld` file and create these 4 entities:

### Entity 1: `UserProfile`
| Attribute | Type |
|-----------|------|
| `id` | UUID |
| `name` | String |
| `email` | String |
| `age` | Integer 16 |
| `fitnessGoal` | String |
| `createdAt` | Date |

### Entity 2: `WorkoutLog`
| Attribute | Type |
|-----------|------|
| `id` | UUID |
| `date` | Date |
| `workoutType` | String |
| `durationMinutes` | Integer 16 |
| `caloriesBurned` | Double |
| `userID` | String |

### Entity 3: `DailyGoal`
| Attribute | Type |
|-----------|------|
| `id` | UUID |
| `date` | Date |
| `calorieTarget` | Double |
| `workoutMinutesTarget` | Integer 16 |
| `userID` | String |

### Entity 4: `CalorieEntry`
| Attribute | Type |
|-----------|------|
| `id` | UUID |
| `timestamp` | Date |
| `calories` | Double |
| `label` | String |
| `userID` | String |

After creating each entity:
- Set **Codegen** to `Manual/None` for each entity (in the Data Model Inspector on the right)
- This lets Agent 2 write the NSManagedObject subclasses manually

---

## STEP 6 — Add Camera & HealthKit Entitlements to Info.plist

Open `FitnessApp/Resources/Info.plist` and verify these keys exist
(Agent 3 will add them, but double-check after running Agent 3):

```
NSHealthShareUsageDescription
NSHealthUpdateUsageDescription
NSCameraUsageDescription
NSMotionUsageDescription
```

---

## STEP 7 — Verify Build

1. Select a simulator (iPhone 15, iOS 17 or iPhone 14 with iOS 16.4)
2. Press `Cmd+B` to build
3. It should compile with 0 errors (stub files are already in place)

If build fails → check the error and fix before launching any agent.

---

## ✅ Checklist

- [ ] Firebase package added (FirebaseAuth at minimum)
- [ ] GoogleSignIn package added
- [ ] `GoogleService-Info.plist` placed in `SupportingFiles/`
- [ ] URL Scheme (`REVERSED_CLIENT_ID`) added to Info → URL Types
- [ ] HealthKit capability enabled
- [ ] `.xcdatamodeld` created with all 4 entities, Codegen = Manual/None
- [ ] Project builds successfully (`Cmd+B`) with 0 errors

**Once all 7 boxes are checked → you are ready to launch the agents.**

---

## Agent Launch Order

```
You (manual) → STEP 1–7 above
     ↓
Agent 0 (Setup)     — configures app shell, navigation, URL handling
     ↓
Agent 1 (Auth)  ┐
Agent 3 (UI)    ├── run these 2 in parallel
                ┘
     ↓ (wait for Agent 1 to finish AuthManager)
Agent 2 (Data)      — CoreData + HealthKit
     ↓ (wait for Agent 2 CoreData models)
Agent 3 (UI)        — connect real data (second session)
Agent 4 (Tests)     — starts whenever any file reaches ✅ STABLE
     ↓ (everything is stable)
Agent 5 (Polish)    — Progress screen, notifications, App Store prep
```
