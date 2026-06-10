import Vision
import CoreML
import Foundation

// MARK: - FlexFitClassifierManager
//
// Integrates the custom-trained FitnessModel.mlmodel (a Create ML Action Classifier)
// into the camera pipeline as the SOURCE OF TRUTH for the Squats exercise only.
//
// MODEL STATUS:
//   FitnessModel.mlmodel is the squat detection authority. When the model fails to
//   load, the existing rule-based ExerciseDetector handles Squats as a fallback.
//
// MODEL INTERFACE (FitnessModel.mlmodel):
//   • input  `poses`              — MLMultiArray shape [60, 3, 18] (window, channel, joint)
//                                    channel order is (x, y, confidence); 18 Vision joints
//   • output `label`              — predicted movement label (String)
//   • output `labelProbabilities` — per-label probabilities ([String: Double])
//
// Mirrors ExerciseClassifierManager line-for-line in shape: same `static let shared`,
// same `loadModel()` / `MLModelConfiguration.computeUnits = .cpuAndNeuralEngine` pattern,
// same sliding `poseWindow`, same `featureValue(for:)`-based output reading (no coupling
// to an auto-generated output type).

@MainActor
final class FlexFitClassifierManager: ObservableObject {

    // MARK: - Singleton
    static let shared = FlexFitClassifierManager()

    // MARK: - Published State

    /// The squat phase label predicted by the ML model.
    /// Read directly from model output — never hardcoded. The down/up/rest vocabulary
    /// is discovered at runtime and interpreted by SquatPhase.
    @Published private(set) var squatLabel: String = ""

    /// Confidence score for the current prediction (0.0 – 1.0)
    @Published private(set) var squatConfidence: Double = 0.0

    /// Whether the ML model is loaded and active.
    @Published private(set) var isModelLoaded: Bool = false

    // MARK: - Configuration

    /// Number of frames the model analyzes per prediction.
    /// Must match the "Prediction Window" used during Create ML training (FitnessModel = 60).
    private let predictionWindowSize: Int = 60

    // MARK: - Internal State

    /// Sliding window of recent pose observations fed to the model.
    private var poseWindow: [VNHumanBodyPoseObservation] = []

    // MARK: - Model

    private var model: FitnessModel?

    // MARK: - Init

    /// Loaded exactly once per launch via the singleton.
    private init() {
        loadModel()
    }

    // MARK: - Model Loading

    private func loadModel() {
        do {
            let config = MLModelConfiguration()
            // Use Neural Engine for best performance on device
            config.computeUnits = .cpuAndNeuralEngine
            model = try FitnessModel(configuration: config)
            isModelLoaded = true
            print("✅ FitnessModel loaded successfully")
        } catch {
            isModelLoaded = false
            print("❌ Failed to load FitnessModel: \(error)")
        }
    }

    // MARK: - Public API

    /// Feed a new pose observation into the classifier.
    /// Call this every time VisionBodyPoseAnalyzer detects a pose while Squats is active.
    /// When the sliding window is full, runs inference automatically and slides forward.
    func addPose(_ observation: VNHumanBodyPoseObservation) {
        poseWindow.append(observation)

        // Only predict when the window has reached the prediction size.
        guard poseWindow.count >= predictionWindowSize else { return }

        if isModelLoaded {
            runInference()
        }

        // Slide the window forward by dropping the oldest frame.
        poseWindow.removeFirst()
    }

    /// Reset the classifier state (call when switching exercises or resetting workout).
    func reset() {
        poseWindow.removeAll()
        squatLabel = ""
        squatConfidence = 0.0
    }

    // MARK: - Inference

    private func runInference() {
        guard let model = model else { return }

        do {
            let posesArray = try buildPoseArray(from: poseWindow)
            let input = FitnessModelInput(poses: posesArray)
            let output = try model.prediction(input: input)

            // Use MLFeatureProvider to access outputs by name (avoids auto-generated type issues)
            squatLabel = output.featureValue(for: "label")?.stringValue ?? squatLabel

            if let probs = output.featureValue(for: "labelProbabilities")?.dictionaryValue as? [String: NSNumber] {
                squatConfidence = probs[squatLabel]?.doubleValue ?? 0.0
            }

        } catch {
            print("Inference error: \(error)")
        }
    }

    // MARK: - Pose Array Builder

    /// Converts a window of VNHumanBodyPoseObservation into an MLMultiArray
    /// in the format FitnessModel (a Create ML Action Classifier) expects.
    ///
    /// Shape: [windowSize, 3, numJoints] = [60, 3, 18]
    ///   • dim 0 (window)  — one slice per frame, oldest → newest
    ///   • dim 1 (channel) — 0 = x, 1 = y, 2 = confidence
    ///   • dim 2 (joint)   — 18 Vision joints in the order trained on
    ///
    /// Element (frame f, channel c, joint j) lives at the C-contiguous flat index
    /// `f * (3 * numJoints) + c * numJoints + j`.
    private func buildPoseArray(from window: [VNHumanBodyPoseObservation]) throws -> MLMultiArray {
        let jointNames: [VNHumanBodyPoseObservation.JointName] = [
            .nose,
            .leftEye, .rightEye,
            .leftEar, .rightEar,
            .leftShoulder, .rightShoulder,
            .leftElbow, .rightElbow,
            .leftWrist, .rightWrist,
            .leftHip, .rightHip,
            .leftKnee, .rightKnee,
            .leftAnkle, .rightAnkle,
            .neck
        ]

        let numJoints = jointNames.count          // 18
        let numChannels = 3                        // x, y, confidence
        let frameStride = numChannels * numJoints  // 54
        let shape: [NSNumber] = [
            NSNumber(value: window.count),         // 60
            NSNumber(value: numChannels),          // 3
            NSNumber(value: numJoints)             // 18
        ]

        let array = try MLMultiArray(shape: shape, dataType: .float32)

        for (frameIdx, observation) in window.enumerated() {
            let points = (try? observation.recognizedPoints(.all)) ?? [:]

            for (jointIdx, jointName) in jointNames.enumerated() {
                let base = frameIdx * frameStride + jointIdx   // channel 0 (x) slot for this joint

                if let point = points[jointName], point.confidence > 0.1 {
                    array[base]                 = NSNumber(value: Float(point.location.x))   // c = 0
                    array[base + numJoints]     = NSNumber(value: Float(point.location.y))   // c = 1
                    array[base + 2 * numJoints] = NSNumber(value: Float(point.confidence))   // c = 2
                } else {
                    array[base]                 = 0
                    array[base + numJoints]     = 0
                    array[base + 2 * numJoints] = 0
                }
            }
        }

        return array
    }
}
