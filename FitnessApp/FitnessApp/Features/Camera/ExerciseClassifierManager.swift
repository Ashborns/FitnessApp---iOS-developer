import Vision
import CoreML
import Foundation

// MARK: - ExerciseClassifierManager
//
// Integrates the custom-trained ExerciseClassifier.mlmodel into the camera pipeline.
//
// MODEL STATUS:
//   ✅ Active — ExerciseClassifier.mlmodel is used as a secondary validation layer.
//   Primary rep counting remains rule-based via Apple Vision + ExerciseDetector.
//
// NOTE: The model was trained on synthetic data and is less accurate than Apple Vision.
// It serves as a supplementary tool for exercise classification, not the primary source.

@MainActor
final class ExerciseClassifierManager: ObservableObject {

    // MARK: - Singleton
    static let shared = ExerciseClassifierManager()

    // MARK: - Published State

    /// The exercise label predicted by the ML model.
    /// Values: "jumping_jack", "squat", "push_up", "high_knees", "lunge", "rest"
    @Published private(set) var predictedLabel: String = "rest"

    /// Confidence score for the current prediction (0.0 – 1.0)
    @Published private(set) var confidence: Double = 0.0

    /// Whether the ML model is loaded and active.
    @Published private(set) var isModelLoaded: Bool = false

    // MARK: - Configuration

    /// Set to true after adding ExerciseClassifier.mlmodel to the Xcode project.
    private let isModelAvailable: Bool = true

    /// Number of frames the model analyzes per prediction.
    /// Must match the "Prediction Window" used during Create ML training.
    private let predictionWindowSize: Int = 60

    // MARK: - Internal State

    /// Sliding window of recent pose observations fed to the model.
    private var poseWindow: [VNHumanBodyPoseObservation] = []

    // MARK: - Model

    private var model: ExerciseClassifier?

    // MARK: - Init

    private init() {
        if isModelAvailable {
            loadModel()
        }
    }

    // MARK: - Model Loading

    private func loadModel() {
        do {
            let config = MLModelConfiguration()
            // Use Neural Engine for best performance on device
            config.computeUnits = .cpuAndNeuralEngine
            model = try ExerciseClassifier(configuration: config)
            isModelLoaded = true
            print("✅ ExerciseClassifier loaded successfully")
        } catch {
            isModelLoaded = false
            print("❌ Failed to load ExerciseClassifier: \(error)")
        }
    }

    // MARK: - Public API

    /// Feed a new pose observation into the classifier.
    /// Call this every time VisionBodyPoseAnalyzer detects a pose.
    /// When the sliding window is full, runs inference automatically.
    func addPose(_ observation: VNHumanBodyPoseObservation) {
        poseWindow.append(observation)

        // Keep window at fixed size (sliding window)
        if poseWindow.count > predictionWindowSize {
            poseWindow.removeFirst()
        }

        // Only predict when window is full
        guard poseWindow.count == predictionWindowSize else { return }

        if isModelAvailable && isModelLoaded {
            runInference()
        }
    }

    /// Reset the classifier state (call when switching exercises or resetting workout).
    func reset() {
        poseWindow.removeAll()
        predictedLabel = "rest"
        confidence = 0.0
    }

    /// Human-readable display name for the current prediction.
    var predictedDisplayName: String {
        switch predictedLabel {
        case "jumping_jack": return "Jumping Jacks"
        case "squat":        return "Squats"
        case "push_up":      return "Push-Ups"
        case "high_knees":   return "High Knees"
        case "lunge":        return "Lunges"
        case "rest":         return "Rest"
        default:             return predictedLabel.replacingOccurrences(of: "_", with: " ").capitalized
        }
    }

    // MARK: - Inference

    private func runInference() {
        guard let model = model else { return }

        do {
            let posesArray = try buildPoseArray(from: poseWindow)
            let input = ExerciseClassifierInput(poses: posesArray)
            let output = try model.prediction(input: input)

            // Use MLFeatureProvider to access outputs by name (avoids auto-generated type issues)
            predictedLabel = output.featureValue(for: "label")?.stringValue ?? "rest"

            if let probs = output.featureValue(for: "labelProbabilities")?.dictionaryValue as? [String: NSNumber] {
                confidence = probs[predictedLabel]?.doubleValue ?? 0.0
            }

        } catch {
            print("Inference error: \(error)")
        }
    }

    // MARK: - Pose Array Builder

    /// Converts a window of VNHumanBodyPoseObservation into an MLMultiArray
    /// in the format expected by the neural network classifier.
    ///
    /// Shape: [1, 1, windowSize × numJoints × 3] = [1, 1, 3240] (3D with batch + channel dims)
    /// Each joint contributes: x (normalized), y (normalized), confidence
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

        let numJoints = jointNames.count
        let featuresPerJoint = 3  // x, y, confidence
        let flatSize = window.count * numJoints * featuresPerJoint  // 60 * 18 * 3 = 3240
        let shape: [NSNumber] = [1, 1, NSNumber(value: flatSize)]

        let array = try MLMultiArray(shape: shape, dataType: .float32)

        for (frameIdx, observation) in window.enumerated() {
            guard let points = try? observation.recognizedPoints(.all) else { continue }

            for (jointIdx, jointName) in jointNames.enumerated() {
                let baseIdx = frameIdx * (numJoints * featuresPerJoint) + jointIdx * featuresPerJoint

                if let point = points[jointName], point.confidence > 0.1 {
                    array[baseIdx]     = NSNumber(value: Float(point.location.x))
                    array[baseIdx + 1] = NSNumber(value: Float(point.location.y))
                    array[baseIdx + 2] = NSNumber(value: Float(point.confidence))
                } else {
                    array[baseIdx]     = 0
                    array[baseIdx + 1] = 0
                    array[baseIdx + 2] = 0
                }
            }
        }

        return array
    }
}