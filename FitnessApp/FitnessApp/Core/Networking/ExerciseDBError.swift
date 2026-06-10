import Foundation

/// Errors surfaced by the ExerciseDB networking/caching layer.
///
/// `ExerciseDBError` is a closed set of failure cases produced by `ExerciseDB_Service` and its
/// supporting pieces. It conforms to `LocalizedError` so each case provides a descriptive,
/// user-presentable message (R4.3, R4.7, R5.3, R5.5), and to `Equatable` so call sites and tests
/// can compare failures precisely (including the associated `retryAfter`/`underlying` payloads).
///
/// Cases:
/// - `missingCredentials`: API key/host absent from `KeychainWrapper`; no network request is made (R4.7).
/// - `offlineNoCache`: device is offline and the requested data is not present in `Exercise_Cache` (R5.3).
/// - `rateLimited(retryAfter:)`: ExerciseDB responded with HTTP 429; `retryAfter` carries the cooldown
///   in seconds when provided by the response (R5.5).
/// - `network(underlying:)`: a transport-level failure persisted after the retry budget was exhausted (R4.8).
/// - `decoding`: the response could not be decoded into `ExerciseItem`; no partial data is cached (R4.3).
/// - `timeout`: the request exceeded its configured time budget.
enum ExerciseDBError: LocalizedError, Equatable {
    /// API credentials (key/host) are not available in secure storage.
    case missingCredentials
    /// The device is offline and no cached data exists for the request.
    case offlineNoCache
    /// The API rate limit was hit (HTTP 429). `retryAfter` is the cooldown in seconds, if known.
    case rateLimited(retryAfter: TimeInterval?)
    /// A transport-level error that persisted after retries. `underlying` is a description for diagnostics.
    case network(underlying: String)
    /// The response payload could not be decoded into `ExerciseItem`.
    case decoding
    /// The request exceeded its time budget.
    case timeout

    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "Kredensial ExerciseDB belum diatur. Tambahkan API key di pengaturan untuk memuat latihan."
        case .offlineNoCache:
            return "Tidak ada koneksi internet dan data latihan belum tersimpan. Sambungkan ke jaringan lalu coba lagi."
        case let .rateLimited(retryAfter):
            if let retryAfter, retryAfter > 0 {
                let seconds = Int(retryAfter.rounded())
                return "Batas permintaan ExerciseDB terlampaui. Coba lagi dalam \(seconds) detik."
            }
            return "Batas permintaan ExerciseDB terlampaui. Coba lagi nanti."
        case let .network(underlying):
            return "Gagal terhubung ke ExerciseDB: \(underlying). Periksa koneksi Anda lalu coba lagi."
        case .decoding:
            return "Data latihan dari ExerciseDB tidak dapat dibaca. Coba lagi nanti."
        case .timeout:
            return "Permintaan ke ExerciseDB melebihi batas waktu. Periksa koneksi Anda lalu coba lagi."
        }
    }
}
