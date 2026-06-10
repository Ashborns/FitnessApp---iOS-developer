import SwiftUI

/// Muscle Map screen (`Muscle_Map_Screen`, Requirement 11).
///
/// Presents a set of selectable `BodyRegion` controls and, below them, the
/// exercises that target the currently selected region. Because a literal
/// anatomical SVG asset isn't available, the body map is rendered as a grid of
/// tappable region buttons — each is a ≥44×44 tap target whose
/// `accessibilityLabel` is the muscle name (R11.1, R11.9). The selected region
/// is highlighted with `Color.themePrimary` and additionally exposes its
/// selected state through a visible text badge plus `accessibilityValue`, so the
/// selection is never conveyed by color alone (R11.8, R17.2).
///
/// Selecting a region fetches its exercises through `MuscleMapViewModel` and the
/// result is rendered with the shared `AsyncStateView`
/// (loading / empty / error / loaded — R11.4–R11.7). Tapping a result navigates
/// to the exercise detail route via `AppRouter` (R11.3).
struct MuscleMapView: View {

    @StateObject private var viewModel = MuscleMapViewModel()
    @EnvironmentObject private var router: AppRouter

    /// Adaptive grid for the region buttons; each cell is at least 44pt wide so
    /// the buttons keep a ≥44×44 tap target on every device size (R11.1).
    private let regionColumns = [
        GridItem(.adaptive(minimum: 120), spacing: .spacingMedium)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .spacingExtraLarge) {
                regionSelector
                resultsSection
            }
            .padding(.spacingLarge)
        }
        .background(Color.themeBackground.ignoresSafeArea())
        .navigationTitle("Peta Otot")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Region selector

    @ViewBuilder
    private var regionSelector: some View {
        VStack(alignment: .leading, spacing: .spacingMedium) {
            Text("Pilih Area Otot")
                .font(.headline.weight(.semibold))
                .foregroundColor(.primary)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: regionColumns, spacing: .spacingMedium) {
                ForEach(BodyRegion.allCases) { region in
                    RegionButton(
                        region: region,
                        isSelected: viewModel.selectedRegion == region,
                        onTap: { viewModel.select(region) }
                    )
                }
            }
        }
    }

    // MARK: - Results

    @ViewBuilder
    private var resultsSection: some View {
        AsyncStateView(
            state: viewModel.state,
            emptyConfig: emptyConfig,
            onRetry: { viewModel.retry() }
        ) { items in
            LazyVStack(spacing: .spacingMedium) {
                ForEach(items) { item in
                    Button {
                        router.navigate(to: .exerciseDetail(exerciseID: item.id))
                    } label: {
                        ExerciseListRow(
                            item: item,
                            thumbnail: {
                                ExerciseAsyncImage(url: URL(string: item.gifUrl))
                            },
                            label: muscleMapRowLabel(for: item),
                            identifier: "muscleMap.row.\(item.id)"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// Builds a guaranteed non-empty, descriptive label for a result row even
    /// when an item's name or target arrives empty/dynamic (R17.1 / R17.6).
    private func muscleMapRowLabel(for item: ExerciseItem) -> String {
        let name = AccessibilityLabel.resolve(item.name, fallback: "Latihan")
        let target = item.target.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = target.isEmpty ? name : "\(name), target \(target)"
        return AccessibilityLabel.resolve(candidate, fallback: "Latihan")
    }

    /// Empty-state shown before any region is picked and when a region has no
    /// matching exercises (R11.5).
    private var emptyConfig: EmptyStateView {
        EmptyStateView(
            icon: "figure.run.circle",
            title: "Belum ada latihan",
            message: "Pilih area otot di atas untuk melihat latihan yang menargetkannya."
        )
    }
}

// MARK: - RegionButton

/// A single tappable body-region control.
///
/// Guarantees a ≥44×44 tap target (R11.1) and a non-empty `accessibilityLabel`
/// equal to the muscle name (R11.9). When selected it fills with
/// `Color.themePrimary` (R11.8) and shows a checkmark plus an
/// `accessibilityValue` ("dipilih" / "tidak dipilih") so the selected state is
/// also conveyed by text/shape, not color alone (R17.2).
private struct RegionButton: View {

    let region: BodyRegion
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: .spacingSmall) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                }
                Text(region.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, .spacingLarge)
            .padding(.vertical, .spacingMedium)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: .cornerRadiusSmall, style: .continuous)
                    .fill(isSelected ? Color.themePrimary : Color.themeSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: .cornerRadiusSmall, style: .continuous)
                    .stroke(Color.themeBorder, lineWidth: isSelected ? 0 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(region.displayName)
        .accessibilityValue(isSelected ? "dipilih" : "tidak dipilih")
        .accessibilityIdentifier("muscleMap.region.\(region.rawValue)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

#if DEBUG
struct MuscleMapView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            MuscleMapView()
        }
        .environmentObject(AppRouter())
        .preferredColorScheme(.dark)
    }
}
#endif
