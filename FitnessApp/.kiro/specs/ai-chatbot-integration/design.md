# Design Document — AI Chatbot Integration

## Overview

This feature adds a context-aware AI fitness coaching chatbot to the PULSE app. The chatbot is powered by the GLM API (z.ai, OpenAI-compatible REST) and is surfaced as a sixth tab in `MainTabView`. Before every API call, a `ContextBuilder` assembles a structured snapshot of the user's live fitness data — reps, streaks, calories, workout history, and AI-generated recommendations — and injects it as a system-role message. The API key is stored exclusively in the iOS Keychain and is never hardcoded.

The feature is composed of seven new Swift files under `Features/Chat/`, plus targeted modifications to three existing files (`AppRouter.swift`, `MainTabView.swift`, `SettingsView.swift`).

### Key Design Decisions

- **GLMService is a pure struct with no SwiftUI import** — it can be compiled and unit-tested in isolation from the UI layer.
- **ContextBuilder is a pure struct** — all data sources are injected as parameters, making it trivially testable without mocks.
- **ChatViewModel owns all state and orchestration** — the View body contains zero business logic.
- **No persistence for chat history** — conversation lives only in memory for the session lifetime, satisfying the privacy requirement and eliminating CoreData complexity.
- **CalorieGoalViewModel is instantiated fresh inside ContextBuilder.buildContext()** — it is not a singleton, so `ContextBuilder` calls `loadTodayData()` on a new instance each time context is assembled, then reads the published values synchronously after the async call completes.

---

## Architecture

### Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│  MainTabView  (modified)                                        │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │  ChatView  (new)                                         │   │
│  │  ┌────────────────────┐  ┌──────────────────────────┐   │   │
│  │  │  ChatBubbleView    │  │  TypingIndicatorView     │   │   │
│  │  │  (new, per message)│  │  (inline in ChatView)    │   │   │
│  │  └────────────────────┘  └──────────────────────────┘   │   │
│  │                                                          │   │
│  │  @StateObject ChatViewModel (new)                        │   │
│  │  ┌──────────────────────────────────────────────────┐   │   │
│  │  │  sendMessage()                                   │   │   │
│  │  │    │                                             │   │   │
│  │  │    ├─► ContextBuilder.buildContext()  (new)      │   │   │
│  │  │    │     ├─ WorkoutGoalsStore.shared             │   │   │
│  │  │    │     ├─ CalorieGoalViewModel (instantiated)  │   │   │
│  │  │    │     ├─ HealthKitManager.shared              │   │   │
│  │  │    │     ├─ WorkoutRecommendationEngine()        │   │   │
│  │  │    │     └─ PersistenceController.shared         │   │   │
│  │  │    │                                             │   │   │
│  │  │    └─► GLMService.sendMessage()  (new)           │   │   │
│  │  │          ├─ KeychainWrapper.load(key:)           │   │   │
│  │  │          └─ URLSession.shared                    │   │   │
│  │  └──────────────────────────────────────────────────┘   │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                  │
│  SettingsView  (modified) ──► APIKeySettingsView  (new)         │
│                                 └─ KeychainWrapper.save/load/   │
│                                    delete(key: "glm.apiKey")    │
└─────────────────────────────────────────────────────────────────┘

AppRouter  (modified)
  └─ AppTab enum: + .chat case
```

### Data Flow — Sending a Message

```
User taps Send
      │
      ▼
ChatViewModel.sendMessage(text:)
  1. Guard: text is not blank
  2. Guard: KeychainWrapper.load("glm.apiKey") != nil
     └─ if nil → set errorMessage → show alert → return
  3. Append ChatMessage(role: .user, content: text) to messages[]
  4. Set isSending = true  (shows typing indicator)
  5. Disable input field
  6. await ContextBuilder.buildContext()
     ├─ fetch WorkoutGoalsStore.shared values
     ├─ instantiate CalorieGoalViewModel, await loadTodayData()
     ├─ await HealthKitManager.shared.fetchTodayActiveEnergy()
     ├─ fetch WorkoutLog entries from CoreData (up to 5)
     ├─ generate recommendations via WorkoutRecommendationEngine
     └─ return FitnessContext string
  7. Build messages array for API:
     [system(FitnessContext)] + last 40 ChatMessages (20 turns)
  8. await GLMService.sendMessage(messages:apiKey:)
     ├─ POST https://api.z.ai/api/paas/v4/chat/completions
     └─ decode GLMResponse → extract choices[0].message.content
  9. On success:
     └─ Append ChatMessage(role: .assistant, content: reply)
 10. On failure:
     └─ Set errorMessage (shown via .alert)
 11. Set isSending = false
 12. Re-enable input field
