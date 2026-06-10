import SwiftUI

/// Workout screen — editorial layout.
/// Shows weekly stats, recommendations, and recent activity timeline.
struct WorkoutView: View {

    @StateObject private var viewModel = WorkoutViewModel()
    @EnvironmentObject var router: AppRouter

    var body: some View {
        NavigationStack(path: $router.path) {
            ZStack(alignment: .top) {
                Color.themeBackground.ignoresSafeArea()
                content
            }
            .task { await viewModel.loadData() }
            .alert("Error", isPresented: errorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
            .accessibilityIdentifier("workout-root")
            .navigationDestination(for: AppRouter.AppRoute.self) { route in
                destination(for: route)
            }
        }
    }

    // MARK: - Route Destinations (design §3 Navigation & Router)

    /// Single switch over `AppRoute` returning the matching screen for every
    /// route pushed onto `router.path` (R3.2 / R3.3). Uses `@ViewBuilder` so no
    /// `AnyView` is needed. `.exerciseDetail` resolves the id through a
    /// lightweight loader since `ExerciseDetailView` requires a full item.
    @ViewBuilder
    private func destination(for route: AppRouter.AppRoute) -> some View {
        switch route {
        case .library:
            LibraryView()
        case .exerciseDetail(let exerciseID):
            ExerciseDetailLoaderView(exerciseID: exerciseID)
        case .builder(let routineID):
            WorkoutBuilderView(routineID: routineID)
        case .muscleMap:
            MuscleMapView()
        case .schedule:
            ScheduleView()
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            ProgressView()
                .tint(.themePrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    topNav
                    headerSection
                    weekStats
                    Divider().background(Color.themeBorder).padding(.vertical, 32)
                    exerciseHubSection
                    Divider().background(Color.themeBorder).padding(.vertical, 32)
                    recommendationsSection
                    Divider().background(Color.themeBorder).padding(.vertical, 32)
                    recentSection
                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, 24)
            }
            .refreshable { await viewModel.loadData() }
        }
    }

    // MARK: - Top Nav

