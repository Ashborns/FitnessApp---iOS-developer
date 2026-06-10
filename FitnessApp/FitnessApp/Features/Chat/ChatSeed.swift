import Foundation

/// Optional seed used to pre-fill the chat input with a context-aware prompt
/// when a fresh conversation is opened (e.g. from an exercise or routine).
/// Assembled by `ExerciseContextSeeder`; reuses the existing chat pipeline
/// (`DeepSeekService`/`ContextBuilder`) without duplicating any service logic.
struct ChatSeed: Equatable {
    /// Text shown pre-filled in the input field; the user can send or edit it.
    let userVisiblePrompt: String
}
