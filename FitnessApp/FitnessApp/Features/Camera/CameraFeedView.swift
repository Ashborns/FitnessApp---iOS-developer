import SwiftUI
import AVFoundation
import Vision

/// The main camera feed view that displays a live camera preview with
/// body pose overlay for real-time exercise form feedback.
///
/// - Requirements: 13.1, 13.3, 13.4, 13.6
struct CameraFeedView: View {

    @StateObject private var viewModel = CameraViewModel()
    @EnvironmentObject private var router: AppRouter
    @Environment(\.dismiss) private var dismiss
    @State private var poseDetectedPulse: Bool = false
    @State private var repPulse: Bool = false
    @State private var workoutStartTime: Date?
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var demoExercise: ExerciseType?
    @State private var completionSummary: WorkoutSummary?

    var body: some View {
        ZStack {
            if viewModel.isAuthorized {
                cameraContent
            } else {
                permissionDeniedContent
            }

            // Demo overlay (shown when user picks an exercise)
            if let demo = demoExercise {
                ExerciseDemoView(
                    exercise: demo,
                    onStart: {
                        viewModel.selectExercise(demo)
                        demoExercise = nil
                        resetWorkout()
                        startTimer()  // Start timer when user actually starts tracking
                    },
                    onCancel: {
                        demoExercise = nil
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                .zIndex(10)
            }

            // Completion sheet (shown after user finishes workout)
            if let summary = completionSummary {
                WorkoutCompletionSheet(summary: summary) {
                    completionSummary = nil
                    dismiss()
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(20)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: demoExercise)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: completionSummary != nil)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .task {
            await viewModel.requestPermission()
            if viewModel.isAuthorized {
                viewModel.configureAndStart()
                // DON'T start timer here — wait until user dismisses demo and starts tracking

                // If opened from chat with a specific exercise, select it directly (skip demo)
                if let pending = router.pendingExercise {
                    viewModel.selectExercise(pending)
                    router.pendingExercise = nil
                    startTimer()  // Start timer immediately when skipping demo
                } else {
                    // Show demo for default exercise on first open
                    demoExercise = viewModel.selectedExercise
                }
            }
        }
        .onDisappear {
            viewModel.stopSession()
            stopTimer()
        }
    }

    // MARK: - Camera Content

    @ViewBuilder
    private var cameraContent: some View {
        ZStack {
            CameraPreviewLayer(session: viewModel.session)
                .ignoresSafeArea()
                .accessibilityLabel("Camera preview")

            if let pose = viewModel.detectedPose {
                PoseOverlayView(
                    observation: pose,
                    mirrored: viewModel.cameraPosition == .front
                )
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
            }

                    // Top + bottom gradient overlays for readable HUD
            gradientOverlay

            // Frame position warning border overlay
            if !viewModel.frameCheckResult.isReady {
                frameWarningBorder
            }

            VStack {
                topBar
                Spacer()
                heroCounter
                Spacer().frame(height: 16)
                feedbackBanner
                if viewModel.mlModelUnavailable {
                    Spacer().frame(height: 10)
                    mlFallbackBanner
                }
                Spacer().frame(height: 16)
                bottomControls
            }
        }
        .onChange(of: viewModel.repCount) { newCount in
            guard newCount > 0 else { return }
            withAnimation(.easeOut(duration: 0.15)) {
                repPulse = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.easeOut(duration: 0.15)) {
                    repPulse = false
                }
            }
        }
    }

    // MARK: - Gradient Overlay (single thin top + bottom strip)

    private var gradientOverlay: some View {
        VStack(spacing: 0) {
            Color.black.opacity(0.5)
                .frame(height: 110)
            Spacer()
            Color.black.opacity(0.6)
                .frame(height: 240)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: - Top Bar (status + timer + close)

    private var topBar: some View {
        HStack(spacing: 10) {
            // Detection badge — solid pill, no blur
            HStack(spacing: 5) {
                Circle()
                    .fill(viewModel.detectedPose != nil ? Color.themePrimary : Color.orange)
                    .frame(width: 7, height: 7)
                Text(viewModel.detectedPose != nil ? "TRACKING" : "SCANNING")
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.white)
                    .tracking(1.2)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.5))
            .cornerRadius(16)

            // Timer — solid
            HStack(spacing: 5) {
                Image(systemName: "timer")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.themePrimary)
                Text(formatTime(elapsedTime))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .monospacedDigit()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.5))
            .cornerRadius(16)

            Spacer()

            // Voice coach mute toggle — solid circle
            Button {
                viewModel.toggleVoice()
            } label: {
                Image(systemName: viewModel.voiceEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Voice Coach")
            .accessibilityValue(viewModel.voiceEnabled ? "On" : "Off")
            .accessibilityIdentifier("camera-voice-toggle-btn")

            // Flip camera — solid circle
            Button {
                viewModel.flipCamera()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Flip camera")
            .accessibilityIdentifier("camera-flip-btn")

            // Close — solid circle
            Button {
                handleClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Finish workout")
            .accessibilityIdentifier("camera-dismiss-btn")
        }
        .padding(.horizontal, 14)
        .padding(.top, 14)
    }

    // MARK: - Hero Counter

    private var heroCounter: some View {
        VStack(spacing: 4) {
            // Phase pill — solid
            HStack(spacing: 5) {
                Image(systemName: viewModel.selectedExercise.icon)
                    .font(.system(size: 10))
                Text(viewModel.selectedExercise.displayName.uppercased())
                    .font(.system(size: 11, weight: .heavy))
                    .tracking(1.5)
            }
            .foregroundColor(.themePrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.5))
            .cornerRadius(16)

            // Big number — solid color (no gradient, no shadow)
            Text("\(viewModel.repCount)")
                .font(.system(size: 100, weight: .heavy, design: .rounded))
                .foregroundColor(.themePrimary)
                .scaleEffect(repPulse ? 1.10 : 1.0)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("\(viewModel.repCount) repetitions")

            // Phase indicator
            HStack(spacing: 5) {
                Circle()
                    .fill(Color.themePrimary)
                    .frame(width: 5, height: 5)
                Text(viewModel.phase.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))
                    .tracking(1.2)
            }

            // ML prediction label (secondary info only)
            if ExerciseClassifierManager.shared.isModelLoaded {
                mlPredictionLabel
            }
        }
    }

    // MARK: - ML Prediction Label

    private var mlPredictionLabel: some View {
        let classifier = ExerciseClassifierManager.shared
        return HStack(spacing: 4) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 8))
                .foregroundColor(.white.opacity(0.5))
            Text("AI: \(classifier.predictedDisplayName)")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
            Text("(\(Int(classifier.confidence * 100))%)")
                .font(.system(size: 8, weight: .regular))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.white.opacity(0.1))
        .cornerRadius(6)
        .accessibilityIdentifier("camera-ml-label")
    }

    // MARK: - Feedback Banner

    // MARK: - Frame Warning Border

    private var frameWarningBorder: some View {
        ZStack {
            // Outer pulsing border
            RoundedRectangle(cornerRadius: 16)
                .stroke(warningColor, lineWidth: 3)
                .padding(12)
                .opacity(0.8)

            // Warning icon + text at top
            VStack {
                HStack(spacing: 6) {
                    Image(systemName: warningIcon)
                        .font(.system(size: 11, weight: .bold))
                    Text(viewModel.frameCheckResult.feedbackMessage)
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(warningColor.opacity(0.7))
                .cornerRadius(8)
                .padding(.top, 20)
                Spacer()
            }
        }
        .allowsHitTesting(false)
        .accessibilityIdentifier("camera-frame-warning")
    }

    private var warningColor: Color {
        switch viewModel.frameCheckResult {
        case .ok:                         return .clear
        case .tooFar, .tooClose, .partiallyOutOfFrame: return .orange
        case .notCentered:                return .yellow
        case .noBodyDetected:             return .red
        }
    }

    private var warningIcon: String {
        switch viewModel.frameCheckResult {
        case .ok:                         return ""
        case .tooFar:                     return "arrow.up.left.and.arrow.down.right"
        case .tooClose:                   return "arrow.down.right.and.arrow.up.left"
        case .notCentered:                return "arrow.left.and.right"
        case .partiallyOutOfFrame:        return "person.crop.rectangle"
        case .noBodyDetected:             return "person.slash"
        }
    }

    private var feedbackBanner: some View {
        HStack(spacing: 6) {
            if !viewModel.frameCheckResult.isReady {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
            }
            Text(viewModel.feedback)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            viewModel.frameCheckResult.isReady
                ? Color.black.opacity(0.5)
                : Color.orange.opacity(0.3)
        )
        .cornerRadius(10)
        .padding(.horizontal, 20)
        .accessibilityIdentifier("camera-instruction-label")
    }

    // MARK: - ML Fallback Banner (R8.1)

    /// Shown when the Squat FlexFitClassifier model failed to load and the
    /// rule-based fallback detector is being used instead. Reuses the
    /// `feedbackBanner` visual style.
    private var mlFallbackBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
                .foregroundColor(.orange)
            Text("Squat ML model unavailable — using fallback detection")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.3))
        .cornerRadius(10)
        .padding(.horizontal, 20)
        .accessibilityIdentifier("camera-ml-fallback-banner")
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 10) {
            exercisePicker

            Button {
                resetWorkout()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 12, weight: .bold))
                    Text("Reset")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.black.opacity(0.5))
                .cornerRadius(12)
            }
            .accessibilityLabel("Reset workout")
            .accessibilityIdentifier("camera-reset-btn")
            .padding(.horizontal, 14)
        }
        .padding(.bottom, 24)
    }

    private var exercisePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ExerciseType.allCases) { exercise in
                    let isSelected = viewModel.selectedExercise == exercise
                    Button {
                        demoExercise = exercise
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: exercise.icon)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(isSelected ? .black : .white)
                            Text(exercise.displayName)
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundColor(isSelected ? .black : .white)
                                .lineLimit(1)
                        }
                        .frame(width: 70, height: 60)
                        .background(isSelected ? Color.themePrimary : Color.black.opacity(0.5))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Select \(exercise.displayName)")
                    .accessibilityIdentifier("camera-exercise-\(exercise.rawValue)")
                }
            }
            .padding(.horizontal, 14)
        }
    }

    // MARK: - Timer

    private func startTimer() {
        workoutStartTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if let start = workoutStartTime {
                elapsedTime = Date().timeIntervalSince(start)
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func resetWorkout() {
        viewModel.resetCounter()
        workoutStartTime = Date()
        elapsedTime = 0
    }

    /// Close button: if user has logged any reps, save session and show summary.
    /// Otherwise just dismiss.
    private func handleClose() {
        stopTimer()  // Stop timer before saving to prevent leak
        let summary = viewModel.saveWorkoutSession()
        if summary.hasData {
            completionSummary = summary
        } else {
            dismiss()
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalSec = Int(seconds)
        let mins = totalSec / 60
        let secs = totalSec % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    // MARK: - Permission Denied

    @ViewBuilder
    private var permissionDeniedContent: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.07, blue: 0.12), Color(red: 0.12, green: 0.12, blue: 0.20)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 120, height: 120)
                    Image(systemName: "camera.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.white.opacity(0.6))
                }
                .accessibilityHidden(true)

                VStack(spacing: 12) {
                    Text("Camera Access Required")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    Text("FitnessApp needs camera access to analyze your exercise form and provide real-time body pose feedback.")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        openSettings()
                    } label: {
                        HStack {
                            Image(systemName: "gear")
                            Text("Open Settings")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .foregroundColor(.black)
                        .cornerRadius(14)
                    }
                    .accessibilityIdentifier("camera-open-settings-btn")

                    Button {
                        dismiss()
                    } label: {
                        Text("Not Now")
                            .fontWeight(.medium)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .accessibilityIdentifier("camera-permission-dismiss-btn")
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
    }

    // MARK: - Helpers

    private func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }
}

// MARK: - CameraPreviewLayer

/// A UIViewRepresentable that wraps AVCaptureVideoPreviewLayer to display
/// the live camera feed within SwiftUI.
struct CameraPreviewLayer: UIViewRepresentable {

    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView(frame: .zero)
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.previewLayer.frame = uiView.bounds
    }
}

