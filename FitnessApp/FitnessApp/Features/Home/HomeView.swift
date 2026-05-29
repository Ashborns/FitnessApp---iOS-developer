import SwiftUI
import CoreData

// MARK: - HomeView (PULSE — Editorial Layout)

struct HomeView: View {

    @StateObject private var viewModel = HomeViewModel()
    @StateObject private var goalsStore = WorkoutGoalsStore.shared
    @StateObject private var profileStore = UserProfileStore.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var detailWorkoutID: NSManagedObjectID?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.themeBackground.ignoresSafeArea()

                if viewModel.isLoading {
                    loadingState
                } else {
                    mainScroll
                }
            }
            .navigationDestination(isPresented: detailIsPresented) {
                if let id = detailWorkoutID,
                   let workout = try? viewModel.fetchWorkout(by: id) {
                    WorkoutDetailView(workout: workout)
                }
            }
            .task { await viewModel.loadData() }
            .alert("Error", isPresented: errorBinding) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .accessibilityIdentifier("home-root")
        }
    }

    // MARK: - Main Scroll

    private var mainScroll: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                topNav
                heroSection
                ringsBlock
                Divider().background(Color.themeBorder).padding(.vertical, 32)
                activityFeed
                Divider().background(Color.themeBorder).padding(.vertical, 32)
                progressLink
                Spacer().frame(height: 100)
            }
            .padding(.horizontal, 24)
        }
        .refreshable { await viewModel.loadData() }
    }

    // MARK: - Top Navigation Bar (no card, just text + icon)

    private var topNav: some View {
        HStack(alignment: .center, spacing: 12) {
            // Wordmark
            HStack(spacing: 8) {
                Image(systemName: BrandTokens.logoSymbol)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundStyle(Color.brandGradient)
                Text(BrandTokens.appName)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                    .tracking(2)
            }

            Spacer()

            Text(todayDateString().uppercased())
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(.secondary)
                .tracking(1.5)
        }
        .padding(.top, 12)
        .padding(.bottom, 28)
    }

    // MARK: - Hero Section (editorial display)

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Greeting
            Text(timeOfDayGreeting())
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)

            // Big name
            Text(profileStore.name.isEmpty ? "Athlete" : profileStore.name)
                .font(.system(size: 42, weight: .black, design: .rounded))
                .foregroundColor(.primary)
                .tracking(-1)
                .padding(.bottom, 24)

            // Inline streak / status pill — only one motivational element
            HStack(spacing: 8) {
                if goalsStore.currentStreak > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(Color.coachGradient)
                        Text("\(goalsStore.currentStreak)-day streak")
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundColor(.primary)
                    }
                } else {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.themePrimary)
                            .frame(width: 6, height: 6)
                        Text("Ready when you are")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                if goalsStore.bestStreak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.themeSecondary)
                        Text("Best \(goalsStore.bestStreak)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: - Rings Block (Apple Fitness inspired, 3 rings stacked + side text)

    private var ringsBlock: some View {
        HStack(alignment: .center, spacing: 24) {
            // Triple concentric rings
            ZStack {
                ringTrack(diameter: 130, lineWidth: 11)
                ringTrack(diameter: 100, lineWidth: 11)
                ringTrack(diameter: 70, lineWidth: 11)

                ringFill(
                    diameter: 130, lineWidth: 11,
                    progress: progressFraction,
                    gradient: LinearGradient(
                        colors: [Color.themePrimary, Color.themeAccent],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                ringFill(
                    diameter: 100, lineWidth: 11,
                    progress: burnFraction,
                    gradient: LinearGradient(
                        colors: [Color.themeAccent, Color.themeSecondary],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                ringFill(
                    diameter: 70, lineWidth: 11,
                    progress: goalsStore.todayProgressFraction,
                    gradient: LinearGradient(
                        colors: [Color.themeSecondary, Color.themePrimary],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            }
            .frame(width: 130, height: 130)
            .accessibilityHidden(true)

            // Side metrics, big & bold
            VStack(alignment: .leading, spacing: 14) {
                metricLine(
                    color: Color.themePrimary,
                    value: "\(Int(viewModel.consumed))",
                    unit: "/ \(Int(viewModel.calorieGoal)) kcal",
                    label: "Eaten"
                )
                metricLine(
                    color: Color.themeAccent,
                    value: "\(Int(viewModel.burned))",
                    unit: "kcal",
                    label: "Burned"
                )
                metricLine(
                    color: Color.themeSecondary,
                    value: "\(goalsStore.todayReps)",
                    unit: "/ \(goalsStore.dailyRepGoal) reps",
                    label: "Workout"
                )
            }
            Spacer(minLength: 0)
        }
        .padding(.bottom, 32)
    }

    private func ringTrack(diameter: CGFloat, lineWidth: CGFloat) -> some View {
        Circle()
            .stroke(Color.themeBorder, lineWidth: lineWidth)
            .frame(width: diameter, height: diameter)
    }

    private func ringFill<S: ShapeStyle>(
        diameter: CGFloat,
        lineWidth: CGFloat,
        progress: Double,
        gradient: S
    ) -> some View {
        Circle()
            .trim(from: 0, to: max(0.001, min(progress, 1.0)))
            .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .frame(width: diameter, height: diameter)
            .animation(reduceMotion ? .none : .easeInOut(duration: 0.7), value: progress)
    }

    private func metricLine(color: Color, value: String, unit: String, label: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                    Text(unit)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                Text(label)
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.secondary)
                    .tracking(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value) \(unit)")
    }

    private var progressFraction: Double {
        guard viewModel.calorieGoal > 0 else { return 0 }
        return min(viewModel.consumed / viewModel.calorieGoal, 1.0)
    }

    private var burnFraction: Double {
        // Visual goal: 500 kcal burned/day is a healthy target
        min(viewModel.burned / 500.0, 1.0)
    }

    // MARK: - Activity Feed (Strava-like list, no boxy card)

    private var activityFeed: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Activity")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(.primary)

                Spacer()

                if !viewModel.recentWorkouts.isEmpty {
                    Text("\(viewModel.recentWorkouts.count) recent")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, 16)

            if viewModel.recentWorkouts.isEmpty {
                emptyActivity
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.recentWorkouts.enumerated()), id: \.offset) { index, workout in
                        Button {
                            HapticManager.shared.selection()
                            detailWorkoutID = workout.objectID
                        } label: {
                            activityRow(workout, isFirst: index == 0, isLast: index == viewModel.recentWorkouts.count - 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func activityRow(_ workout: WorkoutLog, isFirst: Bool, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // Timeline dot column
            VStack(spacing: 0) {
                if !isFirst {
                    Rectangle()
                        .fill(Color.themeBorder)
                        .frame(width: 1, height: 8)
                } else {
                    Spacer().frame(height: 8)
                }
                ZStack {
                    Circle()
                        .fill(Color.themeBackground)
                        .frame(width: 14, height: 14)
                    Circle()
                        .stroke(Color.themePrimary, lineWidth: 2)
                        .frame(width: 14, height: 14)
                    Circle()
                        .fill(Color.themePrimary)
                        .frame(width: 6, height: 6)
                }
                if !isLast {
                    Rectangle()
                        .fill(Color.themeBorder)
                        .frame(width: 1)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 14)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: iconForWorkoutType(workout.workoutType ?? ""))
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.themePrimary)
                    Text(workout.workoutType ?? "Workout")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.secondary.opacity(0.5))
                }

                // Inline metrics
                HStack(spacing: 16) {
                    inlineStat(value: "\(Int(workout.durationMinutes))", unit: "min")
                    inlineStat(value: "\(Int(workout.caloriesBurned))", unit: "kcal")
                    inlineStat(value: parseRepsFromNotes(workout.notes), unit: "reps")
                }

                Text(relativeDate(workout.date))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
            .padding(.bottom, isLast ? 0 : 20)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(workout.workoutType ?? "Workout"), \(Int(workout.durationMinutes)) minutes")
    }

    private func inlineStat(value: String, unit: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundColor(.primary)
            Text(unit)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
    }

    private var emptyActivity: some View {
        HStack(spacing: 12) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 28))
                .foregroundColor(.themePrimary.opacity(0.5))
            VStack(alignment: .leading, spacing: 2) {
                Text("Nothing logged yet")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary)
                Text("Start your first workout from the camera tab")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
    }

    // MARK: - Progress Link (text-based, not card)

    private var progressLink: some View {
        NavigationLink(destination: FitnessProgressView()) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Progress & history")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                    Text("Charts, trends, weekly insights")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundColor(.themePrimary)
                    .padding(10)
                    .background(Circle().fill(Color.themePrimary.opacity(0.12)))
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("home-progress-link")
    }

    // MARK: - Loading state

    private var loadingState: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SkeletonLoader(cornerRadius: 8).frame(width: 80, height: 16)
                Spacer()
                SkeletonLoader(cornerRadius: 8).frame(width: 60, height: 14)
            }
            SkeletonLoader(cornerRadius: 8).frame(width: 200, height: 36)
                .padding(.top, 12)
            SkeletonLoader(cornerRadius: 8).frame(width: 140, height: 14)
            SkeletonLoader(cornerRadius: 65).frame(width: 130, height: 130)
                .padding(.top, 16)
            SkeletonLoader(cornerRadius: 8).frame(height: 60)
            SkeletonLoader(cornerRadius: 8).frame(height: 60)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
    }

    // MARK: - Helpers

    private var detailIsPresented: Binding<Bool> {
        Binding(
            get: { detailWorkoutID != nil },
            set: { if !$0 { detailWorkoutID = nil } }
        )
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: Date())
    }

    private func timeOfDayGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning,"
        case 12..<17: return "Good afternoon,"
        case 17..<21: return "Good evening,"
        default: return "Working late,"
        }
    }

    private func relativeDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func parseRepsFromNotes(_ notes: String?) -> String {
        guard let notes = notes, !notes.isEmpty else { return "0" }
        // notes format: "Squats: 5 reps, Jumping Jacks: 2 reps"
        let total = notes
            .split(separator: ",")
            .compactMap { part -> Int? in
                let trimmed = part.trimmingCharacters(in: .whitespaces)
                let comps = trimmed.split(separator: ":")
                guard comps.count == 2 else { return nil }
                let repsString = comps[1]
                    .trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: " reps", with: "")
                    .replacingOccurrences(of: " rep", with: "")
                return Int(repsString)
            }
            .reduce(0, +)
        return "\(total)"
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

#if DEBUG
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .preferredColorScheme(.dark)
    }
}
#endif
