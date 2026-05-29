import SwiftUI

/// Reusable empty-state placeholder with brand styling.
/// Shows an icon in a colored circle, title, message, and optional CTA button.
struct EmptyStateView: View {

    let icon: String
    let title: String
    let message: String
    let cta: CTAConfig?

    struct CTAConfig {
        let label: String
        let action: () -> Void
    }

    init(
        icon: String,
        title: String,
        message: String,
        cta: CTAConfig? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.cta = cta
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.themePrimary.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: icon)
                    .font(.system(size: 36))
                    .foregroundStyle(Color.brandGradient)
            }

            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .padding(.horizontal, 24)

            if let cta = cta {
                Button(action: {
                    HapticManager.shared.selection()
                    cta.action()
                }) {
                    HStack(spacing: 6) {
                        Text(cta.label)
                            .fontWeight(.bold)
                        Image(systemName: "arrow.right")
                            .font(.caption)
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(
                        Capsule().fill(Color.brandGradient)
                    )
                    .shadow(color: Color.themePrimary.opacity(0.4), radius: 8)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.themeSurface)
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.themeBorder, lineWidth: 1)
            }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(message)")
    }
}

#if DEBUG
struct EmptyStateView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            EmptyStateView(
                icon: "figure.run.circle",
                title: "No workouts yet",
                message: "Start your first session with PULSE coach",
                cta: EmptyStateView.CTAConfig(label: "Start Workout", action: {})
            )
        }
        .padding()
        .background(Color.themeBackground)
        .preferredColorScheme(.dark)
    }
}
#endif