/// A UIView subclass that hosts an AVCaptureVideoPreviewLayer and keeps
/// its frame synchronized with layout changes.
final class CameraPreviewUIView: UIView {

    /// The video preview layer displaying the camera feed.
    let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(previewLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}

// MARK: - PoseOverlayView

/// Draws detected joint positions and skeleton lines overlaid on the camera preview.
/// Only joints with confidence >= 0.5 are displayed.
///
/// - Requirements: 13.3, 13.4
struct PoseOverlayView: View {

    let observation: VNHumanBodyPoseObservation
    /// Whether to mirror X coordinates (true for front camera, false for back camera)
    let mirrored: Bool

    /// Minimum confidence threshold for displaying a joint.
    /// Matches detector threshold (0.2) so any joint that affects rep counting is also drawn.
    private let confidenceThreshold: Float = 0.2

    /// Skeleton connections — minimal set, no head/neck for lighter load.
    private let skeletonConnections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        // Torso
        (.leftShoulder, .rightShoulder),
        (.leftShoulder, .leftHip),
        (.rightShoulder, .rightHip),
        (.leftHip, .rightHip),
        // Arms
        (.leftShoulder, .leftElbow),
        (.leftElbow, .leftWrist),
        (.rightShoulder, .rightElbow),
        (.rightElbow, .rightWrist),
        // Legs
        (.leftHip, .leftKnee),
        (.leftKnee, .leftAnkle),
        (.rightHip, .rightKnee),
        (.rightKnee, .rightAnkle)
    ]

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let pointMap = extractJointMap(in: size)

