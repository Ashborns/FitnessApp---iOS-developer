# Design Document

## Overview

This feature adds two capabilities to the existing camera workout screen (`CameraFeedView` + `CameraViewModel`):

1. **ML-based squat detection** — a new Core ML action classifier, `FlexFitClassifier.mlmodel`, becomes the source of truth for the Squats exercise only. It is owned by `FlexFitClassifierManager`, a new `@MainActor` `ObservableObject` singleton that mirrors the existing `ExerciseClassifierManager` exactly (same `static let shared`, same `loadModel()` / `MLModelConfiguration.computeUnits = .cpuAndNeuralEngine` pattern, same sliding `poseWindow`, same `featureValue(for:)`-based output reading). A new `SquatRepCounter` derives reps from label transitions. When the model fails to load, the existing rule-based `ExerciseDetector` (in `JumpingJackCounter.swift`) handles Squats as a fallback.

2. **On-device voice coaching** — a new `@MainActor` singleton `VoiceCoach` wraps `AVSpeechSynthesizer` and converts `CoachingEvent` values into spoken cues. It mirrors the `HapticManager.shared` pattern. `CameraViewModel` requests events at the existing trigger points (the same places that already call `HapticManager.shared.repCounted()` / `.milestone()`), a `VoiceMuteToggle` is added to `CameraFeedView`'s top bar, and `VoicePreference` is persisted in `UserDefaults` under key `voiceCoachEnabled`.

Both capabilities are local-only: no recording, no network, no disk writes of spoken text. The design reuses the existing frame pipeline in `CameraViewModel.poseAnalyzer.onPoseDetected` rather than introducing a parallel path.

### Design Goals

- **Mirror existing patterns** — `FlexFitClassifierManager` is a near-clone of `ExerciseClassifierManager`; `VoiceCoach` is a near-clone of `HapticManager`'s singleton shape. No new architectural concepts.
- **Squats-only routing** — only Squats frames go through `FlexFitClassifier`; all other exercises keep using `ExerciseDetector` unchanged.
- **Graceful degradation** — a failed model load or silent synthesizer never blocks rep counting or form feedback.
- **iOS 16.4 compliant** — `ObservableObject` + `@Published`, `.onChange(of:perform:)` single-param form, no `@Observable`/`@Bindable`/SwiftData.

## Architecture

The two new managers plug into the single existing frame callback. `CameraViewModel` remains the only orchestrator; the managers are stateless-to-the-view singletons it talks to.

```mermaid
flowchart TD
    Cam[AVCaptureSession] --> Analyzer[VisionBodyPoseAnalyzer<br/>every 3rd frame]
    Analyzer -->|onPoseDetected obs| VM[CameraViewModel<br/>@MainActor]

    VM -->|exercise == .squats AND model loaded| Flex[FlexFitClassifierManager<br/>PoseWindow + inference]
    VM -->|otherwise| Det[ExerciseDetector<br/>rule-based]

    Flex -->|SquatLabel + SquatConfidence| SRC[SquatRepCounter<br/>transition + threshold]
    SRC -->|repCount delta| VM
    Det -->|state.repCount / feedback| VM

    VM -->|repCount changed| Hap[HapticManager.shared]
    VM -->|CoachingEvent| VC[VoiceCoach<br/>@MainActor]
    VC --> Synth[AVSpeechSynthesizer]
    VC --> Audio[AVAudioSession<br/>.playback/.spokenAudio/.duckOthers]

    VM --> View[CameraFeedView<br/>repCount, phase, VoiceMuteToggle]
```

### Routing decision (the core control-flow change)

The current pipeline always feeds `ExerciseClassifierManager.shared.addPose(observation)` and then always runs `detector.process(...)`. The new logic adds a branch inside the existing `onPoseDetected` closure:

```
on each confident observation, when frameCheckResult.isReady:
    if selectedExercise == .squats AND FlexFitClassifierManager.shared.isModelLoaded:
        FlexFitClassifierManager.shared.addPose(observation)      // ML path (source of truth)
        let delta = squatRepCounter.consume(label, confidence)    // derive reps from published label
        apply delta to repCount + phase + feedback
    else:
        detector.process(observation, exercise, &detectorState)   // existing rule-based path
        repCount = detectorState.repCount ...
```

