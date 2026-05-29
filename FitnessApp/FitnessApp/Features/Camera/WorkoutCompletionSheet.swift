import SwiftUI

/// Summary sheet shown when user finishes a camera workout session.
/// Displays total reps, calories burned, duration, and per-exercise breakdown.
struct WorkoutCompletionSheet: View {

    let summary: WorkoutSummary
    let onDone: () -> Void

    var body: some View {
        ZStack {
            Color.themeBackground.ignoresSafeArea()

            // Glow background
            Circle()
                .fill(Color.themePrimary.opacity(0.2))
                .frame(width: 400, height: 400)
                .blur(radius: 100)
                .offset(y: -200)

            VStack(spacing: 0) {
                Spacer()

                // Trophy / completion icon
                ZStack {
                    Circle()
                        .fill(Color.themePrimary.opacity(0.15))
                        .frame(width: 100, height: 100)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(Color.brandGradient)
                }
                .padding(.bottom, 16)

                Text("WORKOUT COMPLETE")
                    .font(.caption)
                    .fontWeight(.heavy)
                    .foregroundColor(.themePrimary)
                    .tracking(2)

                Text("Nice work!")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary)
                    .padding(.bottom, 24)

                // Stats row
                HStack(spacing: 12) {
                    statCard(
                        value: "\(summary.totalReps)",
                        label: "Total Reps",
                        icon: "flame.fill",
                        color: .themePrimary
                    )
                    statCard(
                        value: "\(Int(summary.totalCalories))",
                        label: "kcal",
                        icon: "bolt.fill",
                        color: .themeSecondary
                    )
                    statCard(
                        value: formatDuration(summary.durationMinutes),
                        label: "Duration",
                        icon: "clock.fill",
                        color: .themeAccent
                    )
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

                // Breakdown
                if summary.breakdown.count > 1 {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("BREAKDOWN")
                            .font(.caption2)
                            .fontWeight(.heavy)
                            .foregroundColor(.secondary)
                            .tracking(1.5)

                        ForEach(sortedBreakdown, id: \.0) { exercise, reps in
                            HStack {
                                Image(systemName: exercise.icon)
                                    .foregroundColor(.themePrimary)
                                    .font(.subheadline)
                                Text(exercise.displayName)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Spacer()
                                Text("\(reps) reps")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundColor(.themePrimary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.themeSurface)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }

                Spacer()

                // Done button
                Button(action: onDone) {
                    Text("Done")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.brandGradient)
                        .cornerRadius(28)
                        .shadow(color: Color.themePrimary.opacity(0.4), radius: 12, x: 0, y: 4)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
                .accessibilityLabel("Done, save workout")
                .accessibilityIdentifier("workout-summary-done-btn")
            }
        }
        .preferredColorScheme(.dark)
    }

    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundColor(.primary)
            Text(label.uppercased())
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.themeSurface)
        .cornerRadius(14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label)")
    }

    private var sortedBreakdown: [(ExerciseType, Int)] {
        summary.breakdown.sorted { $0.value > $1.value }
    }

    private func formatDuration(_ minutes: Double) -> String {
        let totalSec = Int(minutes * 60)
        let mins = totalSec / 60
        let secs = totalSec % 60
        if mins > 0 {
            return "\(mins)m \(secs)s"
        }
        return "\(secs)s"
    }
}

#if DEBUG
struct WorkoutCompletionSheet_Previews: PreviewProvider {
    static var previews: some View {
        WorkoutCompletionSheet(
            summary: WorkoutSummary(
                totalReps: 25,
                totalCalories: 10,
                durationMinutes: 2.5,
                breakdown: [.jumpingJacks: 15, .squats: 10]
            ),
            onDone: {}
        )
    }
}
#endif
