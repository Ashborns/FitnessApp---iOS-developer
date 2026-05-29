# Design Document — Exercise Form Correction Feedback

## Overview

This feature adds real-time form correction feedback to the camera workout screen by modifying **exactly one file**: `JumpingJackCounter.swift`. No other file is touched.

The change is surgical:

1. One new field is added to `ExerciseDetector.State` (`lastFeedbackChangeTime`).
2. One call to `evaluateForm()` is appended at the end of `process()`, after all rep-counting logic has already run.
3. Two new private methods are added to `ExerciseDetector`: `evaluateForm()` and `formFeedbackMessage()`.

The existing propagation path — `CameraViewModel.onPoseDetected` → `self.feedback = self.detectorState.feedback` → `CameraFeedView.feedbackBanner` — already carries the updated value to the UI with no changes required in those files.

### Files Modified

| File | Change |
|------|--------|
| `JumpingJackCounter.swift` | Add `lastFeedbackChangeTime` to `State`; add `evaluateForm()` call in `process()`; add two private methods |

### Files NOT Modified

| File | Reason |
|------|--------|
| `CameraFeedView.swift` | Already reads `viewModel.feedback`; no structural change needed |
| `CameraViewModel.swift` | Already assigns `self.feedback = self.detectorState.feedback` in `onPoseDetected` |
| `VisionBodyPoseAnalyzer.swift` | Unchanged — frame capture and pose delivery are unaffected |

---

## Architecture

The feature slots into the existing data-flow pipeline without altering any interface:

```
VisionBodyPoseAnalyzer
  │  (every 3rd frame, ~10 fps)
  ▼
CameraViewModel.onPoseDetected
  │
  ▼
ExerciseDetector.process(observation:exercise:state:)
  │
  ├─ 1. computeAngle() — joint angle extraction (unchanged)
  ├─ 2. countSingleSided() / countLegExercise() — rep counting (unchanged)
  └─ 3. evaluateForm() ◄── NEW: reads stage/angles, writes state.feedback only
         │
         └─ formFeedbackMessage() ◄── NEW: pure function, returns String? or nil
  │
  ▼
state.feedback (updated by evaluateForm or by counting logic)
  │
  ▼
CameraViewModel: self.feedback = self.detectorState.feedback  (unchanged)
  │
  ▼
CameraFeedView.feedbackBanner  (unchanged)
```

**Key invariant**: `evaluateForm()` runs *after* counting. It reads `state.stage`, `state.leftStage`, `state.rightStage`, and `state.repCount` (read-only) but never writes them. It only writes `state.feedback` and `state.lastFeedbackChangeTime`.

---

## Components and Interfaces

### 2.1 Modified `ExerciseDetector.State`

**Diff — one field added:**

```swift
struct State {
    var repCount: Int = 0
    var phase: String = "Ready"
    var feedback: String = "Stand in frame to begin"

    var stage: Stage = .none
    var leftStage: Stage = .none
    var rightStage: Stage = .none
    var lastCountTime: TimeInterval = 0
    var angleHistory: [Double] = []

    // NEW ↓
    var lastFeedbackChangeTime: TimeInterval = 0

    static var initial: State { State() }
}
```

`State.initial` returns `State()`, so the default value `0` is automatically used on every reset — no change to `State.initial` is required.

---

### 2.2 Modified `process()` — call site for `evaluateForm`

The only change to `process()` is a single call appended after the existing counting branch:

```swift
func process(
    observation: VNHumanBodyPoseObservation,
    exercise: ExerciseType,
    state: inout State
) {
    guard let points = try? observation.recognizedPoints(.all),
          let config = ExerciseConfig.configs[exercise] else { return }

    let triplets = jointTriplets(for: exercise)

    guard
        let leftAngle = computeAngle(points, joints: triplets.left),
        let rightAngle = computeAngle(points, joints: triplets.right)
    else {
        state.feedback = "Move back — show your full body"
        return
    }

    // ── Existing rep-counting logic (UNCHANGED) ──────────────────────────
    if config.isLegExercise {
        countLegExercise(left: leftAngle, right: rightAngle,
                         config: config, state: &state, exercise: exercise)
    } else {
        let avgAngle = (leftAngle + rightAngle) / 2
        let smoothed = smoothAngle(avgAngle, history: &state.angleHistory)
        countSingleSided(angle: smoothed, config: config,
                         state: &state, exercise: exercise)
    }

    // ── NEW: form evaluation runs AFTER counting ─────────────────────────
    evaluateForm(points: points, exercise: exercise,
                 config: config, state: &state)
}
```

