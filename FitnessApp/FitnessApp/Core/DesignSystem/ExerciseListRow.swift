import SwiftUI

/// Reusable name-truncation helper for exercise display.
///
/// Exercise names are capped at a maximum length so that list rows stay on a
/// single, predictable line. When a name exceeds the limit it is shortened to a
/// **prefix of the original name** with a trailing ellipsis appended, and the
/// returned string never exceeds `maxLength` characters (the ellipsis is counted
/// against the budget). Names at or under the limit are returned unchanged.
///
/// This is kept as a standalone, view-agnostic helper so it can be reused by any
/// surface that renders an exercise name (and exercised directly by tests).
///
/// Requirements: 8.1 (name ≤ 80 characters, truncated with an ellipsis when it
/// exceeds the limit).
enum ExerciseNameFormatter {

    /// Default maximum displayed name length (R8.1).
    static let defaultMaxLength = 80

    /// Character appended to a truncated name. Uses the single-scalar horizontal
    /// ellipsis so it occupies exactly one character of the length budget.
    private static let ellipsis: Character = "\u{2026}"

    /// Returns `name` unchanged when its length is `<= maxLength`, otherwise a
    /// prefix of `name` with a trailing ellipsis such that the total length is
    /// exactly `maxLength`.
    ///
    /// - Parameters:
    ///   - name: The original exercise name.
    ///   - maxLength: The maximum allowed length of the returned string. Values
    ///     `<= 0` yield an empty string; a value of `1` yields just the ellipsis.
    /// - Returns: A display string no longer than `maxLength` characters.
    static func truncated(_ name: String, maxLength: Int = defaultMaxLength) -> String {
        guard maxLength > 0 else { return "" }
        guard name.count > maxLength else { return name }
        guard maxLength > 1 else { return String(ellipsis) }
        let prefix = name.prefix(maxLength - 1)
        return String(prefix) + String(ellipsis)
    }
}

/// List row for the PULSE design system showing a single `ExerciseItem`.
///
/// Lays out a leading thumbnail alongside the exercise name and its target
/// muscle. The thumbnail is supplied by the caller through a `@ViewBuilder`
/// closure (no `AnyView`) so callers can inject an async-loading image, a
/// skeleton placeholder, or a static symbol without this component depending on
/// the asset-loading layer. The name is truncated to ≤ 80 characters via
/// `ExerciseNameFormatter` before display.
///
/// Styling uses semantic `Color`, spacing, and corner-radius tokens only. The
/// row is exposed as a single combined accessibility element with a mandatory,
/// non-optional `label` and `identifier`.
///
/// Requirements: 2.1 (reusable list row), 2.2 (token-only styling),
/// 8.1 (thumbnail + name ≤ 80 chars with ellipsis + target muscle).
struct ExerciseListRow<Thumbnail: View>: View {

    private let item: ExerciseItem
    private let thumbnail: Thumbnail
    private let accessibilityLabel: String
    private let accessibilityIdentifier: String

    /// Fixed thumbnail edge length, expressed via spacing tokens only.
    private let thumbnailSize: CGFloat = .spacingExtraLarge + .spacingExtraLarge // 48pt

    init(
        item: ExerciseItem,
        @ViewBuilder thumbnail: () -> Thumbnail,
        label: String,
        identifier: String
    ) {
        self.item = item
        self.thumbnail = thumbnail()
        self.accessibilityLabel = label
        self.accessibilityIdentifier = identifier
    }

    private var displayName: String {
        ExerciseNameFormatter.truncated(item.name)
    }

    var body: some View {
        HStack(spacing: .spacingLarge) {
            thumbnail
                .frame(width: thumbnailSize, height: thumbnailSize)
                .background(
                    RoundedRectangle(cornerRadius: .cornerRadiusSmall, style: .continuous)
                        .fill(Color.themeSurfaceElevated)
                )
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: .cornerRadiusSmall, style: .continuous)
                        .stroke(Color.themeBorder, lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: .spacingSmall) {
                Text(displayName)
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(item.target)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, .spacingMedium)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

#if DEBUG
struct ExerciseListRow_Previews: PreviewProvider {
    static let sample = ExerciseItem(
        id: "0001",
        name: "Barbell Bench Press",
        gifUrl: "https://example.com/bench.gif",
        target: "pectorals",
        secondaryMuscles: ["triceps", "deltoids"],
        bodyPart: "chest",
        equipment: "barbell",
        instructions: ["Lie on the bench", "Lower the bar", "Press up"]
    )

    static let longName = ExerciseItem(
        id: "0002",
        name: String(repeating: "Incline Dumbbell ", count: 8) + "Press",
        gifUrl: "https://example.com/incline.gif",
        target: "upper pectorals",
        secondaryMuscles: [],
        bodyPart: "chest",
        equipment: "dumbbell",
        instructions: []
    )

    static var previews: some View {
        VStack(spacing: .spacingLarge) {
            ExerciseListRow(
                item: sample,
                thumbnail: {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .foregroundColor(.themePrimary)
                },
                label: "Barbell Bench Press, targets pectorals",
                identifier: "exercise.row.0001"
            )

            ExerciseListRow(
                item: longName,
                thumbnail: { Color.themeSurface },
                label: "Incline Dumbbell Press, targets upper pectorals",
                identifier: "exercise.row.0002"
            )
        }
        .padding(.spacingLarge)
        .background(Color.themeBackground)
        .preferredColorScheme(.dark)
    }
}
#endif
