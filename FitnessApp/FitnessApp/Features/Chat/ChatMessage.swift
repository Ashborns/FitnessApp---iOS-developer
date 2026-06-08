import Foundation

// MARK: - ChatRole

enum ChatRole: String, Codable {
    case user
    case assistant
    case system
}

// MARK: - ChatActionPayload

/// An optional action embedded in an assistant message that the user can tap to
/// perform an in-app action (e.g. open camera with a specific exercise).
struct ChatActionPayload: Codable, Equatable {
    enum ActionType: String, Codable, Equatable {
        case openCamera
        case viewWorkout
        case setGoal
    }

    let actionType: ActionType
    let exercise: String?
    let buttonLabel: String

    static func cameraExercise(_ exercise: String, label: String) -> ChatActionPayload {
        ChatActionPayload(actionType: .openCamera, exercise: exercise, buttonLabel: label)
    }
}

// MARK: - ChatErrorRetryPayload

/// Stored with an error bubble so user can retry the failed message.
struct ChatErrorRetryPayload: Codable, Equatable {
    let userText: String
}

// MARK: - ChatMessage

/// A value type representing a single message in the conversation.
struct ChatMessage: Identifiable, Equatable, Codable {
    let id: UUID
    let role: ChatRole
    let content: String
    let timestamp: Date
    var actionPayload: ChatActionPayload?

    /// True when this is an error bubble shown inline — not from the AI.
    var isError: Bool

    /// Payload to re-send on retry (only non-nil when `isError == true`).
    var retryPayload: ChatErrorRetryPayload?

    init(
        id: UUID = UUID(),
        role: ChatRole,
        content: String,
        timestamp: Date = Date(),
        actionPayload: ChatActionPayload? = nil,
        isError: Bool = false,
        retryPayload: ChatErrorRetryPayload? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.actionPayload = actionPayload
        self.isError = isError
        self.retryPayload = retryPayload
    }
}