    private var topNav: some View {
        HStack {
            Text("WORKOUTS")
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(.secondary)
                .tracking(2)
            Spacer()
        }
        .padding(.top, 12)
        .padding(.bottom, 12)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Train")
                .font(.system(size: 42, weight: .black, design: .rounded))
                .foregroundColor(.primary)
                .tracking(-1)

            Text("Pick a session, hit your reps")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.bottom, 28)
    }

    // MARK: - Week Stats (inline metrics, no boxy card)

    private var weekStats: some View {
        HStack(alignment: .top, spacing: 0) {
            statCol(value: "\(viewModel.recentWorkouts.count)", unit: "sessions", label: "This week")
            verticalDivider
            statCol(value: totalMinutes(), unit: "min", label: "Total time")
            verticalDivider
            statCol(value: totalCalories(), unit: "kcal", label: "Burned")
        }
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(Color.themeBorder)
            .frame(width: 1, height: 44)
            .padding(.horizontal, 8)
    }

    private func statCol(value: String, unit: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                Text(unit)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            Text(label.uppercased())
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(.secondary)
                .tracking(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value) \(unit)")
    }

    // MARK: - Exercise Hub (entry points to ExerciseDB features — R3.2)

    private var exerciseHubSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Exercise Hub")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Color.brandGradient)
            }

            LazyVGrid(columns: hubColumns, spacing: 12) {
                hubTile(
                    icon: "books.vertical.fill",
                    title: "Library",
                    subtitle: "Jelajahi latihan",
                    route: .library,
                    identifier: "workout-hub-library"
                )
                hubTile(
                    icon: "figure.arms.open",
                    title: "Muscle Map",
                    subtitle: "Pilih dari tubuh",
                    route: .muscleMap,
                    identifier: "workout-hub-musclemap"
                )
                hubTile(
                    icon: "hammer.fill",
                    title: "Builder",
                    subtitle: "Susun rutinitas",
                    route: .builder(routineID: nil),
                    identifier: "workout-hub-builder"
                )
                hubTile(
                    icon: "calendar",
                    title: "Schedule",
                    subtitle: "Atur jadwal",
                    route: .schedule,
                    identifier: "workout-hub-schedule"
                )
            }
        }
    }

    private var hubColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
    }

    private func hubTile(
        icon: String,
        title: String,
        subtitle: String,
        route: AppRouter.AppRoute,
        identifier: String
    ) -> some View {
        Button {
            HapticManager.shared.selection()
            router.navigate(to: route)
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.themePrimary.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color.brandGradient)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.themeBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(subtitle)")
        .accessibilityIdentifier(identifier)
    }

    // MARK: - Recommendations (chip row, no card grid)

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Suggested for you")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Color.brandGradient)
            }

            if viewModel.recommendations.isEmpty {
                emptyRecommendationsView
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(
                            Array(viewModel.recommendations.enumerated()),
                            id: \.offset
                        ) { _, recommendation in
                            recommendationCard(recommendation)
                        }
                    }
                }
                .padding(.horizontal, -24)
                .padding(.horizontal, 24)
            }
        }
    }

    private func recommendationCard(_ recommendation: WorkoutRecommendationEngine.Recommendation) -> some View {
        Button {
            HapticManager.shared.selection()
            router.selectedTab = .camera
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: iconForWorkoutType(recommendation.workoutType))
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(Color.brandGradient)
                    .padding(.bottom, 4)

                Text(recommendation.workoutType)
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11, weight: .bold))
                    Text("\(Int(recommendation.suggestedDurationMinutes)) min")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.secondary)

                Spacer()

                HStack(spacing: 4) {
                    Text("Start")
                        .font(.system(size: 12, weight: .heavy))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .heavy))
                }
                .foregroundColor(.themePrimary)
            }
            .frame(width: 160, height: 180, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.themeBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(recommendation.workoutType), \(Int(recommendation.suggestedDurationMinutes)) minutes")
        .accessibilityIdentifier("workout-recommendation-\(recommendation.workoutType.lowercased())")
    }

    // MARK: - Recent (Strava timeline)

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Recent")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                if !viewModel.recentWorkouts.isEmpty {
                    Text("\(viewModel.recentWorkouts.count) sessions")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }

            if viewModel.recentWorkouts.isEmpty {
                emptyRecentView
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.recentWorkouts.enumerated()), id: \.offset) { index, workout in
                        recentWorkoutRow(
                            workout,
                            isFirst: index == 0,
                            isLast: index == viewModel.recentWorkouts.count - 1
                        )
                    }
                }
            }
        }
    }

    private func recentWorkoutRow(_ workout: WorkoutLog, isFirst: Bool, isLast: Bool) -> some View {
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
                }

                HStack(spacing: 16) {
                    inlineStat(value: "\(Int(workout.durationMinutes))", unit: "min")
                    inlineStat(value: "\(Int(workout.caloriesBurned))", unit: "kcal")
                }

                Text(relativeDate(workout.date))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
            .padding(.bottom, isLast ? 0 : 20)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(workout.workoutType ?? "Unknown"), \(Int(workout.durationMinutes)) minutes, \(formattedDate(workout.date))")
        .accessibilityIdentifier("workout-recent-\(workout.id?.uuidString ?? "unknown")")
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

    // MARK: - Empty States

    private var emptyRecommendationsView: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(.themePrimary.opacity(0.5))
            VStack(alignment: .leading, spacing: 2) {
                Text("Personalized soon")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary)
                Text("Complete a few workouts to unlock recommendations")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .accessibilityIdentifier("workout-empty-recommendations")
    }

    private var emptyRecentView: some View {
        Button {
            HapticManager.shared.selection()
            router.selectedTab = .camera
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.themePrimary.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(Color.brandGradient)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("No workouts yet")
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                    Text("Tap to start your first session")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.themePrimary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("workout-empty-recent")
    }

    // MARK: - Helpers

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let date = date else { return "—" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func relativeDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func totalMinutes() -> String {
        let total = viewModel.recentWorkouts.reduce(0) { $0 + $1.durationMinutes }
        return "\(Int(total))"
    }

    private func totalCalories() -> String {
        let total = viewModel.recentWorkouts.reduce(0) { $0 + $1.caloriesBurned }
        return "\(Int(total))"
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
struct WorkoutView_Previews: PreviewProvider {
    static var previews: some View {
        WorkoutView()
            .environmentObject(AppRouter())
            .environment(
                \.managedObjectContext,
                PersistenceController.preview.container.viewContext
            )
    }
}
#endif