            ZStack {
                // Sharp skeleton stroke
                skeletonLinesPath(pointMap: pointMap, size: size)
                    .stroke(
                        Color.themePrimary,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )

                // All joints visible
                ForEach(Array(pointMap.values), id: \.id) { point in
                    Circle()
                        .fill(Color.themePrimary)
                        .frame(width: point.isKeyJoint ? 10 : 7, height: point.isKeyJoint ? 10 : 7)
                        .position(point.position)
                }
            }
        }
    }

    // MARK: - Skeleton Lines

    private func skeletonLinesPath(pointMap: [String: JointPoint], size: CGSize) -> Path {
        var path = Path()
        guard let recognizedPoints = try? observation.recognizedPoints(.all) else { return path }

        for (fromJoint, toJoint) in skeletonConnections {
            guard
                let fromPoint = recognizedPoints[fromJoint],
                let toPoint = recognizedPoints[toJoint],
                fromPoint.confidence >= confidenceThreshold,
                toPoint.confidence >= confidenceThreshold
            else { continue }

            let from = projectPoint(fromPoint.location, in: size)
            let to = projectPoint(toPoint.location, in: size)

            path.move(to: from)
            path.addLine(to: to)
        }

        return path
    }

    /// Convert Vision's normalized coordinate (origin bottom-left) to view coordinate (origin top-left).
    /// Mirrors X horizontally only when `mirrored` is true (front camera selfie mode).
    private func projectPoint(_ location: CGPoint, in size: CGSize) -> CGPoint {
        let x = mirrored ? (1 - location.x) * size.width : location.x * size.width
        let y = (1 - location.y) * size.height
        return CGPoint(x: x, y: y)
    }

    // MARK: - Joint Extraction

    /// Extracts recognized joint positions from the pose observation,
    /// converting from Vision's normalized coordinate space to view coordinates.
    private func extractJointMap(in size: CGSize) -> [String: JointPoint] {
        guard let recognizedPoints = try? observation.recognizedPoints(.all) else {
            return [:]
        }

        let keyJoints: Set<String> = [
            VNHumanBodyPoseObservation.JointName.leftShoulder.rawValue.rawValue,
            VNHumanBodyPoseObservation.JointName.rightShoulder.rawValue.rawValue,
            VNHumanBodyPoseObservation.JointName.leftHip.rawValue.rawValue,
            VNHumanBodyPoseObservation.JointName.rightHip.rawValue.rawValue,
            VNHumanBodyPoseObservation.JointName.leftKnee.rawValue.rawValue,
            VNHumanBodyPoseObservation.JointName.rightKnee.rawValue.rawValue,
            VNHumanBodyPoseObservation.JointName.nose.rawValue.rawValue
        ]

        var jointMap: [String: JointPoint] = [:]

        for (key, point) in recognizedPoints where point.confidence >= confidenceThreshold {
            let projected = projectPoint(point.location, in: size)
            let jointId = key.rawValue.rawValue

            jointMap[jointId] = JointPoint(
                id: jointId,
                position: projected,
                isKeyJoint: keyJoints.contains(jointId)
            )
        }

        return jointMap
    }
}

// MARK: - JointPoint

/// A single joint position for rendering in the overlay.
private struct JointPoint: Identifiable {
    let id: String
    let position: CGPoint
    let isKeyJoint: Bool
}
