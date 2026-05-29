# Requirements Document

## Introduction

This feature adds real-time exercise form correction feedback to the camera workout screen. During a workout, the app analyzes joint angles each frame and compares them against per-exercise thresholds. When a user's form deviates from the expected range — for example, arms not raised high enough during Jumping Jacks or knees not deep enough in a Squat — a specific corrective message replaces the motivational text in the existing feedback banner at the bottom of the camera screen. When form is correct, the banner reverts to the normal rep-count or coaching message. Feedback is debounced to prevent flickering.

The feature covers all five supported exercises: Jumping Jacks, Squats, High Knees, Arm Raises, and Toe Touches.

## Glossary

- **ExerciseDetector**: The Swift struct in `JumpingJackCounter.swift` that processes `VNHumanBodyPoseObservation` frames, computes joint angles, counts reps, and writes to `ExerciseDetector.State.feedback`.
- **ExerciseConfig**: The private struct that holds `upAngle` and `downAngle` thresholds per exercise type.
- **FeedbackBanner**: The `feedbackBanner` view in `CameraFeedView` that displays `CameraViewModel.feedback` as a text banner at the bottom of the camera screen.
- **FormFeedback**: A corrective message generated when a measured joint angle does not meet the required threshold for the current exercise phase.
- **RepFeedback**: The motivational message shown after a rep is counted (e.g., "5 reps — keep going!").
- **CoachingMessage**: The initial instructional message shown before the first rep is counted.
- **FeedbackCooldown**: A minimum time interval (1.5 seconds) that must elapse before the displayed feedback message is allowed to change, preventing per-frame flickering.
- **Phase**: The current movement phase of an exercise — `up` (extended position, `state.stage == .up`) or `down` (contracted/lowered position, `state.stage == .down`).
- **upAngle**: The joint angle threshold that must be reached for the "up" phase to be recognized as complete.
- **downAngle**: The joint angle threshold that must be reached for the "down" phase to be recognized as complete.

---

## Requirements

### Requirement 1: Form Angle Evaluation Per Exercise

**User Story:** As a user performing an exercise, I want the app to evaluate whether my joint angles meet the required thresholds, so that the app can determine whether my form is correct or needs correction.

#### Acceptance Criteria

1. WHEN a `VNHumanBodyPoseObservation` is processed, THE `ExerciseDetector` SHALL compute the relevant joint angles for the active exercise using the existing `computeAngle()` method.
2. IF any joint required for the active exercise has a Vision confidence value below 0.2, or is absent from the observation, THEN THE `ExerciseDetector` SHALL skip angle computation and rep counting for that frame and retain the previously displayed feedback message without modification.
3. WHEN the active exercise is Jumping Jacks or Arm Raises, THE `ExerciseDetector` SHALL compute the shoulder angle (hip → shoulder → wrist) on both the left and right sides and use the average of the two angles for threshold comparison.
4. WHEN the active exercise is Squats, THE `ExerciseDetector` SHALL compute the knee angle (hip → knee → ankle) on both the left and right sides and use the average of the two angles for threshold comparison.
5. WHEN the active exercise is High Knees, THE `ExerciseDetector` SHALL evaluate the hip angle (shoulder → hip → knee) on the left and right sides using separate per-side stage tracking, counting one rep per side each time that side's angle transitions from above the up-threshold to below the down-threshold.
6. WHEN the active exercise is Toe Touches, THE `ExerciseDetector` SHALL compute the torso bend angle (shoulder → hip → ankle) on both the left and right sides and use the average of the two angles for threshold comparison.
7. THE `ExerciseDetector` SHALL use the following angle thresholds per exercise for form evaluation: Jumping Jacks and Arm Raises — up-threshold 130°, down-threshold 60°; Squats — up-threshold 155°, down-threshold 100°; High Knees — up-threshold 155°, down-threshold 100°; Toe Touches — up-threshold 155°, down-threshold 100°.
8. THE `ExerciseDetector` SHALL use the same joint triplets already defined in `jointTriplets(for:)` for form evaluation, with no new joint definitions required.

---

### Requirement 2: Form Correction Message Generation