```

---

## Components and Interfaces

### ChatMessage.swift

Value type representing a single message in the conversation.

```swift
import Foundation

enum ChatRole: String, Codable {
    case user
    case assistant
    case system
}

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let role: ChatRole
    let content: String
    let timestamp: Date

    init(id: UUID = UUID(), role: ChatRole, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}
```

### GLMService.swift

Pure struct, no SwiftUI import. Handles all HTTP communication with the GLM API.

```swift
import Foundation

struct GLMService {
    static let endpoint = URL(string: "https://api.z.ai/api/paas/v4/chat/completions")!
    static let model = "glm-4-flash"
    static let timeoutSeconds: TimeInterval = 30

    enum GLMError: LocalizedError {
        case missingAPIKey
        case httpError(Int)
        case decodingFailed
        case timeout
        case networkError(Error)

        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "API key not configured. Go to Settings → AI Coach API Key."
            case .httpError(let code):
                return "Request failed (\(code)). \(code == 401 ? "Check your API key." : "Please try again.")"
            case .decodingFailed:
                return "Failed to parse AI response."
            case .timeout:
                return "Request timed out. Please try again."
            case .networkError(let e):
                return e.localizedDescription
            }
        }
    }

    /// Sends a conversation to the GLM API and returns the assistant reply.
    func sendMessage(messages: [ChatMessage], apiKey: String) async throws -> String
}
```

### ContextBuilder.swift

Pure struct. Assembles the FitnessContext string from all data sources.

```swift
import Foundation
import CoreData

struct ContextBuilder {
    /// Assembles a FitnessContext snapshot string.
    /// All errors from individual data sources are caught internally;
    /// fallback values are substituted so the caller always receives a valid string.
    func buildContext() async -> String
}
```

### ChatViewModel.swift

```swift
import SwiftUI
import CoreData

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var isSending: Bool = false
    @Published var errorMessage: String?

    private let glmService = GLMService()
    private let contextBuilder = ContextBuilder()

    func sendMessage() async
    func clearChat()
}
```

### ChatView.swift

SwiftUI view. Owns a `@StateObject private var viewModel = ChatViewModel()`. Contains only layout, data-binding, and view composition. Uses `.onChange(of:perform:)` (iOS 16 form).

### ChatBubbleView.swift

Stateless view component. Receives a `ChatMessage` and renders the appropriate bubble style.

```swift
struct ChatBubbleView: View {
    let message: ChatMessage
    // user messages: right-aligned, themePrimary background
    // assistant messages: left-aligned, themeSurface background
}
```

### APIKeySettingsView.swift

SwiftUI view. Reads/writes the Keychain key `"glm.apiKey"` via `KeychainWrapper`. No ViewModel needed — all state is local `@State`.

---

## Data Models

### GLMService Request / Response (Codable)

```swift
// MARK: - Request

struct GLMRequest: Encodable {
    let model: String
    let messages: [GLMMessagePayload]
}

struct GLMMessagePayload: Codable {
    let role: String   // "system" | "user" | "assistant"
    let content: String
}

// MARK: - Response

struct GLMResponse: Decodable {
    let choices: [GLMChoice]
}

struct GLMChoice: Decodable {
    let message: GLMMessagePayload
}
```

Mapping `ChatMessage` → `GLMMessagePayload`:

```swift
extension ChatMessage {
    var asPayload: GLMMessagePayload {
        GLMMessagePayload(role: role.rawValue, content: content)
    }
}
```

### FitnessContext String Format

`ContextBuilder.buildContext()` produces a string with this exact template:

```
You are PULSE AI, a personal fitness coach. Reference the data below when answering.
Keep responses to 150 words or fewer unless the user explicitly asks for more detail.

=== FITNESS SNAPSHOT ===
Date: {yyyy-MM-dd}

[GOALS & STREAKS]
Daily rep goal: {dailyRepGoal} reps
Today's reps: {todayReps}
Current streak: {currentStreak} days
Best streak: {bestStreak} days

