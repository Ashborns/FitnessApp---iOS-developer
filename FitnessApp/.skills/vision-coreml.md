# Skill: Vision & CoreML Camera
# Project: FitnessCoach iOS App
# Target: iOS 16.4 / Xcode 14.0 / Swift 5.7
# Read this before writing any camera, Vision, or CoreML code in this project.

---

## Required Info.plist Key

```xml
<key>NSCameraUsageDescription</key>
<string>FitnessCoach uses your camera to analyze your exercise form and provide real-time feedback.</string>
```

The app will crash without this key when camera access is first requested.

---

## AVFoundation Camera Setup (iOS 16.4)

```swift
import AVFoundation
import SwiftUI

final class CameraViewModel: ObservableObject {
    @Published var isAuthorized: Bool = false
    @Published var isRunning: Bool = false
    @Published var formFeedback: String = ""
    @Published var poseConfidence: Double = 0

    let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let poseAnalyzer = VisionBodyPoseAnalyzer()
    private let queue = DispatchQueue(label: "camera.output.queue")

    func requestPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            await MainActor.run { isAuthorized = true }
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            await MainActor.run { isAuthorized = granted }
        default:
            await MainActor.run { isAuthorized = false }
        }
    }

    func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                    for: .video,
                                                    position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        videoOutput.setSampleBufferDelegate(poseAnalyzer, queue: queue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        session.commitConfiguration()
    }

    func startSession() {
        guard !session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
            DispatchQueue.main.async { self?.isRunning = true }
        }
    }

    func stopSession() {
        guard session.isRunning else { return }
        session.stopRunning()
        DispatchQueue.main.async { self.isRunning = false }
    }
}
```

---

## CameraFeedView (SwiftUI + AVFoundation bridge)

```swift
struct CameraFeedView: View {
    @StateObject private var viewModel = CameraViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            CameraPreviewLayer(session: viewModel.session)
                .ignoresSafeArea()

            VStack {
                Text(viewModel.formFeedback)
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding()
            }
        }
        .task {
            await viewModel.requestPermission()
            if viewModel.isAuthorized {
                viewModel.setupSession()
                viewModel.startSession()
            }
        }
        .onDisappear {
            viewModel.stopSession()
        }
    }
}

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

---

## VisionBodyPoseAnalyzer

```swift
import Vision
import AVFoundation

final class VisionBodyPoseAnalyzer: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {

    var onPoseDetected: ((VNHumanBodyPoseObservation) -> Void)?

    private lazy var poseRequest: VNDetectHumanBodyPoseRequest = {
        let request = VNDetectHumanBodyPoseRequest()
        return request
    }()

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                           orientation: .up,
                                           options: [:])
        do {
            try handler.perform([poseRequest])
            if let observation = poseRequest.results?.first {
                DispatchQueue.main.async { [weak self] in
                    self?.onPoseDetected?(observation)
                }
            }
        } catch {
            // Silent failure — camera frames drop if analysis fails, not a crash
        }
    }

    // Example: check if both wrists are raised (push-up top position)
    func analyzeSquatForm(_ observation: VNHumanBodyPoseObservation) -> String {
        guard let leftKnee = try? observation.recognizedPoint(.leftKnee),
              let rightKnee = try? observation.recognizedPoint(.rightKnee),
              let leftHip = try? observation.recognizedPoint(.leftHip),
              leftKnee.confidence > 0.5,
              rightKnee.confidence > 0.5 else {
            return "Adjust your position"
        }

        let kneeY = (leftKnee.location.y + rightKnee.location.y) / 2
        let hipY = leftHip.location.y

        // In Vision coordinates, y=0 is bottom. Hip above knee = standing.
        if hipY < kneeY {
            return "Good depth! Hold position."
        } else {
            return "Go lower for full squat depth."
        }
    }
}
```

---

## CoreML Integration

```swift
// If a .mlmodel file is provided, add it to the Xcode target.
// Xcode auto-generates a Swift class for it.

// Example usage (replace ModelName with your actual .mlmodel class name):
// let model = try? ModelName()
// let input = ModelNameInput(image: pixelBuffer)
// let output = try? model?.prediction(input: input)

// For this project, if no .mlmodel is provided yet, use a placeholder:
struct CoreMLPlaceholder {
    static func predictFormScore(from observation: VNHumanBodyPoseObservation) -> Double {
        // TODO: Replace with real CoreML model when available
        // Placeholder: return confidence of key joints as a proxy
        let joints: [VNHumanBodyPoseObservation.JointName] = [.leftKnee, .rightKnee, .leftHip, .rightHip]
        let confidences = joints.compactMap { try? observation.recognizedPoint($0) }
                                .map { $0.confidence }
        return Double(confidences.reduce(0, +)) / Double(max(confidences.count, 1))
    }
}
```

---

## Rules

- Always stop the AVCaptureSession in `.onDisappear` — a running session keeps the camera LED on.
- Vision requests are expensive. Process every 3rd–5th frame, not every frame:
  ```swift
  private var frameCount = 0
  // In captureOutput:
  frameCount += 1
  guard frameCount % 4 == 0 else { return }
  ```
- Never call UI updates from the camera queue — always dispatch to main thread.
- Simulator: AVCaptureSession returns no video frames. Test all camera features on a real device.
- If camera permission is denied, show a Settings deep-link — never block the whole screen:
  ```swift
  if let url = URL(string: UIApplication.openSettingsURLString) {
      UIApplication.shared.open(url)
  }
  ```
