# Firebase & Google Sign-In — Manual Setup Guide

Complete these steps in order before running any AI agents.

---

## ✅ Step 1: Firebase Console Setup

- [ ] Go to [Firebase Console](https://console.firebase.google.com)
- [ ] Create a new project → name it `FitnessApp`
- [ ] Click **Add app** → select **iOS**
- [ ] Enter your **Bundle ID** (find it in Xcode → Project → Targets → Signing & Capabilities)
- [ ] Register the app

---

## ✅ Step 2: Download GoogleService-Info.plist

- [ ] Download `GoogleService-Info.plist` from the Firebase Console after registering the iOS app
- [ ] Drag the file into Xcode under `FitnessApp/SupportingFiles/`
- [ ] Check **"Copy items if needed"**
- [ ] Ensure **"Add to target: FitnessApp"** is checked
- [ ] Verify the file appears in your Xcode project navigator with a target membership checkmark

---

## ✅ Step 3: Add SPM Packages

In Xcode: **File → Add Package Dependencies…**

### Package 1 — Firebase iOS SDK
```
URL:     https://github.com/firebase/firebase-ios-sdk
Rule:    Up to Next Major from 10.0.0
Add:     ✅ FirebaseAuth
```

### Package 2 — Google Sign-In iOS
```
URL:     https://github.com/google/GoogleSignIn-iOS
Rule:    Up to Next Major from 7.0.0
Add:     ✅ GoogleSignIn
         ✅ GoogleSignInSwift
```

- [ ] Both packages resolved and added to target

---

## ✅ Step 4: URL Scheme for Google Sign-In

1. Open `GoogleService-Info.plist` in Xcode
2. Find the key **`REVERSED_CLIENT_ID`** — copy its value (looks like `com.googleusercontent.apps.XXXXXX`)
3. Select the **FitnessApp** target → **Info** tab → **URL Types**
4. Click **+**
5. Paste the `REVERSED_CLIENT_ID` value into the **URL Schemes** field

- [ ] URL Scheme added

---

## ✅ Step 5: Enable Auth Methods in Firebase Console

1. Go to Firebase Console → your project → **Authentication**
2. Click **Sign-in method** tab
3. Enable **Email/Password**
4. Enable **Google** (set a support email when prompted)

- [ ] Email/Password enabled
- [ ] Google sign-in enabled

---

## ✅ Step 6: HealthKit Capability

1. In Xcode → select **FitnessApp** target
2. Go to **Signing & Capabilities** tab
3. Click **+ Capability**
4. Search and add **HealthKit**
5. Check:
   - ✅ Background Delivery

- [ ] HealthKit capability added

---

## ✅ Step 7: CoreData Model

Verify the `.xcdatamodeld` file exists at `FitnessApp/Core/Data/` with these 4 entities:

| Entity | Key Attributes |
|--------|---------------|
| **UserProfile** | id (UUID), name (String), email (String), age (Int16), fitnessGoal (String), createdAt (Date) |
| **WorkoutLog** | id (UUID), date (Date), workoutType (String), durationMinutes (Int16), caloriesBurned (Double), userID (String) |
| **DailyGoal** | id (UUID), date (Date), calorieTarget (Double), workoutMinutesTarget (Int16), userID (String) |
| **CalorieEntry** | id (UUID), timestamp (Date), calories (Double), label (String), userID (String) |

For each entity, set **Codegen → Manual/None** in the Data Model Inspector.

- [ ] All 4 entities exist
- [ ] Codegen set to Manual/None for each

---

## ✅ Step 8: Verify Build

1. Select a simulator (iPhone 15, iOS 17+)
2. Press **Cmd+B**
3. Confirm **0 errors**

- [ ] Build succeeds with no errors

---

## Summary Checklist

| # | Item | Done |
|---|------|------|
| 1 | Firebase project created, iOS app registered | ☐ |
| 2 | `GoogleService-Info.plist` in project & target | ☐ |
| 3 | FirebaseAuth + GoogleSignIn SPM packages added | ☐ |
| 4 | `REVERSED_CLIENT_ID` URL Scheme configured | ☐ |
| 5 | Email/Password + Google auth enabled in Console | ☐ |
| 6 | HealthKit capability added | ☐ |
| 7 | CoreData model with 4 entities, Codegen = Manual/None | ☐ |
| 8 | Project builds with 0 errors | ☐ |
