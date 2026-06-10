import SwiftUI

// MARK: - ScheduleView
// Requirements: 14.1, 14.3, 14.5, 14.6 (design §6.5 Schedule_Screen)
//
// One View per screen, driven by a single `ScheduleViewModel` (design §6.5).
// Composition:
//  - A graphical `DatePicker` acts as the calendar; selecting a day funnels
//    through `viewModel.selectDate(_:)` which loads that day's entries sorted
//    by time ascending (R14.3). Calendar markers for the visible month are
//    summarised from `viewModel.markedDates`, computed via `loadMonth(_:)`
//    (R14.1).
//  - The per-day list is rendered through `AsyncStateView`. A day with no
//    entries shows the reusable `EmptyStateView` with a "Tambah Jadwal" CTA
//    (R14.6).
//  - Each row shows the routine title and scheduled time. A dangling entry
//    (its Routine was deleted) is styled distinctly as "Routine tidak lagi
//    tersedia" and still exposes a delete control to remove the orphaned entry
//    without crashing (R14.5).
//  - Save/delete failures surface a non-fatal error alert while preserving the
//    current selection (R14.7).
//
// Styling uses Design_System tokens only; no `AnyView`, no iOS 17+ APIs.

/// The Schedule screen: a calendar plus the selected day's scheduled workouts.
struct ScheduleView: View {

    // MARK: - State

    @StateObject private var viewModel = ScheduleViewModel()

    /// Presents the routine picker used to add a schedule on the selected day.
    @State private var isShowingAddSheet = false

    /// Mirrors `viewModel.errorMessage` so the alert can be dismissed locally
    /// while the message string itself is owned by the ViewModel (R14.7).
    @State private var isShowingError = false

    // MARK: - Date formatting

