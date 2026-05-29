import Foundation
import Vision
import SwiftUI
import CoreGraphics

// MARK: - ExerciseType

enum ExerciseType: String, CaseIterable, Identifiable {
    case jumpingJacks = "jumpingJacks"
    case squats       = "squats"
    case highKnees    = "highKnees"
    case armRaises    = "armRaises"
    case toeTouches   = "toeTouches"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .jumpingJacks: return "Jumping Jacks"
        case .squats:       return "Squats"
        case .highKnees:    return "High Knees"
        case .armRaises:    return "Arm Raises"
        case .toeTouches:   return "Toe Touches"
        }
    }

    var icon: String {
        switch self {
        case .jumpingJacks: return "figure.mixed.cardio"
        case .squats:       return "figure.strengthtraining.functional"
        case .highKnees:    return "figure.run"
        case .armRaises:    return "figure.arms.open"
        case .toeTouches:   return "figure.flexibility"
        }
    }
}

// MARK: - Exercise Config (angle-based, à la Good-GYM)

private struct ExerciseConfig {
    let upAngle: Double
    let downAngle: Double
    let isLegExercise: Bool

    static let configs: [ExerciseType: ExerciseConfig] = [
        // Jumping Jack — hip→shoulder→wrist
        // Arms at side ≈ 20°, arms overhead ≈ 160°
        .jumpingJacks: ExerciseConfig(upAngle: 130, downAngle: 60, isLegExercise: false),

        // Squat — hip→knee→ankle
        // Standing ≈ 170°, full squat ≈ 80°
        .squats: ExerciseConfig(upAngle: 155, downAngle: 100, isLegExercise: false),

        // High Knees — shoulder→hip→knee (per leg)
        // Leg straight down ≈ 170°, knee raised ≈ 80°
        .highKnees: ExerciseConfig(upAngle: 155, downAngle: 100, isLegExercise: true),

        // Arm Raises — hip→shoulder→wrist
        // Arms at side ≈ 20°, arms overhead ≈ 160°
        .armRaises: ExerciseConfig(upAngle: 130, downAngle: 60, isLegExercise: false),

        // Toe Touches — shoulder→hip→ankle
        // Standing ≈ 170°, bent forward ≈ 80°
        .toeTouches: ExerciseConfig(upAngle: 155, downAngle: 100, isLegExercise: false)
    ]
}

// MARK: - ExerciseDetector

struct ExerciseDetector {

    private let confidenceThreshold: Float = 0.2
    private let smoothingWindow: Int = 3
    private let minRepTime: TimeInterval = 0.4

    enum Stage { case up, down, none }

    // MARK: - Detection State

    struct State {
        var repCount: Int = 0
        var phase: String = "Ready"
        var feedback: String = "Stand in frame to begin"

        var stage: Stage = .none
        var leftStage: Stage = .none
        var rightStage: Stage = .none
        var lastCountTime: TimeInterval = 0
        var angleHistory: [Double] = []
        var lastFeedbackChangeTime: TimeInterval = 0

        static var initial: State { State() }
    }


    // MARK: - Main entry

    func process(
        observation: VNHumanBodyPoseObservation,
        exercise: ExerciseType,
        state: inout State
    ) {
        guard let points = try? observation.recognizedPoints(.all),
              let config = ExerciseConfig.configs[exercise] else { return }

        // Get joint triplets per exercise — (left triplet, right triplet)
        let triplets = jointTriplets(for: exercise)

        guard
            let leftAngle = computeAngle(points, joints: triplets.left),
            let rightAngle = computeAngle(points, joints: triplets.right)
        else {
            state.feedback = "Move back — show your full body"
            return
        }

        // Capture feedback BEFORE counting so evaluateForm can restore it
        // if the cooldown blocks a RepFeedback / CoachingMessage change.
        let feedbackSnapshot = state.feedback

        if config.isLegExercise {
            countLegExercise(left: leftAngle, right: rightAngle, config: config, state: &state, exercise: exercise)
        } else {
            let avgAngle = (leftAngle + rightAngle) / 2
            let smoothed = smoothAngle(avgAngle, history: &state.angleHistory)
            countSingleSided(angle: smoothed, config: config, state: &state, exercise: exercise)
        }

        // Form evaluation runs AFTER counting — reads stage/angles, writes feedback only.
        evaluateForm(points: points, exercise: exercise,
                     config: config, state: &state,
                     feedbackSnapshot: feedbackSnapshot)
    }

