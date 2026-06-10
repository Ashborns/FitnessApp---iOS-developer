# Requirements Document

## Introduction

This feature adds two related capabilities to the camera workout screen:

1. **ML-based squat detection.** A new Core ML action classifier (`FlexFitClassifier.mlmodel`) becomes the authoritative source for detecting and counting squat repetitions, replacing the existing rule-based knee-angle detector for the Squats exercise. Other exercises (Jumping Jacks, High Knees, Arm Raises, Toe Touches) remain on the rule-based detector and are out of scope for the model swap.
2. **Voice coaching.** A new on-device text-to-speech coach speaks short cues to the user during a workout — announcing reps, calling out form corrections, and marking workout start, milestones, and completion — so the user can keep their eyes on their movement instead of the phone screen.

The feature is local-only: no audio is recorded, no data is sent off-device, and the user can mute voice coaching at any time from the camera screen.

## Glossary

- **FlexFitClassifier**: The Core ML action classifier model file (`FlexFitClassifier.mlmodel`) trained on squat movement, bundled into the iOS app. Takes a fixed-length window of `VNHumanBodyPoseObservation` frames and emits a predicted movement label plus per-label probabilities.
- **FlexFitClassifierManager**: The Swift `@MainActor` singleton that owns the FlexFitClassifier instance, maintains the sliding `PoseWindow`, runs inference, and publishes the current squat label and confidence.
- **PoseWindow**: A fixed-size sliding window of consecutive `VNHumanBodyPoseObservation` frames fed into FlexFitClassifier. Window size matches the prediction window used during Create ML training of FlexFitClassifier.
- **SquatLabel**: A string emitted by FlexFitClassifier identifying the current squat phase. Possible values come from FlexFitClassifier's training labels (e.g., a "down" / "up" / "rest" style vocabulary). Exact label strings are read from the model output, not hardcoded in requirements.
- **SquatConfidence**: The probability (0.0 to 1.0) FlexFitClassifier assigns to its currently predicted SquatLabel.
- **SquatRepCounter**: The component that derives an integer rep count from a sequence of FlexFitClassifier predictions by tracking SquatLabel transitions through a complete down-then-up cycle.
- **ConfidenceThreshold**: The minimum SquatConfidence (0.6) required for a FlexFitClassifier prediction to update SquatRepCounter state. Predictions below the threshold are ignored for counting purposes.
- **VoiceCoach**: The Swift `@MainActor` singleton that converts `CoachingEvent` values into spoken audio using `AVSpeechSynthesizer`.
- **CoachingEvent**: A discrete coaching cue produced during a workout. Categories: `repAnnouncement`, `formCorrection`, `milestone`, `workoutStart`, `workoutEnd`, `exerciseSwitch`.
- **VoicePreference**: The user setting controlling whether VoiceCoach speaks. Persisted across app launches in `UserDefaults`. Default: enabled.
- **VoiceMuteToggle**: The control on the camera screen that flips VoicePreference between enabled and disabled and updates immediately.
- **AudioSession**: The shared `AVAudioSession` instance used by VoiceCoach to play TTS audio while ducking other audio playing on the device.
- **CoachingDebounce**: The minimum interval (3 seconds) that must elapse between two spoken `formCorrection` CoachingEvents with the same message before the same message is allowed to be spoken again.
- **FormCorrectionInterval**: The minimum interval (2.5 seconds) that must elapse between any two spoken `formCorrection` CoachingEvents, regardless of whether their message text is the same or different.

---

## Requirements

### Requirement 1: FlexFitClassifier Model Integration

**User Story:** As a developer integrating the squat ML model, I want FlexFitClassifier to be bundled into the app and loaded once at startup, so that squat detection has a ready-to-use classifier whenever the camera screen is opened.

#### Acceptance Criteria

1. THE FlexFitClassifierManager SHALL bundle `FlexFitClassifier.mlmodel` into the iOS app target as a compiled Core ML resource.
2. WHEN FlexFitClassifierManager is first accessed, THE FlexFitClassifierManager SHALL load FlexFitClassifier with `MLModelConfiguration.computeUnits = .cpuAndNeuralEngine`.
3. WHEN FlexFitClassifier loads successfully, THE FlexFitClassifierManager SHALL set its `isModelLoaded` published property to `true`.
4. IF FlexFitClassifier fails to load, THEN THE FlexFitClassifierManager SHALL set `isModelLoaded` to `false`, log the underlying error to the console, and continue the camera session without crashing.
5. THE FlexFitClassifierManager SHALL load FlexFitClassifier exactly once per app launch.

---

### Requirement 2: Squat Detection via FlexFitClassifier

**User Story:** As a user performing squats, I want the app to use the dedicated squat ML model to recognize my movement, so that squat detection is more accurate than the previous rule-based knee-angle check.

#### Acceptance Criteria

