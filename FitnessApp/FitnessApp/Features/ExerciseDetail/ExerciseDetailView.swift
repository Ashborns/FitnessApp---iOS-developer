import SwiftUI

// MARK: - ExerciseDetailView
// Requirements: 10.1, 10.2, 10.3, 10.5, 15.1
//
// Enriched Exercise Detail screen (design §6.2 Detail_Screen). Renders, in the
// exact order supplied by the `ExerciseItem`:
//   1. Demo GIF (skeleton handled internally by `ExerciseAsyncImage`, R10.2)
//   2. name + target muscle (R10.1)
//   3. secondaryMuscles, equipment, instructions sections (R10.1) — each
//      section AND its header is hidden when its optional field is empty (R10.3)
//
// Actions:
//   - "Buka Camera Coaching": shown ONLY when the exercise maps to a supported
//     `ExerciseType` (`viewModel.canOpenCamera`, R10.5) → `openCamera(router:)`.
//   - "Tambah ke rutinitas" (SecondaryButton): appends a RoutineItem and shows a
//     transient confirmation; errors surface via an alert.
//   - "Tanya AI Coach" (PrimaryButton): presents `ChatView(seed:)` pre-filled
//     with the exercise context via `.fullScreenCover` (R10.8 / 15.1).
//
// Styling is token-only (Design_System); composition uses `@ViewBuilder`
// (no `AnyView`); no iOS 17+ APIs.

/// Detail screen for a single `ExerciseItem`.
struct ExerciseDetailView: View {

    @StateObject private var viewModel: ExerciseDetailViewModel
    @EnvironmentObject private var router: AppRouter

    /// Whether the AI Coach chat cover is presented.
    @State private var showChat = false