`ExerciseClassifierManager` (the pre-existing secondary "AI:" label classifier) is left untouched and continues to run for its display label; `FlexFitClassifierManager` is the new Squats authority. Routing is keyed strictly on `selectedExercise == .squats` so Requirement 2.7 (non-squat frames never touch FlexFitClassifier) holds by construction.

## Components and Interfaces

### FlexFitClassifierManager (new)

Mirrors `ExerciseClassifierManager` line-for-line in shape. Lives in `Features/Camera/FlexFitClassifierManager.swift`.

```swift
@MainActor
final class FlexFitClassifierManager: ObservableObject {
    static let shared = FlexFitClassifierManager()

    @Published private(set) var squatLabel: String = ""        // read from model output, not hardcoded
    @Published private(set) var squatConfidence: Double = 0.0
    @Published private(set) var isModelLoaded: Bool = false

    private let predictionWindowSize: Int = 60   // MUST match Create ML prediction window
    private var poseWindow: [VNHumanBodyPoseObservation] = []
    private var model: FlexFitClassifier?

    private init() { loadModel() }               // R1.5: loaded exactly once per launch via singleton

    private func loadModel() {                   // R1.2 / R1.4
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndNeuralEngine
            model = try FlexFitClassifier(configuration: config)
            isModelLoaded = true
        } catch {
            isModelLoaded = false
            print("❌ Failed to load FlexFitClassifier: \(error)")   // log, do not crash
        }
    }

    /// R2.1–R2.4: append, gate on window size, infer, slide.
    func addPose(_ observation: VNHumanBodyPoseObservation) {
        poseWindow.append(observation)
        guard poseWindow.count >= predictionWindowSize else { return }  // R2.2 skip until full
        runInference()                                                  // R2.3 publish label+confidence
        poseWindow.removeFirst()                                        // R2.4 slide forward
    }

    /// R2.5: clear window + reset published values to initial.
    func reset() { poseWindow.removeAll(); squatLabel = ""; squatConfidence = 0.0 }

    private func runInference() { /* featureValue(for: "label") / "labelProbabilities") */ }
}
```

Output reading uses the same `MLFeatureProvider` approach as `ExerciseClassifierManager.runInference()` (`output.featureValue(for: "label")?.stringValue`, `featureValue(for: "labelProbabilities")?.dictionaryValue`) to avoid auto-generated-type coupling. **SquatLabel strings are never hardcoded in requirements**; the down/up vocabulary is discovered at runtime (see Data Models → `SquatPhase`).

### SquatRepCounter (new)

A pure-logic value type (struct with mutating `consume`) so it is trivially unit- and property-testable. It does no Core ML work; it only interprets a stream of `(label, confidence)` pairs.

```swift
struct SquatRepCounter {
    static let confidenceThreshold: Double = 0.6   // R3.2

    private(set) var repCount: Int = 0
    private var phase: SquatPhase = .unknown        // tracks down/up transition

    /// Returns the rep delta (0 or 1) produced by this prediction.
    /// R3.1: count one rep on down -> up/rest transition.
    /// R3.2: ignore predictions below the confidence threshold (no phase advance).
    mutating func consume(label: String, confidence: Double) -> Int {
        guard confidence >= Self.confidenceThreshold else { return 0 }
        let incoming = SquatPhase(modelLabel: label)
        defer { if incoming != .unknown { phase = incoming } }
        if phase == .down && incoming.isResting { repCount += 1; return 1 }
        return 0
    }

    mutating func resetPhase() { phase = .unknown }            // R3.6 keep committed totals
    mutating func resetAll()   { phase = .unknown; repCount = 0 } // R3.5 full reset
}
```

### VoiceCoach (new)

Mirrors `HapticManager.shared`: a `@MainActor` singleton with intent-based methods. Lives in `Core/Audio/VoiceCoach.swift`. Conforms to `AVSpeechSynthesizerDelegate` to drive the queue.

