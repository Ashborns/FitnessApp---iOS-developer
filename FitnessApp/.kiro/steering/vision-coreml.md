---
inclusion: fileMatch
fileMatchPattern: "**/Camera/**,**/Vision*"
---

# Vision & CoreML Camera — FitnessApp

## Required Info.plist Key

```xml
<key>NSCameraUsageDescription</key>
<string>FitnessApp uses your camera to analyze exercise form and provide real-time feedback.</string>
```

## CameraViewModel Pattern

```swift
import AVFoundation

@MainActor
final class CameraViewModel: ObservableObject {
    @Published var isAuthorized: Bool = false
    @Published var isRunning: Bool = false
    @Published var formFeedback: String = ""

    let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let poseAnalyzer = VisionBodyPoseAnalyzer()
    private let queue = DispatchQueue(label: "camera.output.queue")

    func requestPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized: isAuthorized = true
        case .notDetermined:
            isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        default: isAuthorized = false
        }
    }

    func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .high
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)
        videoOutput.setSampleBufferDelegate(poseAnalyzer, queue: queue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
        session.commitConfiguration()
    }

    func startSession() {
        guard !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    func stopSession() {
        session.stopRunning()
    }
}
```

## VisionBodyPoseAnalyzer

```swift
import Vision
import AVFoundation

final class VisionBodyPoseAnalyzer: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    var onPoseDetected: ((VNHumanBodyPoseObservation) -> Void)?
    private var frameCount = 0

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        frameCount += 1
        guard frameCount % 4 == 0 else { return } // Process every 4th frame

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        let request = VNDetectHumanBodyPoseRequest()

        do {
            try handler.perform([request])
            if let observation = request.results?.first {
                DispatchQueue.main.async { [weak self] in
                    self?.onPoseDetected?(observation)
                }
            }
        } catch { /* frame dropped, not a crash */ }
    }
}
```

## CameraPreviewLayer (UIViewRepresentable)

```swift
struct CameraPreviewLayer: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.bounds
        }
    }
}
```

## Rules

- Always stop AVCaptureSession in `.onDisappear`
- Process every 4th frame (not every frame) for performance
- Never call UI updates from camera queue — dispatch to main
- Camera does NOT work in Simulator — test on real device
- If permission denied, show Settings deep-link button
