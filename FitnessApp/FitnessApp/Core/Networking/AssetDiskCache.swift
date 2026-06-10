import Foundation
import CryptoKit

/// On-disk LRU cache for ExerciseDB demo GIF/image assets (`AssetDiskCache`).
///
/// Assets are persisted under `Caches/exercise-assets/` so the OS may reclaim the directory under
/// disk pressure, while the cache itself enforces a hard capacity (default 200 MB) by evicting the
/// least-recently-used entries whenever a write pushes the total above the limit (R6.2, R6.3).
///
/// The cache maintains a small in-memory index keyed by a stable hash of each asset URL, tracking
/// `lastAccessed` and `sizeBytes` per entry. The index is mirrored to an `index.json` sidecar so
/// access ordering survives app launches; if the sidecar is missing or unreadable it is rebuilt
/// from the directory contents on demand.
///
/// Declared as an `actor` so concurrent loaders can read/write safely without data races. All file
/// system interaction is failure-tolerant: read/write/delete errors degrade gracefully (return
/// `nil`, skip the write/evict) and never trap, so a misbehaving disk cannot crash the app.
///
/// Both the capacity and backing directory are injectable to keep the type deterministic and
/// unit-/property-testable in isolation.
actor AssetDiskCache {

    /// Per-asset bookkeeping used to drive LRU eviction.
    private struct IndexEntry: Codable, Equatable {
        /// Filename (stable hash of the source URL) stored inside `directory`.
        var fileName: String
        /// Size of the on-disk asset in bytes.
        var sizeBytes: Int
        /// Last time the asset was read or written; oldest entries are evicted first.
        var lastAccessed: Date
    }

    /// Hard capacity in bytes. Once a write pushes the total above this, LRU eviction runs until
    /// the total is back below the limit.
    private let capacityBytes: Int

    /// Directory backing the cache (e.g. `Caches/exercise-assets/`).
    private let directory: URL

    /// Location of the persisted index sidecar.
    private let indexURL: URL

    private let fileManager: FileManager

    /// In-memory index keyed by the stable cache key (hash of the asset URL).
    private var index: [String: IndexEntry]

    /// Creates a disk cache.
    ///
    /// - Parameters:
    ///   - capacityBytes: Maximum total size in bytes before LRU eviction kicks in. Defaults to
    ///     200 MB (`200 * 1024 * 1024`).
    ///   - directory: Backing directory. Defaults to `Caches/exercise-assets/`.
    ///   - fileManager: Injected `FileManager` for testability. Defaults to `.default`.
    init(
        capacityBytes: Int = 200 * 1024 * 1024,
        directory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.capacityBytes = max(0, capacityBytes)
        self.fileManager = fileManager

        let resolvedDirectory = AssetDiskCache.resolveDirectory(directory, fileManager: fileManager)
        self.directory = resolvedDirectory
        self.indexURL = resolvedDirectory.appendingPathComponent("index.json")

        // Ensure the directory exists; ignore failures (handled lazily on each write).
        try? fileManager.createDirectory(at: resolvedDirectory, withIntermediateDirectories: true)

        self.index = AssetDiskCache.loadIndex(at: indexURL, fileManager: fileManager)
    }

    // MARK: - Public API

    /// Returns the cached asset for `url`, updating its `lastAccessed` timestamp (R6.2).
    ///
    /// Returns `nil` when the asset is not cached or cannot be read. A successful read keeps the
    /// entry "fresh" so it survives LRU eviction longer.
    func data(for url: URL) -> Data? {
        let key = AssetDiskCache.key(for: url)
        guard var entry = index[key] else { return nil }

        let fileURL = directory.appendingPathComponent(entry.fileName)
        guard let data = try? Data(contentsOf: fileURL) else {
            // The index references a file that no longer exists or is unreadable; drop the stale
            // entry so the index stays consistent with disk.
            index[key] = nil
            persistIndex()
            return nil
        }

        entry.lastAccessed = Date()
        index[key] = entry
        persistIndex()
        return data
    }

    /// Writes `data` for `url` to disk and evicts least-recently-used entries until the total size
    /// is back below capacity (R6.2, R6.3).
    ///
    /// A write failure is swallowed (the cache simply will not contain the asset) so callers never
    /// crash on disk errors.
    func store(_ data: Data, for url: URL) {
        let key = AssetDiskCache.key(for: url)
        let fileName = key
        let fileURL = directory.appendingPathComponent(fileName)

        // Make sure the directory still exists (it can be purged by the OS at any time).
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Could not persist the asset; leave the index unchanged.
            return
        }

        index[key] = IndexEntry(
            fileName: fileName,
            sizeBytes: data.count,
            lastAccessed: Date()
        )

        evictLRUIfNeeded()
        persistIndex()
    }

    /// Total size in bytes of all cached assets according to the index.
    func totalSize() -> Int {
        index.values.reduce(0) { $0 + $1.sizeBytes }
    }

    /// Removes every cached asset and clears the index. Best-effort; ignores file system errors.
    func clear() {
        for entry in index.values {
            let fileURL = directory.appendingPathComponent(entry.fileName)
            try? fileManager.removeItem(at: fileURL)
        }
        index.removeAll()
        persistIndex()
    }

    // MARK: - Eviction

    /// Evicts the least-recently-used entries until the total size is strictly below capacity.
    private func evictLRUIfNeeded() {
        guard capacityBytes > 0 else {
            // A zero capacity means nothing may be retained.
            clearAllFilesForZeroCapacity()
            return
        }

        var total = totalSize()
        guard total > capacityBytes else { return }

        // Order entries oldest-first so we evict the least-recently-used asset each iteration.
        let lruOrder = index
            .sorted { $0.value.lastAccessed < $1.value.lastAccessed }
            .map { $0.key }

        for key in lruOrder {
            guard total > capacityBytes else { break }
            guard let entry = index[key] else { continue }

            let fileURL = directory.appendingPathComponent(entry.fileName)
            try? fileManager.removeItem(at: fileURL)
            index[key] = nil
            total -= entry.sizeBytes
        }
    }

    /// Helper for the degenerate zero-capacity case: nothing may be retained on disk.
    private func clearAllFilesForZeroCapacity() {
        for entry in index.values {
            let fileURL = directory.appendingPathComponent(entry.fileName)
            try? fileManager.removeItem(at: fileURL)
        }
        index.removeAll()
    }

    // MARK: - Index persistence

    /// Mirrors the in-memory index to the `index.json` sidecar. Best-effort; ignores write errors.
    private func persistIndex() {
        guard let data = try? JSONEncoder().encode(index) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    // MARK: - Static helpers

    /// Resolves the backing directory, defaulting to `Caches/exercise-assets/`.
    private static func resolveDirectory(_ directory: URL?, fileManager: FileManager) -> URL {
        if let directory { return directory }

        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return caches.appendingPathComponent("exercise-assets", isDirectory: true)
    }

    /// Loads the persisted index, returning an empty index when the sidecar is absent or invalid.
    private static func loadIndex(at indexURL: URL, fileManager: FileManager) -> [String: IndexEntry] {
        guard
            let data = try? Data(contentsOf: indexURL),
            let decoded = try? JSONDecoder().decode([String: IndexEntry].self, from: data)
        else {
            return [:]
        }
        return decoded
    }

    /// Derives a stable, filesystem-safe cache key for an asset URL.
    ///
    /// Uses a SHA-256 hex digest so the same URL always maps to the same filename across launches
    /// (unlike `Hashable`, which is randomized per process).
    private static func key(for url: URL) -> String {
        let source = Data(url.absoluteString.utf8)
        let digest = SHA256.hash(data: source)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