1. WHEN the active exercise is Squats and a new `VNHumanBodyPoseObservation` is delivered to CameraViewModel, THE FlexFitClassifierManager SHALL append the observation to the PoseWindow.
2. WHILE the PoseWindow contains fewer frames than FlexFitClassifier's required prediction window size, THE FlexFitClassifierManager SHALL skip inference for the current frame.
3. WHEN the PoseWindow reaches FlexFitClassifier's required prediction window size, THE FlexFitClassifierManager SHALL run FlexFitClassifier inference and publish the predicted SquatLabel and SquatConfidence to its observable properties.
4. WHEN inference completes, THE FlexFitClassifierManager SHALL slide the PoseWindow forward by removing its oldest frame so subsequent inferences use the most recent frames.
5. WHEN the user switches the active exercise away from Squats, THE FlexFitClassifierManager SHALL clear the PoseWindow and reset the published SquatLabel and SquatConfidence to their initial values.
6. WHILE the active exercise is Squats, THE CameraViewModel SHALL use FlexFitClassifierManager's SquatLabel as the source of truth for squat phase rather than the rule-based knee-angle detector in `ExerciseDetector`.
7. WHILE the active exercise is not Squats, THE CameraViewModel SHALL continue to use `ExerciseDetector` for that exercise's rep counting and SHALL NOT route those frames through FlexFitClassifier.

---

### Requirement 3: Squat Rep Counting from ML Predictions

**User Story:** As a user performing squats, I want each completed squat to be counted exactly once, so that my rep count and calorie estimate are accurate.

#### Acceptance Criteria

1. THE SquatRepCounter SHALL count one squat repetition each time the published SquatLabel completes a transition from a "down" phase label back to an "up" or resting phase label, where the specific label strings are taken from FlexFitClassifier's training vocabulary.
2. IF a FlexFitClassifier prediction has SquatConfidence below the ConfidenceThreshold (0.6), THEN THE SquatRepCounter SHALL ignore that prediction and SHALL NOT advance its phase tracking.
3. WHEN SquatRepCounter increments the rep count, THE CameraViewModel SHALL update its published `repCount` property and trigger the existing rep-counted haptic via `HapticManager.shared.repCounted()`.
4. WHEN the rep count reaches a multiple of 10 due to a SquatRepCounter increment, THE CameraViewModel SHALL trigger `HapticManager.shared.milestone()` instead of `HapticManager.shared.repCounted()`.
5. WHEN the user taps the "Reset Workout" button, THE SquatRepCounter SHALL reset its rep count and phase state to their initial values.
6. WHEN the user switches the active exercise away from Squats and back to Squats, THE SquatRepCounter SHALL reset its phase tracking but SHALL preserve the per-exercise total already committed to `sessionSummary` so that historical totals are not lost.

---

### Requirement 4: Voice Coach Speech Output

**User Story:** As a user working out, I want short spoken cues during my workout, so that I can keep my eyes on my movement instead of looking at the phone screen.

#### Acceptance Criteria

1. WHEN VoiceCoach is asked to speak a CoachingEvent and VoicePreference is enabled, THE VoiceCoach SHALL synthesize the event's text using `AVSpeechSynthesizer` and play it through AudioSession.
2. WHILE VoicePreference is disabled, THE VoiceCoach SHALL NOT produce any audio output and SHALL ignore all CoachingEvents until VoicePreference is enabled again.
3. WHEN VoiceCoach speaks a CoachingEvent, THE VoiceCoach SHALL set the `AVSpeechUtterance` rate to `AVSpeechUtteranceDefaultSpeechRate` and use the user's current device language voice when available, falling back to the system default voice.
4. WHEN a new CoachingEvent is requested while VoiceCoach is still speaking a previous CoachingEvent of category `repAnnouncement`, THE VoiceCoach SHALL stop the in-progress utterance immediately and speak the new CoachingEvent so rep counts stay current.
5. WHEN a new CoachingEvent of category `formCorrection` or `milestone` is requested while VoiceCoach is still speaking, THE VoiceCoach SHALL queue the new event and speak it after the current utterance finishes.
6. THE VoiceCoach SHALL keep each spoken CoachingEvent text under 60 characters so the cue completes before the next rep is likely to occur.

---

### Requirement 5: Voice Coaching Triggers

**User Story:** As a user, I want the voice to speak at the right moments — when I complete a rep, when my form is wrong, and when I hit milestones — so that the cues are useful rather than noisy.

#### Acceptance Criteria

