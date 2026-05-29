import AVFoundation
import Vision

/// Analyzes camera frames for human body pose detection using the Vision framework.
/// Processes every 4th frame to maintain real-time performance while providing
/// pose detection results via the `onPoseDetected` callback.
///
/// - Requirements: 13.2, 13.3, 13.6
final class VisionBodyPoseAnalyzer: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    /// Callback invoked on the main thread when a body pose is detected.
    /// The observation contains joint positions with confidence >= 0.2.
    var onPoseDetected: ((VNHumanBodyPoseObservation) -> Void)?

    /// Callback invoked on the main thread when no body is currently visible.
    /// View should clear the skeleton overlay and switch detection badge to "scanning".
    var onPoseLost: (() -> Void)?

    /// Tracks the number of frames received to implement frame skipping.
    private var frameCount: Int = 0

    /// Confidence floor — any joint below this is considered absent.
    private let confidenceThreshold: Float = 0.2

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        frameCount += 1

        // Process every 3rd frame (~10 fps detection — accurate & responsive)
        guard frameCount % 3 == 0 else { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        let request = VNDetectHumanBodyPoseRequest()

        do {
            try handler.perform([request])

            guard let observation = request.results?.first else {
                // No body detected — notify view to clear overlay
                DispatchQueue.main.async { [weak self] in
                    self?.onPoseLost?()
                }
                return
            }

            // Filter joints by confidence threshold
            let recognizedPoints = try observation.recognizedPoints(.all)
            let hasConfidentJoints = recognizedPoints.values.contains { point in
                point.confidence >= self.confidenceThreshold
            }

            guard hasConfidentJoints else {
                DispatchQueue.main.async { [weak self] in
                    self?.onPoseLost?()
                }
                return
            }

            DispatchQueue.main.async { [weak self] in
                self?.onPoseDetected?(observation)
            }
        } catch {
            // Silent failure on Vision errors
        }
    }
}
