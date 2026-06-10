// PULSE — Builder_Screen
// Requirements: 12.2, 12.3, 12.4, 12.5, 13.8, 13.9, 15.3 (design section 6.4)
//
// The screen for creating / editing a Routine. It binds to a single
// `WorkoutBuilderViewModel` and provides:
//   • A name field (12.1 / 13.8).
//   • An editable list of `RoutineItem`s with per-item sets / reps / rest
//     controls (12.2 / 12.3), drag-to-reorder via `.onMove` (12.6) and
//     swipe / edit-mode delete via `.onDelete` (12.7).
//   • Validation messages that identify the offending field and its valid
//     range before a save is allowed (12.4 / 12.5 / 13.8 / 13.9).
//   • A "Tanya AI Coach" control that opens the existing `ChatView` seeded
//     with the current routine context (15.3).
//   • A Save control that persists via the ViewModel and surfaces a retryable
//     error message on failure (13.7), preserving the user's input.
//
// iOS 16.4 / Swift 5.7: token-only styling, no `AnyView`, single-parameter
// `.onChange(of:perform:)`, every interactive element has a non-empty
// accessibility label and identifier.

import SwiftUI

struct WorkoutBuilderView: View {

    // MARK: Dependencies

    @StateObject private var viewModel: WorkoutBuilderViewModel

    // MARK: Local UI state

    @State private var isPresentingCoach = false
    @Environment(\.dismiss) private var dismiss

    // MARK: Init

    /// Builds a builder for a new Routine, or for editing an existing Routine
    /// when `routineID` is supplied.
    init(routineID: UUID? = nil) {
        _viewModel = StateObject(wrappedValue: WorkoutBuilderViewModel(routineID: routineID))
    }

    // MARK: Body