```swift
@MainActor
final class VoiceCoach: NSObject, ObservableObject {
    static let shared = VoiceCoach()

    private let synthesizer = AVSpeechSynthesizer()
    private var queue: [CoachingEvent] = []
    private var lastFormCorrection: (text: String, at: Date)?    // R5.5 identical-text debounce memory
    private var lastAnyFormCorrectionAt: Date?                   // R5.6 global last-spoken-formCorrection time
    static let debounceInterval: TimeInterval = 3.0              // CoachingDebounce
    static let formCorrectionInterval: TimeInterval = 2.5       // FormCorrectionInterval (global gap)

    var isEnabled: Bool {                                        // reads VoicePreference
        get { UserDefaults.standard.object(forKey: "voiceCoachEnabled") as? Bool ?? true }  // R6.4 default enabled
    }

    private override init() {
        super.init()
        synthesizer.delegate = self
        configureAudioSession()                                  // R7.1
        registerInterruptionObserver()                          // R7.4 / R7.5
    }

    func speak(_ event: CoachingEvent) { /* enqueue/interrupt per policy below */ }
    func stop() { synthesizer.stopSpeaking(at: .immediate) }    // R6.3 mute, R7.4 interruption
    func deactivateSession() { /* .notifyOthersOnDeactivation — R7.6 */ }
}
```

**Speak policy** (R4.4 / R4.5):

- `isEnabled == false` → drop the event entirely, no audio (R4.2).
- `formCorrection` events must pass **both** debounce gates before being spoken (a single failing gate skips the event):
  - **(a) identical-text 3 s debounce (R5.5):** skip if the same text as `lastFormCorrection.text` was spoken < `debounceInterval` (3 s) ago.
  - **(b) global 2.5 s gate (R5.6):** skip if *any* `formCorrection` was spoken < `formCorrectionInterval` (2.5 s) ago, i.e. `now - lastAnyFormCorrectionAt < 2.5`, regardless of text.
  - On a spoken `formCorrection`, update both `lastFormCorrection = (text, now)` and `lastAnyFormCorrectionAt = now`.
- If synthesizer is idle → speak immediately.
- If speaking and incoming is `repAnnouncement` → `stopSpeaking(.immediate)` then speak now (R4.4, keeps counts current).
- If speaking and incoming is `formCorrection` / `milestone` (and others) → append to `queue`; `speechSynthesizer(_:didFinish:)` dequeues the next (R4.5).

**Utterance config** (R4.3): `rate = AVSpeechUtteranceDefaultSpeechRate`; voice = `AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())`, falling back to system default when `nil`.

### CameraViewModel (modified)

New published state + new trigger calls inserted at the exact points that already fire haptics. No new queue or thread is introduced — everything stays on the existing `@MainActor` closure.

```swift
// new state
@Published var voiceEnabled: Bool = UserDefaults.standard
    .object(forKey: "voiceCoachEnabled") as? Bool ?? true       // R6.4
@Published var mlModelUnavailable: Bool = false                 // drives R8.1 banner
private var squatRepCounter = SquatRepCounter()
private var lastSpokenFormCorrection: String?                   // R5.4 "differs from most recent"

// inside onPoseDetected, replacing the single detector.process call:
if selectedExercise == .squats && FlexFitClassifierManager.shared.isModelLoaded {
    FlexFitClassifierManager.shared.addPose(observation)
    let delta = squatRepCounter.consume(
        label: FlexFitClassifierManager.shared.squatLabel,
        confidence: FlexFitClassifierManager.shared.squatConfidence)
    if delta > 0 { repCount = squatRepCounter.repCount; phase = "Squat" }
} else {
    detector.process(observation: observation, exercise: selectedExercise, state: &detectorState)
    repCount = detectorState.repCount; phase = detectorState.phase; feedback = detectorState.feedback
}

// existing haptic block is extended with voice (R5.2 / R5.3):
if repCount > prevCount {
    if repCount % 10 == 0 {
        HapticManager.shared.milestone()
        VoiceCoach.shared.speak(.milestone(reps: repCount))
    } else {
        HapticManager.shared.repCounted()
        VoiceCoach.shared.speak(.repAnnouncement(count: repCount))
    }
}
// form correction (R5.4): only when message differs from last spoken
if feedback != lastSpokenFormCorrection, isFormCorrection(feedback) {
    VoiceCoach.shared.speak(.formCorrection(message: feedback))
    lastSpokenFormCorrection = feedback
}
```

New methods: `toggleVoice()` (R6.2 — invert `voiceEnabled`, write to `UserDefaults`, and `VoiceCoach.shared.stop()` when turning off per R6.3); `selectExercise` extended to call `squatRepCounter.resetPhase()` (R3.6) + `VoiceCoach.shared.speak(.exerciseSwitch(...))` (R5.6); `configureAndStart` speaks `.workoutStart` (R5.1); `saveWorkoutSession` speaks `.workoutEnd` when `totalReps > 0` (R5.7); `stopSession` calls `VoiceCoach.shared.deactivateSession()` (R7.6); `resetCounter` calls `squatRepCounter.resetAll()` (R3.5).

