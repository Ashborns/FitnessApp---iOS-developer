# Implementation Plan: Exercise Form Correction Feedback

## Overview

All changes are confined to a single file: `JumpingJackCounter.swift`. The implementation adds one field to `ExerciseDetector.State`, one pure helper function (`formFeedbackMessage`), one method (`evaluateForm`), and a small modification to `process()` to capture a feedback snapshot and call `evaluateForm` after counting. No other file is touched.

## Tasks

- [x] 1. Add `lastFeedbackChangeTime` to `ExerciseDetector.State`
  - In `JumpingJackCounter.swift`, add `var lastFeedbackChangeTime: TimeInterval = 0` to `ExerciseDetector.State`, after the existing `angleHistory` field
  - `State.initial` returns `State()` so the default value `0` is automatically applied on every reset — no change to `State.initial` is required
  - _Requirements: 4.4, 4.6, 7.1, 7.2_

- [x] 2. Implement `formFeedbackMessage` pure function
  - [x] 2.1 Add the `formFeedbackMessage` private method to `ExerciseDetector`
    - Signature: `private func formFeedbackMessage(exercise: ExerciseType, stage: Stage, leftStage: Stage, rightStage: Stage, leftAngle: Double?, rightAngle: Double?, leftLegAngle: Double?, rightLegAngle: Double?, config: ExerciseConfig) -> String?`
    - `leftLegAngle` / `rightLegAngle` are hip→knee→ankle angles; only used for the Jumping Jacks leg-spread check; pass `nil` for all other exercises
    - Return `nil` immediately when `stage == .none` (and for High Knees when both `leftStage == .none` and `rightStage == .none`)
    - No state mutation, no side effects — pure function
    - _Requirements: 2.8, 1.7_

  - [x] 2.2 Implement Jumping Jacks branch inside `formFeedbackMessage`
    - Guard `stage == .up`, else return `nil`
    - Compute `armAvg = (leftAngle + rightAngle) / 2`; if `armAvg < config.upAngle` (130°) return `"Raise arms higher"` — arm error takes priority
    - Compute `legAvg = (leftLegAngle + rightLegAngle) / 2`; if `legAvg > 100` return `"Spread legs wider"`
    - Return `nil` if neither condition fires
    - _Requirements: 2.1, 2.2_

  - [x] 2.3 Implement Squats branch inside `formFeedbackMessage`
    - Compute `avg = (leftAngle + rightAngle) / 2`
    - If `stage == .down` and `avg > config.downAngle` (100°) return `"Go deeper — bend knees more"`
    - If `stage == .up` and `avg < config.upAngle` (155°) return `"Stand fully upright"`
    - Return `nil` otherwise
    - _Requirements: 2.3, 2.4, 2.9_

  - [x] 2.4 Implement High Knees branch inside `formFeedbackMessage`
    - If `leftStage == .down` and `leftAngle > config.downAngle` (100°) return `"Lift knee higher"`
    - If `rightStage == .down` and `rightAngle > config.downAngle` (100°) return `"Lift knee higher"`
    - Return `nil` otherwise
    - _Requirements: 2.5_

  - [x] 2.5 Implement Arm Raises and Toe Touches branches inside `formFeedbackMessage`
    - Arm Raises: guard `stage == .up`; compute `avg`; if `avg < config.upAngle` (130°) return `"Raise arms fully overhead"`
    - Toe Touches: guard `stage == .down`; compute `avg`; if `avg > config.downAngle` (100°) return `"Bend further — reach for your toes"`
    - Return `nil` otherwise for both
    - _Requirements: 2.6, 2.7_

  - [ ]* 2.6 Write property test — `formFeedbackMessage` returns nil when stage is `.none` (Property 2)
    - **Property 2: `formFeedbackMessage` returns nil when stage is `.none`**
    - For every `ExerciseType` and arbitrary angle values, assert `formFeedbackMessage(..., stage: .none, leftStage: .none, rightStage: .none, ...) == nil`
    - Tag: `// Feature: exercise-form-feedback, Property 2: formFeedbackMessage returns nil when stage is .none`
    - **Validates: Requirements 2.8**

  - [ ]* 2.7 Write property test — arm correction for all sub-threshold angles (Property 3)
    - **Property 3: Arm form error detected for all sub-threshold angles (Jumping Jacks / Arm Raises)**
    - Generate arbitrary `angle` in `0..<130` for Jumping Jacks (`stage == .up`) and Arm Raises (`stage == .up`); assert the correct arm message is returned
    - Tag: `// Feature: exercise-form-feedback, Property 3: arm form error detected for all sub-threshold angles`
    - **Validates: Requirements 2.1, 2.6**

  - [ ]* 2.8 Write property test — arm error takes priority over leg spread error (Property 4)
    - **Property 4: Arm error takes priority over leg spread error (Jumping Jacks)**
    - Generate arbitrary `armAvg < 130` and `legAvg > 100` simultaneously with `stage == .up` and `exercise == .jumpingJacks`; assert result is `"Raise arms higher"`
    - Tag: `// Feature: exercise-form-feedback, Property 4: arm error takes priority over leg spread error`
    - **Validates: Requirements 2.2**

  - [ ]* 2.9 Write property test — squat messages are exercise-exclusive (Property 5)
    - **Property 5: Squat depth and upright messages are exercise-exclusive**
    - For every `ExerciseType` except `.squats`, for arbitrary angles and stages, assert result is never `"Go deeper — bend knees more"` or `"Stand fully upright"`
    - Tag: `// Feature: exercise-form-feedback, Property 5: squat depth and upright messages are exercise-exclusive`
    - **Validates: Requirements 2.9**

