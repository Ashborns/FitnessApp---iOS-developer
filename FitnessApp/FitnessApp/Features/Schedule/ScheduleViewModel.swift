import Foundation

// MARK: - ScheduleViewModel
// Requirements: 14.1, 14.2, 14.3, 14.4, 14.5, 14.7
//
// One ViewModel per screen (design §6.5 Schedule_Screen). Drives the calendar
// markers, the per-day scheduled-workout list, and create/delete operations on
// top of `ScheduleRepositoring`, with routine listing for the "add schedule"
// flow provided by `RoutineRepositoring`.
//
// Key behaviours:
//  - `loadMonth(_:)` populates `markedDates` from
//    `repository.datesWithWorkouts(in:)` so the calendar can mark any day with
//    ≥1 scheduled workout (R14.1).
//  - `selectDate(_:)` loads that day's entries, resolving each snapshot to its
//    Routine via `repository.resolve`; the list is sorted by time ascending
//    (R14.3). A day with no entries is `.empty` (the View shows the add CTA,
//    R14.6).
//  - A dangling reference (the Routine was deleted) resolves to `nil` and is
//    surfaced as an entry titled "Routine tidak lagi tersedia" that can still
//    be safely removed (R14.5).
//  - `schedule(routineID:on:)` creates a `ScheduledWorkout` and refreshes; on
//    failure it surfaces `errorMessage` and preserves the current view (R14.2,
//    R14.7).
//  - `deleteEntry(id:)` removes only the schedule entry, leaving the Routine
//    intact (R14.4); it also safely removes dangling entries (R14.5).

/// Presentation logic for the Schedule screen.
@MainActor
final class ScheduleViewModel: ObservableObject {

    // MARK: - ScheduledEntry

    /// A view-model row wrapping a persisted `ScheduledWorkoutSnapshot` together
    /// with its resolved `RoutineSnapshot`. A `nil` routine marks a dangling
    /// reference whose Routine has been deleted (R14.5).
    struct ScheduledEntry: Equatable, Identifiable, Hashable {
        /// The schedule entry id (used for deletion). Distinct from the
        /// referenced routine id.
        let id: UUID
        let snapshot: ScheduledWorkoutSnapshot
        /// Resolved routine, or `nil` when the reference is dangling (R14.5).
        let routine: RoutineSnapshot?

        /// True when the referenced Routine no longer exists (R14.5).
        var isDangling: Bool { routine == nil }

        /// The time the workout is scheduled for; the list is sorted by this
        /// ascending (R14.3).
        var scheduledDate: Date { snapshot.scheduledDate }

        /// Display title: the routine name, or the dangling placeholder (R14.5).
        var title: String { routine?.name ?? Self.danglingTitle }

        /// User-facing label for a dangling schedule entry (R14.5).
        static let danglingTitle = "Routine tidak lagi tersedia"

        init(snapshot: ScheduledWorkoutSnapshot, routine: RoutineSnapshot?) {
            self.id = snapshot.id
            self.snapshot = snapshot
            self.routine = routine
        }
    }

    // MARK: - Published state

    /// Calendar-day starts within the visible month that have ≥1 scheduled
    /// workout, for marking the calendar (R14.1). Mutated only on the main actor.
    @Published private(set) var markedDates: Set<Date> = []

    /// The day whose schedule is shown in the list. Bound to the calendar
    /// selection; funnel changes through `selectDate(_:)`.
    @Published var selectedDate: Date

    /// Single source of truth for the per-day list: loading / loaded / empty /
    /// error. Sorted by time ascending when `.loaded` (R14.3). An empty day is
    /// `.empty` so the View can present the add CTA (R14.6).
    @Published private(set) var state: AsyncState<[ScheduledEntry]> = .loading

    /// Routines available to schedule, for the "add schedule" picker. Populated
    /// by `loadRoutines()`.
    @Published private(set) var availableRoutines: [RoutineSnapshot] = []

    /// Non-nil when a write (schedule/delete) failed. The View surfaces this
    /// while preserving the current input/selection (R14.7).
    @Published private(set) var errorMessage: String?

    // MARK: - Dependencies

    private let repository: ScheduleRepositoring
    private let routineRepository: RoutineRepositoring
    private let calendar: Calendar

    // MARK: - Internal state

