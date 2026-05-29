import SwiftUI
import CoreData

/// Settings — editorial layout with profile hero, inline stats, and minimal list rows.
struct SettingsView: View {

    @StateObject private var profileStore = UserProfileStore.shared
    @StateObject private var goalsStore = WorkoutGoalsStore.shared
    @AppStorage("settings.useImperial") private var useImperial: Bool = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    @State private var showResetConfirm = false
    @State private var showProfileEditor = false

    var body: some View {
        ZStack(alignment: .top) {
            Color.themeBackground.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    topNav
                    profileHero
                    statsBar
                    sectionsGroup
                    appFooter
                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, 24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("Reset all data?", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetAllData()
            }
        } message: {
            Text("This will permanently delete all workouts, calorie entries, profile, and streaks.")
        }
        .sheet(isPresented: $showProfileEditor) {
            NavigationStack {
                ProfileEditView()
            }
        }
    }

    // MARK: - Sections Group (collapsed into one view to keep ViewBuilder count low)

    private var sectionsGroup: some View {
        VStack(alignment: .leading, spacing: 0) {
            divider(top: 28)
            personalSection
            divider(top: 24)
            workoutSection
            divider(top: 24)
            dataSection
            divider(top: 24)
        }
    }

    private func divider(top: CGFloat) -> some View {
        Divider()
            .background(Color.themeBorder)
            .padding(.vertical, top)
    }

    // MARK: - Personal Section

    private var personalSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Personal")
            listRow(icon: "person", title: "Edit profile", subtitle: profileSubtitle, action: {
                HapticManager.shared.selection()
                showProfileEditor = true
            })
            listRow(
                icon: "ruler",
                title: "Units",
                subtitle: useImperial ? "Imperial" : "Metric"
            ) {
                Toggle("", isOn: $useImperial)
                    .labelsHidden()
                    .tint(.themePrimary)
            }
        }
    }

    // MARK: - Workout Section

    private var workoutSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Workout")
            repGoalRow
            NavigationLink {
                NotificationSettingsView()
            } label: {
                listRowContent(
                    icon: "bell",
                    title: "Notifications",
                    subtitle: "Daily reminders",
                    trailingChevron: true
                )
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Data Section

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Data")
            listRow(
                icon: "arrow.counterclockwise",
                title: "Reset all data",
                subtitle: "Workouts, goals, profile",
                isDestructive: true,
                action: {
                    HapticManager.shared.warning()
                    showResetConfirm = true
                }
            )
        }
    }

    // MARK: - Top Nav

    private var topNav: some View {
        HStack {
            Text("SETTINGS")
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(.secondary)
                .tracking(2)
            Spacer()
        }
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    // MARK: - Profile Hero

    private var profileHero: some View {
        HStack(alignment: .center, spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.brandGradient)
                    .frame(width: 64, height: 64)
                    .shadow(color: Color.themePrimary.opacity(0.4), radius: 10)
                Text(initialString)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(.black)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(profileStore.name.isEmpty ? "Athlete" : profileStore.name)
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                    .tracking(-0.5)
                HStack(spacing: 6) {
                    Image(systemName: profileStore.fitnessGoal.icon)
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.themePrimary)
                    Text(profileStore.fitnessGoal.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text("·")
                        .foregroundColor(.secondary)
                    Text("\(Int(profileStore.dailyCalorieGoal)) kcal")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(.bottom, 24)
    }

    private var initialString: String {
        let trimmed = profileStore.name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "A" }
        return String(trimmed.prefix(1)).uppercased()
    }

    // MARK: - Stats Bar (inline, no card)

    private var statsBar: some View {
        HStack(alignment: .top, spacing: 0) {
            statCol(value: "\(goalsStore.currentStreak)", unit: goalsStore.currentStreak == 1 ? "day" : "days", label: "Streak", color: .themeAccent)
            verticalDivider
            statCol(value: "\(goalsStore.bestStreak)", unit: "best", label: "Record", color: .themeSecondary)
            verticalDivider
            statCol(value: String(format: "%.1f", profileStore.bmi), unit: profileStore.bmiCategory.lowercased(), label: "BMI", color: .themePrimary)
        }
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(Color.themeBorder)
            .frame(width: 1, height: 44)
            .padding(.horizontal, 8)
    }

    private func statCol(value: String, unit: String, label: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.secondary)
                    .tracking(1)
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                Text(unit)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value) \(unit)")
    }

    // MARK: - Section Label

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .heavy))
            .foregroundColor(.secondary)
            .tracking(1.5)
            .padding(.bottom, 8)
    }

    // MARK: - List Row Components

    /// Tappable row with action.
    private func listRow(
        icon: String,
        title: String,
        subtitle: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            listRowContent(
                icon: icon,
                title: title,
                subtitle: subtitle,
                isDestructive: isDestructive,
                trailingChevron: true
            )
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    /// Static row with custom trailing view (e.g. Toggle).
    private func listRow<Trailing: View>(
        icon: String,
        title: String,
        subtitle: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.themePrimary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            Spacer()
            trailing()
        }
        .padding(.vertical, 14)
    }

    private func listRowContent(
        icon: String,
        title: String,
        subtitle: String,
        isDestructive: Bool = false,
        trailingChevron: Bool = false
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isDestructive ? .themeError : .themePrimary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(isDestructive ? .themeError : .primary)
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            Spacer()
            if trailingChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.secondary.opacity(0.6))
            }
        }
    }

    // MARK: - Rep Goal Row (inline stepper)

    private var repGoalRow: some View {
        HStack(spacing: 14) {
            Image(systemName: "target")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.themePrimary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("Daily rep goal")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text("\(goalsStore.dailyRepGoal)")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(Color.brandGradient)
                    Text("reps per day")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Stepper("", value: $goalsStore.dailyRepGoal, in: 10...500, step: 10)
                .labelsHidden()
                .tint(.themePrimary)
        }
        .padding(.vertical, 14)
    }

    // MARK: - App Footer

    private var appFooter: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: BrandTokens.logoSymbol)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Color.brandGradient)
                    Text(BrandTokens.appName)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                        .tracking(2)
                }
                Text("Version 1.0.0 · \(BrandTokens.tagline)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Helpers

    private var profileSubtitle: String {
        let name = profileStore.name.isEmpty ? "Set your name" : profileStore.name
        return "\(name) · \(profileStore.age) yrs"
    }

    // MARK: - Reset

    private func resetAllData() {
        let defaults = UserDefaults.standard
        let keysToRemove = [
            "profile.name", "profile.age", "profile.weightKg", "profile.heightCm",
            "profile.gender", "profile.activityLevel", "profile.fitnessGoal",
            "profile.hasCompletedProfile", "profile.dailyCalorieGoal",
            "goals.dailyRepGoal", "goals.dailyProgress", "goals.bestStreak",
            "settings.useImperial", "hasCompletedOnboarding"
        ]
        keysToRemove.forEach { defaults.removeObject(forKey: $0) }

        let context = PersistenceController.shared.container.viewContext
        ["WorkoutLog", "CalorieEntry", "DailyGoal", "UserProfile"].forEach { entity in
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entity)
            let delete = NSBatchDeleteRequest(fetchRequest: request)
            _ = try? context.execute(delete)
        }
        try? context.save()

        hasCompletedOnboarding = false
    }
}

