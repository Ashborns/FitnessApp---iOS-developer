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

    // Workout summary (per exercise totals — saved on dismiss)
    @Published private(set) var sessionSummary: [ExerciseType: Int] = [:]
    @Published var workoutStartedAt: Date = Date()

    // MARK: - Detection

    private var detectorState = ExerciseDetector.State.initial
    private let detector = ExerciseDetector()

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

                // Rule-based rep counting (primary)
                self.detector.process(
                    observation: observation,
                    exercise: self.selectedExercise,
                    state: &self.detectorState
                )
                self.repCount = self.detectorState.repCount
                self.phase = self.detectorState.phase
                self.feedback = self.detectorState.feedback

                // Haptic feedback when a new rep is counted
                if self.repCount > prevCount {
                    if self.repCount % 10 == 0 {
                        HapticManager.shared.milestone()
                    } else {
                        HapticManager.shared.repCounted()
                    }
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
