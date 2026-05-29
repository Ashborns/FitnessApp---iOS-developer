import SwiftUI

/// Detail view for a single workout log — shows breakdown by exercise + 7-day chart.
struct WorkoutDetailView: View {

    let workout: WorkoutLog
    @StateObject private var goalsStore = WorkoutGoalsStore.shared

    var body: some View {
        ZStack {
            Color.themeBackground.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: .spacingLarge) {
                    headerCard
                    statsRow
                    if !breakdown.isEmpty {
                        breakdownSection
                    }
                    weeklyChart
                }
                .padding(.horizontal, .spacingLarge)
                .padding(.bottom, .spacingExtraLarge)
            }
        }
        .navigationTitle("Workout Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.themePrimary.opacity(0.15))
                    .frame(width: 72, height: 72)
                Image(systemName: iconForWorkoutType(workout.workoutType ?? ""))
                    .font(.title)
                    .foregroundStyle(Color.brandGradient)
            }
            VStack(spacing: 4) {
                Text(workout.workoutType ?? "Workout")
                    .font(.title3)
                    .fontWeight(.heavy)
                    .foregroundColor(.primary)
                Text(formattedDateLong(workout.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.spacingExtraLarge)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.themeSurface)
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.themeBorder, lineWidth: 1)
            }
        )
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: .spacingMedium) {
            statCard(value: "\(Int(workout.durationMinutes))", unit: "min", label: "Duration", icon: "clock.fill", color: .themeSecondary)
            statCard(value: "\(Int(workout.caloriesBurned))", unit: "kcal", label: "Burned", icon: "flame.fill", color: .themeAccent)
            statCard(value: "\(totalReps)", unit: "reps", label: "Total", icon: "figure.run", color: .themePrimary)
        }
    }

    private func statCard(value: String, unit: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary)
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Text(label.uppercased())
                .font(.system(size: 9))
                .fontWeight(.bold)
                .foregroundColor(.secondary)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.themeSurface)
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.themeBorder, lineWidth: 1)
            }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(unit) \(label)")
    }

    // MARK: - Breakdown (parsed from notes)

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("BREAKDOWN")
                .font(.caption2)
                .fontWeight(.heavy)
                .foregroundColor(.secondary)
                .tracking(1.5)

            VStack(spacing: 8) {
                ForEach(breakdown, id: \.0) { name, reps in
                    HStack(spacing: 12) {
                        Image(systemName: iconForWorkoutType(name))
                            .foregroundColor(.themePrimary)
                            .font(.subheadline)
                            .frame(width: 24)
                        Text(name)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(reps)")
                            .font(.subheadline)
                            .fontWeight(.heavy)
                            .foregroundStyle(Color.brandGradient)
                        Text("reps")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(14)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.themeSurface)
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.themeBorder, lineWidth: 1)
                        }
                    )
                }
            }
        }
    }

    /// Parse notes string e.g. "Squats: 5 reps, Jumping Jacks: 2 reps" → [(name, reps)]
    private var breakdown: [(String, Int)] {
        guard let notes = workout.notes, !notes.isEmpty else { return [] }
        return notes
            .split(separator: ",")
            .compactMap { part -> (String, Int)? in
                let trimmed = part.trimmingCharacters(in: .whitespaces)
                let components = trimmed.split(separator: ":")
                guard components.count == 2 else { return nil }
                let name = components[0].trimmingCharacters(in: .whitespaces)
                let repsString = components[1]
                    .trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: " reps", with: "")
                    .replacingOccurrences(of: " rep", with: "")
                guard let reps = Int(repsString) else { return nil }
                return (name, reps)
            }
    }

    private var totalReps: Int {
        breakdown.reduce(0) { $0 + $1.1 }
    }

    // MARK: - Weekly Chart (last 7 days)

    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("LAST 7 DAYS")
                .font(.caption2)
                .fontWeight(.heavy)
                .foregroundColor(.secondary)
                .tracking(1.5)

            let data = goalsStore.last7Days()
            let maxReps = max(data.map(\.1).max() ?? 1, 1)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(data.enumerated()), id: \.offset) { _, item in
                    let (date, reps) = item
                    VStack(spacing: 8) {
                        Text("\(reps)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(reps > 0 ? .themePrimary : .secondary.opacity(0.5))

                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.themeBackground)
                                .frame(height: 100)
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.brandGradient)
                                .frame(height: max(CGFloat(reps) / CGFloat(maxReps) * 100, reps > 0 ? 6 : 0))
                                .shadow(color: Color.themePrimary.opacity(0.4), radius: 4)
                        }

                        Text(dayLabel(date))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.spacingLarge)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.themeSurface)
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.themeBorder, lineWidth: 1)
            }
        )
    }

    // MARK: - Helpers

    private func formattedDateLong(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return String(formatter.string(from: date).prefix(1))
    }

    private func iconForWorkoutType(_ type: String) -> String {
        switch type.lowercased() {
        case "running": return "figure.run"
        case "walking": return "figure.walk"
        case "cycling": return "bicycle"
        case "yoga": return "figure.mind.and.body"
        case "strength": return "dumbbell"
        case "hiit", "mixed workout": return "flame"
        case "swimming": return "figure.pool.swim"
        case "stretching": return "figure.flexibility"
        case "jumping jacks": return "figure.mixed.cardio"
        case "squats": return "figure.strengthtraining.functional"
        case "high knees": return "figure.run"
        case "arm raises": return "figure.arms.open"
        case "toe touches": return "figure.flexibility"
        default: return "figure.mixed.cardio"
        }
    }
}
