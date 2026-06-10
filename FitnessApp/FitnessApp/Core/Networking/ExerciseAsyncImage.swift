import SwiftUI
import UIKit

/// Main-actor observable that drives a single ``ExerciseAsyncImage``.
///
/// Bridges the off-main ``AssetLoader`` (which downloads + decodes on the cooperative thread pool,
/// R6.1/R18.5) to SwiftUI by funnelling every result onto the main actor before mutating its
/// `@Published` state (R18.6). The view observes two published values:
///
/// - ``phase``: the terminal-ish rendering state (`loading` / `loaded` / `failed`).
/// - ``showSkeleton``: becomes `true` only once a load has been in flight for `skeletonDelay`
///   (0.3s) without finishing, so fast/cache-served loads (≤100ms, R18.4) never flash a skeleton
///   while slow loads still get one (R6.4).
///
/// Declared `@MainActor` so that `loadTask`/`skeletonTask` closures inherit main-actor isolation —
/// the only place `@Published` properties are written. The heavy work (`loader.image(for:)`) runs
/// off the main actor because ``AssetLoader`` is a plain `Sendable` class, not main-actor isolated.
@MainActor
final class AssetImageLoader: ObservableObject {

    /// Rendering state for the associated view.
    enum Phase: Equatable {
        /// The asset is being fetched/decoded (or has not started yet).
        case loading
        /// The asset decoded successfully.
        case loaded(UIImage)
        /// The asset failed to load, timed out, or the URL was missing (R6.5).
        case failed
    }

    /// Current rendering state. Mutated only on the main actor.
    @Published private(set) var phase: Phase = .loading

    /// Whether the skeleton placeholder should be shown. Flips to `true` only after the load has
    /// been pending for `skeletonDelay` seconds (R6.4).
    @Published private(set) var showSkeleton: Bool = false

    private let loader: AssetLoader
    private let skeletonDelay: TimeInterval

    private var loadTask: Task<Void, Never>?
    private var skeletonTask: Task<Void, Never>?
    private var loadedURL: URL?

    /// Creates a loader.
    ///
    /// - Parameters:
    ///   - loader: The underlying asset loader. Defaults to ``AssetLoader/shared``; inject a custom
    ///     instance (with its own cache/session) for previews or tests.
    ///   - skeletonDelay: Delay before the skeleton appears (R6.4). Defaults to 0.3 seconds.
    init(loader: AssetLoader = .shared, skeletonDelay: TimeInterval = 0.3) {
        self.loader = loader
        self.skeletonDelay = max(0, skeletonDelay)
    }

    /// Begins loading `url`, replacing any in-flight load.
    ///
    /// No-ops when the requested URL is already loaded so re-rendering the row during scrolling
    /// does not re-decode an asset that is already on screen.
    func load(url: URL?) {
        // Already showing this exact asset — nothing to do.
        if case .loaded = phase, loadedURL == url { return }

        guard let url else {
            cancel()
            phase = .failed
            showSkeleton = false
            return
        }

        // Restart from scratch for a new URL.
        loadTask?.cancel()
        skeletonTask?.cancel()
        phase = .loading
        showSkeleton = false
        loadedURL = nil

        // Skeleton appears only if the load is still pending after `skeletonDelay` (R6.4).
        skeletonTask = Task { [weak self] in
            guard let self else { return }
            let delay = self.skeletonDelay
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            if case .loading = self.phase {
                self.showSkeleton = true
            }
        }

        // The actual fetch/decode runs off the main actor inside `loader.image(for:)`.
        loadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let image = try await self.loader.image(for: url)
                guard !Task.isCancelled else { return }
                self.skeletonTask?.cancel()
                self.loadedURL = url
                self.phase = .loaded(image)
                self.showSkeleton = false
            } catch {
                guard !Task.isCancelled else { return }
                // Any failure (network, retries exhausted, timeout) becomes a non-crashing
                // fallback state (R6.5/R6.6).
                self.skeletonTask?.cancel()
                self.phase = .failed
                self.showSkeleton = false
            }
        }
    }

    /// Cancels any in-flight load and skeleton timer (e.g. when the row scrolls off screen).
    func cancel() {
        loadTask?.cancel()
        skeletonTask?.cancel()
        loadTask = nil
        skeletonTask = nil
    }

    deinit {
        loadTask?.cancel()
        skeletonTask?.cancel()
    }
}

/// Asynchronously loads and displays an exercise demo GIF/image, with a delayed skeleton and a
/// non-crashing fallback (Requirements 6, 18).
///
/// Rendering states (selected via `@ViewBuilder`, never `AnyView`):
/// - **Loading:** a flat surface fill, upgraded to an animated ``SkeletonLoader`` once the load has
///   been pending for 0.3s (R6.4). Cache-served assets (≤100ms, R18.4) skip the skeleton entirely.
/// - **Loaded:** the decoded image, clipped to `cornerRadius` and laid out with `contentMode`.
/// - **Failed / timed out:** a placeholder surface with an error SF Symbol — the view never crashes
///   on load failure (R6.5).
struct ExerciseAsyncImage: View {

    private let url: URL?
    private let cornerRadius: CGFloat
    private let contentMode: ContentMode

    @StateObject private var loader: AssetImageLoader

    /// Creates an async image view.
    ///
    /// - Parameters:
    ///   - url: The asset URL. A `nil` URL renders the fallback.
    ///   - cornerRadius: Corner radius applied to every state. Defaults to `.cornerRadiusSmall`.
    ///   - contentMode: How the loaded image fills its frame. Defaults to `.fill`.
    ///   - assetLoader: Underlying loader, injectable for previews/tests. Defaults to `.shared`.
    init(
        url: URL?,
        cornerRadius: CGFloat = .cornerRadiusSmall,
        contentMode: ContentMode = .fill,
        assetLoader: AssetLoader = .shared
    ) {
        self.url = url
        self.cornerRadius = cornerRadius
        self.contentMode = contentMode
        _loader = StateObject(wrappedValue: AssetImageLoader(loader: assetLoader))
    }

    var body: some View {
        content
            .task(id: url) { loader.load(url: url) }
            .onDisappear { loader.cancel() }
    }

    @ViewBuilder
    private var content: some View {
        switch loader.phase {
        case .loading:
            loadingPlaceholder
        case .loaded(let image):
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: contentMode)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .accessibilityLabel("Demo latihan")
        case .failed:
            fallback
        }
    }

    @ViewBuilder
    private var loadingPlaceholder: some View {
        if loader.showSkeleton {
            SkeletonLoader(cornerRadius: cornerRadius)
                .accessibilityHidden(true)
        } else {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.themeSurface)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var fallback: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.themeSurface)
            .overlay(
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 28, weight: .regular))
                    .foregroundColor(.themeError)
            )
            .accessibilityLabel("Gambar demo latihan gagal dimuat")
    }
}

#if DEBUG
struct ExerciseAsyncImage_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            ExerciseAsyncImage(url: nil)
                .frame(height: 120)
            ExerciseAsyncImage(url: URL(string: "https://example.com/missing.gif"))
                .frame(height: 120)
        }
        .padding()
        .background(Color.themeBackground)
        .preferredColorScheme(.dark)
    }
}
#endif
