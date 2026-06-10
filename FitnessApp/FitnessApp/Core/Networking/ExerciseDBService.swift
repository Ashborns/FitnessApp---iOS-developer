import Foundation
import Network

// MARK: - Credential reading abstraction

/// Minimal read-only Keychain surface needed to fetch ExerciseDB credentials.
///
/// Injecting this (rather than calling `KeychainWrapper` statics directly) keeps `ExerciseDBService`
/// testable: a fake reader can supply present/absent credentials without touching the real Keychain.
protocol KeychainReading {
    /// Return the stored string for `key`, or `nil` if no value exists.
    func load(key: String) -> String?
}

/// Default `KeychainReading` adapter backed by the app's `KeychainWrapper`.
struct KeychainCredentialReader: KeychainReading {
    func load(key: String) -> String? { KeychainWrapper.load(key: key) }
}

// MARK: - Reachability abstraction

/// Reports whether the device currently has a usable network path.
///
/// Injected so offline behaviour (R5.2–R5.4) can be exercised deterministically in tests.
protocol NetworkReachabilityProviding: Sendable {
    /// `true` when a network path is available, `false` when the device is offline.
    func isOnline() async -> Bool
}

/// Default reachability backed by `NWPathMonitor`.
///
/// Tracks the latest path status on a background queue behind a lock. Defaults to "online" until the
/// monitor reports otherwise so a cold start never spuriously blocks a first fetch.
final class NWPathReachability: NetworkReachabilityProviding, @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.pulse.exercisedb.reachability")
    private let lock = NSLock()
    private var satisfied = true

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            self.lock.lock()
            self.satisfied = (path.status == .satisfied)
            self.lock.unlock()
        }
        monitor.start(queue: queue)
    }

    deinit { monitor.cancel() }

    func isOnline() async -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return satisfied
    }
}

// MARK: - Service protocol

/// `async`/`throws` networking surface consumed by ViewModels (R4.4).
protocol ExerciseDBServicing {
    /// Fetch a page of exercises. `limit` is clamped to `1...50` (R18.7).
    func fetchExercises(offset: Int, limit: Int) async throws -> [ExerciseItem]
    /// Fetch a single exercise by its stable id.
    func fetchExercise(id: String) async throws -> ExerciseItem
    /// Fetch a page of exercises for a body part. `limit` is clamped to `1...50`.
    func fetchByBodyPart(_ bodyPart: String, offset: Int, limit: Int) async throws -> [ExerciseItem]
    /// Fetch a page of exercises for a target muscle. `limit` is clamped to `1...50`.
    func fetchByTarget(_ target: String, offset: Int, limit: Int) async throws -> [ExerciseItem]
}

// MARK: - ExerciseDBService

