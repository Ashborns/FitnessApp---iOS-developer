import Foundation

// MARK: - ExerciseDetailViewModel
// Requirements: 10.4, 10.6, 10.7, 10.8, 15.1, 15.2
//
// One ViewModel per screen (design §6.2 Detail_Screen). Holds the displayed
// `ExerciseItem` and drives the three Detail_Screen actions:
//  - "Tambah ke rutinitas": append exactly one RoutineItem referencing this
//    exercise to the routine currently being built, creating a new Routine
//    first if none exists (R10.6/10.7) via `RoutineRepositoring`.
//  - "Buka Camera Coaching": open Camera_Coaching with this exercise
//    pre-selected (R10.4) — only when the exercise maps to a supported
//    `ExerciseType`.
//  - "Tanya AI Coach": build a `ChatSeed` from the exercise context so the AI
//    Coach opens with the prompt pre-filled (R10.8/15.1/15.2).

/// Presentation logic for the Enriched Exercise Detail screen.
@MainActor
final class ExerciseDetailViewModel: ObservableObject {

    // MARK: - State

    /// The exercise being displayed on the Detail_Screen.
    let item: ExerciseItem

    /// True briefly after an exercise is successfully added to a routine so the
    /// View can surface a confirmation (R10.6: confirmation within 1 second).
    /// Auto-resets after ~1 second.
    @Published private(set) var showRoutineConfirmation: Bool = false

    /// User-facing error message when adding to a routine fails. `nil` when
    /// there is no error to present.
    @Published private(set) var errorMessage: String?

    // MARK: - Dependencies

    private let routineRepository: RoutineRepositoring

    /// The routine currently being built across repeated "tambah ke rutinitas"
    /// taps within this session. `nil` until the first add creates a new
    /// Routine; thereafter its `id` identifies the persisted Routine so further
    /// adds update the same record in place rather than creating duplicates.
    private var currentDraft: RoutineDraft?

    /// Handle for the pending confirmation auto-reset so repeated adds restart
    /// the 1-second window cleanly.
    private var confirmationResetTask: Task<Void, Never>?

    // MARK: - Init

    init(
        item: ExerciseItem,
        routineRepository: RoutineRepositoring = RoutineRepository()
    ) {
        self.item = item
        self.routineRepository = routineRepository
    }

    // MARK: - Camera (R10.4 / R10.5)

    /// The camera-supported exercise type this item maps to, or `nil` when the
    /// exercise is not supported by Camera_Coaching.
    var mappedExerciseType: ExerciseType? {
        CameraExerciseMapper.map(item)
    }

    /// Whether the View should show the "open camera coaching" control.
    /// True only when the exercise maps to a supported `ExerciseType` (R10.4);
    /// false hides the control (R10.5).
    var canOpenCamera: Bool {
        mappedExerciseType != nil
    }

    /// Opens Camera_Coaching with this exercise pre-selected, but only when a
    /// supported `ExerciseType` mapping exists (R10.4). No-op otherwise.
    /// - Parameter router: The app router used to present the camera cover.
    func openCamera(router: AppRouter) {
        guard let type = mappedExerciseType else { return }
        router.openCamera(with: type)
    }

    // MARK: - Add to routine (R10.6 / R10.7)

    /// Adds exactly one `RoutineItem` referencing this exercise to the routine
    /// being built.
    ///
    /// - If no routine is currently being built, creates a new `RoutineDraft`
    ///   (with a default name) containing exactly one item, then persists it
    ///   (R10.7).
    /// - If a routine already exists in this session, appends exactly one item
    ///   referencing this exercise and re-saves the same Routine by id (R10.6).
    ///
    /// On success a confirmation flag is raised for the View (R10.6, ≤1s) and
    /// auto-reset shortly after. On failure an `errorMessage` is published.
    func addToRoutine() {
        let newItem = RoutineItemDraft(
            exerciseID: item.id,
            exerciseName: item.name
        )

        var draft = currentDraft ?? RoutineDraft(name: Self.defaultRoutineName)
        draft.items.append(newItem)

        do {
            let savedID = try routineRepository.save(draft)
            // Persist the resolved id so subsequent adds update in place.
            draft.id = savedID
            currentDraft = draft
            errorMessage = nil
            presentConfirmation()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Clears any presented error message (e.g. after the View dismisses it).
    func dismissError() {
        errorMessage = nil
    }

    // MARK: - AI Coach (R10.8 / 15.1 / 15.2)

    /// Builds the AI Coach seed carrying this exercise's context so the chat
    /// opens with the prompt pre-filled.
    func chatSeed() -> ChatSeed {
        ChatSeed(userVisiblePrompt: ExerciseContextSeeder.prompt(for: item))
    }

    // MARK: - Helpers

    /// Default name applied to a freshly created Routine when the user adds an
    /// exercise without an in-progress routine.
    private static let defaultRoutineName = "Rutinitas Baru"

    /// Raises the confirmation flag and schedules an auto-reset within ~1s.
    private func presentConfirmation() {
        showRoutineConfirmation = true
        confirmationResetTask?.cancel()
        confirmationResetTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            guard !Task.isCancelled else { return }
            self?.showRoutineConfirmation = false
        }
    }
}
