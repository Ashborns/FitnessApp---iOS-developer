import SwiftUI

/// Calories screen — editorial layout with big number, inline form, list timeline.
struct CalorieGoalView: View {

    @StateObject private var viewModel = CalorieGoalViewModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var entryLabel: String = ""
    @State private var entryCalories: String = ""
    @State private var showAddSheet: Bool = false
    @FocusState private var focusedField: Field?

    private enum Field { case label, calories }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.themeBackground.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        topNav
                        headerSection
                        bigNumber
                        macroBar
                        Divider().background(Color.themeBorder).padding(.vertical, 24)
                        addCTA
                        Divider().background(Color.themeBorder).padding(.vertical, 24)
                        entriesSection
                        Spacer().frame(height: 100)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .task { await viewModel.loadTodayData() }
            .sheet(isPresented: $showAddSheet) {
                addEntrySheet
            }
        }
        .accessibilityIdentifier("calorie-goal-root")
    }

    // MARK: - Top Nav

    private var topNav: some View {
        HStack {
            Text("CALORIES")
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(.secondary)
                .tracking(2)
            Spacer()
            Text(todayDateString().uppercased())
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(.secondary)
                .tracking(1.5)
        }
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Today")
                .font(.system(size: 42, weight: .black, design: .rounded))
                .foregroundColor(.primary)
                .tracking(-1)

            Text(headerSubtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.bottom, 32)
    }

    private var headerSubtitle: String {
        let remaining = max(viewModel.dailyGoal - viewModel.consumed, 0)
        let isOver = viewModel.consumed > viewModel.dailyGoal
        if isOver {
            return "\(Int(viewModel.consumed - viewModel.dailyGoal)) over your goal"
        } else {
            return "\(Int(remaining)) kcal left to spend"
        }
    }

    // MARK: - Big Number Display

    private var bigNumber: some View {
        let progress = viewModel.dailyGoal > 0
            ? min(viewModel.consumed / viewModel.dailyGoal, 1.0)
            : 0.0

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(Int(viewModel.consumed))")
                    .font(.system(size: 72, weight: .black, design: .rounded))
                    .foregroundStyle(Color.brandGradient)
                    .tracking(-2)

                VStack(alignment: .leading, spacing: 0) {
                    Text("of \(Int(viewModel.dailyGoal))")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text("kcal")
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundColor(.secondary)
                        .tracking(1.5)
                }
            }

            // Slim progress bar — full width, no card
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.themeBorder)
                        .frame(height: 6)
                    Capsule()
                        .fill(Color.brandGradient)
                        .frame(width: geo.size.width * progress, height: 6)
                        .shadow(color: Color.themePrimary.opacity(0.4), radius: 4)
                        .animation(reduceMotion ? .none : .easeInOut(duration: 0.6), value: progress)
                }
            }
            .frame(height: 6)
        }
        .padding(.bottom, 24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(Int(viewModel.consumed)) of \(Int(viewModel.dailyGoal)) calories")
    }

    // MARK: - Macro / Stats Bar (inline, no card)

    private var macroBar: some View {
        HStack(alignment: .top, spacing: 0) {
            macroCol(label: "Goal", value: "\(Int(viewModel.dailyGoal))", color: .themeSecondary)
            verticalDivider
            macroCol(label: "Eaten", value: "\(Int(viewModel.consumed))", color: .themePrimary)
            verticalDivider
            macroCol(
                label: "Left",
                value: "\(Int(max(viewModel.dailyGoal - viewModel.consumed, 0)))",
                color: .themeAccent
            )
        }
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(Color.themeBorder)
            .frame(width: 1, height: 32)
            .padding(.horizontal, 8)
    }

    private func macroCol(label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.secondary)
                    .tracking(1)
            }
            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: - Add CTA (inline button, not card)

    private var addCTA: some View {
        Button {
            HapticManager.shared.selection()
            showAddSheet = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.brandGradient)
                        .frame(width: 36, height: 36)
                        .shadow(color: Color.themePrimary.opacity(0.4), radius: 8)
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(.black)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Log a meal")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                    Text("Track what you ate today")
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
    }

    // MARK: - Entries Section

    private var entriesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today's meals")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                if !viewModel.entries.isEmpty {
                    Text("\(viewModel.entries.count) entries")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }

            if viewModel.entries.isEmpty {
                emptyEntriesView
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.entries.enumerated()), id: \.offset) { index, entry in
                        entryRow(
                            entry,
                            isFirst: index == 0,
                            isLast: index == viewModel.entries.count - 1
                        )
                    }
                }
            }

            if let errorMessage = viewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.themeError)
                        .font(.system(size: 12))
                    Text(errorMessage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.themeError)
                }
                .padding(.top, 8)
                .accessibilityIdentifier("calorie-error-message")
            }
        }
    }

    private func entryRow(_ entry: CalorieEntry, isFirst: Bool, isLast: Bool) -> some View {
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
                        .stroke(Color.themeAccent, lineWidth: 2)
                        .frame(width: 14, height: 14)
                    Circle()
                        .fill(Color.themeAccent)
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
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.label ?? "Meal")
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundColor(.primary)
                    Text(entryTimeString(entry))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                Spacer()
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(Int(entry.amount))")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(Color.brandGradient)
                    Text("kcal")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.bottom, isLast ? 0 : 20)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.label ?? "Entry"), \(Int(entry.amount)) calories")
    }

    private var emptyEntriesView: some View {
        HStack(spacing: 12) {
            Image(systemName: "fork.knife")
                .font(.system(size: 20, weight: .heavy))
                .foregroundColor(.themePrimary.opacity(0.5))
            VStack(alignment: .leading, spacing: 2) {
                Text("No meals logged yet")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary)
                Text("Tap log a meal above to start tracking")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .accessibilityIdentifier("calorie-empty-state")
    }

    // MARK: - Add Entry Sheet

    private var addEntrySheet: some View {
        NavigationStack {
            ZStack {
                Color.themeBackground.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Log a meal")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(.primary)
                            .tracking(-0.5)
                        Text("Add what you ate to today's count")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 16)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("WHAT")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(.secondary)
                            .tracking(1.5)
                        TextField("Chicken Rice", text: $entryLabel)
                            .focused($focusedField, equals: .label)
                            .submitLabel(.next)
                            .onSubmit { focusedField = .calories }
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.primary)
                            .padding(.vertical, 12)
                            .overlay(alignment: .bottom) {
                                Rectangle()
                                    .fill(Color.themeBorder)
                                    .frame(height: 1)
                            }
                            .accessibilityIdentifier("calorie-entry-label")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("CALORIES")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(.secondary)
                            .tracking(1.5)
                        HStack(alignment: .firstTextBaseline) {
                            TextField("0", text: $entryCalories)
                                .focused($focusedField, equals: .calories)
                                .keyboardType(.decimalPad)
                                .submitLabel(.done)
                                .onSubmit { addEntry() }
                                .font(.system(size: 36, weight: .black, design: .rounded))
                                .foregroundStyle(Color.brandGradient)
                                .accessibilityIdentifier("calorie-entry-amount")
                            Text("kcal")
                                .font(.system(size: 14, weight: .heavy))
                                .foregroundColor(.secondary)
                                .tracking(1)
                        }
                        .padding(.vertical, 8)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(Color.themeBorder)
                                .frame(height: 1)
                        }
                    }

                    Spacer()

                    Button { addEntry() } label: {
                        Text("Add to Today")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Capsule().fill(Color.brandGradient))
                            .shadow(color: Color.themePrimary.opacity(0.4), radius: 12, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 16)
                    .accessibilityIdentifier("calorie-add-button")
                }
                .padding(.horizontal, 24)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        showAddSheet = false
                        entryLabel = ""
                        entryCalories = ""
                    }
                    .foregroundColor(.themePrimary)
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Actions

    private func addEntry() {
        focusedField = nil
        let calorieAmount = Double(entryCalories) ?? 0
        let result = viewModel.saveEntry(amount: calorieAmount, label: entryLabel)

        switch result {
        case .success:
            HapticManager.shared.selection()
            entryLabel = ""
            entryCalories = ""
            showAddSheet = false
        case .failure:
            HapticManager.shared.warning()
        }
    }

    // MARK: - Helpers

    private func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: Date())
    }

    private func entryTimeString(_ entry: CalorieEntry) -> String {
        guard let date = entry.date else { return "" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

struct CalorieGoalView_Previews: PreviewProvider {
    static var previews: some View {
        CalorieGoalView()
            .preferredColorScheme(.dark)
    }
}
