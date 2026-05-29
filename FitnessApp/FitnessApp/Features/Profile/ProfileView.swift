import SwiftUI

/// Profile screen — user enters age, weight, height, gender, activity level, and fitness goal.
/// All values feed into BMR/TDEE calculation to set a personalized daily calorie goal.
struct ProfileView: View {

    @StateObject private var viewModel = ProfileViewModel()
    @StateObject private var store = UserProfileStore.shared

    var body: some View {
        ZStack {
            Color.themeBackground.ignoresSafeArea()
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: .spacingLarge) {
                    profileHeader
                    statsCards
                    personalInfoSection
                    activitySection
                    goalSection
                    saveButton
                }
                .padding(.horizontal, .spacingLarge)
                .padding(.top, .spacingLarge)
                .padding(.bottom, .spacingExtraLarge)
            }
        }
        .accessibilityIdentifier("profile-root")
    }

    // MARK: - Header

    private var profileHeader: some View {
        VStack(spacing: .spacingMedium) {
            ZStack {
                Circle()
                    .fill(Color.themePrimary.opacity(0.15))
                    .frame(width: 90, height: 90)
                Image(systemName: "person.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.themePrimary)
            }
            .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text(store.name.isEmpty ? "Your Profile" : store.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text("Personalize your fitness goals")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, .spacingLarge)
    }

    // MARK: - Stats Cards (BMR / TDEE / BMI)

    private var statsCards: some View {
        VStack(alignment: .leading, spacing: .spacingMedium) {
            Text("Your Stats")
                .font(.headline)
                .foregroundColor(.primary)

            HStack(spacing: .spacingMedium) {
                statCard(
                    title: "BMR",
                    value: "\(Int(store.bmr))",
                    unit: "kcal/day",
                    icon: "heart.fill",
                    color: .themeAccent,
                    tooltip: "Calories at rest"
                )
                statCard(
                    title: "Goal",
                    value: "\(Int(store.dailyCalorieGoal))",
                    unit: "kcal/day",
                    icon: "target",
                    color: .themePrimary,
                    tooltip: "Your daily target"
                )
                statCard(
                    title: "BMI",
                    value: String(format: "%.1f", store.bmi),
                    unit: store.bmiCategory,
                    icon: "scalemass.fill",
                    color: bmiColor,
                    tooltip: store.bmiCategory
                )
            }
        }
        .padding(.spacingLarge)
        .background(Color.themeSurface)
        .cornerRadius(.cornerRadiusLarge)
    }

    private func statCard(title: String, value: String, unit: String, icon: String, color: Color, tooltip: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(unit)
                .font(.system(size: 9))
                .foregroundColor(color)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.spacingMedium)
        .background(Color.themeBackground)
        .cornerRadius(.cornerRadiusSmall)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value) \(unit)")
    }

    private var bmiColor: Color {
        switch store.bmi {
        case ..<18.5: return .themeSecondary
        case 18.5..<25: return .green
        case 25..<30: return .orange
        default: return .themeError
        }
    }

    // MARK: - Personal Info Section

    private var personalInfoSection: some View {
        VStack(alignment: .leading, spacing: .spacingMedium) {
            sectionHeader(icon: "person.text.rectangle", title: "Personal Info")

            // Name
            formField(label: "Name") {
                TextField("Your name", text: $store.name)
                    .foregroundColor(.primary)
                    .accessibilityIdentifier("profile-name-field")
            }

            // Age
            formField(label: "Age") {
                HStack {
                    Stepper("", value: $store.age, in: 10...100)
                        .labelsHidden()
                    Spacer()
                    Text("\(store.age) yrs")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.themePrimary)
                        .frame(width: 60, alignment: .trailing)
                }
                .accessibilityLabel("Age: \(store.age) years")
                .accessibilityIdentifier("profile-age-stepper")
            }

            // Weight
            formField(label: "Weight") {
                HStack {
                    Slider(value: $store.weightKg, in: 30...200, step: 0.5)
                        .tint(.themePrimary)
                    Text(String(format: "%.1f kg", store.weightKg))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.themePrimary)
                        .frame(width: 70, alignment: .trailing)
                }
                .accessibilityLabel("Weight: \(String(format: "%.1f", store.weightKg)) kilograms")
                .accessibilityIdentifier("profile-weight-slider")
            }

            // Height
            formField(label: "Height") {
                HStack {
                    Slider(value: $store.heightCm, in: 100...220, step: 1)
                        .tint(.themeSecondary)
                    Text("\(Int(store.heightCm)) cm")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.themeSecondary)
                        .frame(width: 70, alignment: .trailing)
                }
                .accessibilityLabel("Height: \(Int(store.heightCm)) centimeters")
                .accessibilityIdentifier("profile-height-slider")
            }

            // Gender
            formField(label: "Gender") {
                Picker("Gender", selection: $store.gender) {
                    ForEach(Gender.allCases) { g in
                        Text(g.displayName).tag(g)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("profile-gender-picker")
            }
        }
        .padding(.spacingLarge)
        .background(Color.themeSurface)
        .cornerRadius(.cornerRadiusLarge)
    }

    // MARK: - Activity Section

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: .spacingMedium) {
            sectionHeader(icon: "bolt.fill", title: "Activity Level")

            ForEach(ActivityLevel.allCases) { level in
                activityRow(level)
            }
        }
        .padding(.spacingLarge)
        .background(Color.themeSurface)
        .cornerRadius(.cornerRadiusLarge)
    }

    private func activityRow(_ level: ActivityLevel) -> some View {
        let isSelected = store.activityLevel == level
        return Button {
            store.activityLevel = level
        } label: {
            HStack(spacing: .spacingMedium) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.themePrimary : Color.themeBackground)
                        .frame(width: 36, height: 36)
                    Image(systemName: isSelected ? "checkmark" : "circle")
                        .font(.caption)
                        .foregroundColor(isSelected ? .white : .secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(level.displayName)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundColor(.primary)
                    Text(level.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.spacingMedium)
            .background(isSelected ? Color.themePrimary.opacity(0.08) : Color.themeBackground)
            .cornerRadius(.cornerRadiusSmall)
        }
        .accessibilityLabel("\(level.displayName): \(level.description)")
        .accessibilityIdentifier("profile-activity-\(level.rawValue)")
    }

    // MARK: - Goal Section

    private var goalSection: some View {
        VStack(alignment: .leading, spacing: .spacingMedium) {
            sectionHeader(icon: "target", title: "Fitness Goal")

            HStack(spacing: .spacingMedium) {
                ForEach(FitnessGoal.allCases) { goal in
                    goalCard(goal)
                }
            }
        }
        .padding(.spacingLarge)
        .background(Color.themeSurface)
        .cornerRadius(.cornerRadiusLarge)
    }

    private func goalCard(_ goal: FitnessGoal) -> some View {
        let isSelected = store.fitnessGoal == goal
        return Button {
            store.fitnessGoal = goal
        } label: {
            VStack(spacing: .spacingMedium) {
                Image(systemName: goal.icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : .themePrimary)

                Text(goal.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? .white : .primary)
                    .multilineTextAlignment(.center)

                Text(goal.description)
                    .font(.system(size: 9))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.spacingMedium)
            .background(isSelected ? Color.themePrimary : Color.themeBackground)
            .cornerRadius(.cornerRadiusSmall)
        }
        .accessibilityLabel("\(goal.displayName): \(goal.description)")
        .accessibilityIdentifier("profile-goal-\(goal.rawValue)")
    }

    // MARK: - Save Button

    private var saveButton: some View {
        Button {
            store.hasCompletedProfile = true
            viewModel.syncCalorieGoal(store.dailyCalorieGoal)
        } label: {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("Save Profile")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.spacingLarge)
            .background(
                LinearGradient(
                    colors: [Color.themePrimary, Color.themeAccent],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(.cornerRadiusLarge)
        }
        .accessibilityLabel("Save profile")
        .accessibilityIdentifier("profile-save-btn")
    }

    // MARK: - Helpers

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: .spacingMedium) {
            Image(systemName: icon)
                .foregroundColor(.themePrimary)
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)
        }
        .accessibilityAddTraits(.isHeader)
    }

    private func formField<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            content()
                .padding(.spacingMedium)
                .background(Color.themeBackground)
                .cornerRadius(.cornerRadiusSmall)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
    }
}
#endif