### CameraFeedView (modified)

Add `VoiceMuteToggle` to the existing `topBar` HStack, styled like the existing flip/close buttons (solid black-opacity circle, `Color.themePrimary` icon). iOS 16.4: keep `.onChange(of:perform:)` single-param form already used in this file.

```swift
Button { viewModel.toggleVoice() } label: {
    Image(systemName: viewModel.voiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")  // R6.5
        .font(.system(size: 13, weight: .bold)).foregroundColor(.white)
        .frame(width: 32, height: 32).background(Color.black.opacity(0.5)).clipShape(Circle())
}
.accessibilityLabel("Voice Coach")                                   // R6.1
.accessibilityValue(viewModel.voiceEnabled ? "On" : "Off")           // R6.1
.accessibilityIdentifier("camera-voice-toggle-btn")
```

The R8.1 fallback banner reuses the existing `feedbackBanner` style, shown when `viewModel.mlModelUnavailable` is true with text `"Squat ML model unavailable — using fallback detection"`.

## Data Models

### SquatPhase (new)

Maps runtime model-output strings to a small phase enum so the rep counter never hardcodes the training vocabulary. Label classification is tolerant (substring/case-insensitive) because the exact strings come from FlexFitClassifier's training labels.

```swift
enum SquatPhase: Equatable {
    case down            // squatted / bottom phase
    case up              // standing / top phase
    case resting         // idle between reps
    case unknown         // below-threshold or unrecognized label

    var isResting: Bool { self == .up || self == .resting }   // either completes a rep (R3.1)

    init(modelLabel: String) {
        let l = modelLabel.lowercased()
        if l.contains("down") || l.contains("squat") { self = .down }
        else if l.contains("up") || l.contains("stand") { self = .up }
        else if l.contains("rest") || l.contains("idle") { self = .resting }
        else { self = .unknown }   // unknown labels never advance phase
    }
}
```

### CoachingEvent (new)

A discrete cue. The associated values are formatted into spoken text capped at 60 characters (R4.6). Category drives the queue/interrupt policy.

```swift
enum CoachingEvent {
    case repAnnouncement(count: Int)
    case formCorrection(message: String)
    case milestone(reps: Int)
    case workoutStart(exercise: String)
    case workoutEnd(totalReps: Int)
    case exerciseSwitch(exercise: String)

    var category: Category { /* repAnnouncement | formCorrection | milestone | workoutStart | workoutEnd | exerciseSwitch */ }

    /// R4.6: always <= 60 characters (truncated if needed).
    var text: String {
        switch self {
        case .repAnnouncement(let n): return "\(n)"
        case .formCorrection(let m):  return String(m.prefix(60))
        case .milestone(let n):       return "Great work, \(n) reps!"
        case .workoutStart(let e):    return "Starting \(e)"
        case .workoutEnd(let n):      return "Workout complete, \(n) reps"
        case .exerciseSwitch(let e):  return "Switching to \(e)"
        }
    }

    var interrupts: Bool { category == .repAnnouncement }   // R4.4 vs R4.5
}
```

### VoicePreference (persistence)

Not a type — a `Bool` stored in `UserDefaults.standard` under key `"voiceCoachEnabled"`. Read with `object(forKey:) as? Bool ?? true` so a missing value defaults to enabled (R6.4). Written on every toggle (R6.2). This is the single source of truth read by both `VoiceCoach.isEnabled` and `CameraViewModel.voiceEnabled`.

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

The pure-logic cores of this feature — `SquatRepCounter.consume`, the `VoiceCoach` debounce/queue/mute decision, and `CoachingEvent.text` formatting — are exactly the kind of deterministic, input-varying logic where property-based testing finds edge cases that examples miss. The Core ML inference, `AVSpeechSynthesizer` audio, `AVAudioSession` configuration, and SwiftUI rendering are NOT property-tested (see Testing Strategy).

### Property 1: Confidence threshold gates phase advancement

*For any* sequence of `(label, confidence)` predictions, every prediction with `confidence < 0.6` leaves both `repCount` and the internal phase unchanged (it is as if the prediction was never delivered).