    var body: some View {
        List {
            nameSection
            itemsSection
            validationSection
            actionsSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.themeBackground.ignoresSafeArea())
        .navigationTitle("Buat Rutinitas")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
                    .accessibilityLabel("Ubah daftar latihan")
                    .accessibilityIdentifier("workoutBuilder.editButton")
            }
        }
        .fullScreenCover(isPresented: $isPresentingCoach) {
            ChatView(seed: viewModel.chatSeed())
        }
        .onChange(of: viewModel.savedRoutineID) { savedID in
            // Dismiss once the Routine has been persisted successfully (13.1).
            if savedID != nil { dismiss() }
        }
    }

    // MARK: - Name (12.1 / 13.8)

    @ViewBuilder
    private var nameSection: some View {
        Section {
            TextField("Nama rutinitas", text: $viewModel.draft.name)
                .font(.body)
                .foregroundColor(.primary)
                .textInputAutocapitalization(.words)
                .accessibilityLabel("Nama rutinitas")
                .accessibilityIdentifier("workoutBuilder.nameField")
                .listRowBackground(Color.themeSurface)
        } header: {
            SectionHeader(title: "Nama")
        }
    }

    // MARK: - Items (12.2 / 12.3 / 12.6 / 12.7)

    @ViewBuilder
    private var itemsSection: some View {
        Section {
            if viewModel.draft.items.isEmpty {
                Text("Belum ada latihan. Tambahkan latihan dari pustaka untuk mulai menyusun rutinitas.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("workoutBuilder.emptyItemsHint")
                    .listRowBackground(Color.themeSurface)
            } else {
                ForEach(viewModel.draft.items) { item in
                    itemRow(for: item)
                        .listRowBackground(Color.themeSurface)
                }
                .onMove { source, destination in
                    viewModel.moveItems(from: source, to: destination)
                }
                .onDelete { offsets in
                    viewModel.deleteItems(at: offsets)
                }
            }
        } header: {
            SectionHeader(title: "Latihan")
        }
    }

    @ViewBuilder
    private func itemRow(for item: RoutineItemDraft) -> some View {
        // Resolve a descriptive name once so every per-item control keeps a
        // non-empty, meaningful label even when `exerciseName` is empty (R17.1 / R17.6).
        let displayName = AccessibilityLabel.resolve(item.exerciseName, fallback: "Latihan")
        VStack(alignment: .leading, spacing: .spacingMedium) {
            Text(item.exerciseName.isEmpty ? "Latihan" : item.exerciseName)
                .font(.headline)
                .foregroundColor(.primary)

            Stepper(
                "Set: \(item.sets)",
                value: setsBinding(for: item)
            )
            .accessibilityLabel("Jumlah set untuk \(displayName)")
            .accessibilityIdentifier("workoutBuilder.item.\(item.id.uuidString).sets")

            Stepper(
                "Repetisi: \(item.reps)",
                value: repsBinding(for: item)
            )
            .accessibilityLabel("Jumlah repetisi untuk \(displayName)")
            .accessibilityIdentifier("workoutBuilder.item.\(item.id.uuidString).reps")

            Stepper(
                "Istirahat: \(item.restSeconds) detik",
                value: restBinding(for: item),
                step: 5
            )
            .accessibilityLabel("Waktu istirahat untuk \(displayName)")
            .accessibilityIdentifier("workoutBuilder.item.\(item.id.uuidString).rest")
        }
        .padding(.vertical, .spacingSmall)
    }

    // MARK: - Validation messages (12.4 / 12.5 / 13.8 / 13.9)

    @ViewBuilder
    private var validationSection: some View {
        if !viewModel.validationErrors.isEmpty || viewModel.errorMessage != nil {
            Section {
                PulseCard {
                    VStack(alignment: .leading, spacing: .spacingMedium) {
                        ForEach(Array(viewModel.validationErrors.enumerated()), id: \.offset) { _, error in
                            validationRow(message: message(for: error))
                        }
                        if let errorMessage = viewModel.errorMessage {
                            validationRow(message: errorMessage)
                        }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
    }

    @ViewBuilder
    private func validationRow(message: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: .spacingSmall) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.themeError)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.themeError)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
        .accessibilityIdentifier("workoutBuilder.validationMessage")
    }

    // MARK: - Actions (13.7 / 15.3)

    @ViewBuilder
    private var actionsSection: some View {
        Section {
            VStack(spacing: .spacingLarge) {
                PrimaryButton(
                    title: viewModel.isSaving ? "Menyimpan…" : "Simpan Rutinitas",
                    isEnabled: !viewModel.isSaving,
                    label: "Simpan rutinitas",
                    identifier: "workoutBuilder.saveButton"
                ) {
                    Task { await viewModel.save() }
                }

                SecondaryButton(
                    title: "Tanya AI Coach",
                    isEnabled: !viewModel.isSaving,
                    label: "Tanya AI Coach tentang rutinitas ini",
                    identifier: "workoutBuilder.askCoachButton"
                ) {
                    isPresentingCoach = true
                }
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
    }

    // MARK: - Item value bindings

    /// Live binding for an item's sets that reads the current ViewModel state by
    /// id and writes back through `updateItem(id:sets:)`. No clamping is applied
    /// here so out-of-range values surface as validation messages (12.4 / 12.5).
    private func setsBinding(for item: RoutineItemDraft) -> Binding<Int> {
        Binding(
            get: { currentItem(item.id)?.sets ?? item.sets },
            set: { viewModel.updateItem(id: item.id, sets: $0) }
        )
    }

    private func repsBinding(for item: RoutineItemDraft) -> Binding<Int> {
        Binding(
            get: { currentItem(item.id)?.reps ?? item.reps },
            set: { viewModel.updateItem(id: item.id, reps: $0) }
        )
    }

    private func restBinding(for item: RoutineItemDraft) -> Binding<Int> {
        Binding(
            get: { currentItem(item.id)?.restSeconds ?? item.restSeconds },
            set: { viewModel.updateItem(id: item.id, restSeconds: $0) }
        )
    }

    private func currentItem(_ id: UUID) -> RoutineItemDraft? {
        viewModel.draft.items.first(where: { $0.id == id })
    }

    // MARK: - Validation message mapping (12.4 / 12.5 / 13.8 / 13.9)

    /// Maps a `RoutineValidator.ValidationError` to a user-facing message that
    /// names the offending field and its valid range, using the validator's
    /// single source-of-truth range constants.
    private func message(for error: RoutineValidator.ValidationError) -> String {
        switch error {
        case .emptyName:
            let range = RoutineValidator.nameLength
            return "Nama wajib diisi (\(range.lowerBound)–\(range.upperBound) karakter)."
        case .noItems:
            return "Tambahkan minimal satu latihan."
        case .setsOutOfRange(let index):
            let range = RoutineValidator.setsRange
            return "Latihan \(index + 1): Sets harus \(range.lowerBound)–\(range.upperBound)."
        case .repsOutOfRange(let index):
            let range = RoutineValidator.repsRange
            return "Latihan \(index + 1): Repetisi harus \(range.lowerBound)–\(range.upperBound)."
        case .restOutOfRange(let index):
            let range = RoutineValidator.restRange
            return "Latihan \(index + 1): Istirahat harus \(range.lowerBound)–\(range.upperBound) detik."
        }
    }
}

#if DEBUG
struct WorkoutBuilderView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            WorkoutBuilderView()
        }
        .preferredColorScheme(.dark)
    }
}
#endif