    // MARK: - Counting (single-sided, e.g. squat, push-up)

    private func countSingleSided(
        angle: Double,
        config: ExerciseConfig,
        state: inout State,
        exercise: ExerciseType
    ) {
        // Update phase indicator for UI
        if angle > config.upAngle {
            state.stage = .up
            state.phase = "Up"
        } else if angle < config.downAngle && state.stage == .up && checkTiming(state: &state) {
            state.stage = .down
            state.phase = "Down"
            state.repCount += 1
            state.lastCountTime = Date().timeIntervalSince1970
            state.feedback = repFeedback(state.repCount, exercise: exercise)
        } else if angle < config.downAngle {
            state.phase = "Down"
        }

        // Initial coaching message
        if state.repCount == 0 {
            switch exercise {
            case .jumpingJacks: state.feedback = "Raise both arms above your head"
            case .squats:       state.feedback = "Lower your hips to begin"
            case .armRaises:    state.feedback = "Raise both arms straight up"
            case .toeTouches:   state.feedback = "Bend down and touch your toes"
            default: break
            }
        }
    }

    // MARK: - Counting (per-leg, e.g. high knees)

    private func countLegExercise(
        left: Double,
        right: Double,
        config: ExerciseConfig,
        state: inout State,
        exercise: ExerciseType
    ) {
        guard checkTiming(state: &state) else { return }

        // Left leg up→down cycle = 1 rep
        if left > config.upAngle {
            state.leftStage = .up
        } else if left < config.downAngle && state.leftStage == .up {
            state.leftStage = .down
            state.repCount += 1
            state.phase = "Left"
            state.lastCountTime = Date().timeIntervalSince1970
            state.feedback = repFeedback(state.repCount, exercise: exercise)
        }

        // Right leg
        if right > config.upAngle {
            state.rightStage = .up
        } else if right < config.downAngle && state.rightStage == .up {
            state.rightStage = .down
            state.repCount += 1
            state.phase = "Right"
            state.lastCountTime = Date().timeIntervalSince1970
            state.feedback = repFeedback(state.repCount, exercise: exercise)
        }

        if state.repCount == 0 {
            state.feedback = "Lift your knees alternately"
        }
    }

    // MARK: - Joint triplets per exercise

    private struct Triplets {
        let left: (VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)
        let right: (VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)
    }

    private func jointTriplets(for exercise: ExerciseType) -> Triplets {
        switch exercise {
        case .jumpingJacks, .armRaises:
            // Shoulder angle: hip → shoulder → wrist
            return Triplets(
                left:  (.leftHip, .leftShoulder, .leftWrist),
                right: (.rightHip, .rightShoulder, .rightWrist)
            )
        case .squats:
            // Knee angle: hip → knee → ankle
            return Triplets(
                left:  (.leftHip, .leftKnee, .leftAnkle),
                right: (.rightHip, .rightKnee, .rightAnkle)
            )
        case .highKnees:
            // Hip angle: shoulder → hip → knee (small when knee raised)
            return Triplets(
                left:  (.leftShoulder, .leftHip, .leftKnee),
                right: (.rightShoulder, .rightHip, .rightKnee)
            )
        case .toeTouches:
            // Torso bend angle: shoulder → hip → ankle
            return Triplets(
                left:  (.leftShoulder, .leftHip, .leftAnkle),
                right: (.rightShoulder, .rightHip, .rightAnkle)
            )
        }
    }

    // MARK: - Geometry: compute angle in degrees between three points