No other line in `process()` changes.

---

### 2.3 `evaluateForm(points:exercise:config:state:)`

**Signature:**

```swift
private func evaluateForm(
    points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint],
    exercise: ExerciseType,
    config: ExerciseConfig,
    state: inout State
)
```

**Pseudocode:**

```
func evaluateForm(points, exercise, config, state):

    now = Date().timeIntervalSince1970
    cooldown: TimeInterval = 1.5

    // 1. Compute angles needed for form evaluation
    //    Re-use the same triplets already used for counting.
    triplets = jointTriplets(for: exercise)
    leftAngle  = computeAngle(points, joints: triplets.left)   // may be nil
    rightAngle = computeAngle(points, joints: triplets.right)  // may be nil

    // 2. Ask the pure function for a candidate form message
    candidate: String? = formFeedbackMessage(
        exercise:   exercise,
        stage:      state.stage,        // read-only
        leftStage:  state.leftStage,    // read-only (High Knees)
        rightStage: state.rightStage,   // read-only (High Knees)
        leftAngle:  leftAngle,
        rightAngle: rightAngle,
        config:     config
    )

    // 3. Apply priority + cooldown rules
    if let formMsg = candidate:
        // FormFeedback — ALWAYS bypasses cooldown
        state.feedback = formMsg
        state.lastFeedbackChangeTime = now

    else:
        // RepFeedback or CoachingMessage — subject to cooldown
        // (These were already written into state.feedback by counting logic above.)
        // Only allow the change if cooldown has elapsed.
        //
        // NOTE: counting logic already wrote the RepFeedback / CoachingMessage
        // into state.feedback. We need to decide whether to keep it or revert.
        //
        // Implementation approach: capture the feedback value BEFORE counting
        // runs (in process()), pass it in, and restore it if cooldown blocks.
        // Simpler alternative (used here): evaluateForm receives the pre-count
        // feedback via a snapshot taken at the top of process().
        //
        // Concrete implementation (see Section 2.4 for the snapshot pattern):
        if now - state.lastFeedbackChangeTime < cooldown:
            state.feedback = state.feedback   // no-op: retain current value
            // (the counting logic's write is effectively reverted by the snapshot)
        else:
            // Allow the RepFeedback / CoachingMessage written by counting logic
            state.lastFeedbackChangeTime = now
```

**Snapshot pattern** (how cooldown interacts with counting writes):

Because `countSingleSided` / `countLegExercise` write directly to `state.feedback`, `evaluateForm` needs to know what the feedback was *before* counting ran in order to restore it when the cooldown blocks. The cleanest approach is to capture a snapshot at the top of `process()`:

```swift
// At the top of process(), before counting:
let feedbackSnapshot = state.feedback

// ... counting runs, may write state.feedback ...

// Pass snapshot into evaluateForm:
evaluateForm(points: points, exercise: exercise,
             config: config, state: &state,
             feedbackSnapshot: feedbackSnapshot)
```

Inside `evaluateForm`, when no FormFeedback and cooldown is active:

```swift
state.feedback = feedbackSnapshot   // restore pre-count value
```

This keeps the cooldown semantics clean: the banner only changes when either (a) FormFeedback fires, or (b) 1.5 s have elapsed since the last change.

---

### 2.4 `formFeedbackMessage(exercise:stage:leftStage:rightStage:leftAngle:rightAngle:config:) -> String?`

**Signature:**

```swift
private func formFeedbackMessage(
    exercise:   ExerciseType,
    stage:      Stage,
    leftStage:  Stage,
    rightStage: Stage,
    leftAngle:  Double?,
    rightAngle: Double?,
    config:     ExerciseConfig
) -> String?
```

This is a **pure function** — no state mutation, no side effects. Returns a corrective string or `nil` if form is correct (or stage is `.none`).

**Full per-exercise logic:**

