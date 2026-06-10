import Foundation
import ImageIO
import UIKit

/// Errors surfaced by ``AssetLoader`` while fetching or decoding an exercise demo asset.
///
/// All cases are non-fatal: the loader converts every failure (network, timeout, decode) into a
/// thrown error so the UI can fall back to an error symbol without crashing (R6.5).
enum AssetLoaderError: Error, Equatable {
    /// The overall load exceeded the configured timeout window (R6.5).
    case timeout
    /// The provided URL was missing or malformed.
    case invalidURL
    /// The server returned a non-2xx HTTP status code.
    case badResponse(Int)
    /// The download completed but returned no bytes.
    case emptyData
    /// Every download attempt (initial + retries) failed (R6.6).
    case downloadFailed(String)
    /// The downloaded bytes could not be decoded into an image.
    case decodeFailed
}

/// Async counting semaphore implemented as an `actor` to cap concurrent work without data races.
///
/// Used by ``AssetLoader`` to bound the number of simultaneous image *decode* operations to a
/// fixed limit (default 4) so memory stays bounded while scrolling a large list (R6.7). Callers
/// `await acquire()` before decoding and `release()` afterwards; waiters are resumed in FIFO order
/// as slots free up.
actor AsyncSemaphore {
    private let limit: Int
    private var available: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    /// Creates a semaphore permitting `limit` concurrent holders (clamped to at least 1).
    init(limit: Int) {
        let normalized = max(1, limit)
        self.limit = normalized
        self.available = normalized
    }

    /// Acquires a slot, suspending until one is available.
    func acquire() async {
        if available > 0 {
            available -= 1
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    /// Releases a slot, resuming the oldest waiter if any.
    func release() {
        if waiters.isEmpty {
            available = min(limit, available + 1)
        } else {
            let next = waiters.removeFirst()
            next.resume()
        }
    }
}

/// Loads exercise demo GIF/image assets asynchronously, off the main thread (R6.1).
///
/// Behavior:
/// - **Cache-first (R6.2, R18.4):** checks ``AssetDiskCache`` before the network; a cache hit is
///   decoded and returned without re-downloading, keeping repeat displays fast (≤100ms target).
/// - **Download + persist (R6.2):** on a cache miss the asset is downloaded and stored back to the
///   disk cache for subsequent requests.
/// - **Retry (R6.6):** transient download failures are retried up to `maxRetries` (default 2)
///   times before giving up.
/// - **Timeout (R6.5):** the whole load races a `timeoutSeconds` (default 10s) deadline; exceeding
///   it cancels the in-flight work and throws ``AssetLoaderError/timeout`` so the view can show a
///   fallback symbol — never a crash.
/// - **Bounded decode concurrency (R6.7):** every decode passes through a shared ``AsyncSemaphore``
///   capping simultaneous decodes at 4.
///
/// Implemented as a `final class` (immutable, `Sendable` state) rather than an `actor` so multiple
/// decodes can genuinely run concurrently up to the semaphore limit instead of being serialized by
/// actor isolation. The backing ``AssetDiskCache`` and `URLSession` are injected for testability.
final class AssetLoader: @unchecked Sendable {

    /// Shared default loader backed by the default 200 MB disk cache and `URLSession.shared`.
    static let shared = AssetLoader()

    private let cache: AssetDiskCache
    private let session: URLSession
    private let decodeLimiter: AsyncSemaphore
    private let maxRetries: Int
    private let timeoutSeconds: TimeInterval

    /// Creates an asset loader.
    ///
    /// - Parameters:
    ///   - cache: On-disk asset cache. Defaults to a fresh 200 MB ``AssetDiskCache``.
    ///   - session: `URLSession` used for downloads. Defaults to `.shared`.
    ///   - maxConcurrentDecodes: Upper bound on simultaneous decodes (R6.7). Defaults to 4.
    ///   - maxRetries: Maximum download retries after the first attempt (R6.6). Defaults to 2.
    ///   - timeoutSeconds: Hard deadline for the whole load (R6.5). Defaults to 10 seconds.
    init(
        cache: AssetDiskCache = AssetDiskCache(),
        session: URLSession = .shared,
        maxConcurrentDecodes: Int = 4,
        maxRetries: Int = 2,
        timeoutSeconds: TimeInterval = 10
    ) {
        self.cache = cache
        self.session = session
        self.decodeLimiter = AsyncSemaphore(limit: maxConcurrentDecodes)
        self.maxRetries = max(0, maxRetries)
        self.timeoutSeconds = max(0, timeoutSeconds)
    }

    // MARK: - Public API

    /// Loads and decodes the asset at `url`, serving from the disk cache when present.
    ///
    /// Throws ``AssetLoaderError/timeout`` if the operation exceeds `timeoutSeconds`, or another
    /// ``AssetLoaderError`` on network/decode failure. Never crashes.
    func image(for url: URL) async throws -> UIImage {
        try await withTimeout(timeoutSeconds) { [self] in
            try await loadImage(url: url)
        }
    }

    // MARK: - Loading

    private func loadImage(url: URL) async throws -> UIImage {
        // 1. Cache-first: serve a previously stored asset without hitting the network (R6.2, R18.4).
        if let cached = await cache.data(for: url) {
            return try await decode(cached)
        }

        // 2. Cache miss: download (with retry), persist, then decode.
        let data = try await download(url: url)
        await cache.store(data, for: url)
        return try await decode(data)
    }

    /// Downloads `url`, retrying transient failures up to `maxRetries` times (R6.6).
    private func download(url: URL) async throws -> Data {
        var lastError: Error?

        // Initial attempt + up to `maxRetries` retries.
        for _ in 0...maxRetries {
            do {
                try Task.checkCancellation()
                let (data, response) = try await session.data(from: url)

                if let http = response as? HTTPURLResponse,
                   !(200...299).contains(http.statusCode) {
                    throw AssetLoaderError.badResponse(http.statusCode)
                }
                guard !data.isEmpty else { throw AssetLoaderError.emptyData }
                return data
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
            }
        }

        throw AssetLoaderError.downloadFailed(lastError?.localizedDescription ?? "unknown")
    }

    // MARK: - Decoding (bounded concurrency)

    /// Decodes `data` into a `UIImage` while holding a decode slot, capping concurrency at 4 (R6.7).
    private func decode(_ data: Data) async throws -> UIImage {
        await decodeLimiter.acquire()
        do {
            let image = try Self.makeImage(from: data)
            await decodeLimiter.release()
            return image
        } catch {
            await decodeLimiter.release()
            throw error
        }
    }

    /// Builds a `UIImage` from raw bytes, preserving GIF animation when present.
    private static func makeImage(from data: Data) throws -> UIImage {
        if let animated = animatedImage(from: data) {
            return animated
        }
        if let still = UIImage(data: data) {
            return still
        }
        throw AssetLoaderError.decodeFailed
    }

    /// Assembles an animated `UIImage` from multi-frame GIF data using ImageIO; returns `nil` for
    /// single-frame or non-GIF data so the caller falls back to a still image.
    private static func animatedImage(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let frameCount = CGImageSourceGetCount(source)
        guard frameCount > 1 else { return nil }

        var frames: [UIImage] = []
        frames.reserveCapacity(frameCount)
        var totalDuration: TimeInterval = 0

        for index in 0..<frameCount {
            guard let cgImage = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
            frames.append(UIImage(cgImage: cgImage))
            totalDuration += frameDuration(at: index, source: source)
        }

        guard !frames.isEmpty else { return nil }
        if totalDuration <= 0 { totalDuration = Double(frames.count) * 0.1 }
        return UIImage.animatedImage(with: frames, duration: totalDuration)
    }

    /// Reads the per-frame display delay from a GIF source, defaulting to 0.1s when unspecified.
    private static func frameDuration(at index: Int, source: CGImageSource) -> TimeInterval {
        guard
            let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any],
            let gif = properties[kCGImagePropertyGIFDictionary] as? [CFString: Any]
        else {
            return 0.1
        }

        let unclamped = gif[kCGImagePropertyGIFUnclampedDelayTime] as? Double
        let clamped = gif[kCGImagePropertyGIFDelayTime] as? Double
        let delay = unclamped ?? clamped ?? 0.1
        // GIF spec: delays below 0.02s are commonly clamped to 0.1s by renderers.
        return delay < 0.02 ? 0.1 : delay
    }
}

/// Races `operation` against a deadline, throwing ``AssetLoaderError/timeout`` if it elapses first.
///
/// Cancels the losing child task once a winner is determined so no work leaks past the deadline
/// (R6.5). Built on `withThrowingTaskGroup` for iOS 16 compatibility (no iOS 17+ APIs).
private func withTimeout<T: Sendable>(
    _ seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    guard seconds > 0 else { return try await operation() }

    return try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw AssetLoaderError.timeout
        }

        defer { group.cancelAll() }

        guard let result = try await group.next() else {
            throw AssetLoaderError.timeout
        }
        return result
    }
}