**Validates: Requirements 3.2**

### Property 2: A rep is counted exactly once per down→rest cycle

*For any* sequence of above-threshold predictions, `SquatRepCounter.repCount` increases by exactly one each time the phase transitions from a `down` label to an `up`/`resting` label, and never increments without first having observed a `down` phase. Repeated `down` labels with no intervening `up`/`rest` produce at most one rep.

**Validates: Requirements 3.1**

### Property 3: Rep count is monotonic and idempotent under label repetition

*For any* sequence of above-threshold predictions, `repCount` is non-decreasing, and feeding the same label value repeatedly (without a phase transition) never changes `repCount` — i.e. `consume(x); consume(x)` after the first has no additional counting effect.

**Validates: Requirements 3.1, 3.4**

### Property 4: Phase reset preserves committed total

*For any* `SquatRepCounter` state, calling `resetPhase()` sets the phase to `unknown` while leaving `repCount` unchanged, whereas `resetAll()` sets both to their initial values.

**Validates: Requirements 3.5, 3.6**

### Property 5: PoseWindow inference gating and bounded size

*For any* sequence of appended observations, `FlexFitClassifierManager` runs inference only on appends where the window has reached `predictionWindowSize`, and after each inference the window size never exceeds `predictionWindowSize` (the oldest frame is dropped).

**Validates: Requirements 2.2, 2.3, 2.4**

### Property 6: Mute suppresses all output

*For any* `CoachingEvent` and *any* event ordering, while `VoicePreference` is disabled `VoiceCoach` produces zero utterances; the count of synthesized utterances over a disabled session is always zero regardless of how many events are requested.

**Validates: Requirements 4.2, 6.3**

### Property 7: Form-correction debounce suppresses identical back-to-back cues

*For any* stream of `formCorrection` events with timestamps, two requests carrying identical text less than 3 seconds apart never both result in speech; the second is skipped. Events with differing text, or identical text ≥ 3 seconds apart, are not suppressed by the debounce.

**Validates: Requirements 5.5**

### Property 8: Interrupt-vs-queue policy by category

*For any* event requested while the synthesizer is speaking, a `repAnnouncement` causes the in-progress utterance to stop and the new one to start, while a `formCorrection` or `milestone` is appended to the queue and the in-progress utterance is allowed to finish first. No queued event is dropped (when voice is enabled).

**Validates: Requirements 4.4, 4.5**

### Property 9: Spoken text length bound

*For any* `CoachingEvent` (including `formCorrection` with arbitrarily long messages), `event.text` is at most 60 characters.

**Validates: Requirements 4.6**

### Property 10: VoicePreference round-trips through UserDefaults with enabled default

*For any* boolean preference value written under key `voiceCoachEnabled`, reading it back yields the same value; and reading when no value has ever been stored yields `true`.

**Validates: Requirements 6.2, 6.4**

### Property 11: Global form-correction spacing (any text)

*For any* stream of `formCorrection` events with arbitrary (mixed) message text and arbitrary timestamps, the set of events VoiceCoach actually speaks never contains two spoken `formCorrection` cues less than 2.5 seconds apart — i.e. for every pair of consecutively spoken form corrections, the gap between them is ≥ `formCorrectionInterval` (2.5 s), regardless of whether their text matches. This global gate composes with the identical-text debounce of Property 7: an event is spoken only when it passes both, so differing-text corrections arriving within 2.5 s of the previous spoken correction are still suppressed.

**Validates: Requirements 5.6**

## Error Handling