```
func formFeedbackMessage(exercise, stage, leftStage, rightStage,
                         leftAngle, rightAngle, config) -> String?:

    // Guard: no message when stage is unknown
    if stage == .none AND exercise != .highKnees:
        return nil

    switch exercise:

    // ── Jumping Jacks ────────────────────────────────────────────────────
    case .jumpingJacks:
        guard stage == .up else return nil
        guard let L = leftAngle, let R = rightAngle else return nil
        let armAvg = (L + R) / 2

        // Arm error takes priority over leg error
        if armAvg < config.upAngle:          // < 130°
            return "Raise arms higher"

        // Leg spread check — requires separate hip→knee→ankle triplet
        let legTriplets = Triplets(
            left:  (.leftHip,  .leftKnee,  .leftAnkle),
            right: (.rightHip, .rightKnee, .rightAnkle)
        )
        if let legL = computeAngle(points, joints: legTriplets.left),
           let legR = computeAngle(points, joints: legTriplets.right):
            let legAvg = (legL + legR) / 2
            if legAvg > 100:                 // legs not spread wide enough
                return "Spread legs wider"

        return nil

    // ── Squats ───────────────────────────────────────────────────────────
    case .squats:
        guard let L = leftAngle, let R = rightAngle else return nil
        let avg = (L + R) / 2

        if stage == .down AND avg > config.downAngle:    // > 100°
            return "Go deeper — bend knees more"
        if stage == .up   AND avg < config.upAngle:      // < 155°
            return "Stand fully upright"
        return nil

    // ── High Knees ───────────────────────────────────────────────────────
    case .highKnees:
        // Evaluate the leg that most recently entered .down
        // leftStage / rightStage are read from state (read-only)
        if leftStage == .down:
            if let L = leftAngle, L > config.downAngle:  // > 100°
                return "Lift knee higher"
        if rightStage == .down:
            if let R = rightAngle, R > config.downAngle: // > 100°
                return "Lift knee higher"
        return nil

    // ── Arm Raises ───────────────────────────────────────────────────────
    case .armRaises:
        guard stage == .up else return nil
        guard let L = leftAngle, let R = rightAngle else return nil
        let avg = (L + R) / 2
        if avg < config.upAngle:                         // < 130°
            return "Raise arms fully overhead"
        return nil

    // ── Toe Touches ──────────────────────────────────────────────────────
    case .toeTouches:
        guard stage == .down else return nil
        guard let L = leftAngle, let R = rightAngle else return nil
        let avg = (L + R) / 2
        if avg > config.downAngle:                       // > 100°
            return "Bend further — reach for your toes"
        return nil
```

> **Note on Jumping Jacks leg spread**: `formFeedbackMessage` receives `leftAngle`/`rightAngle` which are the shoulder angles (hip→shoulder→wrist) for Jumping Jacks. The leg spread check requires a *second* angle computation (hip→knee→ankle). `evaluateForm` must pass the `points` dictionary to `formFeedbackMessage`, or compute the leg angles separately before calling it. The cleanest approach is to compute both angle pairs in `evaluateForm` and pass all four values in.

**Revised signature (preferred):**

```swift
private func formFeedbackMessage(
    exercise:    ExerciseType,
    stage:       Stage,
    leftStage:   Stage,
    rightStage:  Stage,
    leftAngle:   Double?,   // primary triplet (per exercise)
    rightAngle:  Double?,   // primary triplet (per exercise)
    leftLegAngle:  Double?, // hip→knee→ankle left  (Jumping Jacks only)
    rightLegAngle: Double?, // hip→knee→ankle right (Jumping Jacks only)
    config:      ExerciseConfig
) -> String?
```

For all exercises other than Jumping Jacks, `leftLegAngle` and `rightLegAngle` are passed as `nil` and ignored.

---

## Data Models

No new data models are introduced. The only data change is one new field on the existing value type:

```swift
// ExerciseDetector.State — existing fields unchanged, one field added
struct State {
    var repCount: Int = 0                        // existing
    var phase: String = "Ready"                  // existing
    var feedback: String = "Stand in frame to begin" // existing
    var stage: Stage = .none                     // existing
    var leftStage: Stage = .none                 // existing
    var rightStage: Stage = .none                // existing
    var lastCountTime: TimeInterval = 0          // existing
    var angleHistory: [Double] = []              // existing
    var lastFeedbackChangeTime: TimeInterval = 0 // NEW
    static var initial: State { State() }        // existing — no change needed
}
```

**Angle thresholds** (unchanged from `ExerciseConfig`):

| Exercise | upAngle | downAngle | Form check phase |
|----------|---------|-----------|-----------------|
| Jumping Jacks | 130° | 60° | `.up` (arms + legs) |
| Squats | 155° | 100° | `.down` (depth) + `.up` (upright) |
| High Knees | 155° | 100° | `.down` per leg (knee height) |
| Arm Raises | 130° | 60° | `.up` (overhead) |
| Toe Touches | 155° | 100° | `.down` (bend depth) |

---

## Feedback Priority and Cooldown Flow

