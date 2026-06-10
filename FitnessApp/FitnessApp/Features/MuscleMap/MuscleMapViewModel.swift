import Foundation

// MARK: - BodyRegion
// Requirements: 11.2, 11.8, 11.9
//
// A selectable muscle / body area on the Muscle_Map_Screen. Each region maps to
// a concrete ExerciseDB query (`bodyPart` or `target`) so tapping it can fetch the
// matching `ExerciseItem`s (R11.2). `displayName` doubles as the accessibility
// label of the tappable shape (R11.9).

/// A region of the body that can be selected on the Muscle Map screen.
///
/// Cases map to ExerciseDB `bodyPart` values, which the API uses to group
/// exercises by anatomical area. Each region exposes a human-readable
/// `displayName` and an `ExerciseDBQuery` describing how to fetch its exercises.
enum BodyRegion: String, CaseIterable, Identifiable, Hashable {
    case chest
    case back
    case shoulders
    case upperArms
    case lowerArms
    case upperLegs
    case lowerLegs
    case waist
    case neck
    case cardio

    var id: String { rawValue }

    /// Localized, user-facing name shown on the map and used as the
    /// accessibility label of the region (R11.9).
    var displayName: String {
        switch self {
        case .chest: return "Dada"
        case .back: return "Punggung"
        case .shoulders: return "Bahu"
        case .upperArms: return "Lengan Atas"
        case .lowerArms: return "Lengan Bawah"
        case .upperLegs: return "Paha"
        case .lowerLegs: return "Betis"
        case .waist: return "Perut & Pinggang"
        case .neck: return "Leher"
        case .cardio: return "Kardio"
        }
    }

    /// The ExerciseDB query used to fetch exercises for this region (R11.2).
    var query: ExerciseDBQuery {
        switch self {
        case .chest: return ExerciseDBQuery(kind: .bodyPart, value: "chest")
        case .back: return ExerciseDBQuery(kind: .bodyPart, value: "back")
        case .shoulders: return ExerciseDBQuery(kind: .bodyPart, value: "shoulders")
        case .upperArms: return ExerciseDBQuery(kind: .bodyPart, value: "upper arms")
        case .lowerArms: return ExerciseDBQuery(kind: .bodyPart, value: "lower arms")
        case .upperLegs: return ExerciseDBQuery(kind: .bodyPart, value: "upper legs")
        case .lowerLegs: return ExerciseDBQuery(kind: .bodyPart, value: "lower legs")
        case .waist: return ExerciseDBQuery(kind: .bodyPart, value: "waist")
        case .neck: return ExerciseDBQuery(kind: .bodyPart, value: "neck")
        case .cardio: return ExerciseDBQuery(kind: .bodyPart, value: "cardio")
        }
    }
}

/// Describes how to fetch exercises for a `BodyRegion`: by target muscle or by
/// body part, plus the ExerciseDB value to query for.
struct ExerciseDBQuery: Equatable, Hashable {
    enum Kind: Equatable, Hashable {
        case target
        case bodyPart
    }

    let kind: Kind
    let value: String
}

// MARK: - MuscleMapViewModel
// Requirements: 11.2, 11.4, 11.5, 11.6, 11.7, 11.8
//
// One ViewModel per screen (ObservableObject + @Published). Owns the currently
// highlighted region and the async result state for that region's exercises.
// All `@Published` mutations happen on the main actor; the actual network work
// runs off-main on the injected `ExerciseDBServicing` actor.

/// View model backing the Muscle Map screen.
///
/// Selecting a `BodyRegion` highlights it (replacing any previous highlight so
/// exactly one region is highlighted at a time — R11.8) and fetches the matching
/// exercises with a 10-second timeout (R11.2). The result is exposed as an
/// `AsyncState`: `loading` while fetching (R11.4), `empty` when there are no
/// matches (R11.5), `loaded` with the exercises, or `error` on failure/timeout
/// (R11.6) — and the selected region's highlight is preserved across an error so
/// the user can retry (R11.6, R11.7).
@MainActor
final class MuscleMapViewModel: ObservableObject {

    /// Result state for the currently selected region's exercise list.
    @Published private(set) var state: AsyncState<[ExerciseItem]> = .empty

    /// The currently highlighted region, or `nil` before any selection. Exactly
    /// one region is ever highlighted at a time (R11.8).
    @Published private(set) var selectedRegion: BodyRegion?

    /// Default request budget: 10 seconds (R11.2, R11.7).
    static let requestTimeout: TimeInterval = 10

    /// Upper bound on items requested per region; ExerciseDB pages are clamped to 50.
    static let pageLimit = 50

    private let service: ExerciseDBServicing
    private let timeout: TimeInterval
    private var fetchTask: Task<Void, Never>?

    /// Creates the view model.
    ///
    /// - Parameters:
    ///   - service: networking surface (defaults to a production `ExerciseDBService`).
    ///   - timeout: per-request budget in seconds (defaults to 10s, R11.2).
    init(
        service: ExerciseDBServicing = ExerciseDBService(cache: ExerciseMetadataCache()),
        timeout: TimeInterval = MuscleMapViewModel.requestTimeout
    ) {
        self.service = service
        self.timeout = timeout
    }

    deinit {
        fetchTask?.cancel()
    }

    /// Selects `region`, highlighting it (and removing any previous highlight so
    /// exactly one region is highlighted — R11.8) and fetching its exercises.
    func select(_ region: BodyRegion) {
        selectedRegion = region
        load(region)
    }

    /// Re-runs the fetch for the currently selected region (R11.7). No-op if no
    /// region is selected.
    func retry() {
        guard let region = selectedRegion else { return }
        load(region)
    }

    // MARK: - Private

    private func load(_ region: BodyRegion) {
        fetchTask?.cancel()
        state = .loading
        let timeout = self.timeout
        let service = self.service
        let query = region.query

        fetchTask = Task { [weak self] in
            do {
                let items = try await Self.fetch(query, service: service, timeout: timeout)
                guard !Task.isCancelled else { return }
                self?.state = items.isEmpty ? .empty : .loaded(items)
            } catch is CancellationError {
                // Superseded by a newer selection; leave state to the new request.
                return
            } catch {
                guard !Task.isCancelled else { return }
                // Preserve the highlighted region on error so the user can retry
                // the same region (R11.6, R11.7); only the result state changes.
                self?.state = .error(message: Self.message(for: error))
            }
        }
    }

    private static func fetch(
        _ query: ExerciseDBQuery,
        service: ExerciseDBServicing,
        timeout: TimeInterval
    ) async throws -> [ExerciseItem] {
        try await withTimeout(timeout) {
            switch query.kind {
            case .bodyPart:
                return try await service.fetchByBodyPart(query.value, offset: 0, limit: pageLimit)
            case .target:
                return try await service.fetchByTarget(query.value, offset: 0, limit: pageLimit)
            }
        }
    }

    private static func message(for error: Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return error.localizedDescription
    }
}

// MARK: - Timeout helper

/// Error thrown when an operation exceeds its allotted time budget.
private struct MuscleMapTimeoutError: Error {}

/// Races `operation` against a `seconds` deadline, throwing on timeout.
///
/// Cancels the losing child task once a winner is determined so no work leaks
/// past the deadline. Built on `withThrowingTaskGroup` for iOS 16 compatibility
/// (no iOS 17+ APIs).
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
            throw MuscleMapTimeoutError()
        }

        defer { group.cancelAll() }

        guard let result = try await group.next() else {
            throw MuscleMapTimeoutError()
        }
        return result
    }
}