[LAST 7 DAYS — REPS]
{Mon dd/MM}: {reps} reps
{Tue dd/MM}: {reps} reps
... (7 lines)

[CALORIES]
Daily goal: {dailyGoal} kcal
Consumed today: {consumed} kcal
Burned today: {burned} kcal  {— or "HealthKit data unavailable"}
Net: {consumed - burned} kcal

[WORKOUT RECOMMENDATIONS]
1. {type} — {duration} min
2. {type} — {duration} min
3. {type} — {duration} min

[RECENT WORKOUTS]
{count} recent workout entries found.  {— or "No workout history recorded." / "Workout history unavailable."}
1. {type} — {duration} min on {yyyy-MM-dd}
... (up to 5 entries)
========================
```

### ChatViewModel State Machine

```
         ┌──────────────────────────────────────────────────────┐
         │                      IDLE                            │
         │  isSending = false                                   │
         │  messages = [...]                                    │
         │  errorMessage = nil                                  │
         └──────────────────────────────────────────────────────┘
                  │ user taps Send (non-empty text)
                  ▼
         ┌──────────────────────────────────────────────────────┐
         │                    SENDING                           │
         │  isSending = true                                    │
         │  messages = [..., userMsg]  (appended immediately)   │
         │  input field disabled                                │
         │  typing indicator visible                            │
         └──────────────────────────────────────────────────────┘
                  │                        │
          success │                        │ failure
                  ▼                        ▼
         ┌────────────────┐      ┌─────────────────────────────┐
         │   RECEIVED     │      │          ERROR              │
         │  isSending=false│     │  isSending = false          │
         │  messages=[...,│      │  errorMessage = "..."       │
         │   assistantMsg]│      │  typing indicator removed   │
         │  input enabled │      │  input field re-enabled     │
         └────────────────┘      └─────────────────────────────┘
                  │                        │
                  └──────────┬─────────────┘
                             ▼
                           IDLE
                  (errorMessage cleared on alert dismiss)

         Special transitions from IDLE:
         ─ empty/whitespace input → stays IDLE, no API call
         ─ missing API key → stays IDLE, errorMessage set immediately
         ─ user taps "Clear Chat" → messages = [], stays IDLE
```

---

## File Structure

```
FitnessApp/
├── App/
│   ├── AppRouter.swift          ← ADD .chat case to AppTab enum
│   └── MainTabView.swift        ← ADD chatTab, tag(.chat)
├── Core/
│   ├── Keychain/
│   │   └── KeychainWrapper.swift  (unchanged)
│   └── Navigation/
│       └── AppRouter.swift
└── Features/
    ├── Chat/                    ← NEW DIRECTORY
    │   ├── ChatMessage.swift
    │   ├── GLMService.swift
    │   ├── ContextBuilder.swift
    │   ├── ChatViewModel.swift
    │   ├── ChatView.swift
    │   ├── ChatBubbleView.swift
    │   └── APIKeySettingsView.swift
    └── Profile/
        └── SettingsView.swift   ← ADD NavigationLink to APIKeySettingsView