```
process() called
│
├─ computeAngle() → leftAngle, rightAngle
│   └─ if nil → feedback = "Move back…", return early
│
├─ feedbackSnapshot = state.feedback   ← capture BEFORE counting
│
├─ countSingleSided() / countLegExercise()
│   ├─ may write state.feedback = repFeedback(...)
│   └─ may write state.feedback = coachingMessage
│
└─ evaluateForm(…, feedbackSnapshot: feedbackSnapshot)
    │
    ├─ formFeedbackMessage() → candidate
    │
    ├─ candidate != nil  (FormFeedback)
    │   ├─ state.feedback = candidate        ← ALWAYS (bypass cooldown)
    │   └─ state.lastFeedbackChangeTime = now
    │
    └─ candidate == nil  (RepFeedback or CoachingMessage)
        │
        ├─ now - lastFeedbackChangeTime < 1.5s
        │   └─ state.feedback = feedbackSnapshot  ← RESTORE (block change)
        │
        └─ now - lastFeedbackChangeTime >= 1.5s
            ├─ state.feedback stays as written by counting logic
            └─ state.lastFeedbackChangeTime = now
```

**Priority summary:**

| Priority | Message type | Cooldown |
|----------|-------------|----------|
| 1 (highest) | FormFeedback | Bypassed — always immediate |
| 2 | RepFeedback | Subject to 1.5 s cooldown |
| 3 | CoachingMessage | Subject to 1.5 s cooldown |

---

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Low-confidence joints suppress feedback changes

*For any* `ExerciseDetector.State` and any joint point map where at least one joint required by the active exercise has confidence below 0.2 (or is absent), calling `process()` SHALL leave `state.feedback` unchanged from its value before the call.

**Validates: Requirements 1.2**

---

### Property 2: `formFeedbackMessage` returns nil when stage is `.none`

*For any* exercise type and any angle values, if `stage == .none` (and for High Knees, both `leftStage == .none` and `rightStage == .none`), `formFeedbackMessage()` SHALL return `nil`.

**Validates: Requirements 2.8**

---

### Property 3: Arm form error detected for all sub-threshold angles (Jumping Jacks / Arm Raises)

*For any* averaged shoulder angle strictly below the exercise's `upAngle` threshold (130°) when `stage == .up`, `formFeedbackMessage()` SHALL return the appropriate arm correction message ("Raise arms higher" for Jumping Jacks, "Raise arms fully overhead" for Arm Raises).

**Validates: Requirements 2.1, 2.6**

---

### Property 4: Arm error takes priority over leg spread error (Jumping Jacks)

*For any* combination of shoulder angle below 130° AND leg spread angle above 100° when `stage == .up` and `exercise == .jumpingJacks`, `formFeedbackMessage()` SHALL return "Raise arms higher" (not "Spread legs wider").

**Validates: Requirements 2.2**

---

### Property 5: Squat depth and upright messages are exercise-exclusive

*For any* exercise other than `.squats`, *for any* angle values and *any* stage, `formFeedbackMessage()` SHALL NOT return "Go deeper — bend knees more" or "Stand fully upright".

**Validates: Requirements 2.9**

---

### Property 6: FormFeedback always bypasses the cooldown

*For any* `ExerciseDetector.State` — regardless of `lastFeedbackChangeTime` (including values set to `Date().timeIntervalSince1970`, i.e., zero elapsed time) — when `formFeedbackMessage()` returns a non-nil string, `evaluateForm()` SHALL update `state.feedback` to that string and update `state.lastFeedbackChangeTime`.

**Validates: Requirements 4.2**

---

### Property 7: RepFeedback and CoachingMessage are blocked within the cooldown window

*For any* `ExerciseDetector.State` where `Date().timeIntervalSince1970 - state.lastFeedbackChangeTime < 1.5` and `formFeedbackMessage()` returns `nil`, calling `evaluateForm()` SHALL leave `state.feedback` equal to its value at the start of the `process()` invocation (the pre-count snapshot).

**Validates: Requirements 4.1, 4.2**

---

### Property 8: `evaluateForm` never modifies rep-counting fields

*For any* `ExerciseDetector.State`, calling `evaluateForm()` SHALL NOT change `state.repCount`, `state.stage`, `state.leftStage`, or `state.rightStage`.

**Validates: Requirements 4.5, 5.3**

---

### Property 9: Rep counting is unaffected by simultaneous form errors

*For any* valid rep transition (angle crossing the down-threshold after being above the up-threshold, with timing guard satisfied) that occurs in the same `process()` invocation as a detected form error, `state.repCount` SHALL increase by exactly 1.

**Validates: Requirements 3.5, 5.2**

---

## Error Handling

