import SwiftUI

/// First-run profile setup screen.
/// Shown after onboarding tutorial; user MUST fill basic info before entering the app.
/// Once completed, sets `profile.hasCompletedProfile` flag and unlocks MainTabView.
struct ProfileSetupView: View {

    @StateObject private var store = UserProfileStore.shared
    @State private var step: Int = 0
    @AppStorage("profile.hasCompletedProfile") private var hasCompletedProfile: Bool = false

    private let totalSteps = 4

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                // Progress bar
                progressBar
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                // Step content
                Group {
                    switch step {
                    case 0: nameStep
                    case 1: physicalStep
                    case 2: activityStep
                    case 3: goalStep
                    default: nameStep
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom nav
                bottomBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            Color.themeBackground.ignoresSafeArea()
            Circle()
                .fill(Color.themePrimary.opacity(0.18))
                .frame(width: 320, height: 320)
                .blur(radius: 100)
                .offset(x: -130, y: -260)
            Circle()
                .fill(Color.themeAccent.opacity(0.15))
                .frame(width: 280, height: 280)
                .blur(radius: 90)
                .offset(x: 140, y: 220)
        }
        .ignoresSafeArea()
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= step ? Color.themePrimary : Color.themeBorder)
                    .frame(height: 4)
                    .animation(.easeInOut(duration: 0.25), value: step)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - Step 1: Name

    private var nameStep: some View {
        stepContent(
            eyebrow: "STEP 1 OF 4",
            title: "What should we call you?",
            subtitle: "Just your first name — we'll use it to personalize your experience."
        ) {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "person.fill")
                        .foregroundColor(.themePrimary)
                    TextField("Your name", text: $store.name)
                        .font(.body)
                        .foregroundColor(.primary)
                        .submitLabel(.next)
                        .onSubmit { advance() }
                }
                .padding(16)
                .background(Color.themeSurface)
                .cornerRadius(14)
                .accessibilityIdentifier("setup-name-field")
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Step 2: Physical Info

