import Foundation

/// Describes an ExerciseDB API endpoint and builds its request URL from a host.
///
/// `ExerciseDBEndpoint` is a pure value type that encapsulates the host/path/query construction for
/// the ExerciseDB API. The host is supplied by the caller (read from `KeychainWrapper` by
/// `ExerciseDB_Service`) so the endpoint stays free of credential/storage concerns and is trivially
/// testable in isolation.
///
/// Pagination (`offset`/`limit`) is normalised on construction: `limit` is clamped to
/// `1...maxLimit` (≤ 50, per R18.7) and `offset` is clamped to `>= 0`, guaranteeing that any URL the
/// endpoint produces carries a valid page window regardless of caller input.
enum ExerciseDBEndpoint: Equatable {
    /// Fetch a page of all exercises.
    case allExercises(offset: Int, limit: Int)
    /// Fetch a single exercise by its stable id.
    case exercise(id: String)
    /// Fetch a page of exercises for a given body part.
    case byBodyPart(String, offset: Int, limit: Int)
    /// Fetch a page of exercises for a given target muscle.
    case byTarget(String, offset: Int, limit: Int)

    /// Scheme used for every ExerciseDB request.
    static let scheme = "https"

    /// Maximum number of items requested per page. Pagination limits are clamped to this value (R18.7).
    static let maxLimit = 50

    /// Clamps a requested page size into the valid `1...maxLimit` window.
    static func clampLimit(_ limit: Int) -> Int {
        min(max(limit, 1), maxLimit)
    }

    /// Clamps a requested offset into the valid `>= 0` range.
    static func clampOffset(_ offset: Int) -> Int {
        max(offset, 0)
    }

    /// Path component for the endpoint (no host, no query).
    var path: String {
        switch self {
        case .allExercises:
            return "/exercises"
        case let .exercise(id):
            return "/exercises/exercise/\(id)"
        case let .byBodyPart(bodyPart, _, _):
            return "/exercises/bodyPart/\(bodyPart)"
        case let .byTarget(target, _, _):
            return "/exercises/target/\(target)"
        }
    }

    /// Query items for the endpoint, with pagination clamped to valid ranges.
    /// Returns an empty array for endpoints that take no query (e.g. single-exercise lookup).
    var queryItems: [URLQueryItem] {
        switch self {
        case let .allExercises(offset, limit),
             let .byBodyPart(_, offset, limit),
             let .byTarget(_, offset, limit):
            return [
                URLQueryItem(name: "offset", value: String(Self.clampOffset(offset))),
                URLQueryItem(name: "limit", value: String(Self.clampLimit(limit)))
            ]
        case .exercise:
            return []
        }
    }

    /// Builds the absolute request URL for this endpoint against the supplied host.
    ///
    /// - Parameter host: API host (e.g. `exercisedb.p.rapidapi.com`), typically read from `KeychainWrapper`.
    /// - Returns: A fully-formed `https` URL, or `nil` if the host is blank or the URL cannot be composed.
    func url(host: String) -> URL? {
        let trimmedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHost.isEmpty else { return nil }

        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = trimmedHost
        // `percentEncodedPath` would require pre-encoding; assigning to `path` lets URLComponents
        // encode path segments (e.g. body part / target names) for us.
        components.path = path

        let items = queryItems
        components.queryItems = items.isEmpty ? nil : items

        return components.url
    }
}