| Scenario | Handling |
|----------|----------|
| One or more required joints missing or below confidence 0.2 | `computeAngle()` returns `nil`; `process()` sets `state.feedback = "Move back — show your full body"` and returns early. `evaluateForm` is never reached. |
| Both angles nil inside `formFeedbackMessage` | All guard-let clauses return `nil` — no message, no crash. |
| `ExerciseConfig.configs[exercise]` returns nil | `process()` returns early at the top-level guard. |
| `lastFeedbackChangeTime` is 0 (initial state) | `now - 0` is always ≥ 1.5 s in practice, so the first message after reset always goes through. |
| Simultaneous arm + leg form error (Jumping Jacks) | Arm error takes priority — explicit ordering in `formFeedbackMessage`. |

---

## Testing Strategy

### Unit Tests (example-based)

Focus on concrete scenarios and boundary conditions:

- `ExerciseConfig` values match the spec (upAngle/downAngle per exercise).
- `State.initial.lastFeedbackChangeTime == 0`.
- `formFeedbackMessage` returns `nil` for `stage == .none` on each exercise.
- `formFeedbackMessage` returns the correct string at the exact threshold boundary (e.g., angle == 129.9° vs 130.0°).
- Arm priority: both arm and leg errors present → "Raise arms higher" returned.
- Squat messages never appear for non-squat exercises.
- After `selectExercise()` / `resetCounter()`, `detectorState.lastFeedbackChangeTime == 0`.
- First `process()` call after reset with valid pose and no form error → CoachingMessage displayed.

### Property-Based Tests

Use a Swift property-based testing library (e.g., **SwiftCheck** or **Genything**). Each property test runs a minimum of **100 iterations**.

Tag format: `// Feature: exercise-form-feedback, Property N: <property text>`

**Property 1 — Low-confidence suppression**
```swift
// Feature: exercise-form-feedback, Property 1: low-confidence joints suppress feedback changes
// For any state and any joint map with at least one required joint below 0.2 confidence,
// process() leaves state.feedback unchanged.
property("low-confidence joints suppress feedback changes") <- forAll(...) { ... }
```

**Property 2 — nil when stage is .none**
```swift
// Feature: exercise-form-feedback, Property 2: formFeedbackMessage returns nil when stage is .none
property("formFeedbackMessage returns nil for stage .none") <- forAll(...) { ... }
```

**Property 3 — Arm correction for all sub-threshold angles**
```swift
// Feature: exercise-form-feedback, Property 3: arm form error detected for all sub-threshold angles
property("arm correction message for any angle below upAngle") <- forAll(...) { ... }
```

**Property 4 — Arm priority over leg spread**
```swift
// Feature: exercise-form-feedback, Property 4: arm error takes priority over leg spread error
property("arm error takes priority when both errors present") <- forAll(...) { ... }
```

**Property 5 — Squat messages are exercise-exclusive**
```swift
// Feature: exercise-form-feedback, Property 5: squat depth and upright messages are exercise-exclusive
property("squat messages never appear for non-squat exercises") <- forAll(...) { ... }
```

**Property 6 — FormFeedback bypasses cooldown**
```swift
// Feature: exercise-form-feedback, Property 6: FormFeedback always bypasses the cooldown
property("form feedback always updates regardless of lastFeedbackChangeTime") <- forAll(...) { ... }
```

**Property 7 — RepFeedback blocked within cooldown**
```swift
// Feature: exercise-form-feedback, Property 7: RepFeedback and CoachingMessage blocked within cooldown
property("non-form feedback blocked when cooldown has not elapsed") <- forAll(...) { ... }
```

**Property 8 — evaluateForm never modifies rep-counting fields**
```swift
// Feature: exercise-form-feedback, Property 8: evaluateForm never modifies rep-counting fields
property("evaluateForm does not mutate repCount, stage, leftStage, rightStage") <- forAll(...) { ... }
```

**Property 9 — Rep counting unaffected by form errors**
```swift
// Feature: exercise-form-feedback, Property 9: rep counting is unaffected by simultaneous form errors
property("repCount increments correctly even when form error is active") <- forAll(...) { ... }
```

### Integration / Smoke Tests

- `CameraFeedView.swift` is byte-for-byte identical to the pre-feature version (no structural changes).
- `CameraViewModel.swift` is byte-for-byte identical to the pre-feature version.
- `VisionBodyPoseAnalyzer.swift` is byte-for-byte identical to the pre-feature version.
- End-to-end: with a live camera feed, performing a Jumping Jack with arms below 130° causes "Raise arms higher" to appear in the feedback banner within one detection cycle (~100 ms).
