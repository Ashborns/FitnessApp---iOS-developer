import Foundation

/// A single exercise sourced from the ExerciseDB API (`Exercise_Item`).
///
/// `ExerciseItem` is a pure `Codable` value type with no framework dependencies so it can be
/// decoded directly from ExerciseDB responses and unit-/property-tested in isolation. It exposes
/// every field required by the data contract: `id`, `name`, `gifUrl`, `target` (target muscle),
/// `secondaryMuscles`, `bodyPart`, `equipment`, and `instructions` (R4.1, R4.2).
///
/// Conforms to `Identifiable` (stable `id`) for use in SwiftUI lists, and `Equatable`/`Hashable`
/// so it can drive diffing, set membership, and value comparisons across the app.
struct ExerciseItem: Codable, Equatable, Identifiable, Hashable {
    /// Stable unique identifier provided by ExerciseDB.
    let id: String
    /// Human-readable exercise name.
    let name: String
    /// URL string of the animated demo GIF.
    let gifUrl: String
    /// Primary target muscle.
    let target: String
    /// Additional muscles engaged by the exercise. May be empty.
    let secondaryMuscles: [String]
    /// Body part the exercise belongs to.
    let bodyPart: String
    /// Equipment required to perform the exercise.
    let equipment: String
    /// Ordered step-by-step performance instructions. May be empty.
    let instructions: [String]
}
