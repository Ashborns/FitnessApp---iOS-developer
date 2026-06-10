import AVFoundation
import Vision
import CoreData

@MainActor
final class CameraViewModel: ObservableObject {

    // MARK: - Published State

    @Published var isAuthorized: Bool = false
    @Published var isRunning: Bool = false
    @Published var detectedPose: VNHumanBodyPoseObservation?

    // Exercise state — flat @Published properties so SwiftUI re-renders properly
    @Published var selectedExercise: ExerciseType = .jumpingJacks
    @Published var repCount: Int = 0
    @Published var phase: String = "Ready"
    @Published var feedback: String = "Stand in frame to begin"

    // Camera position (front = selfie, back = rear)
    @Published var cameraPosition: AVCaptureDevice.Position = .front

    // Frame position check result
    @Published var frameCheckResult: FrameChecker.Result = .noBodyDetected

    // Voice coaching preference — persisted in UserDefaults under "voiceCoachEnabled".
    // Defaults to enabled when no value has been stored previously.
    @Published var voiceEnabled: Bool = UserDefaults.standard
        .object(forKey: "voiceCoachEnabled") as? Bool ?? true

    // Drives the R8.1 fallback banner: true when Squats is active but the
    // FlexFitClassifier model failed to load (rule-based detector is used instead).
    @Published var mlModelUnavailable: Bool = false

    // Workout summary (per exercise totals — saved on dismiss)
    @Published private(set) var sessionSummary: [ExerciseType: Int] = [:]
    @Published var workoutStartedAt: Date = Date()

    // MARK: - Detection

    private var detectorState = ExerciseDetector.State.initial
    private let detector = ExerciseDetector()

    /// Pure-logic rep counter that derives squat reps from FlexFitClassifier
    /// `(label, confidence)` predictions when the ML model is the source of truth.
    private var squatRepCounter = SquatRepCounter()

    /// Frame-position smoothing. Raw `FrameChecker` results can flip between adjacent
    /// states on a single jittery frame near a threshold, which would spam the on-screen
    /// guidance ("step closer" / "move back"). We smooth with a short sliding-window
    /// majority vote: the committed result is whichever state dominates the last few
    /// evaluations. This removes flicker without ever deadlocking on a stale state.
    private var frameResultHistory: [FrameChecker.Result] = []
    private static let frameResultWindow = 5

    /// Returns a debounced frame-position result via a majority vote over the most recent
    /// evaluations. Ties resolve in favor of the most recent value, keeping it responsive.
    private func stabilizedFrameResult(_ raw: FrameChecker.Result) -> FrameChecker.Result {
        frameResultHistory.append(raw)
        if frameResultHistory.count > Self.frameResultWindow {
            frameResultHistory.removeFirst()
        }

        var best = raw
        var bestCount = 0
        // Iterate newest → oldest so that, with a strict `>`, ties favor the most recent state.
        for candidate in frameResultHistory.reversed() {
            let count = frameResultHistory.reduce(0) { $0 + ($1 == candidate ? 1 : 0) }
            if count > bestCount {
                bestCount = count
                best = candidate
            }
        }
        return best
    }

    /// The most recently spoken form-correction message (R5.4). Used so a
    /// `formCorrection` CoachingEvent is only requested when the current feedback
    /// differs from the last one spoken. `VoiceCoach` applies its own debounce /
    /// spacing gates on top of this; this only suppresses identical back-to-back
    /// requests originating from the same banner message.
    private var lastSpokenFormCorrection: String?

    /// The exact set of form-correction messages `ExerciseDetector` can produce
    /// (see `formFeedbackMessage`). Only these are spoken as `formCorrection`
    /// CoachingEvents — rep feedback ("N squats — keep going!"), initial coaching
    /// prompts, and frame-position guidance are intentionally excluded.
    private static let formCorrectionMessages: Set<String> = [
        "Raise arms higher",
        "Spread legs wider",
        "Go deeper — bend knees more",
        "Stand fully upright",
        "Lift knee higher",
        "Raise arms fully overhead",
        "Bend further — reach for your toes"
    ]

