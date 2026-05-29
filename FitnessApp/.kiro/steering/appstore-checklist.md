---
inclusion: fileMatch
fileMatchPattern: "**/Resources/**,**/Info.plist,**/Assets.xcassets/**"
---

# App Store Submission Checklist — FitnessApp

## Info.plist Required Keys

- NSHealthShareUsageDescription — HealthKit read
- NSHealthUpdateUsageDescription — HealthKit write
- NSCameraUsageDescription — camera access
- NSMotionUsageDescription — motion/activity data
- CFBundleDisplayName — "FitnessApp"
- CFBundleShortVersionString — e.g. "1.0.0"
- CFBundleVersion — integer build number
- ITSAppUsesNonExemptEncryption — false
- UISupportedInterfaceOrientations — portrait minimum

## App Icon

- 1024×1024 PNG, no transparency, no alpha channel
- Assigned in Assets.xcassets/AppIcon.appiconset

## Launch Screen

- LaunchScreen storyboard or Info.plist configuration
- Display app name or logo

## Privacy & Data Usage

| Data Type | Collected | Linked to User | Tracking |
|-----------|-----------|----------------|----------|
| Email | Yes | Yes | No |
| Health & Fitness | Yes | Yes | No |
| User ID (Firebase) | Yes | Yes | No |
| Camera | Yes | No | No |

## Pre-Submission Checks

- Tested on real device running iOS 16.4
- All permission alerts show correct descriptions
- App works when HealthKit is denied
- App works when camera is denied
- App works offline (shows appropriate error)
- VoiceOver basic navigation tested
- No crashes in testing
- No debug print statements in production
- Build number incremented
- Zero warnings in project-owned source files

## Screenshots Required

| Device | Size |
|--------|------|
| iPhone 6.9" | 1320 × 2868 px |
| iPhone 6.7" | 1284 × 2778 px |
| iPhone 5.5" | 1242 × 2208 px |

Capture: Home, Workout, Camera, Progress, Onboarding