    /// The most recently loaded month, kept so writes can refresh the calendar
    /// markers for the visible range without the View re-passing it.
    private var loadedMonth: DateInterval?

    // MARK: - Init

    /// Create a Schedule ViewModel.
    ///
    /// - Parameters:
    ///   - repository: Schedule persistence surface. Defaults to a production
    ///     `ScheduleRepository`.
    ///   - routineRepository: Routine listing surface for the add-schedule
    ///     picker. Defaults to a production `RoutineRepository`.
    ///   - calendar: Calendar used for day normalization. Defaults to `.current`.
    ///   - selectedDate: The initially selected day. Defaults to today.
    init(
        repository: ScheduleRepositoring = ScheduleRepository(),
        routineRepository: RoutineRepositoring = RoutineRepository(),
        calendar: Calendar = .current,
        selectedDate: Date = Date()
    ) {
        self.repository = repository
        self.routineRepository = routineRepository
        self.calendar = calendar
        self.selectedDate = selectedDate
    }

    // MARK: - Loading

    /// Populate the calendar markers for the visible month (R14.1) and remember
    /// the range so later writes can refresh it.
    func loadMonth(_ month: DateInterval) {
        loadedMonth = month
        markedDates = repository.datesWithWorkouts(in: month)
    }

    /// Select a day and load its scheduled workouts (R14.3).
    func selectDate(_ date: Date) {
        selectedDate = date
        loadEntries()
    }

    /// Load (or reload) the entries for the currently selected day, resolving
    /// each snapshot to its Routine and sorting by time ascending (R14.3, R14.5).
    func loadEntries() {
        let snapshots = repository.workouts(on: selectedDate)
        let entries = snapshots
            .map { ScheduledEntry(snapshot: $0, routine: repository.resolve($0)) }
            .sorted { $0.scheduledDate < $1.scheduledDate }

        state = entries.isEmpty ? .empty : .loaded(entries)
    }

    /// Load the list of routines available to schedule, for the add picker.
    func loadRoutines() {
        availableRoutines = routineRepository.loadAll()
    }

    // MARK: - Mutations

    /// Schedule a Routine on `date` (R14.2), then refresh the day list and the
    /// calendar markers. On failure, surface `errorMessage` and preserve the
    /// current view so the user's input is not lost (R14.7).
    func schedule(routineID: UUID, on date: Date) {
        errorMessage = nil
        do {
            _ = try repository.schedule(routineID: routineID, on: date)
            refreshAfterWrite(affecting: date)
        } catch {
            // Preserve the current selection/list; only report the failure (R14.7).
            errorMessage = message(from: error)
        }
    }

    /// Delete a schedule entry by id. The referenced Routine is left intact
    /// because the link is a weak UUID reference (R14.4); this also safely
    /// removes dangling entries (R14.5). On failure, surface `errorMessage`.
    func deleteEntry(id: UUID) {
        errorMessage = nil
        do {
            try repository.delete(id: id)
            refreshAfterWrite(affecting: selectedDate)
        } catch {
            errorMessage = message(from: error)
        }
    }

    // MARK: - Helpers

    /// Refresh the day list and re-mark the calendar for the visible month after
    /// a successful write. The affected `date` is used to refresh markers when
    /// no month has been loaded yet.
    private func refreshAfterWrite(affecting date: Date) {
        loadEntries()
        if let month = loadedMonth {
            markedDates = repository.datesWithWorkouts(in: month)
        } else if let month = monthInterval(containing: date) {
            loadedMonth = month
            markedDates = repository.datesWithWorkouts(in: month)
        }
    }

    /// Compute the `DateInterval` spanning the calendar month that contains
    /// `date`, or `nil` if it cannot be derived.
    private func monthInterval(containing date: Date) -> DateInterval? {
        calendar.dateInterval(of: .month, for: date)
    }

    /// User-facing message for a thrown error, preferring localized
    /// descriptions from the repository's error types.
    private func message(from error: Error) -> String {
        if let scheduleError = error as? ScheduleRepositoryError {
            return scheduleError.errorDescription ?? error.localizedDescription
        }
        if let routineError = error as? RoutineRepositoryError {
            return routineError.errorDescription ?? error.localizedDescription
        }
        return error.localizedDescription
    }
}
