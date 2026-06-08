import Vision
import CoreGraphics

// MARK: - FrameChecker

/// Detects whether the user is properly positioned in the camera frame.
/// Evaluates body bounding box size, joint confidence, and centering
/// to provide corrective feedback before counting reps.
struct FrameChecker {

    /// Minimum fraction of frame width the body should occupy (30%).
    static let minBodyWidthFraction: CGFloat = 0.30

    /// Maximum fraction of frame width before body is considered too close (85%).
    static let maxBodyWidthFraction: CGFloat = 0.85

    /// Maximum horizontal offset from center before body is "not centered" (20% of frame width).
    static let maxCenterOffsetFraction: CGFloat = 0.20

    /// Minimum number of key joints required to consider a body "detected".
    static let minKeyJoints: Int = 4

    // MARK: - Result

    enum Result: Equatable {
        case ok
        case tooFar
        case tooClose
        case notCentered
        case partiallyOutOfFrame
        case noBodyDetected

        var feedbackMessage: String {
            switch self {
            case .ok:
                return ""
            case .tooFar:
                return "Step closer — you're too far from the camera"
            case .tooClose:
                return "Move back — you're too close to the camera"
            case .notCentered:
                return "Move to the center of the frame"
            case .partiallyOutOfFrame:
                return "Move back — show your full body"
            case .noBodyDetected:
                return "No body detected — stand in frame"
            }
        }

        /// Whether this result indicates the user is ready for rep counting.
        var isReady: Bool {
            self == .ok
        }

        /// Priority level — higher values take precedence when multiple issues exist.
        var priority: Int {
            switch self {
            case .noBodyDetected:       return 5
            case .partiallyOutOfFrame:  return 4
            case .tooFar:              return 3
            case .tooClose:            return 2
            case .notCentered:         return 1
            case .ok:                  return 0
            }
        }
    }

    // MARK: - Configuration

    /// Key joints that must be visible with high confidence for proper tracking.
    private static let requiredJoints: [VNHumanBodyPoseObservation.JointName] = [
        .leftShoulder, .rightShoulder,
        .leftHip, .rightHip,
        .leftKnee, .rightKnee,
        .nose
    ]

    /// Joints used to compute the bounding box of the body.
    private static let boundingJoints: [VNHumanBodyPoseObservation.JointName] = [
        .nose,
        .leftShoulder, .rightShoulder,
        .leftElbow, .rightElbow,
        .leftWrist, .rightWrist,
        .leftHip, .rightHip,
        .leftKnee, .rightKnee,
        .leftAnkle, .rightAnkle
    ]

    // MARK: - Public API

    /// Evaluates the current pose observation against the frame dimensions.
    /// - Parameters:
    ///   - observation: The current `VNHumanBodyPoseObservation`.
    ///   - frameSize: The pixel size of the camera frame being analyzed.
    /// - Returns: A `FrameChecker.Result` indicating the user's position quality.
    static func evaluate(
        observation: VNHumanBodyPoseObservation,
        frameSize: CGSize
    ) -> Result {
        guard let points = try? observation.recognizedPoints(.all) else {
            return .noBodyDetected
        }

        // Check: are enough key joints visible?
        let visibleKeyJoints = requiredJoints.filter { joint in
            points[joint]?.confidence ?? 0 >= 0.2
        }
        if visibleKeyJoints.count < minKeyJoints {
            return .noBodyDetected
        }

        // Compute body bounding box
        var minX: CGFloat = 1.0
        var maxX: CGFloat = 0.0
        var minY: CGFloat = 1.0
        var maxY: CGFloat = 0.0
        var havePoint = false

        for joint in boundingJoints {
            guard let point = points[joint], point.confidence >= 0.2 else { continue }
            let loc = point.location
            minX = min(minX, loc.x)
            maxX = max(maxX, loc.x)
            minY = min(minY, loc.y)
            maxY = max(maxY, loc.y)
            havePoint = true
        }

        guard havePoint else {
            return .noBodyDetected
        }

        let bodyWidth = maxX - minX
        let bodyHeight = maxY - minY
        let centerX = (minX + maxX) / 2

        // Check: partially out of frame (joints near edges with low confidence)
        let edgeThreshold: CGFloat = 0.05
        let nearLeftEdge = minX < edgeThreshold
        let nearRightEdge = maxX > (1.0 - edgeThreshold)
        let nearTopEdge = maxY > (1.0 - edgeThreshold)  // head
        let nearBottomEdge = minY < edgeThreshold       // feet

        // If body is clipped on any edge, it's partially out of frame
        if nearLeftEdge || nearRightEdge || nearTopEdge || nearBottomEdge {
            // Only trigger if the body width suggests it's actually clipped vs just small
            if bodyWidth > 0.15 {
                return .partiallyOutOfFrame
            }
        }

        // Check: too far (body is too small in frame)
        if bodyWidth < minBodyWidthFraction {
            return .tooFar
        }

        // Check: too close (body fills too much of frame)
        if bodyWidth > maxBodyWidthFraction || bodyHeight > 0.95 {
            return .tooClose
        }

        // Check: not centered (body mass shifted left/right)
        let offsetFromCenter = abs(centerX - 0.5)
        if offsetFromCenter > maxCenterOffsetFraction {
            return .notCentered
        }

        return .ok
    }
}