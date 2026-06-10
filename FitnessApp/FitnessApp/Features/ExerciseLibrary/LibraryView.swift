import SwiftUI

/// Exercise Library screen (design §6.1, Library_Screen).
///
/// Renders the cache-first exercise catalogue as a lazy `List` of
/// ``ExerciseListRow`` driven by ``LibraryViewModel``. Behaviour:
///
/// - Lazy list of rows, each with an async-loading thumbnail (R8.3, R18.1).
/// - `.searchable` free-text query bound to the ViewModel, debounced through
///   `searchTextChanged()` (R9.2).
/// - Filter chips for target / equipment / body part; toggling updates
///   `activeFilters` then calls `filtersChanged()` (R9.2).
/// - `.refreshable` pull-to-refresh (R8.9).
/// - All four async states routed through ``AsyncStateView``: a ≥6-row skeleton
///   while loading (R8.4), ``EmptyStateView`` when there are no matches
///   (R8.7, R9.6), and an inline error + retry that preserves loaded data
///   (R8.5).
/// - Tapping a row pushes `exerciseDetail` via ``AppRouter`` (R8.8, R3.3).
///
/// Styling uses semantic tokens only, no `AnyView`, and no iOS 17+ APIs.
struct LibraryView: View {

    @StateObject private var viewModel = LibraryViewModel()
    @EnvironmentObject private var router: AppRouter

    /// Accumulated, de-duplicated filter option values observed across loads.
    /// Kept locally so selecting a filter (which narrows the loaded list) never
    /// makes the other chips disappear.
    @State private var availableTargets: [String] = []
    @State private var availableEquipment: [String] = []
    @State private var availableBodyParts: [String] = []

    var body: some View {
        VStack(spacing: 0) {
            filterChips
            AsyncStateView(
                state: viewModel.state,
                emptyConfig: emptyConfig,
                onRetry: { Task { await viewModel.retry() } }
            ) { items in
                exerciseList(items)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.themeBackground.ignoresSafeArea())
        .navigationTitle("Latihan")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $viewModel.searchText, prompt: "Cari latihan")
        .onChange(of: viewModel.searchText) { _ in
            viewModel.searchTextChanged()
        }
        .onChange(of: viewModel.state) { newState in
            updateFilterOptions(from: newState)
        }
        .task { await viewModel.load() }
    }

    // MARK: - Loaded list

    @ViewBuilder
    private func exerciseList(_ items: [ExerciseItem]) -> some View {
        List {
            ForEach(items) { item in
                Button {
                    router.navigate(to: .exerciseDetail(exerciseID: item.id))
                } label: {
                    ExerciseListRow(
                        item: item,
                        thumbnail: {
                            ExerciseAsyncImage(url: URL(string: item.gifUrl))
                        },
                        label: rowLabel(for: item),
                        identifier: "exercise.row.\(item.id)"
                    )
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.themeBackground)
                .listRowSeparator(.hidden)
                .onAppear {
                    if item == items.last {
                        Task { await viewModel.loadMore() }
                    }
                }
            }

            if viewModel.isLoadingMore {
                HStack {
                    Spacer(minLength: 0)
                    ProgressView()
                        .tint(.themePrimary)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, .spacingMedium)
                .listRowBackground(Color.themeBackground)
                .listRowSeparator(.hidden)
                .accessibilityLabel("Memuat latihan lainnya")
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { await viewModel.refresh() }
    }

    private func rowLabel(for item: ExerciseItem) -> String {
        // Guarantee a non-empty, descriptive label even when an item's name or
        // target arrives empty/dynamic from the data source (R17.1 / R17.6).
        let name = AccessibilityLabel.resolve(item.name, fallback: "Latihan")
        let target = item.target.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = target.isEmpty ? name : "\(name), target \(target)"
        return AccessibilityLabel.resolve(candidate, fallback: "Latihan")
    }

    // MARK: - Filter chips

    @ViewBuilder
    private var filterChips: some View {
        if hasFilterOptions {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: .spacingMedium) {
                    chipGroup(
                        values: availableTargets,
                        selected: viewModel.activeFilters.targets,
                        category: "target",
                        toggle: toggleTarget
                    )
                    chipGroup(
                        values: availableEquipment,
                        selected: viewModel.activeFilters.equipment,
                        category: "equipment",
                        toggle: toggleEquipment
                    )
                    chipGroup(
                        values: availableBodyParts,
                        selected: viewModel.activeFilters.bodyParts,
                        category: "bodyPart",
                        toggle: toggleBodyPart
                    )
                }
                .padding(.horizontal, .spacingLarge)
                .padding(.vertical, .spacingMedium)
            }
        }
    }

    @ViewBuilder
    private func chipGroup(
        values: [String],
        selected: Set<String>,
        category: String,
        toggle: @escaping (String) -> Void
    ) -> some View {
        ForEach(values, id: \.self) { value in
            let isSelected = selected.contains(value)
            FilterChip(
                title: value.capitalized,
                isSelected: isSelected,
                label: "Filter \(category) \(value)",
                identifier: "filter.chip.\(category).\(value)",
                onTap: { toggle(value) }
            )
        }
    }

    // MARK: - Filter toggling

    private func toggleTarget(_ value: String) {
        toggle(value, in: \LibraryViewModel.activeFilters.targets)
    }

    private func toggleEquipment(_ value: String) {
        toggle(value, in: \LibraryViewModel.activeFilters.equipment)
    }

    private func toggleBodyPart(_ value: String) {
        toggle(value, in: \LibraryViewModel.activeFilters.bodyParts)
    }

    private func toggle(_ value: String, in keyPath: ReferenceWritableKeyPath<LibraryViewModel, Set<String>>) {
        if viewModel[keyPath: keyPath].contains(value) {
            viewModel[keyPath: keyPath].remove(value)
        } else {
            viewModel[keyPath: keyPath].insert(value)
        }
        viewModel.filtersChanged()
    }

    // MARK: - Filter option accumulation

    private var hasFilterOptions: Bool {
        !(availableTargets.isEmpty && availableEquipment.isEmpty && availableBodyParts.isEmpty)
    }

    /// Merge any newly loaded items' distinct category values into the local
    /// option lists so chips stay stable as filters narrow the visible list.
    private func updateFilterOptions(from state: AsyncState<[ExerciseItem]>) {
        guard case .loaded(let items) = state else { return }
        availableTargets = mergedOptions(availableTargets, items.map(\.target))
        availableEquipment = mergedOptions(availableEquipment, items.map(\.equipment))
        availableBodyParts = mergedOptions(availableBodyParts, items.map(\.bodyPart))
    }

    private func mergedOptions(_ existing: [String], _ incoming: [String]) -> [String] {
        var seen = Set(existing)
        var result = existing
        for value in incoming where !value.isEmpty && !seen.contains(value) {
            seen.insert(value)
            result.append(value)
        }
        return result.sorted()
    }

    // MARK: - Empty state

    private var emptyConfig: EmptyStateView {
        EmptyStateView(
            icon: "magnifyingglass",
            title: "Tidak ada latihan",
            message: "Coba ubah kata pencarian atau filter yang aktif."
        )
    }
}

#if DEBUG
struct LibraryView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            LibraryView()
        }
        .environmentObject(AppRouter())
        .preferredColorScheme(.dark)
    }
}
#endif
