import SwiftUI
import CoreData

/// Settings — redesigned with card-based layout matching the PULSE design system.
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
                VStack(alignment: .leading, spacing: 24) {
                    topNav
                    profileHeroCard
                    statsCards
                    personalCard
                    workoutCard
                    dataCard
                    appFooter
                    Spacer().frame(height: 100)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
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

    // MARK: - Top Nav

    private var topNav: some View {
        HStack(alignment: .center, spacing: 12) {
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
            Text("PROFILE")
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(.secondary)
                .tracking(1.5)
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Profile Hero Card

    private var profileHeroCard: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color.brandGradient)
                        .frame(width: 72, height: 72)
                        .shadow(color: Color.themePrimary.opacity(0.4), radius: 14, x: 0, y: 4)
                    Text(initialString)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundColor(.black)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(profileStore.name.isEmpty ? "Athlete" : profileStore.name)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.primary)
                        .tracking(-0.5)
                    HStack(spacing: 6) {
                        Image(systemName: profileStore.fitnessGoal.icon)
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundColor(.themePrimary)
                        Text(profileStore.fitnessGoal.displayName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                        Text("·")
                            .foregroundColor(.secondary)
                        Text("\(Int(profileStore.dailyCalorieGoal)) kcal")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()

                // Edit button
                Button {
                    HapticManager.shared.selection()
                    showProfileEditor = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(.themePrimary)
                        .padding(10)
                        .background(Circle().fill(Color.themePrimary.opacity(0.12)))
                }
                .accessibilityLabel("Edit profile")
            }
        }
        .padding(20)
        .background(Color.themeSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusLarge, style: .continuous))
    }

    // MARK: - Stats Cards

    private var statsCards: some View {
        HStack(spacing: 12) {
            statCard(
                icon: "flame.fill",
                value: "\(goalsStore.currentStreak)",
                unit: goalsStore.currentStreak == 1 ? "day" : "days",
                label: "Streak",
                color: .themeAccent
            )
            statCard(
                icon: "trophy.fill",
                value: "\(goalsStore.bestStreak)",
                unit: "best",
                label: "Record",
                color: .themeSecondary
            )
            statCard(
                icon: "scalemass.fill",
                value: String(format: "%.1f", profileStore.bmi),
                unit: profileStore.bmiCategory.lowercased(),
                label: "BMI",
                color: .themePrimary
            )
        }
    }

    private func statCard(icon: String, value: String, unit: String, label: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)
                .frame(height: 20)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                Text(unit)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
            }
            Text(label.uppercased())
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(.secondary)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.themeSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusLarge, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value) \(unit)")
    }

    // MARK: - Personal Card

    private var personalCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader(icon: "person.fill", title: "Personal")

            cardRow(icon: "person.text.rectangle", title: "Edit profile", subtitle: profileSubtitle) {
                HapticManager.shared.selection()
                showProfileEditor = true
            }

            Divider().background(Color.themeBorder).padding(.leading, 48)

            cardRow(icon: "ruler", title: "Units", subtitle: useImperial ? "Imperial (lbs, ft)" : "Metric (kg, cm)") {
                // no action — toggle is inline
            } trailing: {
                Toggle("", isOn: $useImperial)
                    .labelsHidden()
                    .tint(.themePrimary)
            }
        }
        .padding(.vertical, 12)
        .background(Color.themeSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusLarge, style: .continuous))
    }

    // MARK: - Workout Card

    private var workoutCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader(icon: "figure.run", title: "Workout")

            // Rep goal row with inline stepper
            HStack(spacing: 14) {
                Image(systemName: "target")
                    .font(.system(size: 15, weight: .semibold))
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
            .padding(.horizontal, 20)

            Divider().background(Color.themeBorder).padding(.leading, 48)

            // Notifications row
            NavigationLink {
                NotificationSettingsView()
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.themePrimary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notifications")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                        Text("Daily reminders & workout alerts")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 20)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
        .background(Color.themeSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusLarge, style: .continuous))
    }

    // MARK: - Data Card

    private var dataCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader(icon: "externaldrive.fill", title: "Data")

            Button {
                HapticManager.shared.warning()
                showResetConfirm = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.themeError)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reset all data")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .foregroundColor(.themeError)
                        Text("Workouts, goals, profile & streaks")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 20)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 12)
        .background(Color.themeSurface)
        .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusLarge, style: .continuous))
    }

    // MARK: - Reusable Card Components

    private func cardHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .heavy))
                .foregroundColor(.themePrimary)
            Text(title.uppercased())
                .font(.system(size: 11, weight: .heavy))
                .foregroundColor(.secondary)
                .tracking(1.5)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private func cardRow(
        icon: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
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
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
        }
        .buttonStyle(.plain)
    }

    private func cardRow<Trailing: View>(
        icon: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void = {},
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
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
        .padding(.horizontal, 20)
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
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private var initialString: String {
        let trimmed = profileStore.name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "A" }
        return String(trimmed.prefix(1)).uppercased()
    }

    private var profileSubtitle: String {
        let name = profileStore.name.isEmpty ? "Set your name, age & body metrics" : "\(profileStore.name) · \(profileStore.age) yrs"
        return name
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