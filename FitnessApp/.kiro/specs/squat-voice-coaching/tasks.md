# Implementation Plan: Squat Voice Coaching

## Overview

This plan builds the feature bottom-up: the deterministic pure-logic cores
(`SquatPhase`, `SquatRepCounter`, `CoachingEvent`, and the `VoiceCoach` speak-decision
function) and their property tests come first, since the Core ML and audio integration
depend on them. Then the two new singletons (`FlexFitClassifierManager`, `VoiceCoach`)
are wired up, followed by `CameraViewModel` routing/voice triggers and the
`CameraFeedView` UI controls. Every test that exercises pure logic is a SwiftCheck
property test (min 100 iterations, one-to-one with a design property); Core ML, audio,
and SwiftUI surfaces use smoke/integration tests instead.

All code is Swift, targets iOS 16.4 (`ObservableObject` + `@Published`,
`.onChange(of:perform:)` single-param form, no `@Observable`/`@Bindable`/SwiftData),
and mirrors the existing `ExerciseClassifierManager` / `HapticManager.shared` patterns.

## Tasks

- [x] 1. Squat phase + rep-counting pure logic
  - [x] 1.1 Implement `SquatPhase` enum
    - Create `Features/Camera/SquatPhase.swift` with cases `down`, `up`, `resting`, `unknown`
    - Add `init(modelLabel:)` doing case-insensitive substring mapping (down/squat → `.down`, up/stand → `.up`, rest/idle → `.resting`, else `.unknown`)
    - Add `isResting` computed property returning true for `.up` and `.resting`
    - _Requirements: 3.1_

  - [x] 1.2 Implement `SquatRepCounter` struct
    - Create `Features/Camera/SquatRepCounter.swift` as a pure value type with `private(set) var repCount` and a private `phase: SquatPhase`
    - Add `static let confidenceThreshold = 0.6`
    - Implement `mutating func consume(label:confidence:) -> Int` — return 0 when `confidence < threshold` (no phase advance); map label to `SquatPhase`; increment on `down → isResting` transition only; advance stored phase on recognized labels
    - Implement `mutating func resetPhase()` (phase → `.unknown`, keep `repCount`) and `mutating func resetAll()` (phase → `.unknown`, `repCount = 0`)
    - _Requirements: 3.1, 3.2, 3.5, 3.6_

  - [ ]* 1.3 Write property test for confidence gating
    - File `Tests/SquatRepCounterPropertyTests.swift`, SwiftCheck, min 100 iterations
    - **Property 1: Confidence threshold gates phase advancement**
    - **Validates: Requirements 3.2**

  - [ ]* 1.4 Write property test for single rep per down→rest cycle
    - Append to `Tests/SquatRepCounterPropertyTests.swift`, SwiftCheck, min 100 iterations
    - **Property 2: A rep is counted exactly once per down→rest cycle**
    - **Validates: Requirements 3.1**

  - [ ]* 1.5 Write property test for monotonic + idempotent counting
    - Append to `Tests/SquatRepCounterPropertyTests.swift`, SwiftCheck, min 100 iterations
    - **Property 3: Rep count is monotonic and idempotent under label repetition**
    - **Validates: Requirements 3.1, 3.4**

  - [ ]* 1.6 Write property test for phase reset semantics
    - Append to `Tests/SquatRepCounterPropertyTests.swift`, SwiftCheck, min 100 iterations
    - **Property 4: Phase reset preserves committed total**
    - **Validates: Requirements 3.5, 3.6**

  - [ ]* 1.7 Write unit tests for `SquatRepCounter` and `SquatPhase`
    - File `Tests/SquatRepCounterUnitTests.swift`
    - down→up→down→up counts 2; below-threshold spike between phases ignored; `resetAll` zeroes everything; representative training-label strings map to correct `SquatPhase`; unrecognized → `.unknown`
    - _Requirements: 3.1, 3.2, 3.5_

