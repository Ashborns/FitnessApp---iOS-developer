import SwiftUI

/// Loader for the `.exerciseDetail(exerciseID:)` route (design §3, §6.2).
///
/// `ExerciseDetailView` needs a fully-formed ``ExerciseItem``, but deep links
/// and pushed routes only carry the exercise id. This lightweight loader
/// bridges that gap: it fetches the item by id through ``ExerciseDBService``
/// (cache-first) and renders the four async states via ``AsyncStateView`` —
/// a skeleton while loading, an inline error + retry on failure, an empty
/// state when the id resolves to nothing, and `ExerciseDetailView(item:)`
/// once the item is available.
///
/// Styling uses semantic tokens only, no `AnyView`, and no iOS 17+ APIs.
struct ExerciseDetailLoaderView: View {

    let exerciseID: String

    private let service: ExerciseDBServicing
    @State private var state: AsyncState<ExerciseItem> = .loading

    /// - Parameters:
    ///   - exerciseID: The stable ExerciseDB id to resolve.
    ///   - service: Networking surface; defaults to the production
    ///     `ExerciseDBService` backed by the Core Data `ExerciseMetadataCache`.
    init(
        exerciseID: String,
        service: ExerciseDBServicing = ExerciseDBService(cache: ExerciseMetadataCache())
    ) {
        self.exerciseID = exerciseID
        self.service = service
    }

    var body: some View {
        AsyncStateView(
            state: state,
            emptyConfig: emptyConfig,
            onRetry: { Task { await load() } }
        ) { item in
            ExerciseDetailView(item: item)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.themeBackground.ignoresSafeArea())
        .navigationTitle("Latihan")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: exerciseID) { await load() }
    }

    private var emptyConfig: EmptyStateView {
        EmptyStateView(
            icon: "questionmark.circle",
            title: "Latihan tidak ditemukan",
            message: "Latihan ini tidak tersedia saat ini. Coba lagi nanti."
        )
    }

    /// Fetches the exercise by id and maps the result onto the async state.
    /// Runs on the main actor so `@Published`-style `@State` updates are safe;
    /// the heavy fetch itself happens inside the `ExerciseDBService` actor.
    @MainActor
    private func load() async {
        state = .loading
        do {
            let item = try await service.fetchExercise(id: exerciseID)
            state = .loaded(item)
        } catch {
            let message = (error as? LocalizedError)?.errorDescription
                ?? "Gagal memuat latihan. Coba lagi."
            state = .error(message: message)
        }
    }
}

#if DEBUG
struct ExerciseDetailLoaderView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ExerciseDetailLoaderView(exerciseID: "0001")
        }
        .environmentObject(AppRouter())
        .preferredColorScheme(.dark)
    }
}
#endif