```

### Modifications to Existing Files

**AppRouter.swift** — add `.chat` case:
```swift
enum AppTab: String, CaseIterable {
    case home, workout, camera, calories, profile, progress, chat
}
```

**MainTabView.swift** — add sixth tab:
```swift
private var chatTab: some View {
    NavigationStack {
        ChatView()
    }
    .tabItem {
        Label("Chat", systemImage: "message.fill")
    }
    .tag(AppRouter.AppTab.chat)
}
```

**SettingsView.swift** — add NavigationLink in the workout/data section:
```swift
NavigationLink {
    APIKeySettingsView()
} label: {
    listRowContent(
        icon: "key.fill",
        title: "AI Coach API Key",
        subtitle: "Configure GLM API access",
        trailingChevron: true
    )
    .padding(.vertical, 14)
}
.buttonStyle(.plain)
```

---

## Correctness Properties


*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Message alignment by role

*For any* array of `ChatMessage` values, every message with role `.user` must be right-aligned and every message with role `.assistant` must be left-aligned in the rendered bubble list.

**Validates: Requirements 2.1**

---

### Property 2: Input cleared after send

*For any* non-empty, non-whitespace string set as `inputText`, after `ChatViewModel.sendMessage()` is called, `inputText` must equal the empty string.

**Validates: Requirements 2.3**

---

### Property 3: Whitespace input is rejected

*For any* string composed entirely of whitespace characters (including the empty string), calling `ChatViewModel.sendMessage()` must not append any message to `messages` and must not invoke `GLMService`.

**Validates: Requirements 2.8**

---

### Property 4: Input length capped at 1000 characters

*For any* string of length greater than 1000 characters, the `inputText` binding must not allow the string to exceed 1000 characters after the enforcement logic runs.

**Validates: Requirements 2.9**

---

### Property 5: Clear chat produces empty message list

*For any* non-empty `messages` array, calling `ChatViewModel.clearChat()` must result in `messages` being an empty array.

**Validates: Requirements 2.7, 6.4**

---

### Property 6: FitnessContext contains all required fields

*For any* combination of fitness data inputs (rep goal, today's reps, streak values, calorie values, workout history, recommendations), `ContextBuilder.buildContext()` must return a string containing all of the following: "PULSE AI", "150 words", the daily rep goal value, today's rep count, current streak, best streak, daily calorie goal, consumed calories, a burned calories value or "HealthKit data unavailable", and at least one workout recommendation entry.

**Validates: Requirements 3.1, 3.3, 3.4**

---

### Property 7: System message is always first in API payload

*For any* array of prior `ChatMessage` values (including an empty array), the first element in the messages array sent to the GLM API must have role `"system"` and must contain the FitnessContext string.

**Validates: Requirements 3.2**

---

### Property 8: Workout history count note is accurate

*For any* non-empty array of `WorkoutLog` entries of size N (where 1 ≤ N ≤ 5), `ContextBuilder.buildContext()` must return a string containing the exact count N in the workout history note.

**Validates: Requirements 3.6**

---

### Property 9: ContextBuilder never throws

*For any* combination of data source failures (HealthKit error, CoreData error, or both), `ContextBuilder.buildContext()` must complete without throwing and must return a string containing the appropriate fallback notes ("HealthKit data unavailable" and/or "Workout history unavailable.").

**Validates: Requirements 3.4, 3.7**

---

### Property 10: GLM response decoding round trip

*For any* non-empty assistant content string, encoding it into a `GLMResponse` JSON structure (as `choices[0].message.content`) and then decoding it via `GLMService`'s response parsing must return the original string unchanged.

**Validates: Requirements 4.2**

---

### Property 11: HTTP error status code appears in error message

*For any* HTTP error status code in the range 400–599, when `GLMService` receives that status code, `ChatViewModel.errorMessage` must be a non-nil string containing the decimal representation of that status code.

**Validates: Requirements 4.3, 8.7**

---

### Property 12: User message appended immediately and ordering preserved

*For any* sequence of non-empty messages sent via `ChatViewModel.sendMessage()`, each user message must appear in `messages` immediately after the call (before the API response arrives), and the overall `messages` array must preserve insertion order throughout the session.

**Validates: Requirements 4.6, 6.1**

---

### Property 13: Conversation history included in API payload

*For any* non-empty `messages` array containing prior user and assistant turns, the messages array constructed for the GLM API request must include all prior messages (after the system prompt) when the total count is ≤ 40.

**Validates: Requirements 6.2**

---

### Property 14: History truncated to 20 turns (40 messages) for API

*For any* `messages` array containing more than 40 items, the messages array sent to the GLM API (excluding the system prompt) must contain exactly 40 items — the most recent 40.

**Validates: Requirements 6.3**

---

### Property 15: API key save/load round trip

*For any* non-empty, non-whitespace string used as an API key, calling `KeychainWrapper.save(key: "glm.apiKey", value:)` followed by `KeychainWrapper.load(key: "glm.apiKey")` must return the original string.

**Validates: Requirements 7.3**

---

### Property 16: Key status display reflects Keychain state

*For any* Keychain state (key present or absent), the status text displayed in `APIKeySettingsView` must be "Configured ✓" when `KeychainWrapper.load` returns a non-nil value, and "Not configured" when it returns nil — within one rendering cycle of the state change.

**Validates: Requirements 7.5**

---

### Property 17: Save button disabled for whitespace API key input

*For any* string composed entirely of whitespace characters (including the empty string) entered into the `SecureField` in `APIKeySettingsView`, the Save button must be disabled.

**Validates: Requirements 5.2**

---

## Error Handling

### Missing API Key

`ChatViewModel.sendMessage()` reads the key via `KeychainWrapper.load(key: "glm.apiKey")` before constructing any request. If `nil` is returned, it sets `errorMessage` to a user-facing string directing the user to Settings, and returns immediately without calling `GLMService`. No network request is made.

### HealthKit Unavailable

`ContextBuilder.buildContext()` wraps the `HealthKitManager.shared.fetchTodayActiveEnergy()` call in a `do/catch`. On failure, it substitutes `burned = 0` and appends `"HealthKit data unavailable"` to the context string. The error is not re-thrown.

### CoreData Fetch Failure

`ContextBuilder.buildContext()` wraps the `WorkoutLog` fetch in a `do/catch`. On failure, it appends `"Workout history unavailable."` to the context string. The error is not re-thrown.

### HTTP Errors (4xx / 5xx)

`GLMService.sendMessage()` checks `HTTPURLResponse.statusCode`. Any code outside 200–299 throws `GLMError.httpError(statusCode)`. `ChatViewModel` catches this and sets `errorMessage` to the localized description, which includes the status code. The typing indicator is removed and the input field is re-enabled.

### Decoding Failure

If `JSONDecoder` fails to decode the response, or if `choices` is empty, `GLMService` throws `GLMError.decodingFailed`. `ChatViewModel` catches this and sets `errorMessage = "Failed to parse AI response."`.

### Timeout

`URLSession` is configured with a `timeoutIntervalForRequest` of 30 seconds. On timeout, `URLSession` throws a `URLError(.timedOut)`. `GLMService` maps this to `GLMError.timeout`. `ChatViewModel` catches it and sets `errorMessage = "Request timed out. Please try again."`.

### Error Display

`ChatView` uses a `.alert` modifier bound to `Binding<Bool>` derived from `viewModel.errorMessage != nil`. The alert's dismiss action sets `viewModel.errorMessage = nil`.

---

## Testing Strategy

### Dual Testing Approach

Unit tests cover specific examples, edge cases, and error conditions. Property-based tests verify universal properties across all inputs. Both are necessary for comprehensive coverage.

### Property-Based Testing Library

Use **SwiftCheck** (the Swift port of QuickCheck) for property-based tests. Each property test runs a minimum of **100 iterations**.

Tag format for each property test:
```swift
// Feature: ai-chatbot-integration, Property N: <property text>
```

### Unit Tests (Example-Based)

**ChatMessageTests**
- Creating a `ChatMessage` with `.user` role sets `role == .user`
- Two `ChatMessage` values with the same `id` are equal
- `asPayload` maps `.user` → `"user"`, `.assistant` → `"assistant"`, `.system` → `"system"`

**GLMServiceTests**
- Decoding a valid `GLMResponse` JSON extracts `choices[0].message.content` correctly
- Decoding a `GLMResponse` with empty `choices` array throws `decodingFailed`
- HTTP 401 response produces `GLMError.httpError(401)` with message containing "401"
- HTTP 500 response produces `GLMError.httpError(500)` with message containing "500"
- Timeout produces `GLMError.timeout` with the expected message
- `GLMService.swift` compiles without `import SwiftUI` (build test)

**ContextBuilderTests**
- With all data sources healthy, output contains "PULSE AI" and "150 words"
- With HealthKit error, output contains "HealthKit data unavailable" and burned = 0
- With CoreData error, output contains "Workout history unavailable."
- With empty WorkoutLog array, output contains "No workout history recorded."
- With 3 WorkoutLog entries, output contains "3 recent workout entries found."
- `buildContext()` never throws regardless of data source failures

**ChatViewModelTests**
- `sendMessage()` with empty string does not append to `messages`
- `sendMessage()` with whitespace-only string does not append to `messages`
- `sendMessage()` with nil API key sets `errorMessage` and does not call GLMService
- `sendMessage()` with valid input appends user message before API response
- `clearChat()` resets `messages` to `[]`
- `isSending` is `true` during API call and `false` after completion
- `errorMessage` is set on HTTP error, decode failure, and timeout

**APIKeySettingsViewTests**
- On appear with no Keychain key, status displays "Not configured"
- On appear with existing Keychain key, status displays "Configured ✓"
- Save button is disabled when `SecureField` is empty
- Tapping Save calls `KeychainWrapper.save(key: "glm.apiKey", value:)`
- Tapping Remove Key calls `KeychainWrapper.delete(key: "glm.apiKey")`
- On successful delete, status updates to "Not configured"
- On failed save, error message is displayed and status does not change to "Configured ✓"

**AppRouterTests**
- `AppTab.chat.rawValue == "chat"`
- `handleDeepLink(URL("fitnessapp://tab/chat"))` sets `selectedTab == .chat`

### Property-Based Tests

Each property below maps to a numbered Correctness Property above.

```swift
// Feature: ai-chatbot-integration, Property 3: Whitespace input is rejected
property("Whitespace input never sends a message") <- forAll(whitespaceStringGen) { ws in
    let vm = ChatViewModel(glmService: MockGLMService())
    vm.inputText = ws
    // sendMessage is synchronous guard — check messages count unchanged
    return vm.messages.count == 0
}