- [x] 2. Coaching event model
  - [x] 2.1 Implement `CoachingEvent` enum
    - Create `Core/Audio/CoachingEvent.swift` with cases `repAnnouncement(count:)`, `formCorrection(message:)`, `milestone(reps:)`, `workoutStart(exercise:)`, `workoutEnd(totalReps:)`, `exerciseSwitch(exercise:)`
    - Add a `Category` and `category` mapping; add `text` that formats each case and truncates to ≤ 60 chars; add `interrupts` true only for `repAnnouncement`
    - _Requirements: 4.4, 4.5, 4.6_

  - [ ]* 2.2 Write property test for spoken text length bound
    - File `Tests/CoachingEventPropertyTests.swift`, SwiftCheck, min 100 iterations, arbitrary long `formCorrection` messages
    - **Property 9: Spoken text length bound**
    - **Validates: Requirements 4.6**

- [ ] 3. Voice coach decision logic and synthesizer wiring
  - [ ] 3.1 Implement the pure speak-decision function and utterance sink
    - Create `Core/Audio/VoiceCoachDecision.swift` with an abstract `UtteranceSink` (records speak/stop actions), an injected clock, and a pure decision routine: enabled check (drop when disabled) → `formCorrection` gating → interrupt-vs-queue by category (`repAnnouncement` stops+speaks, `formCorrection`/`milestone` queue and dequeue on finish)
    - Apply BOTH `formCorrection` gates in the pure logic; a `formCorrection` is spoken only when it passes both: (a) identical-text 3 s debounce — skip identical text < 3 s after the last spoken identical text (`lastFormCorrection: (text, Date)?`, `static let debounceInterval = 3.0`); (b) global 2.5 s spacing — skip ANY `formCorrection` when `now - lastAnyFormCorrectionAt < 2.5` regardless of text (`lastAnyFormCorrectionAt: Date?`, `static let formCorrectionInterval = 2.5`). On a spoken `formCorrection`, update both `lastFormCorrection = (text, now)` and `lastAnyFormCorrectionAt = now`
    - Keep it free of `AVSpeechSynthesizer`/`AVAudioSession` so it is testable without audio hardware
    - _Requirements: 4.2, 4.4, 4.5, 5.5, 5.6, 6.3_

  - [ ]* 3.2 Write property test for mute suppression
    - File `Tests/VoiceCoachDecisionPropertyTests.swift`, SwiftCheck, min 100 iterations, random event streams with disabled preference
    - **Property 6: Mute suppresses all output**
    - **Validates: Requirements 4.2, 6.3**

  - [ ]* 3.3 Write property test for form-correction debounce
    - Append to `Tests/VoiceCoachDecisionPropertyTests.swift`, SwiftCheck, min 100 iterations, timestamped `formCorrection` streams
    - **Property 7: Form-correction debounce suppresses identical back-to-back cues**
    - **Validates: Requirements 5.5**

  - [ ]* 3.4 Write property test for interrupt-vs-queue policy
    - Append to `Tests/VoiceCoachDecisionPropertyTests.swift`, SwiftCheck, min 100 iterations, mixed-category event streams while "speaking"
    - **Property 8: Interrupt-vs-queue policy by category**
    - **Validates: Requirements 4.4, 4.5**

  - [x] 3.5 Implement `VoiceCoach` singleton wiring synthesizer + audio session
    - Create `Core/Audio/VoiceCoach.swift` as a `@MainActor NSObject, ObservableObject` with `static let shared`, mirroring `HapticManager.shared`
    - Hold `AVSpeechSynthesizer` (set delegate), drive it from the decision logic in 3.1; `speak(_:)`, `stop()`, `deactivateSession()`
    - `isEnabled` reads `UserDefaults` key `voiceCoachEnabled` (`object(forKey:) as? Bool ?? true`)
    - `configureAudioSession()` sets `.playback` / `.spokenAudio` / `.duckOthers` in `do/catch` (skip+log on failure); utterance uses `AVSpeechUtteranceDefaultSpeechRate` and current-language voice with system-default fallback
    - Register `AVAudioSession.interruptionNotification` observer (stop on `began`, stay ready on `ended`+`shouldResume`); `deactivateSession()` uses `.notifyOthersOnDeactivation`
    - _Requirements: 4.1, 4.3, 6.3, 6.4, 7.1, 7.3, 7.4, 7.5, 7.6, 8.2, 8.3, 8.4, 8.5_

  - [ ]* 3.6 Write audio-session configuration smoke test
    - File `Tests/VoiceCoachSmokeTests.swift`, single execution: after `VoiceCoach` init the shared session reports category `.playback`, mode `.spokenAudio`, options containing `.duckOthers`
    - _Requirements: 7.1, 8.5_

  - [ ]* 3.7 Write synthesizer integration test
    - Append to `Tests/VoiceCoachSmokeTests.swift`, single execution: one or two example utterances confirm `AVSpeechSynthesizer` speaks and the delegate dequeues the next queued event
    - _Requirements: 4.1, 4.5_

  - [ ]* 3.8 Write property test for global form-correction spacing
    - Append to `Tests/VoiceCoachDecisionPropertyTests.swift` (alongside the identical-text debounce test 3.3), SwiftCheck, min 100 iterations, random **mixed-text** `formCorrection` streams with timestamps clustered around the 2.5 s boundary (sub-2.5 s and ≥ 2.5 s gaps, identical and differing text)
    - Assert no two spoken `formCorrection` cues are < 2.5 s apart regardless of text, and that this global gate composes with the identical-text debounce (Property 7)
    - **Property 11: Global form-correction spacing (any text)**
    - **Validates: Requirements 5.6**

