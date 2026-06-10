import Foundation

// MARK: - ExerciseContextSeeder
// Requirements: 10.8, 15.2, 15.4
//
// Assembles the AI Coach seed prompt text from either a single `ExerciseItem`
// or a `RoutineSnapshot`, so the existing GLMService/DeepSeekService and
// ContextBuilder can be reused unchanged (design section 7). The produced text
// is pure (no framework dependencies) so it is trivial to test in isolation.

/// Builds Indonesian-language AI Coach seed prompts from exercise/routine context.
enum ExerciseContextSeeder {

    /// Seed prompt for a single exercise. Includes the exercise name, target
    /// muscle, required equipment, and the first instruction step (if any).
    ///
    /// Empty `instructions` are handled safely via `first ?? ""` so the prompt
    /// is always well-formed (Requirements 10.8, 15.2).
    static func prompt(for item: ExerciseItem) -> String {
        "Saya sedang melihat latihan \"\(item.name)\" (target: \(item.target), equipment: \(item.equipment)). \(item.instructions.first ?? "") Bisa beri tips form dan variasi?"
    }

    /// Seed prompt for a routine. Includes the routine name and a bullet list of
    /// each item's exercise name (Requirement 15.4).
    static func prompt(for routine: RoutineSnapshot) -> String {
        let list = routine.items.map { "- \($0.exerciseName)" }.joined(separator: "\n")
        return "Saya menyusun rutinitas \"\(routine.name)\" berisi:\n\(list)\nTolong evaluasi dan beri saran."
    }
}