// MARK: - Profile Edit Sheet

struct ProfileEditView: View {
    @StateObject private var store = UserProfileStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            Color.themeBackground.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your profile")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundColor(.primary)
                            .tracking(-0.5)
                        Text("Used to personalize your goals")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 16)

                    inputField(label: "Name") {
                        TextField("Your name", text: $store.name)
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("GENDER")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(.secondary)
                            .tracking(1.5)
                        HStack(spacing: 8) {
                            ForEach(Gender.allCases) { g in
                                let isSelected = store.gender == g
                                Button {
                                    store.gender = g
                                } label: {
                                    Text(g.displayName)
                                        .font(.system(size: 13, weight: .heavy))
                                        .foregroundColor(isSelected ? .black : .primary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(
                                            ZStack {
                                                if isSelected {
                                                    Capsule().fill(Color.brandGradient)
                                                } else {
                                                    Capsule().stroke(Color.themeBorder, lineWidth: 1)
                                                }
                                            }
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    sliderField(
                        label: "Age",
                        value: "\(store.age) yrs",
                        binding: Binding(
                            get: { Double(store.age) },
                            set: { store.age = Int($0) }
                        ),
                        range: 10...100,
                        step: 1
                    )

                    sliderField(
                        label: "Weight",
                        value: String(format: "%.1f kg", store.weightKg),
                        binding: $store.weightKg,
                        range: 30...200,
                        step: 0.5
                    )

                    sliderField(
                        label: "Height",
                        value: "\(Int(store.heightCm)) cm",
                        binding: $store.heightCm,
                        range: 100...220,
                        step: 1
                    )

                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    HapticManager.shared.selection()
                    dismiss()
                }
                .fontWeight(.bold)
                .foregroundColor(.themePrimary)
            }
        }
    }

    private func inputField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(.secondary)
                .tracking(1.5)
            content()
                .padding(.vertical, 10)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.themeBorder).frame(height: 1)
                }
        }
    }

    private func sliderField(label: String, value: String, binding: Binding<Double>, range: ClosedRange<Double>, step: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.secondary)
                    .tracking(1.5)
                Spacer()
                Text(value)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(Color.brandGradient)
            }
            Slider(value: binding, in: range, step: step)
                .tint(.themePrimary)
        }
    }
}