    private var physicalStep: some View {
        stepContent(
            eyebrow: "STEP 2 OF 4",
            title: "Tell us about you",
            subtitle: "Used to calculate your personal calorie target — kept private on your device."
        ) {
            VStack(spacing: 16) {
                // Gender pills
                HStack(spacing: 10) {
                    ForEach(Gender.allCases) { g in
                        let isSelected = store.gender == g
                        Button {
                            store.gender = g
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: g == .male ? "figure.stand" : "figure.dress")
                                    .font(.subheadline)
                                Text(g.displayName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(isSelected ? .black : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                ZStack {
                                    if isSelected {
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color.brandGradient)
                                    } else {
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(Color.themeSurface)
                                    }
                                }
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("setup-gender-\(g.rawValue)")
                    }
                }

                // Age stepper
                fieldRow(label: "Age", value: "\(store.age) yrs") {
                    Stepper("", value: $store.age, in: 10...100)
                        .labelsHidden()
                        .tint(.themePrimary)
                }

                // Weight slider
                fieldRow(label: "Weight", value: String(format: "%.1f kg", store.weightKg)) {
                    Slider(value: $store.weightKg, in: 30...200, step: 0.5)
                        .tint(.themePrimary)
                }

                // Height slider
                fieldRow(label: "Height", value: "\(Int(store.heightCm)) cm") {
                    Slider(value: $store.heightCm, in: 100...220, step: 1)
                        .tint(.themeSecondary)
                }
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Step 3: Activity Level

    private var activityStep: some View {
        stepContent(
            eyebrow: "STEP 3 OF 4",
            title: "How active are you?",
            subtitle: "We'll factor this into your daily calorie burn estimate."
        ) {
            VStack(spacing: 10) {
                ForEach(ActivityLevel.allCases) { level in
                    activityRow(level)
                }
            }
            .padding(.horizontal, 24)
        }
    }

    private func activityRow(_ level: ActivityLevel) -> some View {
        let isSelected = store.activityLevel == level
        return Button {
            store.activityLevel = level
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .strokeBorder(isSelected ? Color.themePrimary : Color.themeBorder, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    if isSelected {
                        Circle()
                            .fill(Color.themePrimary)
                            .frame(width: 12, height: 12)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(level.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text(level.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(14)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.themeSurface)
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? Color.themePrimary : Color.themeBorder, lineWidth: 1)
                }
            )
        }
        .accessibilityIdentifier("setup-activity-\(level.rawValue)")
    }

    // MARK: - Step 4: Fitness Goal

    private var goalStep: some View {
        stepContent(
            eyebrow: "STEP 4 OF 4",
            title: "What's your goal?",
            subtitle: "We'll adjust your calorie target accordingly. You can change this anytime."
        ) {
            VStack(spacing: 10) {
                ForEach(FitnessGoal.allCases) { goal in
                    goalRow(goal)
                }

                // Calculated goal preview
                VStack(spacing: 6) {
                    Text("YOUR DAILY TARGET")
                        .font(.caption2)
                        .fontWeight(.heavy)
                        .foregroundColor(.themePrimary)
                        .tracking(1.5)
                    Text("\(Int(store.dailyCalorieGoal)) kcal")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.brandGradient)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color.themeSurface)
                .cornerRadius(14)
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
        }
    }

    private func goalRow(_ goal: FitnessGoal) -> some View {
        let isSelected = store.fitnessGoal == goal
        return Button {
            store.fitnessGoal = goal
        } label: {
            HStack(spacing: 12) {
                Image(systemName: goal.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .black : .themePrimary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(goal.displayName)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(isSelected ? .black : .primary)
                    Text(goal.description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .black.opacity(0.75) : .secondary)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.black)
                }
            }
            .padding(14)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.brandGradient)
                    } else {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.themeSurface)
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.themeBorder, lineWidth: 1)
                    }
                }
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("setup-goal-\(goal.rawValue)")
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { step -= 1 }
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.themeSurface)
                        .clipShape(Circle())
                }
                .accessibilityLabel("Previous step")
                .accessibilityIdentifier("setup-back-btn")
            }

            Button(action: advance) {
                HStack(spacing: 8) {
                    Text(step == totalSteps - 1 ? "Get Started" : "Continue")
                        .fontWeight(.bold)
                    Image(systemName: step == totalSteps - 1 ? "checkmark" : "arrow.right")
                        .font(.subheadline)
                }
                .foregroundColor(canAdvance ? .black : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    ZStack {
                        if canAdvance {
                            Capsule().fill(Color.brandGradient)
                        } else {
                            Capsule().fill(Color.themeBorder)
                        }
                    }
                )
                .shadow(color: canAdvance ? Color.themePrimary.opacity(0.4) : .clear, radius: 12, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .disabled(!canAdvance)
            .accessibilityLabel(step == totalSteps - 1 ? "Get started" : "Continue")
            .accessibilityIdentifier("setup-continue-btn")
        }
    }

    private var canAdvance: Bool {
        if step == 0 {
            return !store.name.trimmingCharacters(in: .whitespaces).isEmpty
        }
        return true
    }

    // MARK: - Step Layout Helper

    private func stepContent<Content: View>(
        eyebrow: String,
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 24) {
            VStack(spacing: 10) {
                Text(eyebrow)
                    .font(.caption2)
                    .fontWeight(.heavy)
                    .foregroundColor(.themePrimary)
                    .tracking(2)
                Text(title)
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.top, 40)

            content()

            Spacer()
        }
    }

    // MARK: - Field Row Helper

    private func fieldRow<Control: View>(
        label: String,
        value: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label.uppercased())
                    .font(.caption2)
                    .fontWeight(.heavy)
                    .foregroundColor(.secondary)
                    .tracking(1)
                Spacer()
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.themePrimary)
            }
            control()
        }
        .padding(14)
        .background(Color.themeSurface)
        .cornerRadius(14)
    }

    // MARK: - Actions

    private func advance() {
        if step < totalSteps - 1 {
            withAnimation(.easeInOut(duration: 0.25)) { step += 1 }
        } else {
            // Final step → save and unlock app
            store.hasCompletedProfile = true
            hasCompletedProfile = true
        }
    }
}

#if DEBUG
struct ProfileSetupView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileSetupView()
    }
}
#endif