    /// `true` when `message` is a recognized, non-empty form-correction string.
    private func isFormCorrection(_ message: String) -> Bool {
        !message.isEmpty && Self.formCorrectionMessages.contains(message)
    }

    // MARK: - Session

    let session = AVCaptureSession()
    private let poseAnalyzer = VisionBodyPoseAnalyzer()
    private let outputQueue = DispatchQueue(label: "camera.output.queue", qos: .userInitiated)
    private let sessionQueue = DispatchQueue(label: "camera.session.queue", qos: .userInitiated)
    private let videoOutput = AVCaptureVideoDataOutput()

    // MARK: - Init

    init() {
        poseAnalyzer.onPoseDetected = { [weak self] observation in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.detectedPose = observation
                let prevCount = self.repCount

                // Feed to ML classifier (sliding window)
                ExerciseClassifierManager.shared.addPose(observation)

                // Frame position check — higher priority than rep counting.
                // Smoothed over a few frames so the guidance message doesn't flicker.
                let rawFrameResult = FrameChecker.evaluate(
                    observation: observation,
                    frameSize: CGSize(width: 720, height: 1280)
                )
                let frameResult = self.stabilizedFrameResult(rawFrameResult)
                self.frameCheckResult = frameResult

                if frameResult.isReady {
                    if self.selectedExercise == .squats
                        && FlexFitClassifierManager.shared.isModelLoaded {
                        // ML path — FlexFitClassifier is the source of truth for Squats.
                        self.mlModelUnavailable = false
                        FlexFitClassifierManager.shared.addPose(observation)
                        let delta = self.squatRepCounter.consume(
                            label: FlexFitClassifierManager.shared.squatLabel,
                            confidence: FlexFitClassifierManager.shared.squatConfidence
                        )
                        if delta > 0 {
                            self.repCount = self.squatRepCounter.repCount
                            self.phase = "Squat"
                        }
                    } else {
                        // Squats with the model unavailable falls back to the
                        // rule-based detector and surfaces the R8.1 banner.
                        if self.selectedExercise == .squats {
                            self.mlModelUnavailable = true
                        }

                        // Rule-based rep counting (primary path for non-Squats exercises).
                        self.detector.process(
                            observation: observation,
                            exercise: self.selectedExercise,
                            state: &self.detectorState
                        )
                        self.repCount = self.detectorState.repCount
                        self.phase = self.detectorState.phase
                        self.feedback = self.detectorState.feedback
                    }
                } else {
                    // Override feedback with position guidance
                    self.feedback = frameResult.feedbackMessage
                    self.phase = "Stand by"
                }

                // Haptic feedback when a new rep is counted
                if self.repCount > prevCount {
                    if self.repCount % 10 == 0 {
                        HapticManager.shared.milestone()
                        VoiceCoach.shared.speak(.milestone(reps: self.repCount))
                    } else {
                        HapticManager.shared.repCounted()
                        VoiceCoach.shared.speak(.repAnnouncement(count: self.repCount))
                    }
                }

                // Voice form correction (R5.4): only speak when the current feedback
                // is a recognized form-correction message AND it differs from the
                // most recently spoken correction. VoiceCoach applies its own mute /
                // debounce / spacing gates on top of this.
                if self.feedback != self.lastSpokenFormCorrection,
                   self.isFormCorrection(self.feedback) {
                    VoiceCoach.shared.speak(.formCorrection(message: self.feedback))
                    self.lastSpokenFormCorrection = self.feedback
                }
            }
        }