    /// Creates the detail screen for the supplied exercise.
    /// - Parameter item: The exercise to display.
    init(item: ExerciseItem) {
        _viewModel = StateObject(wrappedValue: ExerciseDetailViewModel(item: item))
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .spacingExtraLarge) {
                demoImage
                header
                secondaryMusclesSection
                equipmentSection
                instructionsSection
                actions
            }
            .padding(.spacingLarge)
        }
        .background(Color.themeBackground.ignoresSafeArea())
        .navigationTitle(viewModel.item.name)
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .bottom) { confirmationBanner }
        .animation(.easeInOut(duration: 0.30), value: viewModel.showRoutineConfirmation)
        .alert("Gagal", isPresented: errorBinding) {
            Button("OK", role: .cancel) { viewModel.dismissError() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .fullScreenCover(isPresented: $showChat) {
            ChatView(seed: viewModel.chatSeed())
        }
    }

    // MARK: - Demo GIF (R10.1 / R10.2)

    /// Animated demo GIF. The skeleton-while-loading behaviour (R10.2) is handled
    /// inside `ExerciseAsyncImage`.
    private var demoImage: some View {
        ExerciseAsyncImage(
            url: URL(string: viewModel.item.gifUrl),
            cornerRadius: .cornerRadiusLarge,
            contentMode: .fit
        )
        .frame(maxWidth: .infinity)
        .frame(height: 280)
        .accessibilityIdentifier("exerciseDetail.demoImage")
    }

    // MARK: - Header: name + target (R10.1)

    private var header: some View {
        VStack(alignment: .leading, spacing: .spacingMedium) {
            Text(viewModel.item.name)
                .font(.largeTitle.weight(.heavy))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("exerciseDetail.name")

            HStack(spacing: .spacingSmall) {
                Text("Target")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
                PulseBadge(text: viewModel.item.target, style: .accent)
            }
            .accessibilityElement(children: .combine)
            .accessibleLabel(
                viewModel.item.target.isEmpty ? nil : "Target otot \(viewModel.item.target)",
                fallback: "Target otot"
            )
            .accessibilityIdentifier("exerciseDetail.target")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Secondary muscles (R10.1 / R10.3)

    /// Hidden entirely (section + header) when `secondaryMuscles` is empty (R10.3).
    @ViewBuilder
    private var secondaryMusclesSection: some View {
        if !viewModel.item.secondaryMuscles.isEmpty {
            VStack(alignment: .leading, spacing: .spacingLarge) {
                SectionHeader(title: "Otot Sekunder")
                FlowBadges(items: viewModel.item.secondaryMuscles)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("exerciseDetail.secondaryMuscles")
        }
    }

    // MARK: - Equipment (R10.1 / R10.3)

    /// Hidden entirely (section + header) when `equipment` is empty (R10.3).
    @ViewBuilder
    private var equipmentSection: some View {
        if !viewModel.item.equipment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            VStack(alignment: .leading, spacing: .spacingLarge) {
                SectionHeader(title: "Peralatan")
                PulseBadge(text: viewModel.item.equipment)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("exerciseDetail.equipment")
        }
    }

    // MARK: - Instructions (R10.1 / R10.3)

    /// Numbered steps in the original order supplied by the exercise. Hidden
    /// entirely (section + header) when `instructions` is empty (R10.3).
    @ViewBuilder
    private var instructionsSection: some View {
        if !viewModel.item.instructions.isEmpty {
            VStack(alignment: .leading, spacing: .spacingLarge) {
                SectionHeader(title: "Instruksi")
                PulseCard {
                    VStack(alignment: .leading, spacing: .spacingLarge) {
                        ForEach(Array(viewModel.item.instructions.enumerated()), id: \.offset) { index, step in
                            instructionRow(number: index + 1, text: step)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("exerciseDetail.instructions")
        }
    }

    private func instructionRow(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: .spacingMedium) {
            Text("\(number)")
                .font(.subheadline.weight(.bold))
                .foregroundColor(.themePrimary)
                .frame(minWidth: 24, alignment: .leading)
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Langkah \(number). \(text)")
    }

    // MARK: - Actions (R10.5 / 15.1)

    private var actions: some View {
        VStack(spacing: .spacingLarge) {
            // "Buka Camera Coaching" — shown only when mappable to a camera type (R10.5).
            cameraControl

            SecondaryButton(
                title: "Tambah ke rutinitas",
                label: AccessibilityLabel.resolve(
                    viewModel.item.name.isEmpty ? nil : "Tambah \(viewModel.item.name) ke rutinitas",
                    fallback: "Tambah latihan ke rutinitas"
                ),
                identifier: "exerciseDetail.addToRoutineButton",
                action: { viewModel.addToRoutine() }
            )

            PrimaryButton(
                title: "Tanya AI Coach",
                label: AccessibilityLabel.resolve(
                    viewModel.item.name.isEmpty ? nil : "Tanya AI Coach tentang \(viewModel.item.name)",
                    fallback: "Tanya AI Coach tentang latihan ini"
                ),
                identifier: "exerciseDetail.askAICoachButton",
                action: { showChat = true }
            )
        }
        .padding(.top, .spacingMedium)
    }

    /// Renders the camera control only when the exercise maps to a supported
    /// camera type (R10.5); otherwise nothing is rendered.
    @ViewBuilder
    private var cameraControl: some View {
        if viewModel.canOpenCamera {
            SecondaryButton(
                title: "Buka Camera Coaching",
                label: AccessibilityLabel.resolve(
                    viewModel.item.name.isEmpty ? nil : "Buka camera coaching untuk \(viewModel.item.name)",
                    fallback: "Buka camera coaching untuk latihan ini"
                ),
                identifier: "exerciseDetail.openCameraButton",
                action: { viewModel.openCamera(router: router) }
            )
        }
    }

    // MARK: - Confirmation banner (R10.6)

    /// Transient confirmation surfaced after a successful add-to-routine.
    @ViewBuilder
    private var confirmationBanner: some View {
        if viewModel.showRoutineConfirmation {
            HStack(spacing: .spacingMedium) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.themePrimary)
                Text("Ditambahkan ke rutinitas")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, .spacingLarge)
            .padding(.vertical, .spacingMedium)
            .background(
                RoundedRectangle(cornerRadius: .cornerRadiusLarge, style: .continuous)
                    .fill(Color.themeSurfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: .cornerRadiusLarge, style: .continuous)
                    .stroke(Color.themeBorder, lineWidth: 1)
            )
            .padding(.bottom, .spacingExtraLarge)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Ditambahkan ke rutinitas")
            .accessibilityIdentifier("exerciseDetail.routineConfirmation")
        }
    }

    // MARK: - Bindings

    /// Drives the error alert from the read-only `errorMessage`. Dismissing the
    /// alert clears the message via the ViewModel.
    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented { viewModel.dismissError() }
            }
        )
    }
}

// MARK: - FlowBadges

/// Lays out a collection of `PulseBadge`s that wrap onto multiple lines.
///
/// Uses `ViewThatFits`-free token-based wrapping via a simple width-aware
/// `HStack`/`VStack` composition. Kept internal to this screen.
private struct FlowBadges: View {
    let items: [String]

    var body: some View {
        // Simple wrapping layout that stays within iOS 16 APIs and avoids AnyView.
        VStack(alignment: .leading, spacing: .spacingMedium) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: .spacingMedium) {
                    ForEach(row, id: \.self) { value in
                        PulseBadge(text: value)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Chunks the items into rows of at most `maxPerRow` badges so they wrap
    /// predictably without a custom Layout (iOS 16-safe).
    private var rows: [[String]] {
        let maxPerRow = 3
        return stride(from: 0, to: items.count, by: maxPerRow).map { start in
            Array(items[start..<min(start + maxPerRow, items.count)])
        }
    }
}

#if DEBUG
struct ExerciseDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ExerciseDetailView(
                item: ExerciseItem(
                    id: "0001",
                    name: "Barbell Squat",
                    gifUrl: "https://example.com/squat.gif",
                    target: "quads",
                    secondaryMuscles: ["glutes", "hamstrings", "calves", "core"],
                    bodyPart: "upper legs",
                    equipment: "barbell",
                    instructions: [
                        "Berdiri tegak dengan barbell di bahu.",
                        "Turunkan pinggul hingga paha sejajar lantai.",
                        "Dorong kembali ke posisi awal."
                    ]
                )
            )
        }
        .environmentObject(AppRouter())
        .preferredColorScheme(.dark)
    }
}
#endif