    /// Short time-of-day formatter for the per-entry scheduled time (R14.3).
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    /// Medium date formatter for the selected-day section header.
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: .spacingLarge) {
                calendarSection
                markersSummary
                entriesSection
            }
            .padding(.horizontal, .spacingLarge)
            .padding(.vertical, .spacingLarge)
        }
        .background(Color.themeBackground.ignoresSafeArea())
        .navigationTitle("Jadwal")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    HapticManager.shared.selection()
                    presentAddSheet()
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Tambah jadwal")
                .accessibilityIdentifier("schedule-add-button")
            }
        }
        .task {
            viewModel.loadMonth(monthInterval(containing: viewModel.selectedDate))
            viewModel.loadRoutines()
            viewModel.selectDate(viewModel.selectedDate)
        }
        .onChange(of: viewModel.selectedDate) { newDate in
            // Keep the visible month markers in sync when navigating across
            // months, then reload the freshly selected day's entries (R14.1, R14.3).
            viewModel.loadMonth(monthInterval(containing: newDate))
            viewModel.selectDate(newDate)
        }
        .onChange(of: viewModel.errorMessage) { message in
            isShowingError = message != nil
        }
        .sheet(isPresented: $isShowingAddSheet) {
            addScheduleSheet
        }
        .alert("Gagal", isPresented: $isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Calendar

    private var calendarSection: some View {
        PulseCard {
            VStack(alignment: .leading, spacing: .spacingMedium) {
                SectionHeader(
                    title: "Kalender",
                    subtitle: "Pilih tanggal untuk melihat jadwal"
                )

                DatePicker(
                    "Pilih tanggal",
                    selection: $viewModel.selectedDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(.themePrimary)
                .labelsHidden()
                .accessibilityLabel("Kalender jadwal")
                .accessibilityIdentifier("schedule-calendar")
            }
        }
    }

    /// Compact summary of how many days in the visible month carry a scheduled
    /// workout (R14.1). The graphical `DatePicker` does not expose per-day dots
    /// on iOS 16, so this surfaces the marker information textually.
    private var markersSummary: some View {
        HStack(spacing: .spacingSmall) {
            Image(systemName: "circle.fill")
                .font(.caption2)
                .foregroundColor(.themePrimary)
            Text(markersSummaryText)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(markersSummaryText)
        .accessibilityIdentifier("schedule-markers-summary")
    }

    private var markersSummaryText: String {
        let count = viewModel.markedDates.count
        return count == 0
            ? "Belum ada tanggal terjadwal bulan ini"
            : "\(count) tanggal terjadwal bulan ini"
    }

    // MARK: - Entries

    private var entriesSection: some View {
        VStack(alignment: .leading, spacing: .spacingMedium) {
            SectionHeader(title: "Jadwal \(selectedDateText)")

            AsyncStateView(
                state: viewModel.state,
                emptyConfig: emptyConfig,
                onRetry: { viewModel.loadEntries() }
            ) { entries in
                entryList(entries)
            }
        }
    }

    private func entryList(_ entries: [ScheduleViewModel.ScheduledEntry]) -> some View {
        VStack(spacing: .spacingMedium) {
            ForEach(entries) { entry in
                entryRow(entry)
            }
        }
    }

    private func entryRow(_ entry: ScheduleViewModel.ScheduledEntry) -> some View {
        PulseCard {
            HStack(spacing: .spacingMedium) {
                VStack(alignment: .leading, spacing: .spacingSmall) {
                    HStack(spacing: .spacingSmall) {
                        if entry.isDangling {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.subheadline)
                                .foregroundColor(.themeError)
                        }
                        Text(entry.title)
                            .font(.headline)
                            .foregroundColor(entry.isDangling ? .themeError : .primary)
                    }

                    Text(Self.timeFormatter.string(from: entry.scheduledDate))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer(minLength: .spacingMedium)

                deleteButton(for: entry)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowAccessibilityLabel(entry))
        .accessibilityIdentifier("schedule-entry-\(entry.id.uuidString)")
    }

    private func deleteButton(for entry: ScheduleViewModel.ScheduledEntry) -> some View {
        Button {
            HapticManager.shared.selection()
            viewModel.deleteEntry(id: entry.id)
        } label: {
            Image(systemName: "trash")
                .font(.body)
                .foregroundColor(.themeError)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibleLabel(
            entry.title.isEmpty ? nil : "Hapus jadwal \(entry.title)",
            fallback: "Hapus jadwal"
        )
        .accessibilityIdentifier("schedule-delete-\(entry.id.uuidString)")
    }

    private func rowAccessibilityLabel(_ entry: ScheduleViewModel.ScheduledEntry) -> String {
        let time = Self.timeFormatter.string(from: entry.scheduledDate)
        let title = AccessibilityLabel.resolve(entry.title, fallback: "Jadwal latihan")
        if entry.isDangling {
            return "\(title), \(time)"
        }
        return "\(title), terjadwal \(time)"
    }

    private var emptyConfig: EmptyStateView {
        EmptyStateView(
            icon: "calendar.badge.plus",
            title: "Belum ada jadwal",
            message: "Tidak ada latihan terjadwal pada tanggal ini. Tambahkan jadwal untuk mulai merencanakan.",
            cta: EmptyStateView.CTAConfig(
                label: "Tambah Jadwal",
                action: { presentAddSheet() }
            )
        )
    }

    // MARK: - Add schedule sheet

    private var addScheduleSheet: some View {
        NavigationStack {
            addScheduleContent
                .navigationTitle("Tambah Jadwal")
                .navigationBarTitleDisplayMode(.inline)
                .background(Color.themeBackground.ignoresSafeArea())
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Batal") { isShowingAddSheet = false }
                            .accessibilityLabel("Batal tambah jadwal")
                            .accessibilityIdentifier("schedule-add-cancel")
                    }
                }
        }
    }

    @ViewBuilder
    private var addScheduleContent: some View {
        if viewModel.availableRoutines.isEmpty {
            EmptyStateView(
                icon: "list.bullet.rectangle",
                title: "Belum ada Routine",
                message: "Buat Routine terlebih dahulu untuk dapat menjadwalkannya."
            )
            .padding(.spacingLarge)
        } else {
            ScrollView {
                VStack(spacing: .spacingMedium) {
                    Text("Pilih Routine untuk dijadwalkan pada \(selectedDateText).")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(viewModel.availableRoutines) { routine in
                        routinePickerRow(routine)
                    }
                }
                .padding(.spacingLarge)
            }
        }
    }

    private func routinePickerRow(_ routine: RoutineSnapshot) -> some View {
        Button {
            HapticManager.shared.selection()
            viewModel.schedule(routineID: routine.id, on: viewModel.selectedDate)
            isShowingAddSheet = false
        } label: {
            PulseCard {
                HStack(spacing: .spacingMedium) {
                    VStack(alignment: .leading, spacing: .spacingSmall) {
                        Text(routine.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(routineSubtitle(routine))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer(minLength: .spacingMedium)
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(.themePrimary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibleLabel(
            routine.name.isEmpty ? nil : "Jadwalkan \(routine.name)",
            fallback: "Jadwalkan rutinitas"
        )
        .accessibilityIdentifier("schedule-routine-\(routine.id.uuidString)")
    }

    private func routineSubtitle(_ routine: RoutineSnapshot) -> String {
        let count = routine.items.count
        return count == 1 ? "1 latihan" : "\(count) latihan"
    }

    // MARK: - Helpers

    private var selectedDateText: String {
        Self.dateFormatter.string(from: viewModel.selectedDate)
    }

    private func presentAddSheet() {
        viewModel.loadRoutines()
        isShowingAddSheet = true
    }

    /// The calendar month interval containing `date`, used to populate markers.
    private func monthInterval(containing date: Date) -> DateInterval {
        Calendar.current.dateInterval(of: .month, for: date)
            ?? DateInterval(start: date, duration: 0)
    }
}

#if DEBUG
struct ScheduleView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ScheduleView()
        }
        .preferredColorScheme(.dark)
    }
}
#endif
