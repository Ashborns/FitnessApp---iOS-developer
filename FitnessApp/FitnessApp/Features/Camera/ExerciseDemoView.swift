import SwiftUI

/// Animated tutorial overlay that demonstrates how to perform the selected exercise.
/// Shown when user taps an exercise pill — animates between two poses to show movement.
struct ExerciseDemoView: View {

    let exercise: ExerciseType
    let onStart: () -> Void
    let onCancel: () -> Void

    @State private var isAlternate: Bool = false

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            VStack(spacing: 24) {
                Spacer()

                // Header
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: exercise.icon)
                            .font(.caption)
                        Text("HOW TO DO IT")
                            .font(.caption)
                            .fontWeight(.heavy)
                            .tracking(2)
                    }
                    .foregroundColor(.themePrimary)

                    Text(exercise.displayName)
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                }

                // Animated stick figure demo
                StickFigureDemo(exercise: exercise, isAlternate: isAlternate)
                    .frame(width: 220, height: 280)

                // Instructions
                VStack(spacing: 12) {
                    instructionsCard
                    tipsCard
                }
                .padding(.horizontal, 24)

                Spacer()

                // Buttons
                VStack(spacing: 12) {
                    Button(action: onStart) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                            Text("Start Tracking")
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.brandGradient)
                        .cornerRadius(28)
                        .shadow(color: Color.themePrimary.opacity(0.5), radius: 12, x: 0, y: 4)
                    }
                    .accessibilityLabel("Start tracking")
                    .accessibilityIdentifier("demo-start-btn")

                    Button(action: onCancel) {
                        Text("Cancel")
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.vertical, 8)
                    }
                    .accessibilityIdentifier("demo-cancel-btn")
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                isAlternate.toggle()
            }
        }
    }

    // MARK: - Instructions Card

    private var instructionsCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.themePrimary)
                .font(.subheadline)
            Text(instructions)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .cornerRadius(14)
    }

    private var tipsCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.themeSecondary)
                .font(.subheadline)
            Text(tips)
                .font(.caption)
                .foregroundColor(.white.opacity(0.75))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .cornerRadius(14)
    }

    // MARK: - Copy

    private var instructions: String {
        switch exercise {
        case .jumpingJacks:
            return "Jump while raising your arms above your head and spreading your legs wide. Return to the start position."
        case .squats:
            return "Stand with feet shoulder-width apart. Lower your hips down then push back up to standing."
        case .highKnees:
            return "Run in place while lifting each knee toward your hip. Keep alternating left and right."
        case .armRaises:
            return "Stand tall and raise both arms straight up overhead, then lower them back down to your sides."
        case .toeTouches:
            return "Bend forward from your hips and reach for your toes, then stand back up tall with arms relaxed."
        }
    }

    private var tips: String {
        switch exercise {
        case .jumpingJacks: return "Stand 6–8 ft from the camera. Make sure your full body is visible."
        case .squats:       return "Turn sideways to the camera for best knee angle tracking."
        case .highKnees:    return "Lift knees high — at least to hip height for each rep to count."
        case .armRaises:    return "Keep arms straight. Raise fully overhead before lowering."
        case .toeTouches:   return "Turn sideways to the camera so it can clearly see you bend forward."
        }
    }
}

// MARK: - StickFigureDemo

/// Animated stick figure that demonstrates the exercise by toggling between two poses.
struct StickFigureDemo: View {
    let exercise: ExerciseType
    let isAlternate: Bool