**User Story:** As a user performing an exercise, I want to receive a specific corrective message when my form is wrong, so that I know exactly what to fix.

#### Acceptance Criteria

1. WHEN the active exercise is Jumping Jacks and `state.stage == .up` and the averaged shoulder angle is below 130° (upAngle), THE `ExerciseDetector` SHALL set `state.feedback` to "Raise arms higher".
2. WHEN the active exercise is Jumping Jacks and `state.stage == .up` and the averaged leg spread angle (hip → knee → ankle, averaged left and right) is above 100° (indicating legs are not spread wide enough), THE `ExerciseDetector` SHALL set `state.feedback` to "Spread legs wider". IF both arm and leg form errors are detected simultaneously, THEN the arm error ("Raise arms higher") SHALL take priority.
3. WHEN the active exercise is Squats and `state.stage == .down` and the averaged knee angle is above 100° (downAngle, not deep enough), THE `ExerciseDetector` SHALL set `state.feedback` to "Go deeper — bend knees more".
4. WHEN the active exercise is Squats and `state.stage == .up` and the averaged knee angle is below 155° (upAngle, not fully upright), THE `ExerciseDetector` SHALL set `state.feedback` to "Stand fully upright".
5. WHEN the active exercise is High Knees and the currently active leg's `state.leftStage` or `state.rightStage` is `.down` and that leg's hip angle is above 100° (downAngle, knee not raised high enough), THE `ExerciseDetector` SHALL set `state.feedback` to "Lift knee higher". The "active leg" is the leg whose stage most recently transitioned to `.down`.
6. WHEN the active exercise is Arm Raises and `state.stage == .up` and the averaged shoulder angle is below 130° (upAngle), THE `ExerciseDetector` SHALL set `state.feedback` to "Raise arms fully overhead".
7. WHEN the active exercise is Toe Touches and `state.stage == .down` and the averaged torso bend angle is above 100° (downAngle, not bending far enough), THE `ExerciseDetector` SHALL set `state.feedback` to "Bend further — reach for your toes".
8. THE `ExerciseDetector` SHALL generate form correction messages only for the phase that is currently active (`state.stage`), not for the opposite phase. IF `state.stage == .none`, THEN no form correction message SHALL be generated.
9. WHILE any exercise other than Squats is active, THE `ExerciseDetector` SHALL NOT apply Squat-specific form feedback messages ("Go deeper — bend knees more" or "Stand fully upright").

---

### Requirement 3: Feedback Priority Ordering

**User Story:** As a user, I want the most actionable message to appear in the banner at any given moment, so that I am never shown a stale or irrelevant message.

#### Acceptance Criteria

1. THE `ExerciseDetector` SHALL apply feedback in the following priority order within each `process()` invocation: (1) FormFeedback, (2) RepFeedback, (3) CoachingMessage.
2. WHEN a FormFeedback condition is detected in the current `process()` invocation, THE `ExerciseDetector` SHALL set `state.feedback` to the form correction message, overriding any RepFeedback or CoachingMessage that would otherwise be set in the same invocation.
3. WHEN no FormFeedback condition is detected and `state.repCount` was incremented within the same `process()` invocation, THE `ExerciseDetector` SHALL set `state.feedback` to the RepFeedback string.
4. WHEN no FormFeedback condition is detected and `state.repCount` is 0 (no rep has been counted yet in the current exercise session), THE `ExerciseDetector` SHALL set `state.feedback` to the CoachingMessage for the active exercise.
5. THE `ExerciseDetector` SHALL NOT suppress or delay rep counting when a FormFeedback condition is active — rep counting logic SHALL run before feedback logic in `process()`, and both SHALL execute on every frame that has valid joint data.

---

### Requirement 4: Feedback Debounce / Cooldown

**User Story:** As a user, I want the feedback message to remain stable and readable, so that it does not flicker or change every frame.

#### Acceptance Criteria

