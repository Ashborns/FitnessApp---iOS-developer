import SwiftUI

// MARK: - MoreView

/// Dashboard "More" — menggabungkan navigasi ke Profile (Settings) dan Chat AI
/// dalam satu tampilan yang premium dan visual, menggantikan 2 tab terpisah.
struct MoreView: View {

    @EnvironmentObject private var router: AppRouter
    @StateObject private var profileStore = UserProfileStore.shared
    @StateObject private var goalsStore = WorkoutGoalsStore.shared
    @State private var selectedDestination: MoreDestination? = nil
    @State private var showProfile = false
    @State private var showChat = false
    @State private var appearAnimation = false
    /// Exercise yang pending dibuka di camera setelah chat di-dismiss
    @State private var pendingCameraExercise: ExerciseType?? = nil  // nil = tidak ada request; .some(nil) = buka camera tanpa exercise

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.themeBackground.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        headerSection
                            .padding(.horizontal, 24)
                            .padding(.top, 12)

                        profileHeroCard
                            .padding(.horizontal, 20)
                            .padding(.top, 24)
                            .opacity(appearAnimation ? 1 : 0)
                            .offset(y: appearAnimation ? 0 : 30)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: appearAnimation)

                        chatHeroCard
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .opacity(appearAnimation ? 1 : 0)
                            .offset(y: appearAnimation ? 0 : 30)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.2), value: appearAnimation)

                        quickActionsSection
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .opacity(appearAnimation ? 1 : 0)
                            .offset(y: appearAnimation ? 0 : 20)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3), value: appearAnimation)

                        Spacer().frame(height: 110)
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $showProfile) {
                SettingsView()
            }
            .fullScreenCover(isPresented: $showChat, onDismiss: handleChatDismiss) {
                ChatView(onCameraRequested: { exercise in
                    // Simpan exercise yang diminta, lalu dismiss chat
                    pendingCameraExercise = .some(exercise)
                    showChat = false
                })
            }
        }
        .onAppear {
            withAnimation { appearAnimation = true }
        }
        .onDisappear {
            appearAnimation = false
        }
    }

    // MARK: - Camera Handoff

    /// Dipanggil saat fullScreenCover chat selesai di-dismiss.
    /// Jika ada pendingCameraExercise, buka camera setelah delay singkat
    /// agar animasi dismiss selesai dulu.
    private func handleChatDismiss() {
        guard let pending = pendingCameraExercise else { return }
        pendingCameraExercise = nil
        // Delay agar dismiss animation selesai sebelum camera ditampilkan
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            if let exercise = pending {
                router.openCamera(with: exercise)
            } else {
                router.openCamera()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("MORE")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.secondary)
                    .tracking(2)
                Text("Your Space")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
            }
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: BrandTokens.logoSymbol)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Color.brandGradient)
                Text(BrandTokens.appName)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                    .tracking(1.5)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Profile Hero Card

    private var profileHeroCard: some View {
        Button {
            HapticManager.shared.selection()
            showProfile = true
        } label: {
            ZStack(alignment: .bottomLeading) {
                // Background gradient
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.themePrimary.opacity(0.85),
                                Color.themePrimary.opacity(0.55),
                                Color.themeSecondary.opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 200)

                // Decorative circles
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 160, height: 160)
                    .offset(x: 220, y: -80)

                Circle()
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 100, height: 100)
                    .offset(x: 250, y: 20)

                // Content
                HStack(alignment: .bottom, spacing: 0) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Avatar + name
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.25))
                                    .frame(width: 56, height: 56)
                                Text(initialString)
                                    .font(.system(size: 22, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(profileStore.name.isEmpty ? "Athlete" : profileStore.name)
                                    .font(.system(size: 20, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                Text(profileStore.fitnessGoal.displayName)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.75))
                            }
                        }

                        // Mini stats row
                        HStack(spacing: 16) {
                            miniStat(value: "\(goalsStore.currentStreak)", label: "Streak", icon: "flame.fill")
                            miniStat(value: String(format: "%.1f", profileStore.bmi), label: "BMI", icon: "scalemass.fill")
                            miniStat(value: "\(Int(profileStore.dailyCalorieGoal))", label: "kcal", icon: "target")
                        }
                    }
                    .padding(22)

                    Spacer()
                }

                // "PROFILE" badge + arrow
                HStack {
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        Text("PROFILE")
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundColor(.white.opacity(0.7))
                            .tracking(1.5)
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .padding(20)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.themePrimary.opacity(0.35), radius: 20, x: 0, y: 8)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("Open Profile")
    }

    private func miniStat(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundColor(.white.opacity(0.7))
                Text(value)
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
            Text(label.uppercased())
                .font(.system(size: 8, weight: .heavy))
                .foregroundColor(.white.opacity(0.6))
                .tracking(0.8)
        }
    }

    // MARK: - Chat Hero Card

    private var chatHeroCard: some View {
        Button {
            HapticManager.shared.selection()
            showChat = true
        } label: {
            ZStack(alignment: .topLeading) {
                // Background
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.themeSurface)
                    .frame(height: 160)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.themeBorder.opacity(0.5), lineWidth: 1)
                    )

                // Decorative glow
                Circle()
                    .fill(Color.themeAccent.opacity(0.12))
                    .frame(width: 120, height: 120)
                    .offset(x: 260, y: -20)

                HStack(alignment: .center, spacing: 20) {
                    // AI Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.themeAccent, Color.themePrimary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 64, height: 64)
                            .shadow(color: Color.themeAccent.opacity(0.4), radius: 12, x: 0, y: 4)

                        Image(systemName: BrandTokens.logoSymbol)
                            .font(.system(size: 28, weight: .heavy))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Text("PULSE AI")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundColor(.primary)
                            Text("COACH")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundColor(.themeAccent)
                                .tracking(1.5)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.themeAccent.opacity(0.12))
                                )
                        }

                        Text("Ask me about your workouts,\nnutrition, or anything fitness.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineSpacing(2)

                        // Fake message bubbles
                        HStack(spacing: 6) {
                            quickPromptChip("How am I doing?")
                            quickPromptChip("Plan workout")
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .heavy))
                        .foregroundColor(.secondary.opacity(0.4))
                        .padding(.trailing, 4)
                }
                .padding(20)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityLabel("Open AI Chat Coach")
    }

    private func quickPromptChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(.themePrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.themePrimary.opacity(0.1))
            )
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("QUICK ACCESS")
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(.secondary)
                .tracking(1.5)
                .padding(.leading, 2)

            HStack(spacing: 12) {
                quickActionTile(
                    icon: "bell.fill",
                    title: "Notifications",
                    color: .themeSecondary,
                    destination: AnyView(NotificationSettingsView())
                )
                quickActionTile(
                    icon: "ruler",
                    title: "Units",
                    color: .themePrimary,
                    destination: AnyView(UnitsQuickView())
                )
                quickActionTile(
                    icon: "info.circle.fill",
                    title: "About",
                    color: .themeAccent,
                    destination: AnyView(AboutView())
                )
            }
        }
    }

    private func quickActionTile(icon: String, title: String, color: Color, destination: AnyView) -> some View {
        NavigationLink {
            destination
        } label: {
            VStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(color.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(color)
                }
                Text(title)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.themeSurface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.themeBorder.opacity(0.4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private var initialString: String {
        let trimmed = profileStore.name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return "A" }
        return String(trimmed.prefix(1)).uppercased()
    }
}

// MARK: - Scale Button Style

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - MoreDestination

private enum MoreDestination {
    case profile, chat
}

// MARK: - Units Quick View (placeholder inline)

private struct UnitsQuickView: View {
    @AppStorage("settings.useImperial") private var useImperial: Bool = false

    var body: some View {
        ZStack {
            Color.themeBackground.ignoresSafeArea()
            VStack(spacing: 24) {
                Toggle(isOn: $useImperial) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Imperial Units")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .foregroundColor(.primary)
                        Text(useImperial ? "Using lbs & ft" : "Using kg & cm")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .tint(.themePrimary)
                .padding(20)
                .background(Color.themeSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(24)
        }
        .navigationTitle("Units")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - About View (placeholder inline)

private struct AboutView: View {
    var body: some View {
        ZStack {
            Color.themeBackground.ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: BrandTokens.logoSymbol)
                    .font(.system(size: 48, weight: .heavy))
                    .foregroundStyle(Color.brandGradient)
                Text(BrandTokens.appName)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.primary)
                    .tracking(2)
                Text("Version 1.0.0")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                Text(BrandTokens.tagline)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.themePrimary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }
            .padding(40)
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Preview

#if DEBUG
struct MoreView_Previews: PreviewProvider {
    static var previews: some View {
        MoreView()
            .environmentObject(AppRouter())
            .preferredColorScheme(.dark)
    }
}
#endif
