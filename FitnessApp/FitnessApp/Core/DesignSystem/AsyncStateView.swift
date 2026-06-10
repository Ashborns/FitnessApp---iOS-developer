import SwiftUI
import UIKit

/// Generic, reusable wrapper that renders exactly one branch of an
/// ``AsyncState`` value. Because `state` is a single enum value the screen is
/// always in precisely one state, and this view renders precisely one matching
/// branch via `switch` — no `AnyView`, branches resolved through `@ViewBuilder`.
///
/// Branch mapping:
/// - `.loading`  → lightweight skeleton placeholder rendered immediately
///   (synchronous, so it appears well within 100ms), never showing empty or
///   error content (19.2).
/// - `.loaded(v)`→ caller-provided `loaded(v)` content.
/// - `.empty`    → the supplied reusable ``EmptyStateView`` (19.3/19.4).
/// - `.error(m)` → ``ErrorStateView`` showing the message plus a retry control
///   whose action (`onRetry`) is expected to set the ViewModel state back to
///   `loading` and restart loading (19.5/19.6).
///
/// _Requirements: 19.2, 19.3, 19.4, 19.5, 19.6_
struct AsyncStateView<Value: Equatable, Loaded: View>: View {

    let state: AsyncState<Value>
    let emptyConfig: EmptyStateView
    let onRetry: () -> Void
    @ViewBuilder let loaded: (Value) -> Loaded

    init(
        state: AsyncState<Value>,
        emptyConfig: EmptyStateView,
        onRetry: @escaping () -> Void,
        @ViewBuilder loaded: @escaping (Value) -> Loaded
    ) {
        self.state = state
        self.emptyConfig = emptyConfig
        self.onRetry = onRetry
        self.loaded = loaded
    }

    var body: some View {
        // Render exactly one branch (no AnyView), then post a VoiceOver
        // announcement whenever `state` transitions to loading/error/empty so
        // the change is announced within ≤1s (17.4). `loaded` is intentionally
        // not announced — the new content itself is the VoiceOver context.
        content
            .onChange(of: state) { newState in
                announce(for: newState)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            SkeletonList()
        case .loaded(let value):
            loaded(value)
        case .empty:
            emptyConfig
        case .error(let message):
            ErrorStateView(message: message, onRetry: onRetry)
        }
    }

    /// Maps a state transition to a short, user-facing message and posts it as
    /// a VoiceOver announcement. Posting happens immediately on the state
    /// change so it is delivered well within the 1s budget (17.4).
    private func announce(for newState: AsyncState<Value>) {
        let message: String?
        switch newState {
        case .loading:
            message = "Memuat"
        case .empty:
            message = "Tidak ada hasil"
        case .error(let errorMessage):
            message = errorMessage
        case .loaded:
            message = nil
        }
        guard let message, !message.isEmpty else { return }
        // iOS 16.4-compatible VoiceOver announcement (AccessibilityNotification
        // .Announcement is iOS 17+). Posts on the main thread so the change is
        // announced within ≤1s (17.4).
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}

/// Skeleton placeholder used for the `loading` branch. Renders a small list of
/// shimmer rows using the shared ``SkeletonLoader``, giving an immediate,
/// content-shaped loading affordance without any network or async work.
private struct SkeletonList: View {

    private let rowCount = 6
    private let rowHeight: CGFloat = 72

    var body: some View {
        VStack(spacing: .spacingLarge) {
            ForEach(0..<rowCount, id: \.self) { _ in
                SkeletonLoader(cornerRadius: .cornerRadiusSmall)
                    .frame(height: rowHeight)
            }
        }
        .padding(.horizontal, .spacingLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .accessibilityElement()
        .accessibilityLabel("Loading")
    }
}

#if DEBUG
struct AsyncStateView_Previews: PreviewProvider {

    private static let sampleEmpty = EmptyStateView(
        icon: "figure.run.circle",
        title: "No exercises yet",
        message: "Browse the library to add your first exercise.",
        cta: EmptyStateView.CTAConfig(label: "Browse", action: {})
    )

    static var previews: some View {
        Group {
            AsyncStateView(
                state: AsyncState<[String]>.loading,
                emptyConfig: sampleEmpty,
                onRetry: {}
            ) { items in
                Text("\(items.count) items")
            }
            .previewDisplayName("Loading")

            AsyncStateView(
                state: AsyncState<[String]>.empty,
                emptyConfig: sampleEmpty,
                onRetry: {}
            ) { items in
                Text("\(items.count) items")
            }
            .previewDisplayName("Empty")

            AsyncStateView(
                state: AsyncState<[String]>.error(message: "Network unavailable. Please try again."),
                emptyConfig: sampleEmpty,
                onRetry: {}
            ) { items in
                Text("\(items.count) items")
            }
            .previewDisplayName("Error")

            AsyncStateView(
                state: AsyncState<[String]>.loaded(["Push Up", "Squat", "Plank"]),
                emptyConfig: sampleEmpty,
                onRetry: {}
            ) { items in
                VStack(alignment: .leading, spacing: .spacingMedium) {
                    ForEach(items, id: \.self) { Text($0) }
                }
            }
            .previewDisplayName("Loaded")
        }
        .padding()
        .background(Color.themeBackground)
        .preferredColorScheme(.dark)
    }
}
#endif