- [ ] 4. Voice preference persistence
  - [ ]* 4.1 Write property test for `VoicePreference` round-trip
    - File `Tests/VoicePreferencePropertyTests.swift`, SwiftCheck, min 100 iterations, arbitrary booleans against an isolated `UserDefaults` suite
    - **Property 10: VoicePreference round-trips through UserDefaults with enabled default**
    - **Validates: Requirements 6.2, 6.4**

- [ ] 5. FlexFitClassifier model manager
  - [x] 5.1 Implement `FlexFitClassifierManager` singleton
    - Create `Features/Camera/FlexFitClassifierManager.swift` mirroring `ExerciseClassifierManager` line-for-line: `static let shared`, `@Published private(set)` `squatLabel`/`squatConfidence`/`isModelLoaded`, `predictionWindowSize = 60`, sliding `poseWindow`
    - `loadModel()` in `init` with `MLModelConfiguration.computeUnits = .cpuAndNeuralEngine` in `do/catch` (set `isModelLoaded`, log on failure, no crash)
    - `addPose(_:)` appends, gates on `count >= predictionWindowSize`, runs inference, then `removeFirst()` to slide
    - `runInference()` reads `featureValue(for: "label")?.stringValue` and `featureValue(for: "labelProbabilities")?.dictionaryValue` (no auto-generated-type coupling); `reset()` clears window + initial values
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 2.1, 2.2, 2.3, 2.4, 2.5_

  - [ ]* 5.2 Write property test for PoseWindow gating and bounded size
    - File `Tests/FlexFitClassifierManagerPropertyTests.swift`, SwiftCheck, min 100 iterations, random append counts relative to `predictionWindowSize` (inference invoked only when full; window never exceeds the size)
    - **Property 5: PoseWindow inference gating and bounded size**
    - **Validates: Requirements 2.2, 2.3, 2.4**

  - [ ]* 5.3 Write FlexFitClassifier load smoke test
    - File `Tests/FlexFitClassifierManagerSmokeTests.swift`, single execution: the bundled model loads with `.cpuAndNeuralEngine` and `isModelLoaded == true`
    - _Requirements: 1.2, 1.3_