1. THE `ExerciseDetector` SHALL enforce a minimum cooldown interval of 1.5 seconds between changes to `state.feedback`.
2. WHEN a new feedback message candidate is generated and the elapsed time since `state.lastFeedbackChangeTime` is less than 1.5 seconds, THE `ExerciseDetector` SHALL retain the current `state.feedback` value without updating it, EXCEPT when the candidate is a FormFeedback message — FormFeedback SHALL always bypass the cooldown and update `state.feedback` immediately.
3. WHEN a new feedback message candidate is generated and the elapsed time since `state.lastFeedbackChangeTime` is 1.5 seconds or more, THE `ExerciseDetector` SHALL update `state.feedback` to the new message and set `state.lastFeedbackChangeTime` to the current timestamp.
4. THE `ExerciseDetector` SHALL store the cooldown timestamp as `lastFeedbackChangeTime: TimeInterval` in `ExerciseDetector.State`, initialized to `0` in `State.initial`.
5. THE `ExerciseDetector` SHALL NOT modify `state.repCount`, `state.stage`, `state.leftStage`, or `state.rightStage` during form feedback evaluation. THE `ExerciseDetector` MAY modify `state.feedback` and `state.lastFeedbackChangeTime` during form evaluation.
6. WHEN the user switches exercises or resets the workout, `ExerciseDetector.State.initial` SHALL set `lastFeedbackChangeTime` to `0`, allowing the first feedback message for the new exercise to appear immediately without waiting for the cooldown.

---

### Requirement 5: No Disruption to Existing Rep Counting

**User Story:** As a user, I want my rep count to remain accurate even when form correction feedback is active, so that my workout data is not affected by the feedback system.

#### Acceptance Criteria

1. THE `ExerciseDetector` SHALL execute rep counting logic before form feedback evaluation within `process()`, so that `state.repCount`, `state.stage`, `state.leftStage`, and `state.rightStage` are fully updated before any form feedback check runs.
2. WHEN a form correction message is displayed in `state.feedback`, THE `ExerciseDetector` SHALL continue to increment `state.repCount` when a valid rep transition is detected in the same or subsequent frames.
3. THE `ExerciseDetector` SHALL NOT read or write `state.stage`, `state.leftStage`, `state.rightStage`, or `state.repCount` inside the form feedback evaluation block. THE `ExerciseDetector` MAY read these values to determine which form feedback message to generate, but SHALL NOT modify them.

---

### Requirement 6: FeedbackBanner Display

**User Story:** As a user watching the camera screen, I want the corrective message to appear in the same banner I already see, so that I do not need to look elsewhere for feedback.

#### Acceptance Criteria

1. THE `FeedbackBanner` in `CameraFeedView` SHALL display `CameraViewModel.feedback` without any structural changes to `CameraFeedView.swift`.
2. WHEN `ExerciseDetector.State.feedback` is updated with a FormFeedback message, THE `CameraViewModel` SHALL propagate the updated value to `CameraViewModel.feedback` within 100 ms (≤ one detection cycle at ~10 fps), using the existing `self.feedback = self.detectorState.feedback` assignment in the `onPoseDetected` callback.
3. THE `FeedbackBanner` SHALL display FormFeedback, RepFeedback, and CoachingMessage messages using the same font, color, and layout — no visual distinction between message types is required.

---

### Requirement 7: State Reset on Exercise Switch and Workout Reset

**User Story:** As a user switching exercises or resetting my workout, I want the feedback state to clear cleanly, so that stale form messages from a previous exercise do not appear.

#### Acceptance Criteria

1. WHEN the user selects a new exercise via `CameraViewModel.selectExercise(_:)`, THE `CameraViewModel` SHALL reset `detectorState` to `ExerciseDetector.State.initial`, which SHALL set `lastFeedbackChangeTime` to `0`.
2. WHEN the user taps the Reset button, triggering `CameraViewModel.resetCounter()`, THE `CameraViewModel` SHALL reset `detectorState` to `ExerciseDetector.State.initial`, which SHALL set `lastFeedbackChangeTime` to `0`.
3. AFTER a state reset, THE `ExerciseDetector` SHALL display the CoachingMessage for the newly selected exercise within 100 ms of the first valid pose observation received after the reset, subject to the normal feedback priority rules (FormFeedback > RepFeedback > CoachingMessage).
