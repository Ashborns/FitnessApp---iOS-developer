import Foundation

// MARK: - LibraryViewModel
// Requirements: 8.1, 8.5, 8.6, 8.9, 9.1, 9.5, 9.7, 9.8, 18.7, 18.8, 19.5
//
// One ViewModel per screen (design §6.1 Library_Screen). Drives the Exercise
// Library list, search, filtering, pagination and pull-to-refresh on top of
// `ExerciseDBServicing` (cache-first networking) and the pure
// `ExerciseFilterEngine`.
//
// Key behaviours:
//  - Initial `load()` fetches one page (batch ≤50, R18.7) under a 10s timeout
//    (R8.1). Zero items → `.empty`; otherwise `.loaded` (R19.5).
//  - On failure, previously loaded data is preserved: the list stays `.loaded`
//    and an `errorMessage` is surfaced for a retry control; only a failure with
//    no data falls back to `.error` (R8.5, R8.6, R18.8).
//  - `retry()` re-runs the request keeping any existing data (R8.6).
//  - Search and filter changes are debounced ≤500ms and applied to the loaded
//    master list via `ExerciseFilterEngine` so visible results update within
//    that window (R9.1, R9.5, R9.8).
//  - `loadMore()` appends the next page (batch ≤50, R18.7); a paged failure
//    keeps already-loaded items (R18.8).
//  - `refresh()` backs pull-to-refresh under the same 10s timeout (R8.9).
//  - `searchText` and `activeFilters` are retained for the session because the
//    owning view holds this VM as a `@StateObject`, so they survive
//    back-navigation (state restoration, R9.7).

/// Presentation logic for the Exercise Library screen.
@MainActor
final class LibraryViewModel: ObservableObject {

    // MARK: - Published state

    /// Single source of truth for the list rendering: loading / loaded / empty
    /// / error (R19.5). Mutated only on the main actor.
    @Published private(set) var state: AsyncState<[ExerciseItem]> = .loading

    /// Free-text search query bound to `.searchable`. Persists for the session
    /// (R9.7). Changes should be funnelled through `searchTextChanged()`.
    @Published var searchText: String = ""

    /// Selected target / equipment / body-part filters. Persists for the
    /// session (R9.7). Changes should be funnelled through `filtersChanged()`.
    @Published var activeFilters: FilterCriteria = FilterCriteria()

    /// Non-nil when a request failed while displayable data still exists, so the
    /// View can surface an inline error + retry without discarding the list
    /// (R8.5, R8.6, R18.8).
    @Published private(set) var errorMessage: String?

    /// True while a `loadMore()` page request is in flight, so the View can show
    /// a trailing pagination spinner and avoid issuing overlapping requests.
    @Published private(set) var isLoadingMore: Bool = false

    // MARK: - Dependencies

    private let service: ExerciseDBServicing

    // MARK: - Configuration

    /// Pagination batch size. Clamped to `1...50` before every request (R18.7).
    private let pageSize: Int = 50

    /// Per-request timeout budget in seconds (R8.1, R8.6, R8.9).
    private let requestTimeout: TimeInterval = 10

    /// Debounce window for search/filter recomputation (R9.1, R9.5, R9.8).
    private let debounceNanoseconds: UInt64 = 500_000_000

    // MARK: - Internal state

    /// The full set of fetched exercises (across pages). Filtering is applied to
    /// this master list so search/filter never re-hits the network and the
    /// loaded data is preserved across failures (R18.8).
    private var masterItems: [ExerciseItem] = []

    /// Offset for the next page request (number of items already fetched).
    private var nextOffset: Int = 0

    /// Whether another page is expected. False once a short/empty page arrives.
    private var canLoadMore: Bool = true

    /// Pending debounced filter recomputation; cancelled when a newer change
    /// arrives so only the latest input is applied.
    private var filterTask: Task<Void, Never>?

    // MARK: - Init

    /// Create a Library ViewModel.
    ///
    /// - Parameter service: ExerciseDB networking surface. Defaults to a
    ///   production `ExerciseDBService` backed by the Core Data
    ///   `ExerciseMetadataCache`.
    init(service: ExerciseDBServicing = ExerciseDBService(cache: ExerciseMetadataCache())) {
        self.service = service
    }

    // MARK: - Loading

    /// Initial load: fetches the first page under a 10s timeout and renders the
    /// result (R8.1, R18.7, R19.5).
    ///
    /// Shows `.loading` only when there is no data yet; an existing list is kept
    /// visible while refetching so a failure can preserve it (R8.5/R8.6).
    func load() async {
        if masterItems.isEmpty {
            state = .loading
        }
        errorMessage = nil
        await fetchFirstPage()
    }

    /// Re-run the request after a failure, preserving any data already loaded
    /// (R8.6).
    func retry() async {
        errorMessage = nil
        await fetchFirstPage()
    }

