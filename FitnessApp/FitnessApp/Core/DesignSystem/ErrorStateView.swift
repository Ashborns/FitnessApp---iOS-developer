import SwiftUI

/// Reusable error-state view shown when a data-driven screen enters
/// `AsyncState.error`. Presents a descriptive message explaining the failure
/// plus a "retry" control. The `onRetry` action is expected to return the
/// owning ViewModel's state back to `loading` and restart the load operation.
///
/// _Requirements: 19.5, 19.6_
struct ErrorStateView: View {

    let message: String
    let onRetry: () -> Void

    init(message: String, onRetry: @escaping () -> Void) {
        self.message = message
        self.onRetry = onRetry
    }

    var body: some View {
        VStack(spacing: .spacingLarge) {
            ZStack {
                Circle()
                    .fill(Color.themeError.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.themeError)
            }

            VStack(spacing: .spacingMedium) {
                Text("Something went wrong")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .padding(.horizontal, .spacingExtraLarge)

            Button(action: {
                HapticManager.shared.selection()
                onRetry()
            }) {
                HStack(spacing: .spacingMedium - 2) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                    Text("Try Again")
                        .fontWeight(.bold)
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
            .padding(.top, .spacingMedium)
            .accessibilityLabel("Try again")
            .accessibilityIdentifier("errorStateRetryButton")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, .spacingLarge)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: .cornerRadiusLarge)
                    .fill(Color.themeSurface)
                RoundedRectangle(cornerRadius: .cornerRadiusLarge)
                    .stroke(Color.themeBorder, lineWidth: 1)
            }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error. \(message)")
    }
}

#if DEBUG
struct ErrorStateView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            ErrorStateView(
                message: "We couldn't reach the exercise library. Check your connection and try again.",
                onRetry: {}
            )
        }
        .padding()
        .background(Color.themeBackground)
        .preferredColorScheme(.dark)
    }
}
#endif