- [x] 3. Checkpoint — verify `formFeedbackMessage` in isolation
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Implement `evaluateForm` method
  - [x] 4.1 Add the `evaluateForm` private method to `ExerciseDetector`
    - Signature: `private func evaluateForm(points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint], exercise: ExerciseType, config: ExerciseConfig, state: inout State, feedbackSnapshot: String)`
    - Compute `now = Date().timeIntervalSince1970`; define `cooldown: TimeInterval = 1.5`
    - Re-use `jointTriplets(for: exercise)` to get primary left/right angles via `computeAngle`
    - For Jumping Jacks only, compute leg angles using the hip→knee→ankle triplet `(.leftHip, .leftKnee, .leftAnkle)` / `(.rightHip, .rightKnee, .rightAnkle)`; pass `nil` for all other exercises
    - Call `formFeedbackMessage(exercise:stage:leftStage:rightStage:leftAngle:rightAngle:leftLegAngle:rightLegAngle:config:)` to get `candidate`
    - _Requirements: 1.1, 1.8, 4.1, 4.2, 4.3, 4.5_

  - [x] 4.2 Implement priority + cooldown logic inside `evaluateForm`
    - If `candidate != nil` (FormFeedback): set `state.feedback = candidate!` and `state.lastFeedbackChangeTime = now` — always, regardless of cooldown
    - If `candidate == nil` and `now - state.lastFeedbackChangeTime < cooldown`: set `state.feedback = feedbackSnapshot` (restore pre-count value, blocking the counting logic's write)
    - If `candidate == nil` and cooldown has elapsed: leave `state.feedback` as written by counting logic; set `state.lastFeedbackChangeTime = now`
    - `evaluateForm` MUST NOT modify `state.repCount`, `state.stage`, `state.leftStage`, or `state.rightStage`
    - _Requirements: 3.1, 3.2, 4.1, 4.2, 4.3, 4.5, 5.3_

  - [ ]* 4.3 Write property test — FormFeedback always bypasses the cooldown (Property 6)
    - **Property 6: FormFeedback always bypasses the cooldown**
    - Generate arbitrary `State` with arbitrary `lastFeedbackChangeTime` (including `now`); when `formFeedbackMessage` returns non-nil, assert `state.feedback` equals that message after `evaluateForm`
    - Tag: `// Feature: exercise-form-feedback, Property 6: FormFeedback always bypasses the cooldown`
    - **Validates: Requirements 4.2**

  - [ ]* 4.4 Write property test — RepFeedback/CoachingMessage blocked within cooldown window (Property 7)
    - **Property 7: RepFeedback and CoachingMessage are blocked within the cooldown window**
    - Generate arbitrary `State` where `now - lastFeedbackChangeTime < 1.5` and `formFeedbackMessage` returns `nil`; assert `state.feedback == feedbackSnapshot` after `evaluateForm`
    - Tag: `// Feature: exercise-form-feedback, Property 7: RepFeedback and CoachingMessage blocked within cooldown`
    - **Validates: Requirements 4.1, 4.2**

  - [ ]* 4.5 Write property test — `evaluateForm` never modifies rep-counting fields (Property 8)
    - **Property 8: `evaluateForm` never modifies rep-counting fields**
    - Snapshot `repCount`, `stage`, `leftStage`, `rightStage` before calling `evaluateForm`; assert all four are identical after the call for arbitrary inputs
    - Tag: `// Feature: exercise-form-feedback, Property 8: evaluateForm never modifies rep-counting fields`
    - **Validates: Requirements 4.5, 5.3**

- [x] 5. Modify `process()` — snapshot pattern + `evaluateForm` call
  - [x] 5.1 Capture `feedbackSnapshot` and call `evaluateForm` in `process()`
    - At the top of `process()`, immediately before the counting branch, add: `let feedbackSnapshot = state.feedback`
    - After the existing counting branch (`countSingleSided` / `countLegExercise`), append: `evaluateForm(points: points, exercise: exercise, config: config, state: &state, feedbackSnapshot: feedbackSnapshot)`
    - No other line in `process()` changes
    - _Requirements: 3.5, 5.1_

  - [ ]* 5.2 Write property test — low-confidence joints suppress feedback changes (Property 1)
    - **Property 1: Low-confidence joints suppress feedback changes**
    - Construct a joint map where at least one required joint has confidence below 0.2; call `process()`; assert `state.feedback` is unchanged from its pre-call value
    - Tag: `// Feature: exercise-form-feedback, Property 1: low-confidence joints suppress feedback changes`
    - **Validates: Requirements 1.2**

  - [ ]* 5.3 Write property test — rep counting unaffected by simultaneous form errors (Property 9)
    - **Property 9: Rep counting is unaffected by simultaneous form errors**
    - Construct a valid rep-transition scenario (angle crossing down-threshold after up-threshold, timing guard satisfied) combined with a form error condition; assert `state.repCount` increments by exactly 1
    - Tag: `// Feature: exercise-form-feedback, Property 9: rep counting is unaffected by simultaneous form errors`
    - **Validates: Requirements 3.5, 5.2**

- [x] 6. Final checkpoint — Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- All changes are in `JumpingJackCounter.swift` only — `CameraFeedView.swift`, `CameraViewModel.swift`, and `VisionBodyPoseAnalyzer.swift` are not modified
- The snapshot pattern (`feedbackSnapshot = state.feedback` captured before counting) is the key mechanism that lets `evaluateForm` restore the pre-count feedback when the cooldown blocks a non-form message
- `formFeedbackMessage` is a pure function — no state reads or writes, safe to test in complete isolation
- `evaluateForm` reads `state.stage`, `state.leftStage`, `state.rightStage` (read-only) and writes only `state.feedback` and `state.lastFeedbackChangeTime`
- Property tests require a Swift PBT library (e.g., SwiftCheck or Genything) added to the test target
- Each property test must run a minimum of 100 iterations

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["2.1"] },
    { "id": 2, "tasks": ["2.2", "2.3", "2.4", "2.5"] },
    { "id": 3, "tasks": ["2.6", "2.7", "2.8", "2.9", "4.1"] },
    { "id": 4, "tasks": ["4.2", "4.3", "4.4", "4.5"] },
    { "id": 5, "tasks": ["5.1"] },
    { "id": 6, "tasks": ["5.2", "5.3"] }
  ]
}
```
