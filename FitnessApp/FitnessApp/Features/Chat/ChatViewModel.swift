import SwiftUI
import CoreData

@MainActor
final class ChatViewModel: ObservableObject {

    // MARK: - Published State

    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isSending: Bool = false
    @Published var errorMessage: String?

    // MARK: - Constants

    /// Max conversation history items sent to the API (20 turns × 2 = 40).
    static let maxHistoryItems = 40
    private static let persistenceKey = "pulse_chat_messages"

    // MARK: - Dependencies

    private let deepSeekService: DeepSeekService
    private let contextBuilder: ContextBuilder

    /// Serial queue to prevent concurrent sends.
    private let sendQueue = DispatchQueue(label: "chat.send.serial", qos: .userInitiated)

    /// Flag to prevent concurrent sends — checked on main actor.
    private var sendInProgress = false

    init(
        deepSeekService: DeepSeekService = DeepSeekService(),
        contextBuilder: ContextBuilder = ContextBuilder()
    ) {
        self.deepSeekService = deepSeekService
        self.contextBuilder = contextBuilder
        loadMessages()
    }

    // MARK: - Public API

    /// Sends the current input text as a user message and fetches the AI reply.
    func sendMessage() async {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !sendInProgress else { return }

        guard let apiKey = Bundle.main.object(forInfoDictionaryKey: "DeepSeekAPIKey") as? String,
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "DeepSeek API key not configured in Info.plist."
            return
        }

        let userText = trimmed
        inputText = ""
        messages.append(ChatMessage(role: .user, content: userText))
        saveMessages()

        sendInProgress = true
        isSending = true
        defer {
            sendInProgress = false
            isSending = false
        }

        let context = await contextBuilder.buildContext()
        let systemMessage = ChatMessage(role: .system, content: context)
        let history = Self.truncateHistory(messages)
        let apiMessages = [systemMessage] + history

        do {
            let reply = try await deepSeekService.sendMessage(messages: apiMessages, apiKey: apiKey)
            let (cleanContent, actionPayload) = Self.extractExerciseAction(reply)
            messages.append(ChatMessage(
                role: .assistant,
                content: cleanContent,
                actionPayload: actionPayload
            ))
            saveMessages()
        } catch let error as DeepSeekService.ChatAPIError {
            // Remove user message on failure to keep history clean, then show error bubble
            removeLastUserMessage()
            let retryPayload = ChatErrorRetryPayload(userText: userText)
            messages.append(ChatMessage(
                role: .assistant,
                content: error.errorDescription ?? "Request failed.",
                isError: true,
                retryPayload: retryPayload
            ))
            saveMessages()
        } catch {
            removeLastUserMessage()
            messages.append(ChatMessage(
                role: .assistant,
                content: error.localizedDescription,
                isError: true,
                retryPayload: ChatErrorRetryPayload(userText: userText)
            ))
            saveMessages()
        }
    }

    /// Retries the last failed message.
    func retryLastFailed() {
        guard let last = messages.last, last.isError, let retry = last.retryPayload else { return }
        // Remove the error bubble
        messages.removeLast()
        saveMessages()
        // Re-submit the original user text
        inputText = retry.userText
        Task { await sendMessage() }
    }

    /// Clears the in-memory conversation. Not persisted, not recoverable.
    func clearChat() {
        messages = []
        saveMessages()
        UserDefaults.standard.removeObject(forKey: Self.persistenceKey)
    }

    // MARK: - Private

    private func removeLastUserMessage() {
        if let last = messages.last, last.role == .user {
            messages.removeLast()
        }
    }

    // MARK: - Persistence

    private func loadMessages() {
        guard let data = UserDefaults.standard.data(forKey: Self.persistenceKey) else { return }
        do {
            messages = try JSONDecoder().decode([ChatMessage].self, from: data)
        } catch {
            print("⚠️ Failed to load chat messages: \(error)")
            UserDefaults.standard.removeObject(forKey: Self.persistenceKey)
        }
    }

    private func saveMessages() {
        // Don't persist system messages
        let persistable = messages.filter { $0.role != .system }
        guard let data = try? JSONEncoder().encode(persistable) else { return }
        UserDefaults.standard.set(data, forKey: Self.persistenceKey)
    }

    // MARK: - Exercise Tag Parsing

    /// Extracts [EXERCISE:rawValue] tag from the AI reply and returns
    /// (cleaned content without the tag, optional ChatActionPayload).
    private static func extractExerciseAction(_ content: String) -> (String, ChatActionPayload?) {
        let pattern = #"\[EXERCISE:(\w+)\]\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
            return (content, nil)
        }

        let range = NSRange(content.startIndex..., in: content)
        guard let match = regex.firstMatch(in: content, options: [], range: range),
              let tagRange = Range(match.range(at: 0), in: content),
              let exerciseRange = Range(match.range(at: 1), in: content) else {
            return (content, nil)
        }

        let exerciseRaw = String(content[exerciseRange])
        guard let exercise = ExerciseType(rawValue: exerciseRaw) else {
            return (content, nil)
        }

        var clean = content
        clean.removeSubrange(tagRange)
        clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)

        let payload = ChatActionPayload.cameraExercise(
            exerciseRaw,
            label: "Start \(exercise.displayName) in Camera"
        )
        return (clean, payload)
    }

    // MARK: - History Truncation

    static func truncateHistory(_ messages: [ChatMessage]) -> [ChatMessage] {
        guard messages.count > maxHistoryItems else { return messages }
        return Array(messages.suffix(maxHistoryItems))
    }
}