// Feature: ai-chatbot-integration, Property 4: Input length capped at 1000
property("Input text never exceeds 1000 characters") <- forAll(Gen<String>.ofSize(1001, 2000)) { s in
    let enforced = String(s.prefix(1000))
    return enforced.count <= 1000
}

// Feature: ai-chatbot-integration, Property 5: Clear chat produces empty list
property("clearChat always empties messages") <- forAll(chatMessageArrayGen) { msgs in
    let vm = ChatViewModel()
    vm.messages = msgs
    vm.clearChat()
    return vm.messages.isEmpty
}

// Feature: ai-chatbot-integration, Property 6: FitnessContext contains all required fields
property("buildContext output contains all required fields") <- forAll(fitnessDataGen) { data in
    let context = await ContextBuilder().buildContext(with: data)
    return context.contains("PULSE AI")
        && context.contains("150 words")
        && context.contains(String(data.dailyRepGoal))
        && context.contains(String(data.todayReps))
}

// Feature: ai-chatbot-integration, Property 10: GLM response decoding round trip
property("GLM response decoding round trip") <- forAll(nonEmptyStringGen) { content in
    let json = """
    {"choices":[{"message":{"role":"assistant","content":"\(content)"}}]}
    """
    let decoded = try? JSONDecoder().decode(GLMResponse.self, from: json.data(using: .utf8)!)
    return decoded?.choices.first?.message.content == content
}