/// Cache-first ExerciseDB client (R4, R5, R18.7).
///
/// Declared as an `actor` so all mutable state (the rate-limit gate) and every fetch run off the
/// main thread with no data races; ViewModels call its `async`/`throws` API and marshal results back
/// to the main actor themselves. Each fetch follows the algorithm in design § "ExerciseDB Service &
/// Networking":
///
/// 1. Cache hit + fresh (age ≤ 168h) → serve from cache, no network (R5.1).
/// 2. Offline → serve any cache including expired entries; otherwise `offlineNoCache` (R5.2–R5.4).
/// 3. Missing API key/host → `missingCredentials`, no request issued (R4.5, R4.7).
/// 4. Rate-limit gate → while `rateLimitedUntil` is in the future, serve cache or `rateLimited`;
///    on HTTP 429 the gate is armed from `Retry-After` or a 60s default (R5.5).
/// 5. Transport failure → retry up to 3 times, then `network` (R4.8).
/// 6. Decode safely → on failure throw `decoding` and write nothing partial to the cache (R4.3).
/// 7. Success → refresh/store decoded items in the cache (R4.6, R5.6).
///
/// All collaborators (session, cache, keychain reader, reachability, clock) are injected with
/// production defaults so the actor is fully drivable from tests via a `URLProtocol`-mockable
/// session and in-memory fakes.
actor ExerciseDBService: ExerciseDBServicing {

    // MARK: Configuration

    /// Keychain account holding the ExerciseDB API key.
    static let apiKeyKeychainKey = "exercisedb.apiKey"
    /// Keychain account holding the ExerciseDB API host.
    static let apiHostKeychainKey = "exercisedb.apiHost"
    /// Cache time-to-live: 168 hours (7 days) (R5.1).
    static let ttl: TimeInterval = 168 * 3600
    /// Maximum transport attempts before surfacing a network error (R4.8).
    static let maxAttempts = 3
    /// Default rate-limit cooldown when the response omits `Retry-After` (R5.5).
    static let defaultRetryAfter: TimeInterval = 60
    /// Per-request timeout budget in seconds.
    static let requestTimeout: TimeInterval = 10

    // MARK: Dependencies

    private let session: URLSession
    private let cache: ExerciseMetadataCaching
    private let keychain: KeychainReading
    private let reachability: NetworkReachabilityProviding
    private let now: () -> Date
    private let decoder: JSONDecoder

    // MARK: Mutable state

    /// While this is in the future, no new network requests are issued (HTTP 429 gate, R5.5).
    private var rateLimitedUntil: Date?

    // MARK: Init

    /// Create a service. All dependencies default to production implementations.
    ///
    /// - Parameters:
    ///   - session: URL loader. Inject a `URLProtocol`-backed session in tests.
    ///   - cache: metadata cache conforming to `ExerciseMetadataCaching`.
    ///   - keychain: credential reader (defaults to the real Keychain).
    ///   - reachability: online/offline provider (defaults to `NWPathMonitor`).
    ///   - now: clock used for TTL and rate-limit comparisons (defaults to `Date.init`).
    init(
        session: URLSession = .shared,
        cache: ExerciseMetadataCaching,
        keychain: KeychainReading = KeychainCredentialReader(),
        reachability: NetworkReachabilityProviding = NWPathReachability(),
        now: @escaping () -> Date = Date.init
    ) {
        self.session = session
        self.cache = cache
        self.keychain = keychain
        self.reachability = reachability
        self.now = now
        self.decoder = JSONDecoder()
    }

    // MARK: ExerciseDBServicing

    func fetchExercises(offset: Int, limit: Int) async throws -> [ExerciseItem] {
        try await fetchPage(
            endpoint: .allExercises(offset: offset, limit: limit),
            offset: offset,
            limit: limit,
            cachedRecords: { self.cache.loadAllRecords() }
        )
    }

    func fetchByBodyPart(_ bodyPart: String, offset: Int, limit: Int) async throws -> [ExerciseItem] {
        try await fetchPage(
            endpoint: .byBodyPart(bodyPart, offset: offset, limit: limit),
            offset: offset,
            limit: limit,
            cachedRecords: { self.cache.loadRecordsByBodyPart(bodyPart) }
        )
    }

    func fetchByTarget(_ target: String, offset: Int, limit: Int) async throws -> [ExerciseItem] {
        try await fetchPage(
            endpoint: .byTarget(target, offset: offset, limit: limit),
            offset: offset,
            limit: limit,
            cachedRecords: { self.cache.loadRecordsByTarget(target) }
        )
    }

    func fetchExercise(id: String) async throws -> ExerciseItem {
        let cached = cache.loadRecord(id: id)
        let current = now()

        // 1. Fresh cache hit → no network (R5.1).
        if let cached, isFresh(cached.cachedAt, now: current) {
            return cached.item
        }

        // 2. Offline → serve any cache (incl. expired) or fail (R5.2–R5.4).
        let online = await reachability.isOnline()
        if !online {
            if let cached { return cached.item }
            throw ExerciseDBError.offlineNoCache
        }

        // 3. Credentials (R4.5, R4.7).
        let credentials = try requireCredentials()

        // 4. Rate-limit gate (R5.5).
        if let gate = rateLimitedUntil, gate > current {
            if let cached { return cached.item }
            throw ExerciseDBError.rateLimited(retryAfter: gate.timeIntervalSince(current))
        }

        // 5–7. Request, decode, store.
        let outcome = try await requestData(
            endpoint: .exercise(id: id),
            credentials: credentials,
            cachedFallback: cached.map { [$0.item] }
        )
        switch outcome {
        case let .servedFromCache(items):
            // 429 fallback served the cached entry (R5.5); requireCredentials guarantees one exists.
            guard let item = items.first else { throw ExerciseDBError.rateLimited(retryAfter: nil) }
            return item
        case let .data(data):
            let item = try decode(ExerciseItem.self, from: data)
            cache.upsert([item])
            return item
        }
    }

    // MARK: Paged fetch pipeline

    /// Shared cache-first pipeline for the list-returning endpoints.
    private func fetchPage(
        endpoint: ExerciseDBEndpoint,
        offset: Int,
        limit: Int,
        cachedRecords: () -> [CachedExerciseRecord]
    ) async throws -> [ExerciseItem] {
        let entries = cachedRecords()
        // Deterministic ordering so pagination over the cache is stable.
        let sorted = entries.sorted { $0.item.id < $1.item.id }
        let current = now()

        let cachedPage = paginate(sorted, offset: offset, limit: limit)

        // 1. Fresh cache hit for this window → no network (R5.1).
        if !cachedPage.isEmpty, cachedPage.allSatisfy({ isFresh($0.cachedAt, now: current) }) {
            return cachedPage.map(\.item)
        }

        // 2. Offline → serve any cache incl. expired; empty cache → error (R5.2–R5.4).
        let online = await reachability.isOnline()
        if !online {
            if !sorted.isEmpty { return cachedPage.map(\.item) }
            throw ExerciseDBError.offlineNoCache
        }

        // 3. Credentials (R4.5, R4.7).
        let credentials = try requireCredentials()

        // 4. Rate-limit gate (R5.5).
        if let gate = rateLimitedUntil, gate > current {
            if !sorted.isEmpty { return cachedPage.map(\.item) }
            throw ExerciseDBError.rateLimited(retryAfter: gate.timeIntervalSince(current))
        }

        // 5–7. Request, decode safely, refresh cache.
        let outcome = try await requestData(
            endpoint: endpoint,
            credentials: credentials,
            cachedFallback: sorted.isEmpty ? nil : cachedPage.map(\.item)
        )
        switch outcome {
        case let .servedFromCache(items):
            // 429 fallback served the cached page (R5.5).
            return items
        case let .data(data):
            let items = try decode([ExerciseItem].self, from: data)
            cache.upsert(items)
            return items
        }
    }

    // MARK: Networking

    private struct Credentials {
        let apiKey: String
        let host: String
    }

    /// Result of issuing a request: either a raw body to decode, or items served from cache when the
    /// rate-limit gate tripped (HTTP 429 with a cached fallback available).
    private enum RequestOutcome {
        case data(Data)
        case servedFromCache([ExerciseItem])
    }

    /// Read API key + host from the Keychain, failing fast without a request when absent (R4.7).
    private func requireCredentials() throws -> Credentials {
        guard
            let key = keychain.load(key: Self.apiKeyKeychainKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !key.isEmpty,
            let host = keychain.load(key: Self.apiHostKeychainKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !host.isEmpty
        else {
            throw ExerciseDBError.missingCredentials
        }
        return Credentials(apiKey: key, host: host)
    }

    /// Issue the request (with transport retries) and return its outcome, applying rate-limit handling.
    ///
    /// On HTTP 429 the rate-limit gate is armed from `Retry-After` (or a 60s default) and the cached
    /// fallback is served when present, otherwise `rateLimited` is thrown (R5.5).
    private func requestData(
        endpoint: ExerciseDBEndpoint,
        credentials: Credentials,
        cachedFallback: [ExerciseItem]?
    ) async throws -> RequestOutcome {
        guard let url = endpoint.url(host: credentials.host) else {
            throw ExerciseDBError.network(underlying: "URL ExerciseDB tidak valid")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = Self.requestTimeout
        request.setValue(credentials.apiKey, forHTTPHeaderField: "X-RapidAPI-Key")
        request.setValue(credentials.host, forHTTPHeaderField: "X-RapidAPI-Host")

        let (data, http) = try await performWithRetry(request)

        switch http.statusCode {
        case 200..<300:
            return .data(data)
        case 429:
            let retryAfter = parseRetryAfter(http) ?? Self.defaultRetryAfter
            rateLimitedUntil = now().addingTimeInterval(retryAfter)
            if let cachedFallback, !cachedFallback.isEmpty {
                return .servedFromCache(cachedFallback)
            }
            throw ExerciseDBError.rateLimited(retryAfter: retryAfter)
        default:
            throw ExerciseDBError.network(underlying: "HTTP \(http.statusCode)")
        }
    }

    /// Perform the request, retrying transport-level failures up to `maxAttempts` times (R4.8).
    private func performWithRetry(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var lastError: Error?
        for _ in 0..<Self.maxAttempts {
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw ExerciseDBError.network(underlying: "Respons tidak valid")
                }
                return (data, http)
            } catch let error as ExerciseDBError {
                // Non-transport failures are not retried.
                throw error
            } catch {
                lastError = error
                // transport failure → retry
            }
        }
        let message = (lastError as? URLError)?.localizedDescription
            ?? lastError?.localizedDescription
            ?? "kesalahan jaringan tidak diketahui"
        if let urlError = lastError as? URLError, urlError.code == .timedOut {
            throw ExerciseDBError.timeout
        }
        throw ExerciseDBError.network(underlying: message)
    }

    /// Parse `Retry-After` as integer seconds or an HTTP date; `nil` if absent/unparseable.
    private func parseRetryAfter(_ response: HTTPURLResponse) -> TimeInterval? {
        guard let raw = response.value(forHTTPHeaderField: "Retry-After")?
            .trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        if let seconds = TimeInterval(raw) {
            return max(seconds, 0)
        }
        if let date = Self.httpDateFormatter.date(from: raw) {
            return max(date.timeIntervalSince(now()), 0)
        }
        return nil
    }

    private static let httpDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter
    }()

    // MARK: Decoding

    /// Decode `type` from `data`, mapping any failure to `ExerciseDBError.decoding` (R4.3).
    ///
    /// Decoding happens before any cache write, so a decode failure can never leave partial data in
    /// the cache.
    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw ExerciseDBError.decoding
        }
    }

    // MARK: Helpers

    /// `true` when `cachedAt` is within the TTL relative to `now` (R5.1).
    private func isFresh(_ cachedAt: Date, now: Date) -> Bool {
        now.timeIntervalSince(cachedAt) <= Self.ttl
    }

    /// Slice `entries` into the requested page, clamping `limit` to `1...50` (R18.7).
    private func paginate(_ entries: [CachedExerciseRecord], offset: Int, limit: Int) -> [CachedExerciseRecord] {
        let clampedLimit = min(max(limit, 1), ExerciseDBEndpoint.maxLimit)
        let start = max(offset, 0)
        guard start < entries.count else { return [] }
        let end = min(start + clampedLimit, entries.count)
        return Array(entries[start..<end])
    }
}