- **Model load failure (R1.4, R8.1):** `loadModel()` catches the error, sets `isModelLoaded = false`, and logs to console — no crash. `CameraViewModel` observes `isModelLoaded`; when it is `false` while Squats is active, it sets `mlModelUnavailable = true` (banner) and the routing branch naturally falls through to `ExerciseDetector`. The session continues uninterrupted.
- **Inference failure:** wrapped in `do/catch` like `ExerciseClassifierManager.runInference()`; a thrown error leaves the previously published `squatLabel`/`squatConfidence` intact and is logged. The rep counter simply receives no new transition that frame.
- **Audio session activation failure (R7.3):** `configureAudioSession()` and per-utterance activation are wrapped in `do/catch`; on failure the current event is skipped, the error is logged, and subsequent events are still accepted (the session is retried on the next `speak`).
- **Silent synthesizer (R8.2):** voice is fire-and-forget from `CameraViewModel`'s perspective — rep counting, haptics, and on-screen feedback never await or depend on `VoiceCoach`. If no audio is produced, the workout proceeds with text-only feedback.
- **Audio interruptions (R7.4, R7.5):** an `AVAudioSession.interruptionNotification` observer stops the current utterance on `.began` and remains ready (no re-init) on `.ended` with `shouldResume`.
- **Privacy invariants (R8.3, R8.4):** `VoiceCoach` uses only `AVSpeechSynthesizer` output; it never instantiates a recorder, opens a network connection, or writes spoken text to disk. No new `Info.plist` permission keys are added.
- **Silent mode (R8.5):** `.playback` category ensures cues play even with the ringer switch off — verified by the audio-session configuration smoke test.

## Testing Strategy

### Dual approach

- **Property tests** validate the universal logic properties above. The pure cores (`SquatRepCounter`, `CoachingEvent`, and a testable `VoiceCoach` decision function) are extracted so they can be driven without Core ML or audio hardware.
- **Unit / example tests** cover concrete scenarios and integration points.
- **Smoke / integration tests** cover the non-PBT surfaces.

### Property-based testing

Use **SwiftCheck** (the established Swift PBT library) — do not hand-roll generators. Each property test:

- Runs a minimum of **100 iterations**.
- Is tagged with a comment: `// Feature: squat-voice-coaching, Property {n}: {property text}`.
- Maps one-to-one to a property in the Correctness Properties section (Properties 1–11).

Generators of note: random `(label, confidence)` streams drawn from the down/up/rest/unknown vocabulary plus out-of-range confidences (Properties 1–4); random `predictionWindowSize`-relative append counts (Property 5); random `CoachingEvent` streams with timestamps and enabled/disabled flags (Properties 6–8); arbitrary long strings for the 60-char bound (Property 9); arbitrary booleans + an isolated `UserDefaults` suite (Property 10); random **mixed-text** `formCorrection` streams with timestamps clustered around the 2.5 s boundary (sub-2.5 s and ≥ 2.5 s gaps, identical and differing text) asserting the global 2.5 s spacing of spoken corrections (Property 11).

To make `VoiceCoach` testable without real audio, the speak-decision logic (enabled check → identical-text debounce → global 2.5 s form-correction gate → interrupt-vs-queue) is implemented as a pure function (`VoiceCoachDecision`) over an injected clock and an abstract "utterance sink" that records actions; the production path wires that sink to `AVSpeechSynthesizer`. Both the identical-text debounce and the global form-correction gate live in this pure logic (tracking `lastFormCorrection` and `lastAnyFormCorrectionAt`), so Properties 6–8 and 11 all test the pure decision function.

### Unit / example tests

- `SquatRepCounter`: classic down→up→down→up sequence counts 2; below-threshold spike between phases is ignored; `resetAll` zeroes everything.
- `SquatPhase(modelLabel:)`: representative training-label strings map to the correct phase; unrecognized → `unknown`.
- `CameraViewModel` routing: Squats + model loaded routes to `FlexFitClassifierManager` and skips `ExerciseDetector`; Squats + model not loaded uses `ExerciseDetector` and sets `mlModelUnavailable`; a non-Squats exercise never calls `FlexFitClassifierManager.addPose`.
- Milestone trigger: rep count hitting a multiple of 10 fires `.milestone` instead of `.repAnnouncement`.

### Integration / smoke tests (NOT property tests)

- **FlexFitClassifier load smoke test:** the bundled model loads with `.cpuAndNeuralEngine` and `isModelLoaded == true` (R1.2, R1.3) — single execution.
- **AudioSession configuration smoke test:** after `VoiceCoach` init the shared session reports category `.playback`, mode `.spokenAudio`, options containing `.duckOthers` (R7.1, R8.5) — single execution.
- **Synthesizer integration:** one or two example utterances confirm `AVSpeechSynthesizer` speaks and the delegate dequeues — these exercise Apple's framework, so behavior does not vary meaningfully with input and PBT adds no value.
- **VoiceMuteToggle accessibility:** snapshot/inspection test that the toggle exposes label `"Voice Coach"` and a value reflecting state, and shows speaker vs. muted-speaker icon (R6.1, R6.5).