- [x] 6. CameraViewModel integration
  - [x] 6.1 Add squat routing branch and new state
    - In `Features/Camera/CameraViewModel.swift` add `@Published var voiceEnabled` (default from `UserDefaults` key `voiceCoachEnabled` `?? true`), `@Published var mlModelUnavailable`, and a private `squatRepCounter = SquatRepCounter()`
    - Inside the existing `onPoseDetected` `frameCheckResult.isReady` block, branch: when `selectedExercise == .squats && FlexFitClassifierManager.shared.isModelLoaded` feed `addPose` + `squatRepCounter.consume(...)` and apply the rep delta to `repCount`/`phase`; otherwise keep the existing `detector.process(...)` path
    - Set `mlModelUnavailable = true` when Squats is active and `isModelLoaded == false`
    - _Requirements: 2.1, 2.6, 2.7, 3.3, 8.1_

  - [x] 6.2 Add voice triggers at existing haptic points
    - Extend the existing `repCount > prevCount` block so it also calls `VoiceCoach.shared.speak(.milestone(reps:))` on multiples of 10 and `.repAnnouncement(count:)` otherwise, alongside the existing haptic calls
    - Add the form-correction trigger: speak `.formCorrection(message:)` only when `feedback` differs from the last spoken correction (track via `lastSpokenFormCorrection`)
    - _Requirements: 3.3, 3.4, 5.2, 5.3, 5.4_

  - [x] 6.3 Wire lifecycle voice events, toggle, and persistence
    - Add `toggleVoice()` (invert `voiceEnabled`, write to `UserDefaults`, call `VoiceCoach.shared.stop()` when turning off)
    - `configureAndStart` speaks `.workoutStart(exercise:)` when enabled; `selectExercise` calls `squatRepCounter.resetPhase()` + speaks `.exerciseSwitch(exercise:)`; `resetCounter` calls `squatRepCounter.resetAll()`; `saveWorkoutSession` speaks `.workoutEnd(totalReps:)` when `totalReps > 0`; `stopSession` calls `VoiceCoach.shared.deactivateSession()`
    - _Requirements: 3.5, 3.6, 5.1, 5.7, 5.8, 6.2, 6.3, 6.4, 7.6_

  - [ ]* 6.4 Write routing unit tests
    - File `Tests/CameraViewModelRoutingTests.swift`: Squats + model loaded routes to `FlexFitClassifierManager` and skips `ExerciseDetector`; Squats + model not loaded uses `ExerciseDetector` and sets `mlModelUnavailable`; a non-Squats exercise never calls `FlexFitClassifierManager.addPose`
    - _Requirements: 2.6, 2.7, 8.1_

  - [ ]* 6.5 Write milestone trigger unit test
    - Append to `Tests/CameraViewModelRoutingTests.swift`: a rep count hitting a multiple of 10 fires `.milestone` (and `HapticManager.shared.milestone()`) instead of `.repAnnouncement`
    - _Requirements: 3.4, 5.3_

- [x] 7. CameraFeedView UI controls
  - [x] 7.1 Add `VoiceMuteToggle` to the top bar
    - In `Features/Camera/CameraFeedView.swift` add a button to the existing `topBar` HStack styled like the flip/close buttons; icon `speaker.wave.2.fill` / `speaker.slash.fill` driven by `viewModel.voiceEnabled`; action `viewModel.toggleVoice()`
    - Set `.accessibilityLabel("Voice Coach")`, `.accessibilityValue(...)`, `.accessibilityIdentifier("camera-voice-toggle-btn")`; use `Color`+Theme styling (no hardcoded hex)
    - _Requirements: 6.1, 6.2, 6.5_

  - [x] 7.2 Add ML fallback banner
    - Reuse the existing `feedbackBanner` style to show "Squat ML model unavailable — using fallback detection" when `viewModel.mlModelUnavailable` is true
    - _Requirements: 8.1_

  - [ ]* 7.3 Write VoiceMuteToggle accessibility test
    - File `Tests/CameraFeedViewAccessibilityTests.swift`: the toggle exposes label "Voice Coach", a value reflecting state, and the speaker vs. muted-speaker icon
    - _Requirements: 6.1, 6.5_

- [x] 8. Final checkpoint
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional test sub-tasks and can be skipped for a faster MVP.
- Pure-logic cores (`SquatPhase`, `SquatRepCounter`, `CoachingEvent`, `VoiceCoachDecision`) and their property tests precede the Core ML / audio integration that depends on them.
- Property tests use SwiftCheck (min 100 iterations) and map one-to-one to Properties 1–11 in the design; Core ML, audio, and SwiftUI surfaces use smoke/integration tests only.
- Each task references the specific requirement clauses (and property numbers, where applicable) it implements for traceability.
- Checkpoints ensure incremental validation; no orphaned code — each task wires into prior tasks.

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "2.1", "5.1"] },
    { "id": 1, "tasks": ["1.2", "2.2", "3.1", "4.1", "5.2", "5.3"] },
    { "id": 2, "tasks": ["1.3", "1.7", "3.2", "3.5", "6.1"] },
    { "id": 3, "tasks": ["1.4", "3.3", "3.6", "6.2"] },
    { "id": 4, "tasks": ["1.5", "3.4", "3.7", "6.3"] },
    { "id": 5, "tasks": ["1.6", "3.8", "6.4", "7.1"] },
    { "id": 6, "tasks": ["6.5", "7.2", "7.3"] }
  ]
}
```