1. WHEN the camera session starts and VoicePreference is enabled, THE CameraViewModel SHALL request VoiceCoach to speak a `workoutStart` CoachingEvent containing the active exercise's display name.
2. WHEN the rep count for the active exercise increments, THE CameraViewModel SHALL request VoiceCoach to speak a `repAnnouncement` CoachingEvent containing the new integer rep count.
3. WHEN the rep count reaches a multiple of 10, THE CameraViewModel SHALL request VoiceCoach to speak a `milestone` CoachingEvent congratulating the user and stating the rep count.
4. WHEN `ExerciseDetector` or `FlexFitClassifierManager` produces a form correction message that differs from the most recently spoken form correction, THE CameraViewModel SHALL request VoiceCoach to speak a `formCorrection` CoachingEvent containing that message.
5. IF the same `formCorrection` text would be spoken less than CoachingDebounce (3 seconds) after VoiceCoach last spoke that exact text, THEN THE VoiceCoach SHALL skip the request to avoid repeating the same correction back-to-back.
6. IF a `formCorrection` CoachingEvent would be spoken less than FormCorrectionInterval (2.5 seconds) after VoiceCoach last spoke any `formCorrection` CoachingEvent, THEN THE VoiceCoach SHALL skip the request regardless of whether the message text matches the previously spoken correction.
7. WHEN the user changes the active exercise, THE CameraViewModel SHALL request VoiceCoach to speak an `exerciseSwitch` CoachingEvent naming the new exercise.
8. WHEN the user dismisses the camera screen and the saved WorkoutSummary contains a positive `totalReps`, THE CameraViewModel SHALL request VoiceCoach to speak a `workoutEnd` CoachingEvent stating the total reps for the session.

---

### Requirement 6: Voice Mute Control and Persistence

**User Story:** As a user, I want a visible toggle to mute the voice coach mid-workout, so that I can silence it during a phone call, in a quiet gym, or whenever I prefer.

#### Acceptance Criteria

1. THE CameraFeedView SHALL display a VoiceMuteToggle button on the camera screen with an accessibility label of "Voice Coach" and an accessibility value reflecting the current VoicePreference state.
2. WHEN the user taps VoiceMuteToggle, THE CameraViewModel SHALL invert VoicePreference and persist the new value to `UserDefaults` under the key `voiceCoachEnabled`.
3. WHEN VoicePreference transitions from enabled to disabled, THE VoiceCoach SHALL stop any in-progress utterance immediately.
4. WHEN the app launches, THE CameraViewModel SHALL read VoicePreference from `UserDefaults` and SHALL default to enabled when no value has been stored previously.
5. WHEN the camera screen appears, THE VoiceMuteToggle SHALL display a speaker icon if VoicePreference is enabled and a muted speaker icon if VoicePreference is disabled.

---

### Requirement 7: Audio Session and Interruption Handling

**User Story:** As a user, I want voice coaching to coexist with other audio on my phone, so that my workout music can keep playing and the voice cue is briefly heard over it without ending playback.

#### Acceptance Criteria

1. WHEN VoiceCoach is initialized, THE VoiceCoach SHALL configure AudioSession with category `.playback`, mode `.spokenAudio`, and option `.duckOthers`.
2. WHEN VoiceCoach starts speaking a CoachingEvent and other audio is playing on the device, THE AudioSession SHALL duck the other audio for the duration of the utterance and restore it afterward.
3. IF AudioSession activation fails, THEN THE VoiceCoach SHALL skip the current CoachingEvent, log the underlying error to the console, and continue accepting subsequent CoachingEvents.
4. WHEN an `AVAudioSession.interruptionNotification` of type `began` is received, THE VoiceCoach SHALL stop any in-progress utterance immediately.
5. WHEN an `AVAudioSession.interruptionNotification` of type `ended` is received with the `shouldResume` option, THE VoiceCoach SHALL be ready to speak the next CoachingEvent without re-initialization.
6. WHEN the camera session stops, THE VoiceCoach SHALL deactivate AudioSession with the `.notifyOthersOnDeactivation` option so other audio resumes at full volume.

---

### Requirement 8: Graceful Degradation and Permissions

**User Story:** As a user on a device where the squat model fails to load or where audio output is unavailable, I want the workout to keep working, so that one component failure does not break my entire session.

#### Acceptance Criteria

1. IF FlexFitClassifier fails to load at app start, THEN THE CameraViewModel SHALL fall back to the rule-based knee-angle detector in `ExerciseDetector` for squat rep counting and SHALL display a banner message reading "Squat ML model unavailable — using fallback detection".
2. IF VoicePreference is enabled but `AVSpeechSynthesizer` produces no audio for any CoachingEvent during a session, THEN THE CameraViewModel SHALL continue the workout with text-only feedback and SHALL NOT block rep counting or form feedback.
3. THE VoiceCoach SHALL NOT require any iOS permission prompt beyond the existing `NSCameraUsageDescription` already declared in `Info.plist`.
4. THE VoiceCoach SHALL NOT record audio, transmit any data off-device, or write any spoken text to disk.
5. WHEN the device is set to silent mode (ringer switch off), THE VoiceCoach SHALL still play CoachingEvents because AudioSession is configured with category `.playback`.