    /// Pull-to-refresh: re-fetches the first page under the 10s timeout and
    /// replaces the master list on success, keeping old data on failure
    /// (R8.9, R8.5).
    func refresh() async {
        errorMessage = nil
        await fetchFirstPage()
    }

    /// Append the next page when more data is expected (R18.7). A failure here
    /// keeps the already-loaded items and surfaces an error (R18.8).
    func loadMore() async {
        guard canLoadMore, !isLoadingMore, !masterItems.isEmpty else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let page = try await fetchPage(offset: nextOffset)
            mergeNextPage(page)
            errorMessage = nil
            applyFilter()
        } catch {
            // Partial failure: keep loaded items visible (R18.8).
            errorMessage = message(from: error)
        }
    }

    // MARK: - Search & filter (debounced)

    /// Call from the View when the bound `searchText` changes. Debounces
    /// recomputation so visible results update within ≤500ms (R9.1, R9.5).
    func searchTextChanged() {
        scheduleDebouncedFilter()
    }

    /// Call from the View when `activeFilters` changes. Debounces recomputation
    /// so visible results update within ≤500ms (R9.5, R9.8).
    func filtersChanged() {
        scheduleDebouncedFilter()
    }

    // MARK: - Fetch pipeline

    /// Fetch and render the first page, preserving prior data on failure.
    private func fetchFirstPage() async {
        do {
            let page = try await fetchPage(offset: 0)
            masterItems = page
            nextOffset = page.count
            canLoadMore = page.count >= pageSize
            errorMessage = nil
            applyFilter()
        } catch {
            handleLoadFailure(error)
        }
    }

    /// Fetch a single page under the 10s timeout, clamping `limit` to ≤50
    /// (R8.1, R18.7).
    private func fetchPage(offset: Int) async throws -> [ExerciseItem] {
        let limit = clampedLimit(pageSize)
        let svc = service
        return try await withTimeout(seconds: requestTimeout) {
            try await svc.fetchExercises(offset: offset, limit: limit)
        }
    }

    /// Merge a freshly fetched page into the master list, de-duplicating by id
    /// while preserving order, and update pagination bookkeeping.
    private func mergeNextPage(_ page: [ExerciseItem]) {
        guard !page.isEmpty else {
            canLoadMore = false
            return
        }
        let existingIDs = Set(masterItems.map(\.id))
        let fresh = page.filter { !existingIDs.contains($0.id) }
        masterItems.append(contentsOf: fresh)
        nextOffset += page.count
        canLoadMore = page.count >= pageSize
    }

    /// Translate a load failure into state: keep the loaded list when data
    /// exists (R8.5/R18.8), otherwise show a full-screen error (R8.6, R19.5).
    private func handleLoadFailure(_ error: Error) {
        let text = message(from: error)
        if masterItems.isEmpty {
            state = .error(message: text)
        } else {
            errorMessage = text
            applyFilter()
        }
    }

    // MARK: - Filtering

    /// Schedule a debounced filter recomputation, cancelling any pending one so
    /// only the latest search/filter input is applied (R9.1, R9.5, R9.8).
    private func scheduleDebouncedFilter() {
        filterTask?.cancel()
        let delay = debounceNanoseconds
        filterTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            self?.applyFilter()
        }
    }

    /// Apply the current criteria to the master list and publish the resulting
    /// state. Pure filtering runs in-memory; only `@Published` state is mutated
    /// on the main actor.
    private func applyFilter() {
        guard !masterItems.isEmpty else {
            // Nothing loaded → empty unless a fetch is still in flight.
            if case .loading = state { return }
            state = .empty
            return
        }
        let filtered = ExerciseFilterEngine.apply(masterItems, currentCriteria())
        state = filtered.isEmpty ? .empty : .loaded(filtered)
    }

    /// Merge the live `searchText` into `activeFilters` to form the effective
    /// criteria used by `ExerciseFilterEngine`.
    private func currentCriteria() -> FilterCriteria {
        var criteria = activeFilters
        criteria.searchText = searchText
        return criteria
    }

    // MARK: - Helpers

    /// Clamp a requested page size to the supported `1...50` range (R18.7).
    private func clampedLimit(_ limit: Int) -> Int {
        min(max(limit, 1), pageSize)
    }

    /// User-facing message for a thrown error, preferring `ExerciseDBError`'s
    /// localized descriptions.
    private func message(from error: Error) -> String {
        if let dbError = error as? ExerciseDBError {
            return dbError.errorDescription ?? error.localizedDescription
        }
        return error.localizedDescription
    }

    /// Race `operation` against a timeout, throwing `ExerciseDBError.timeout`
    /// when the budget elapses first (R8.1, R8.6, R8.9).
    private func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw ExerciseDBError.timeout
            }
            guard let result = try await group.next() else {
                throw ExerciseDBError.timeout
            }
            group.cancelAll()
            return result
        }
    }
}