        poseAnalyzer.onPoseLost = { [weak self] in
            Task { @MainActor [weak self] in
                self?.detectedPose = nil
            }
        }
    }

    // MARK: - Public API

    func selectExercise(_ exercise: ExerciseType) {
        // Commit current rep count to session summary before switching
        commitCurrentReps()
        selectedExercise = exercise
        // Reset just the per-exercise counter, keep sessionSummary & workoutStartedAt
        detectorState = ExerciseDetector.State.initial
        repCount = 0
        phase = "Ready"
        feedback = "Stand in frame to begin"
        frameCheckResult = .noBodyDetected
        // Clear ML classifier sliding window when switching exercises
        ExerciseClassifierManager.shared.reset()
        // Reset squat phase (R3.6) — keep committed total, just drop the in-progress phase
        squatRepCounter.resetPhase()
        // Announce the newly selected exercise (R5.6 / R5.8)
        VoiceCoach.shared.speak(.exerciseSwitch(exercise: exercise.displayName))
    }

    /// Toggle the voice-coaching preference (R6.2). Persists the new value to
    /// UserDefaults under "voiceCoachEnabled" and silences any in-flight speech
    /// immediately when turning OFF (R6.3).
    func toggleVoice() {
        voiceEnabled.toggle()
        UserDefaults.standard.set(voiceEnabled, forKey: "voiceCoachEnabled")
        if !voiceEnabled {
            VoiceCoach.shared.stop()
        }
    }

    /// Full reset — wipes session summary, counter, and starts a fresh workout.
    /// Called by user-facing "Reset Workout" button.
    func resetCounter() {
        detectorState = ExerciseDetector.State.initial
        repCount = 0
        phase = "Ready"
        feedback = "Stand in frame to begin"
        sessionSummary = [:]
        workoutStartedAt = Date()
        frameCheckResult = .noBodyDetected
        // Fully reset squat rep counter — wipe phase and committed count (R3.5)
        squatRepCounter.resetAll()
    }

    /// Commit the current exercise's rep count into the session summary.
    private func commitCurrentReps() {
        guard repCount > 0 else { return }
        let existing = sessionSummary[selectedExercise] ?? 0
        sessionSummary[selectedExercise] = existing + repCount
    }

    /// Save the entire workout session to CoreData. Returns total reps & calories.
    /// Called when user dismisses the camera.
    @discardableResult
    func saveWorkoutSession() -> WorkoutSummary {
        commitCurrentReps()

        let totalReps = sessionSummary.values.reduce(0, +)
        guard totalReps > 0 else {
            return WorkoutSummary(totalReps: 0, totalCalories: 0, durationMinutes: 0, breakdown: [:])
        }

        // Announce workout completion (R5.7) — only when reps were actually performed.
        VoiceCoach.shared.speak(.workoutEnd(totalReps: totalReps))

        let durationSeconds = Date().timeIntervalSince(workoutStartedAt)
        let durationMinutes = durationSeconds / 60.0

        // Estimate calories burned: ~0.4 kcal per rep across body-weight exercises
        // (rough average — varies by exercise & user weight)
        let calories = Double(totalReps) * 0.4

        // Save one CoreData entry summarizing the session
        let context = PersistenceController.shared.container.viewContext
        let workoutType = primaryExerciseLabel()

        let log = WorkoutLog.create(
            in: context,
            workoutType: workoutType,
            durationMinutes: max(durationMinutes, 0.1),
            caloriesBurned: calories,
            notes: notesString()
        )
        _ = log

        do {
            try context.save()
            HapticManager.shared.workoutCompleted()
        } catch {
            print("Failed to save workout: \(error)")
        }

        // Update workout goals & streak (UserDefaults-based)
        WorkoutGoalsStore.shared.addReps(totalReps)

        let summary = WorkoutSummary(
            totalReps: totalReps,
            totalCalories: calories,
            durationMinutes: durationMinutes,
            breakdown: sessionSummary
        )

        // Reset for next session
        sessionSummary = [:]
        workoutStartedAt = Date()
        return summary
    }

    /// Returns the most-performed exercise name (for workoutType field).
    private func primaryExerciseLabel() -> String {
        if sessionSummary.count == 1, let only = sessionSummary.keys.first {
            return only.displayName
        }
        // Multi-exercise session
        return "Mixed Workout"
    }

    /// Builds a notes string with breakdown per exercise.
    private func notesString() -> String {
        sessionSummary
            .sorted { $0.value > $1.value }
            .map { "\($0.key.displayName): \($0.value) reps" }
            .joined(separator: ", ")
    }

    // MARK: - Permission

    func requestPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        default:
            isAuthorized = false
        }
    }

    // MARK: - Session Lifecycle

    func configureAndStart() {
        let position = cameraPosition
        // Start workout duration timer when camera actually opens
        workoutStartedAt = Date()
        // Announce workout start (R5.1) — gated on the voice preference per task spec.
        if voiceEnabled {
            VoiceCoach.shared.speak(.workoutStart(exercise: selectedExercise.displayName))
        }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.inputs.isEmpty {
                self.configureSession(position: position)
            }
            if !self.session.isRunning {
                self.session.startRunning()
                Task { @MainActor [weak self] in
                    self?.isRunning = true
                }
            }
        }
    }

    func stopSession() {
        // Release the shared audio session so other apps regain audio (R7.6).
        VoiceCoach.shared.deactivateSession()
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
            Task { @MainActor [weak self] in
                self?.isRunning = false
            }
        }
    }

    /// Switch between front/back camera. Reconfigures session on background queue.
    /// Rolls back if new camera can't be added (rare, but safe).
    func flipCamera() {
        let oldPosition = cameraPosition
        let newPosition: AVCaptureDevice.Position = (oldPosition == .front) ? .back : .front

        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()

            // Snapshot existing inputs before removal so we can restore on failure
            let existingInputs = self.session.inputs

            // Try to find the new device first (don't remove until we know it works)
            guard let device = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: newPosition
            ),
            let input = try? AVCaptureDeviceInput(device: device) else {
                // Failed to acquire new device — keep the old session intact
                self.session.commitConfiguration()
                return
            }

            // Remove old inputs
            existingInputs.forEach { self.session.removeInput($0) }

            // Try to add the new input
            guard self.session.canAddInput(input) else {
                // Restore old inputs
                existingInputs.forEach {
                    if self.session.canAddInput($0) { self.session.addInput($0) }
                }
                self.session.commitConfiguration()
                return
            }
            self.session.addInput(input)

            // Re-apply mirroring & orientation for the new camera
            if let connection = self.videoOutput.connection(with: .video) {
                if connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = (newPosition == .front)
                }
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }

            self.session.commitConfiguration()

            // Only update published cameraPosition AFTER session reconfig succeeds
            Task { @MainActor [weak self] in
                self?.cameraPosition = newPosition
                // Clear stale pose so skeleton from old mirror state doesn't linger
                self?.detectedPose = nil
            }
        }
    }

    private nonisolated func configureSession(position: AVCaptureDevice.Position) {
        session.beginConfiguration()
        // Use HD preset — sharp enough for accurate pose detection without blur
        if session.canSetSessionPreset(.hd1280x720) {
            session.sessionPreset = .hd1280x720
        } else {
            session.sessionPreset = .high
        }

        guard let device = AVCaptureDevice.default(
            .builtInWideAngleCamera,
            for: .video,
            position: position
        ) else {
            session.commitConfiguration()
            return
        }

        guard let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        videoOutput.setSampleBufferDelegate(poseAnalyzer, queue: outputQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true

        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                // Mirror only for front camera (selfie style)
                connection.isVideoMirrored = (position == .front)
            }
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
        }

        session.commitConfiguration()
    }
}

// MARK: - WorkoutSummary

/// Result of a saved workout session.
struct WorkoutSummary {
    let totalReps: Int
    let totalCalories: Double
    let durationMinutes: TimeInterval
    let breakdown: [ExerciseType: Int]

    var hasData: Bool { totalReps > 0 }
}