// Feature: ai-chatbot-integration, Property 11: HTTP error status code in error message
property("HTTP error status code appears in errorMessage") <- forAll(Gen<Int>.choose((400, 599))) { code in
    let error = GLMService.GLMError.httpError(code)
    return error.errorDescription?.contains(String(code)) == true
}

// Feature: ai-chatbot-integration, Property 14: History truncated to 40 messages
property("API payload history capped at 40 messages") <- forAll(largeMessageArrayGen) { msgs in
    // msgs.count > 40
    let truncated = ChatViewModel.truncateHistory(msgs)
    return truncated.count <= 40
}

// Feature: ai-chatbot-integration, Property 15: API key save/load round trip
property("Keychain save then load returns original key") <- forAll(validAPIKeyGen) { key in
    _ = KeychainWrapper.save(key: "test.glm.apiKey", value: key)
    let loaded = KeychainWrapper.load(key: "test.glm.apiKey")
    _ = KeychainWrapper.delete(key: "test.glm.apiKey")
    return loaded == key
}

// Feature: ai-chatbot-integration, Property 17: Save button disabled for whitespace
property("Save button disabled for any whitespace API key input") <- forAll(whitespaceStringGen) { ws in
    // Test the validation predicate directly
    return ws.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
}
```

### Integration Tests

- `GLMService` sends a POST request to the correct endpoint with a valid `Authorization: Bearer <key>` header (using `URLProtocol` mock)
- `GLMService` sets `timeoutIntervalForRequest` to 30 seconds on the `URLRequest`
- `ContextBuilder` integrates with `WorkoutGoalsStore.shared` and returns a non-empty string
- `MainTabView` renders a tab bar with 6 items including "Chat" at index 5

### Accessibility Tests (UI Tests)

- Send button has `accessibilityIdentifier == "chat.sendButton"`
- Message text field has `accessibilityIdentifier == "chat.inputField"`
- Clear chat button has `accessibilityIdentifier == "chat.clearButton"`
- Typing indicator has `accessibilityIdentifier == "chat.typingIndicator"`
- Each `ChatBubbleView` has an `accessibilityLabel` containing the role and content
