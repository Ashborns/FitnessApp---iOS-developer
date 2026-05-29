import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @State private var currentPage: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let totalPages = 4

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: BrandTokens.logoSymbol,
            eyebrow: "WELCOME TO",
            title: BrandTokens.appName,
            subtitle: "Your AI fitness coach. Real-time pose tracking, personalized goals, zero judgement.",
            identifier: "onboarding-welcome",
            isHero: true
        ),
        OnboardingPage(
            icon: "camera.viewfinder",
            eyebrow: "AI COACH",
            title: "Form Tracking",
            subtitle: "Point your camera, start moving. PULSE counts your reps and coaches your form in real time.",
            identifier: "onboarding-camera",
            isHero: false
        ),
        OnboardingPage(
            icon: "chart.bar.fill",
            eyebrow: "INSIGHTS",
            title: "Track Everything",
            subtitle: "Calories, workouts, progress — all stored locally on your device. No cloud, no nonsense.",
            identifier: "onboarding-features",
            isHero: false
        ),
        OnboardingPage(
            icon: "target",
            eyebrow: "PERSONAL",
            title: "Your Goals",
            subtitle: "Tell us about you and we'll calculate the right calorie target. Smart, science-based, simple.",
            identifier: "onboarding-profile",
            isHero: false
        )
    ]

    var body: some View {
        ZStack {
            backgroundLayer

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        pageContent(page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                bottomBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Background

    private var backgroundLayer: some View {
        ZStack {
            Color.themeBackground.ignoresSafeArea()

            Circle()
                .fill(Color.themePrimary.opacity(0.25))
                .frame(width: 350, height: 350)
                .blur(radius: 110)
                .offset(x: -120, y: -250)

            Circle()
                .fill(Color.themeAccent.opacity(0.20))
                .frame(width: 300, height: 300)
                .blur(radius: 100)
                .offset(x: 130, y: 200)

            Circle()
                .fill(Color.themeSecondary.opacity(0.15))
                .frame(width: 280, height: 280)
                .blur(radius: 90)
                .offset(x: 0, y: 50)
        }
        .ignoresSafeArea()
    }

    // MARK: - Page Content

    @ViewBuilder
    private func pageContent(_ page: OnboardingPage) -> some View {
        VStack(spacing: 32) {
            Spacer()

            // Icon with brand glow
            ZStack {
                Circle()
                    .fill(Color.brandGradient.opacity(0.2))
                    .frame(width: 200, height: 200)
                    .blur(radius: 20)

                Circle()
                    .fill(Color.themeSurface)
                    .frame(width: 140, height: 140)
                    .overlay(
                        Circle().stroke(Color.brandGradient, lineWidth: 2)
                    )

                Image(systemName: page.icon)
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(Color.brandGradient)
            }
            .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text(page.eyebrow)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.themePrimary)
                    .tracking(3)

                Text(page.title)
                    .font(.system(
                        size: page.isHero ? 56 : 38,
                        weight: .heavy,
                        design: .rounded
                    ))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .tracking(page.isHero ? 4 : 0)
                    .padding(.horizontal, 24)

                Text(page.subtitle)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
        .accessibilityIdentifier(page.identifier)
    }

    // MARK: - Bottom Bar

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: 24) {
            // Page dots
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Capsule()
                        .fill(index == currentPage ? Color.themePrimary : Color.themeBorder)
                        .frame(width: index == currentPage ? 28 : 8, height: 8)
                        .animation(reduceMotion ? .none : .spring(response: 0.3), value: currentPage)
                }
            }
            .accessibilityHidden(true)

            HStack {
                Button("Skip") {
                    completeOnboarding()
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
                .accessibilityLabel("Skip onboarding")
                .accessibilityIdentifier("onboarding-skip-btn")

                Spacer()

                if currentPage < totalPages - 1 {
                    Button(action: {
                        withAnimation(reduceMotion ? .none : .spring(response: 0.4)) {
                            currentPage += 1
                        }
                    }) {
                        HStack(spacing: 8) {
                            Text("Next")
                                .fontWeight(.bold)
                            Image(systemName: "arrow.right")
                                .font(.subheadline)
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(Color.brandGradient)
                        .cornerRadius(28)
                        .shadow(color: Color.themePrimary.opacity(0.4), radius: 12, x: 0, y: 4)
                    }
                    .accessibilityLabel("Next screen")
                    .accessibilityIdentifier("onboarding-next-btn")
                } else {
                    Button(action: { completeOnboarding() }) {
                        HStack(spacing: 8) {
                            Text("Get Started")
                                .fontWeight(.bold)
                            Image(systemName: "bolt.fill")
                                .font(.subheadline)
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(Color.brandGradient)
                        .cornerRadius(28)
                        .shadow(color: Color.themePrimary.opacity(0.5), radius: 12, x: 0, y: 4)
                    }
                    .accessibilityLabel("Get started")
                    .accessibilityIdentifier("onboarding-get-started-btn")
                }
            }
        }
    }

    private func completeOnboarding() {
        hasCompletedOnboarding = true
    }
}

private struct OnboardingPage {
    let icon: String
    let eyebrow: String
    let title: String
    let subtitle: String
    let identifier: String
    let isHero: Bool
}

#if DEBUG
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
    }
}
#endif