    var body: some View {
        ZStack {
            // Glow background ring
            Circle()
                .fill(Color.themePrimary.opacity(0.15))
                .blur(radius: 30)
                .scaleEffect(0.85)

            // Stick figure canvas
            GeometryReader { geo in
                let pose = currentPose(in: geo.size)
                ZStack {
                    // Skeleton lines
                    skeletonPath(pose: pose)
                        .stroke(
                            Color.themePrimary,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                        )
                        .shadow(color: Color.themePrimary.opacity(0.6), radius: 6)

                    // Joint dots
                    ForEach(Array(pose.joints.enumerated()), id: \.offset) { _, joint in
                        Circle()
                            .fill(Color.white)
                            .frame(width: 10, height: 10)
                            .shadow(color: Color.themePrimary, radius: 4)
                            .position(joint)
                    }

                    // Head
                    Circle()
                        .fill(Color.themePrimary.opacity(0.3))
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(Color.themePrimary, lineWidth: 3))
                        .position(pose.head)
                }
            }
        }
    }

    // MARK: - Pose Geometry

    private struct Pose {
        let head: CGPoint
        let neck: CGPoint
        let leftShoulder: CGPoint
        let rightShoulder: CGPoint
        let leftElbow: CGPoint
        let rightElbow: CGPoint
        let leftWrist: CGPoint
        let rightWrist: CGPoint
        let leftHip: CGPoint
        let rightHip: CGPoint
        let leftKnee: CGPoint
        let rightKnee: CGPoint
        let leftAnkle: CGPoint
        let rightAnkle: CGPoint

        var joints: [CGPoint] {
            [neck, leftShoulder, rightShoulder, leftElbow, rightElbow,
             leftWrist, rightWrist, leftHip, rightHip,
             leftKnee, rightKnee, leftAnkle, rightAnkle]
        }
    }

    private func currentPose(in size: CGSize) -> Pose {
        switch exercise {
        case .jumpingJacks: return jumpingJackPose(in: size, alternate: isAlternate)
        case .squats:       return squatPose(in: size, alternate: isAlternate)
        case .highKnees:    return highKneesPose(in: size, alternate: isAlternate)
        case .armRaises:    return armRaisePose(in: size, alternate: isAlternate)
        case .toeTouches:   return toeTouchPose(in: size, alternate: isAlternate)
        }
    }

    // MARK: - Skeleton Path

    private func skeletonPath(pose: Pose) -> Path {
        var path = Path()

        // Spine
        path.move(to: pose.neck)
        path.addLine(to: midpoint(pose.leftHip, pose.rightHip))

        // Shoulders
        path.move(to: pose.leftShoulder)
        path.addLine(to: pose.rightShoulder)

        // Hips
        path.move(to: pose.leftHip)
        path.addLine(to: pose.rightHip)

        // Left arm
        path.move(to: pose.leftShoulder)
        path.addLine(to: pose.leftElbow)
        path.addLine(to: pose.leftWrist)

        // Right arm
        path.move(to: pose.rightShoulder)
        path.addLine(to: pose.rightElbow)
        path.addLine(to: pose.rightWrist)

        // Left leg
        path.move(to: pose.leftHip)
        path.addLine(to: pose.leftKnee)
        path.addLine(to: pose.leftAnkle)

        // Right leg
        path.move(to: pose.rightHip)
        path.addLine(to: pose.rightKnee)
        path.addLine(to: pose.rightAnkle)

        return path
    }

    private func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    // MARK: - Pose Definitions (normalized to canvas)

    private func jumpingJackPose(in size: CGSize, alternate: Bool) -> Pose {
        let cx = size.width / 2
        let cy = size.height / 2 - 10
        if alternate {
            // Arms up, legs spread
            return Pose(
                head: CGPoint(x: cx, y: cy - 100),
                neck: CGPoint(x: cx, y: cy - 70),
                leftShoulder: CGPoint(x: cx - 30, y: cy - 60),
                rightShoulder: CGPoint(x: cx + 30, y: cy - 60),
                leftElbow: CGPoint(x: cx - 60, y: cy - 100),
                rightElbow: CGPoint(x: cx + 60, y: cy - 100),
                leftWrist: CGPoint(x: cx - 70, y: cy - 140),
                rightWrist: CGPoint(x: cx + 70, y: cy - 140),
                leftHip: CGPoint(x: cx - 20, y: cy + 20),
                rightHip: CGPoint(x: cx + 20, y: cy + 20),
                leftKnee: CGPoint(x: cx - 50, y: cy + 70),
                rightKnee: CGPoint(x: cx + 50, y: cy + 70),
                leftAnkle: CGPoint(x: cx - 70, y: cy + 120),
                rightAnkle: CGPoint(x: cx + 70, y: cy + 120)
            )
        } else {
            // Arms down, feet together
            return Pose(
                head: CGPoint(x: cx, y: cy - 100),
                neck: CGPoint(x: cx, y: cy - 70),
                leftShoulder: CGPoint(x: cx - 25, y: cy - 60),
                rightShoulder: CGPoint(x: cx + 25, y: cy - 60),
                leftElbow: CGPoint(x: cx - 30, y: cy - 20),
                rightElbow: CGPoint(x: cx + 30, y: cy - 20),
                leftWrist: CGPoint(x: cx - 30, y: cy + 20),
                rightWrist: CGPoint(x: cx + 30, y: cy + 20),
                leftHip: CGPoint(x: cx - 18, y: cy + 20),
                rightHip: CGPoint(x: cx + 18, y: cy + 20),
                leftKnee: CGPoint(x: cx - 18, y: cy + 70),
                rightKnee: CGPoint(x: cx + 18, y: cy + 70),
                leftAnkle: CGPoint(x: cx - 18, y: cy + 120),
                rightAnkle: CGPoint(x: cx + 18, y: cy + 120)
            )
        }
    }

    private func squatPose(in size: CGSize, alternate: Bool) -> Pose {
        let cx = size.width / 2
        let cy = size.height / 2 - 10
        let dropY: CGFloat = alternate ? 30 : 0  // hips drop in squat
        return Pose(
            head: CGPoint(x: cx, y: cy - 100 + dropY),
            neck: CGPoint(x: cx, y: cy - 70 + dropY),
            leftShoulder: CGPoint(x: cx - 25, y: cy - 60 + dropY),
            rightShoulder: CGPoint(x: cx + 25, y: cy - 60 + dropY),
            leftElbow: CGPoint(x: cx - 35, y: cy - 25 + dropY),
            rightElbow: CGPoint(x: cx + 35, y: cy - 25 + dropY),
            leftWrist: CGPoint(x: cx - 40, y: cy + 5 + dropY),
            rightWrist: CGPoint(x: cx + 40, y: cy + 5 + dropY),
            leftHip: CGPoint(x: cx - 18, y: cy + 20 + dropY),
            rightHip: CGPoint(x: cx + 18, y: cy + 20 + dropY),
            leftKnee: CGPoint(x: cx - 30, y: alternate ? cy + 50 + dropY : cy + 70),
            rightKnee: CGPoint(x: cx + 30, y: alternate ? cy + 50 + dropY : cy + 70),
            leftAnkle: CGPoint(x: cx - 25, y: cy + 120),
            rightAnkle: CGPoint(x: cx + 25, y: cy + 120)
        )
    }

    private func highKneesPose(in size: CGSize, alternate: Bool) -> Pose {
        let cx = size.width / 2
        let cy = size.height / 2 - 10
        return Pose(
            head: CGPoint(x: cx, y: cy - 100),
            neck: CGPoint(x: cx, y: cy - 70),
            leftShoulder: CGPoint(x: cx - 25, y: cy - 60),
            rightShoulder: CGPoint(x: cx + 25, y: cy - 60),
            leftElbow: CGPoint(x: cx - 40, y: alternate ? cy - 90 : cy - 30),
            rightElbow: CGPoint(x: cx + 40, y: alternate ? cy - 30 : cy - 90),
            leftWrist: CGPoint(x: cx - 30, y: alternate ? cy - 120 : cy + 5),
            rightWrist: CGPoint(x: cx + 30, y: alternate ? cy + 5 : cy - 120),
            leftHip: CGPoint(x: cx - 18, y: cy + 20),
            rightHip: CGPoint(x: cx + 18, y: cy + 20),
            // alternate: left knee up, right knee down (and vice versa)
            leftKnee: CGPoint(x: cx - 30, y: alternate ? cy + 5 : cy + 70),
            rightKnee: CGPoint(x: cx + 30, y: alternate ? cy + 70 : cy + 5),
            leftAnkle: CGPoint(x: cx - 30, y: alternate ? cy + 35 : cy + 120),
            rightAnkle: CGPoint(x: cx + 30, y: alternate ? cy + 120 : cy + 35)
        )
    }

    private func armRaisePose(in size: CGSize, alternate: Bool) -> Pose {
        let cx = size.width / 2
        let cy = size.height / 2 - 10
        return Pose(
            head: CGPoint(x: cx, y: cy - 100),
            neck: CGPoint(x: cx, y: cy - 70),
            leftShoulder: CGPoint(x: cx - 25, y: cy - 60),
            rightShoulder: CGPoint(x: cx + 25, y: cy - 60),
            leftElbow: CGPoint(x: cx - 30, y: alternate ? cy - 100 : cy - 20),
            rightElbow: CGPoint(x: cx + 30, y: alternate ? cy - 100 : cy - 20),
            leftWrist: CGPoint(x: cx - 30, y: alternate ? cy - 140 : cy + 20),
            rightWrist: CGPoint(x: cx + 30, y: alternate ? cy - 140 : cy + 20),
            leftHip: CGPoint(x: cx - 18, y: cy + 20),
            rightHip: CGPoint(x: cx + 18, y: cy + 20),
            leftKnee: CGPoint(x: cx - 18, y: cy + 70),
            rightKnee: CGPoint(x: cx + 18, y: cy + 70),
            leftAnkle: CGPoint(x: cx - 18, y: cy + 120),
            rightAnkle: CGPoint(x: cx + 18, y: cy + 120)
        )
    }

    private func toeTouchPose(in size: CGSize, alternate: Bool) -> Pose {
        let cx = size.width / 2
        let cy = size.height / 2 - 10
        if alternate {
            // Bent forward — head and arms reach down
            return Pose(
                head: CGPoint(x: cx, y: cy - 10),
                neck: CGPoint(x: cx, y: cy + 15),
                leftShoulder: CGPoint(x: cx - 25, y: cy + 25),
                rightShoulder: CGPoint(x: cx + 25, y: cy + 25),
                leftElbow: CGPoint(x: cx - 25, y: cy + 65),
                rightElbow: CGPoint(x: cx + 25, y: cy + 65),
                leftWrist: CGPoint(x: cx - 20, y: cy + 105),
                rightWrist: CGPoint(x: cx + 20, y: cy + 105),
                leftHip: CGPoint(x: cx - 18, y: cy + 20),
                rightHip: CGPoint(x: cx + 18, y: cy + 20),
                leftKnee: CGPoint(x: cx - 18, y: cy + 70),
                rightKnee: CGPoint(x: cx + 18, y: cy + 70),
                leftAnkle: CGPoint(x: cx - 18, y: cy + 120),
                rightAnkle: CGPoint(x: cx + 18, y: cy + 120)
            )
        } else {
            // Standing tall
            return Pose(
                head: CGPoint(x: cx, y: cy - 100),
                neck: CGPoint(x: cx, y: cy - 70),
                leftShoulder: CGPoint(x: cx - 25, y: cy - 60),
                rightShoulder: CGPoint(x: cx + 25, y: cy - 60),
                leftElbow: CGPoint(x: cx - 30, y: cy - 20),
                rightElbow: CGPoint(x: cx + 30, y: cy - 20),
                leftWrist: CGPoint(x: cx - 30, y: cy + 20),
                rightWrist: CGPoint(x: cx + 30, y: cy + 20),
                leftHip: CGPoint(x: cx - 18, y: cy + 20),
                rightHip: CGPoint(x: cx + 18, y: cy + 20),
                leftKnee: CGPoint(x: cx - 18, y: cy + 70),
                rightKnee: CGPoint(x: cx + 18, y: cy + 70),
                leftAnkle: CGPoint(x: cx - 18, y: cy + 120),
                rightAnkle: CGPoint(x: cx + 18, y: cy + 120)
            )
        }
    }
}

#if DEBUG
struct ExerciseDemoView_Previews: PreviewProvider {
    static var previews: some View {
        ExerciseDemoView(exercise: .jumpingJacks, onStart: {}, onCancel: {})
    }
}
#endif