    private func computeAngle(
        _ points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint],
        joints: (VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)
    ) -> Double? {
        guard
            let a = pt(points, joints.0),
            let b = pt(points, joints.1),
            let c = pt(points, joints.2)
        else { return nil }

        let ba = CGPoint(x: a.x - b.x, y: a.y - b.y)
        let bc = CGPoint(x: c.x - b.x, y: c.y - b.y)

        let dot = Double(ba.x * bc.x + ba.y * bc.y)
        let magBA = sqrt(Double(ba.x * ba.x + ba.y * ba.y))
        let magBC = sqrt(Double(bc.x * bc.x + bc.y * bc.y))

        guard magBA > 0, magBC > 0 else { return nil }

        let cosine = max(-1.0, min(1.0, dot / (magBA * magBC)))
        return acos(cosine) * 180.0 / .pi
    }

    // MARK: - Smoothing (median + outlier rejection, à la Good-GYM)

    private func smoothAngle(_ angle: Double, history: inout [Double]) -> Double {
        history.append(angle)
        if history.count > smoothingWindow {
            history.removeFirst()
        }
        guard history.count >= 3 else { return angle }

        let sorted = history.sorted()
        let median = sorted[sorted.count / 2]
        let mean = history.reduce(0, +) / Double(history.count)
        let variance = history.reduce(0) { $0 + pow($1 - mean, 2) } / Double(history.count)
        let std = sqrt(variance)

        // Drop outliers > 2 std from median
        let filtered = history.filter { abs($0 - median) <= 2 * std }
        return filtered.isEmpty ? angle : filtered.reduce(0, +) / Double(filtered.count)
    }

    // MARK: - Timing guard (prevent double-count)

    private func checkTiming(state: inout State) -> Bool {
        let now = Date().timeIntervalSince1970
        return now - state.lastCountTime >= minRepTime
    }

    // MARK: - Feedback strings

    private func repFeedback(_ count: Int, exercise: ExerciseType) -> String {
        let unit: String
        switch exercise {
        case .jumpingJacks: unit = count == 1 ? "rep" : "reps"
        case .squats:       unit = count == 1 ? "squat" : "squats"
        case .highKnees:    unit = count == 1 ? "knee" : "knees"
        case .armRaises:    unit = count == 1 ? "raise" : "raises"
        case .toeTouches:   unit = count == 1 ? "touch" : "touches"
        }
        return "\(count) \(unit) — keep going!"
    }

    // MARK: - Form Feedback

    /// Pure function — no state mutation, no side effects.
    /// Returns a corrective message when the user's form deviates from the expected
    /// threshold for the current exercise phase, or `nil` if form is correct (or
    /// the stage is `.none`).
    ///
    /// - Parameters:
    ///   - exercise: The active exercise type.
    ///   - stage: The current bilateral stage (used by all exercises except High Knees).
    ///   - leftStage: Per-leg stage for the left side (High Knees only).
    ///   - rightStage: Per-leg stage for the right side (High Knees only).
    ///   - leftAngle: Primary joint angle for the left side (nil if joint confidence is too low).
    ///   - rightAngle: Primary joint angle for the right side (nil if joint confidence is too low).
    ///   - leftLegAngle: Hip→knee→ankle angle for the left leg (Jumping Jacks leg-spread check only; pass `nil` for all other exercises).
    ///   - rightLegAngle: Hip→knee→ankle angle for the right leg (Jumping Jacks leg-spread check only; pass `nil` for all other exercises).
    ///   - config: The angle thresholds for the active exercise.
    /// - Returns: A corrective feedback string, or `nil` if no correction is needed.
    private func formFeedbackMessage(
        exercise: ExerciseType,
        stage: Stage,
        leftStage: Stage,
        rightStage: Stage,
        leftAngle: Double?,
        rightAngle: Double?,
        leftLegAngle: Double?,
        rightLegAngle: Double?,
        config: ExerciseConfig
    ) -> String? {
        // Guard: no message when stage is unknown
        if exercise == .highKnees {
            if leftStage == .none && rightStage == .none { return nil }
        } else {
            if stage == .none { return nil }
        }

        switch exercise {
        case .jumpingJacks:
            guard stage == .up else { return nil }
            guard let L = leftAngle, let R = rightAngle else { return nil }
            let armAvg = (L + R) / 2
            // Arm error takes priority over leg spread error
            if armAvg < config.upAngle {
                return "Raise arms higher"
            }
            // Leg spread check
            if let legL = leftLegAngle, let legR = rightLegAngle {
                let legAvg = (legL + legR) / 2
                if legAvg > 100 {
                    return "Spread legs wider"
                }
            }
            return nil
        case .squats:
            guard let L = leftAngle, let R = rightAngle else { return nil }
            let avg = (L + R) / 2
            if stage == .down && avg > config.downAngle {
                return "Go deeper — bend knees more"
            }
            if stage == .up && avg < config.upAngle {
                return "Stand fully upright"
            }
            return nil
        case .highKnees:
            if leftStage == .down {
                if let L = leftAngle, L > config.downAngle {
                    return "Lift knee higher"
                }
            }
            if rightStage == .down {
                if let R = rightAngle, R > config.downAngle {
                    return "Lift knee higher"
                }
            }
            return nil
        case .armRaises:
            guard stage == .up else { return nil }
            guard let L = leftAngle, let R = rightAngle else { return nil }
            let avg = (L + R) / 2
            if avg < config.upAngle {   // < 130°
                return "Raise arms fully overhead"
            }
            return nil

        case .toeTouches:
            guard stage == .down else { return nil }
            guard let L = leftAngle, let R = rightAngle else { return nil }
            let avg = (L + R) / 2
            if avg > config.downAngle { // > 100°
                return "Bend further — reach for your toes"
            }
            return nil
        }
    }

    /// Evaluates form for the current frame and updates `state.feedback` accordingly.
    ///
    /// This is a scaffold — angle computation is performed here; priority + cooldown
    /// logic will be filled in by task 4.2.
    ///
    /// - Parameters:
    ///   - points: The full joint map from the current `VNHumanBodyPoseObservation`.
    ///   - exercise: The active exercise type.
    ///   - config: The angle thresholds for the active exercise.
    ///   - state: The mutable detector state. Only `state.feedback` and
    ///     `state.lastFeedbackChangeTime` may be written; rep-counting fields are
    ///     read-only here.
    ///   - feedbackSnapshot: The value of `state.feedback` captured *before* counting
    ///     ran in `process()`, used to restore the banner when the cooldown blocks a change.
    private func evaluateForm(
        points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint],
        exercise: ExerciseType,
        config: ExerciseConfig,
        state: inout State,
        feedbackSnapshot: String
    ) {
        // 1. Timestamp for cooldown logic (task 4.2).
        let now = Date().timeIntervalSince1970

        // 2. Primary left/right angles — re-use the same triplets as counting.
        let triplets = jointTriplets(for: exercise)
        let leftAngle  = computeAngle(points, joints: triplets.left)
        let rightAngle = computeAngle(points, joints: triplets.right)

        // 3. Leg angles — only computed for Jumping Jacks.
        let leftLegAngle: Double?
        let rightLegAngle: Double?
        if exercise == .jumpingJacks {
            leftLegAngle  = computeAngle(points, joints: (.leftHip,  .leftKnee,  .leftAnkle))
            rightLegAngle = computeAngle(points, joints: (.rightHip, .rightKnee, .rightAnkle))
        } else {
            leftLegAngle  = nil
            rightLegAngle = nil
        }

        // 4. Ask the pure function for a candidate form correction message.
        let candidate: String? = formFeedbackMessage(
            exercise:      exercise,
            stage:         state.stage,       // read-only
            leftStage:     state.leftStage,   // read-only (High Knees)
            rightStage:    state.rightStage,  // read-only (High Knees)
            leftAngle:     leftAngle,
            rightAngle:    rightAngle,
            leftLegAngle:  leftLegAngle,
            rightLegAngle: rightLegAngle,
            config:        config
        )

        // 5. Priority + cooldown logic.
        let cooldown: TimeInterval = 1.5

        if let formMsg = candidate {
            // FormFeedback — ALWAYS bypasses cooldown, updates immediately
            state.feedback = formMsg
            state.lastFeedbackChangeTime = now
        } else if now - state.lastFeedbackChangeTime < cooldown {
            // Cooldown active — restore pre-count snapshot to block RepFeedback/CoachingMessage change
            state.feedback = feedbackSnapshot
        } else {
            // Cooldown elapsed — allow the RepFeedback/CoachingMessage written by counting logic
            state.lastFeedbackChangeTime = now
        }
    }

    // MARK: - Helpers

    private func pt(
        _ points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint],
        _ joint: VNHumanBodyPoseObservation.JointName
    ) -> CGPoint? {
        guard let p = points[joint], p.confidence >= confidenceThreshold else { return nil }
        return p.location
    }
}
