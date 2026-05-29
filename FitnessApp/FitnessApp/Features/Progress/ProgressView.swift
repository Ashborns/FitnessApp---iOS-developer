import SwiftUI
import Charts

struct FitnessProgressView: View {

    @StateObject private var viewModel = ProgressViewModel()

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Progress")
                .background(Color.themeBackground)
                .task { await viewModel.loadData() }
                .onChange(of: viewModel.selectedRange) { _ in
                    Task { await viewModel.loadData() }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            FitnessProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.calorieData.isEmpty && viewModel.workoutHistory.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(spacing: .spacingLarge) {
                    timeRangePicker
                    calorieChart
                    workoutHistorySection
                }
                .padding(.spacingLarge)
            }
        }
    }

    // MARK: - Time Range Picker

    private var timeRangePicker: some View {
        Picker("Time Range", selection: $viewModel.selectedRange) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Text(range.displayName)
                    .tag(range)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityLabel("Select time range")
        .accessibilityIdentifier("progress_time_range_picker")
    }

    // MARK: - Calorie Chart

    private var calorieChart: some View {
        VStack(alignment: .leading, spacing: .spacingMedium) {
            Text("Daily Calories")
                .font(.headline)
                .foregroundColor(.themePrimary)

            Chart {
                ForEach(viewModel.calorieData) { item in
                    BarMark(
                        x: .value("Date", item.date, unit: .day),
                        y: .value("Calories", item.total)
                    )
                    .foregroundStyle(Color.themeAccent)
                }
            }
            .frame(height: 220)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .accessibilityLabel("Daily calorie bar chart")
            .accessibilityIdentifier("progress_calorie_chart")
        }
        .padding()
        .background(Color.themeSurface)
        .cornerRadius(.cornerRadiusLarge)
    }

    // MARK: - Workout History

    private var workoutHistorySection: some View {
        VStack(alignment: .leading, spacing: .spacingMedium) {
            Text("Workout History")
                .font(.headline)
                .foregroundColor(.themePrimary)

            if viewModel.workoutHistory.isEmpty {
                Text("No workouts recorded in this period.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, .spacingMedium)
            } else {
                LazyVStack(spacing: .spacingMedium) {
                    ForEach(viewModel.workoutHistory, id: \.id) { workout in
                        workoutRow(workout)
                    }
                }
            }
        }
    }

    private func workoutRow(_ workout: WorkoutLog) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: .spacingSmall) {
                Text(workout.workoutType ?? "Workout")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Text(formattedDate(workout.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: .spacingSmall) {
                Text("\(Int(workout.durationMinutes)) min")
                    .font(.subheadline)
                    .foregroundColor(.themeSecondary)

                Text("\(Int(workout.caloriesBurned)) kcal")
                    .font(.caption)
                    .foregroundColor(.themeAccent)
            }
        }
        .padding()
        .background(Color.themeSurface)
        .cornerRadius(.cornerRadiusSmall)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(workout.workoutType ?? "Workout"), \(Int(workout.durationMinutes)) minutes, \(Int(workout.caloriesBurned)) calories burned")
        .accessibilityIdentifier("progress_workout_row")
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: .spacingLarge) {
            timeRangePicker

            Spacer()

            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundColor(.themeSecondary.opacity(0.6))

            Text("No Progress Data")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.primary)

            Text("Start logging calories and workouts to see your progress here.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, .spacingExtraLarge)

            Spacer()
        }
        .padding(.spacingLarge)
        .accessibilityIdentifier("progress_empty_state")
    }

    // MARK: - Helpers

    private func formattedDate(_ date: Date?) -> String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Preview

struct FitnessProgressView_Previews: PreviewProvider {
    static var previews: some View {
        FitnessProgressView()
    }
}
