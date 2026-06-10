import Vision
import CoreGraphics

// MARK: - FrameChecker

/// Detects whether the user is properly positioned in the camera frame.
/// Evaluates body bounding box size, joint confidence, and centering
/// to provide corrective feedback before counting reps.
struct FrameChecker {

    /// Minimum fraction of frame width the body should occupy (kept as a loose sanity bound).
    static let minBodyWidthFraction: CGFloat = 0.08

    /// Maximum fraction of frame width before body is considered too close.
    static let maxBodyWidthFraction: CGFloat = 0.95

    /// Distance is judged primarily by vertical extent, which is the dominant and most
    /// stable dimension for standing exercises in a portrait frame.
    /// Minimum fraction of frame height the body should span before it's "too far".
    static let minBodyHeightFraction: CGFloat = 0.35

    /// Maximum fraction of frame height before the body is "too close".
    static let maxBodyHeightFraction: CGFloat = 0.98

    /// Maximum horizontal offset from center before body is "not centered" (28% of frame width).
    static let maxCenterOffsetFraction: CGFloat = 0.28

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

    /// Joints used to compute the bounding box of the body. Deliberately excludes the
    /// elbows and wrists: during exercises like jumping jacks the arms swing widely, which
    /// would make a wrist/elbow-based box jump around and cause false "too close" / clipping
    /// readings. The core torso-and-legs joints give a stable distance estimate.
    private static let boundingJoints: [VNHumanBodyPoseObservation.JointName] = [
        .nose,
        .leftShoulder, .rightShoulder,
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

        // Check: is a body present at all? Be lenient here — if *any* reasonable set of joints
        // is visible we treat the body as detected and let the distance / centering checks give
        // actionable guidance, instead of bailing out with "no body" when only part of the body
        // (e.g. upper body) is in view.
        let confidentJointCount = points.values.filter { $0.confidence >= 0.15 }.count
        if confidentJointCount < minKeyJoints {
            return .noBodyDetected
        }

        // Compute body bounding box
        var minX: CGFloat = 1.0
        var maxX: CGFloat = 0.0
        var minY: CGFloat = 1.0
        var maxY: CGFloat = 0.0
        var havePoint = false

        for joint in boundingJoints {
            guard let point = points[joint], point.confidence >= 0.15 else { continue }
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

        // Check: partially out of frame (body clipped at an edge).
        let edgeThreshold: CGFloat = 0.03
        let nearLeftEdge = minX < edgeThreshold
        let nearRightEdge = maxX > (1.0 - edgeThreshold)
        let nearTopEdge = maxY > (1.0 - edgeThreshold)  // head
        let nearBottomEdge = minY < edgeThreshold       // feet

        // Only treat clipping as "out of frame" when the body is clearly large (i.e. genuinely
        // cut off), not merely small and far away (handled by the distance check below).
        if nearLeftEdge || nearRightEdge || nearTopEdge || nearBottomEdge {
            if bodyHeight > 0.75 {
                return .partiallyOutOfFrame
            }
        }

        // Distance is judged primarily by the body's vertical extent — the dominant, most
        // stable dimension for a standing person in a portrait frame. (Horizontal width is
        // unreliable: a standing body is far taller than wide and arm pose changes it.)
        if bodyHeight < minBodyHeightFraction {
            return .tooFar
        }
        if bodyHeight > maxBodyHeightFraction || bodyWidth > maxBodyWidthFraction {
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