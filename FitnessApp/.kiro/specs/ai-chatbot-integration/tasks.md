# Implementation Plan: AI Chatbot Integration

## Overview

Implement a context-aware AI fitness coaching chatbot powered by the GLM API (z.ai). The feature is built in seven layers: data models → pure service layer → ViewModel → UI components → settings integration → navigation wiring → tests. All new code lives under `Features/Chat/`; three existing files receive targeted modifications.

---

## Tasks

- [ ] 1. Define data models and Codable structs
  - [ ] 1.1 Create `ChatMessage.swift`
    - Define `ChatRole` enum with cases `.user`, `.assistant`, `.system` and `String` raw values conforming to `Codable`
    - Define `ChatMessage` struct conforming to `Identifiable` and `Equatable` with fields: `id: UUID`, `role: ChatRole`, `content: String`, `timestamp: Date`
    - Add a memberwise `init` with default values for `id` and `timestamp`
    - File: `FitnessApp/Features/Chat/ChatMessage.swift`
    - _Requirements: 2.1, 4.6, 6.1_

  - [ ] 1.2 Create GLM Codable request/response structs inside `GLMService.swift`
    - Define `GLMRequest: Encodable` with `model: String` and `messages: [GLMMessagePayload]`
    - Define `GLMMessagePayload: Codable` with `role: String` and `content: String`
    - Define `GLMResponse: Decodable` with `choices: [GLMChoice]`
    - Define `GLMChoice: Decodable` with `message: GLMMessagePayload`
    - Add `extension ChatMessage { var asPayload: GLMMessagePayload }` mapping `role.rawValue` → `role`
    - File: `FitnessApp/Features/Chat/GLMService.swift` (initial scaffold — no `import SwiftUI`)
    - _Requirements: 4.1, 4.2, 8.4_

  - [ ]* 1.3 Write property test for GLM response decoding round trip
    - **Property 10: GLM response decoding round trip**
    - For any non-empty assistant content string, encode into `GLMResponse` JSON and decode — must return the original string
    - **Validates: Requirements 4.2**

- [ ] 2. Implement `GLMService` networking
  - [ ] 2.1 Implement `GLMService.sendMessage(messages:apiKey:)` using `async/await`
    - Define `GLMError` enum: `.missingAPIKey`, `.httpError(Int)`, `.decodingFailed`, `.timeout`, `.networkError(Error)` with `LocalizedError` conformance and human-readable `errorDescription` strings (include status code in `.httpError` description)
    - Configure `URLRequest` to `https://api.z.ai/api/paas/v4/chat/completions` with `timeoutIntervalForRequest = 30`, `httpMethod = "POST"`, `Content-Type: application/json`, `Authorization: Bearer <apiKey>`
    - Encode `GLMRequest(model: "glm-4-flash", messages:)` as the request body
    - Use `URLSession.shared.data(for:)` — no callbacks
    - Check `HTTPURLResponse.statusCode`; throw `GLMError.httpError(code)` for any code outside 200–299
    - Decode `GLMResponse`; throw `GLMError.decodingFailed` if `choices` is empty or decoding fails
    - Map `URLError(.timedOut)` to `GLMError.timeout`
    - File: `FitnessApp/Features/Chat/GLMService.swift`
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 8.4_

  - [ ]* 2.2 Write unit tests for `GLMService` decoding and error mapping
    - Decoding a valid `GLMResponse` JSON extracts `choices[0].message.content` correctly
    - Decoding a `GLMResponse` with empty `choices` array throws `decodingFailed`
    - HTTP 401 response produces `GLMError.httpError(401)` with message containing "401"
    - HTTP 500 response produces `GLMError.httpError(500)` with message containing "500"
    - Timeout produces `GLMError.timeout` with the expected message
    - Verify `GLMService.swift` has no `import SwiftUI` statement
    - _Requirements: 4.2, 4.3, 4.4, 8.4_

  - [ ]* 2.3 Write property test for HTTP error status code in error message
    - **Property 11: HTTP error status code appears in error message**
    - For any HTTP status code in 400–599, `GLMError.httpError(code).errorDescription` must contain the decimal representation of that code
    - **Validates: Requirements 4.3**

- [ ] 3. Implement `ContextBuilder`
  - [ ] 3.1 Create `ContextBuilder.swift` with `buildContext() async -> String`
    - Declare `ContextBuilder` as a pure `struct` with no stored properties (all data sources accessed via their singletons/shared instances inside the method)
    - Fetch `WorkoutGoalsStore.shared` values: `dailyRepGoal`, `todayReps`, `currentStreak`, `bestStreak`, `last7Days()`
    - Instantiate `CalorieGoalViewModel`, call `await loadTodayData()`, then read `dailyGoal`, `consumed`, `burned`
    - Wrap `HealthKitManager.shared.fetchTodayActiveEnergy()` in `do/catch`; on failure substitute `burned = 0` and append `"HealthKit data unavailable"` — do not rethrow
    - Fetch up to 5 most recent `WorkoutLog` entries from `PersistenceController.shared` in a `do/catch`; on failure append `"Workout history unavailable."` — do not rethrow; on empty result append `"No workout history recorded."`; on success append `"{N} recent workout entries found."`
    - Generate top-3 recommendations via `WorkoutRecommendationEngine()`
    - Assemble the FitnessContext string using the exact template from the design document (sections: FITNESS SNAPSHOT, GOALS & STREAKS, LAST 7 DAYS, CALORIES, WORKOUT RECOMMENDATIONS, RECENT WORKOUTS)
    - File: `FitnessApp/Features/Chat/ContextBuilder.swift`
    - _Requirements: 3.1, 3.3, 3.4, 3.5, 3.6, 3.7_

  - [ ]* 3.2 Write unit tests for `ContextBuilder`
    - With all data sources healthy, output contains "PULSE AI" and "150 words"
    - With HealthKit error, output contains "HealthKit data unavailable" and burned = 0
    - With CoreData error, output contains "Workout history unavailable."
    - With empty `WorkoutLog` array, output contains "No workout history recorded."
    - With 3 `WorkoutLog` entries, output contains "3 recent workout entries found."
    - `buildContext()` completes without throwing regardless of data source failures
    - _Requirements: 3.1, 3.3, 3.4, 3.5, 3.6, 3.7_

  - [ ]* 3.3 Write property test: FitnessContext contains all required fields
    - **Property 6: FitnessContext contains all required fields**
    - For any combination of fitness data inputs, `buildContext()` output must contain: "PULSE AI", "150 words", the daily rep goal value, today's rep count, current streak, best streak, daily calorie goal, consumed calories, a burned calories value or "HealthKit data unavailable", and at least one workout recommendation entry
    - **Validates: Requirements 3.1, 3.3, 3.4**

  - [ ]* 3.4 Write property test: workout history count note is accurate
    - **Property 8: Workout history count note is accurate**
    - For any non-empty array of `WorkoutLog` entries of size N (1 ≤ N ≤ 5), `buildContext()` must return a string containing the exact count N in the workout history note
    - **Validates: Requirements 3.6**

  - [ ]* 3.5 Write property test: ContextBuilder never throws
    - **Property 9: ContextBuilder never throws**
    - For any combination of data source failures (HealthKit error, CoreData error, or both), `buildContext()` must complete without throwing and must return a string containing the appropriate fallback notes
    - **Validates: Requirements 3.4, 3.7**

- [ ] 4. Checkpoint — Pure layer complete
  - Ensure `ChatMessage`, `GLMService`, and `ContextBuilder` compile cleanly with no SwiftUI imports in `GLMService.swift`. Ensure all tests pass, ask the user if questions arise.

- [ ] 5. Implement `ChatViewModel`
  - [ ] 5.1 Create `ChatViewModel.swift`
    - Declare `@MainActor final class ChatViewModel: ObservableObject`
    - Add `@Published` properties: `messages: [ChatMessage] = []`, `inputText: String = ""`, `isSending: Bool = false`, `errorMessage: String?`
    - Inject `GLMService` and `ContextBuilder` as private stored properties (default-initialized, allowing injection for tests)
    - Implement `sendMessage() async`:
      1. Guard `inputText` is not blank (trim whitespace); return without side effects if empty
      2. Guard `KeychainWrapper.load(key: "glm.apiKey") != nil`; if nil set `errorMessage` to the missing-key message and return — do not call `GLMService`
      3. Capture and clear `inputText`
      4. Append `ChatMessage(role: .user, content: capturedText)` to `messages` immediately
      5. Set `isSending = true`
      6. `await ContextBuilder().buildContext()` to get the system prompt string
      7. Build the API messages array: `[system(context)] + messages.suffix(40)` (most recent 40 items)
      8. Call `await glmService.sendMessage(messages:apiKey:)`; on success append assistant `ChatMessage`; on failure set `errorMessage`
      9. Set `isSending = false`
    - Implement `clearChat()`: reset `messages = []`
    - Expose `static func truncateHistory(_ messages: [ChatMessage]) -> [ChatMessage]` returning the last 40 items (used by property test)
    - File: `FitnessApp/Features/Chat/ChatViewModel.swift`
    - _Requirements: 2.3, 2.7, 2.8, 4.6, 5.3, 6.1, 6.2, 6.3, 6.4, 6.5, 8.1, 8.2, 8.7_

  - [ ]* 5.2 Write unit tests for `ChatViewModel`
    - `sendMessage()` with empty string does not append to `messages`
    - `sendMessage()` with whitespace-only string does not append to `messages`
    - `sendMessage()` with nil API key sets `errorMessage` and does not call `GLMService`
    - `sendMessage()` with valid input appends user message before API response
    - `clearChat()` resets `messages` to `[]`
    - `isSending` is `true` during API call and `false` after completion
    - `errorMessage` is set on HTTP error, decode failure, and timeout
    - _Requirements: 2.3, 2.7, 2.8, 4.6, 5.3, 6.1, 6.4_

  - [ ]* 5.3 Write property test: whitespace input is rejected
    - **Property 3: Whitespace input is rejected**
    - For any string composed entirely of whitespace characters (including empty string), `sendMessage()` must not append any message to `messages` and must not invoke `GLMService`
    - **Validates: Requirements 2.8**

  - [ ]* 5.4 Write property test: input cleared after send
    - **Property 2: Input cleared after send**
    - For any non-empty, non-whitespace string set as `inputText`, after `sendMessage()` is called, `inputText` must equal the empty string
    - **Validates: Requirements 2.3**

  - [ ]* 5.5 Write property test: clear chat produces empty message list
    - **Property 5: Clear chat produces empty message list**
    - For any non-empty `messages` array, calling `clearChat()` must result in `messages` being an empty array
    - **Validates: Requirements 2.7, 6.4**

  - [ ]* 5.6 Write property test: user message appended immediately and ordering preserved
    - **Property 12: User message appended immediately and ordering preserved**
    - For any sequence of non-empty messages sent via `sendMessage()`, each user message must appear in `messages` immediately after the call (before the API response arrives), and the overall `messages` array must preserve insertion order
    - **Validates: Requirements 4.6, 6.1**

  - [ ]* 5.7 Write property test: conversation history included in API payload
    - **Property 13: Conversation history included in API payload**
    - For any non-empty `messages` array with ≤ 40 items, the messages array constructed for the GLM API request must include all prior messages after the system prompt
    - **Validates: Requirements 6.2**

  - [ ]* 5.8 Write property test: history truncated to 20 turns (40 messages) for API
    - **Property 14: History truncated to 40 messages**
    - For any `messages` array containing more than 40 items, `ChatViewModel.truncateHistory(_:)` must return exactly 40 items — the most recent 40
    - **Validates: Requirements 6.3**

  - [ ]* 5.9 Write property test: system message is always first in API payload
    - **Property 7: System message is always first in API payload**
    - For any array of prior `ChatMessage` values (including empty), the first element in the messages array sent to the GLM API must have role `"system"` and must contain the FitnessContext string
    - **Validates: Requirements 3.2**

- [ ] 6. Checkpoint — ViewModel layer complete
  - Ensure all `ChatViewModel` tests pass. Verify `isSending` transitions correctly and `errorMessage` is set for all error paths. Ask the user if questions arise.

- [ ] 7. Implement UI components
  - [ ] 7.1 Create `ChatBubbleView.swift`
    - Declare `struct ChatBubbleView: View` with a single `let message: ChatMessage` property
    - User messages (`.user`): right-aligned, `themePrimary` background, white foreground, `cornerRadiusSmall` corners with flat bottom-right corner
    - Assistant messages (`.assistant`): left-aligned, `themeSurface` background, primary foreground, `cornerRadiusSmall` corners with flat bottom-left corner
    - Add `accessibilityLabel` combining role and content (e.g., "User: <content>" / "Assistant: <content>")
    - Add `accessibilityIdentifier` using pattern `"chat.bubble.<message.id>"`
    - Use only colors from `Color+Theme.swift`; no hardcoded hex values
    - File: `FitnessApp/Features/Chat/ChatBubbleView.swift`
    - _Requirements: 2.1, 2.5, 8.6_

  - [ ]* 7.2 Write property test: message alignment by role
    - **Property 1: Message alignment by role**
    - For any array of `ChatMessage` values, every `.user` message must be right-aligned and every `.assistant` message must be left-aligned in the rendered bubble
    - **Validates: Requirements 2.1**

  - [ ] 7.3 Create `ChatView.swift`
    - Declare `struct ChatView: View` with `@StateObject private var viewModel = ChatViewModel()`
    - Wrap content in `NavigationStack` (iOS 16+, not `NavigationView`)
    - Scrollable message list using `ScrollViewReader` + `ScrollView` + `LazyVStack`; use `LazyVStack` since the list can exceed 20 items
    - Render each `ChatMessage` via `ChatBubbleView`; skip system-role messages
    - When `messages` is empty (excluding system messages), display a welcome prompt asking the user to ask a fitness question
    - When `isSending == true`, display a typing indicator (animated ellipsis) in the assistant position with `accessibilityIdentifier = "chat.typingIndicator"`
    - On API failure, dismiss the typing indicator and display the error via `.alert` bound to `viewModel.errorMessage != nil`; dismiss action sets `viewModel.errorMessage = nil`
    - Bottom input bar: `TextField` bound to `viewModel.inputText` with `accessibilityLabel = "Message input"` and `accessibilityIdentifier = "chat.inputField"`; enforce 1000-character max using `.onChange(of: viewModel.inputText, perform:)` (iOS 16 form — NOT the two-parameter iOS 17 form); optionally show character count when near limit
    - Send button: disabled when `viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending`; `accessibilityLabel = "Send message"`, `accessibilityIdentifier = "chat.sendButton"`; on tap call `Task { await viewModel.sendMessage() }`
    - Scroll to the latest message after appending using `.onChange(of: viewModel.messages.count, perform:)` with `ScrollViewReader.scrollTo(_:anchor: .bottom)`
    - "Clear Chat" toolbar button: `accessibilityLabel = "Clear chat"`, `accessibilityIdentifier = "chat.clearButton"`; calls `viewModel.clearChat()`
    - Use only colors from `Color+Theme.swift`
    - File: `FitnessApp/Features/Chat/ChatView.swift`
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9, 8.1, 8.2, 8.3, 8.5, 8.6, 8.7_

  - [ ]* 7.4 Write property test: input length capped at 1000 characters
    - **Property 4: Input length capped at 1000 characters**
    - For any string of length greater than 1000 characters, the `inputText` binding enforcement logic must not allow the string to exceed 1000 characters
    - **Validates: Requirements 2.9**

- [ ] 8. Implement `APIKeySettingsView`
  - [ ] 8.1 Create `APIKeySettingsView.swift`
    - Declare `struct APIKeySettingsView: View` with all state as local `@State` (no ViewModel)
    - `@State private var keyInput: String = ""`
    - `@State private var keyStatus: String = "Not configured"` — updated on `.onAppear` by calling `KeychainWrapper.load(key: "glm.apiKey")`: set to `"Configured ✓"` if non-nil, `"Not configured"` if nil
    - `@State private var feedbackMessage: String?` — shown for 3 seconds after save/delete operations
    - `SecureField` bound to `keyInput` with `textContentType = .password`; enforces no autocomplete
    - Save button: disabled when `keyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty`; on tap call `KeychainWrapper.save(key: "glm.apiKey", value: keyInput)`: on success display `"Key saved ✓"` for 3 seconds then hide (use `Task { try? await Task.sleep(...); feedbackMessage = nil }`), update `keyStatus` to `"Configured ✓"`, clear `keyInput`; on failure display `"Failed to save key. Please try again."` and do not update `keyStatus`
    - "Remove Key" button: calls `KeychainWrapper.delete(key: "glm.apiKey")`; on success update `keyStatus` to `"Not configured"`; on failure display `"Failed to remove key. Please try again."`
    - Display `keyStatus` label (not the key value itself)
    - Use `NavigationStack` title "AI Coach API Key"
    - File: `FitnessApp/Features/Chat/APIKeySettingsView.swift`
    - _Requirements: 5.1, 5.2, 5.5, 5.6, 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7, 7.8_

  - [ ]* 8.2 Write unit tests for `APIKeySettingsView` logic
    - On appear with no Keychain key, status displays "Not configured"
    - On appear with existing Keychain key, status displays "Configured ✓"
    - Save button is disabled when `SecureField` is empty or whitespace-only
    - Tapping Save calls `KeychainWrapper.save(key: "glm.apiKey", value:)`
    - Tapping Remove Key calls `KeychainWrapper.delete(key: "glm.apiKey")`
    - On successful delete, status updates to "Not configured"
    - On failed save, error message is displayed and status does not change to "Configured ✓"
    - _Requirements: 5.2, 5.5, 5.6, 7.2, 7.5, 7.7, 7.8_

  - [ ]* 8.3 Write property test: save button disabled for whitespace API key input
    - **Property 17: Save button disabled for whitespace API key input**
    - For any string composed entirely of whitespace characters (including empty string) entered into the `SecureField`, the Save button must be disabled
    - **Validates: Requirements 5.2**

  - [ ]* 8.4 Write property test: API key save/load round trip
    - **Property 15: API key save/load round trip**
    - For any non-empty, non-whitespace string used as an API key, `KeychainWrapper.save(key: "glm.apiKey", value:)` followed by `KeychainWrapper.load(key: "glm.apiKey")` must return the original string; clean up with `KeychainWrapper.delete` after each test run
    - **Validates: Requirements 7.3**

  - [ ]* 8.5 Write property test: key status display reflects Keychain state
    - **Property 16: Key status display reflects Keychain state**
    - For any Keychain state (key present or absent), the status text must be "Configured ✓" when `KeychainWrapper.load` returns non-nil, and "Not configured" when it returns nil — within one rendering cycle of the state change
    - **Validates: Requirements 7.5**

- [ ] 9. Checkpoint — Feature components complete
  - Ensure `ChatBubbleView`, `ChatView`, and `APIKeySettingsView` compile cleanly. Verify all accessibility identifiers are present. Ensure all tests pass. Ask the user if questions arise.

- [ ] 10. Wire navigation — AppRouter and MainTabView
  - [ ] 10.1 Add `.chat` case to `AppTab` enum in `AppRouter.swift`
    - Add `case chat` with raw string value `"chat"` to the `AppTab` enum (after `progress`)
    - The existing `handleDeepLink(_:)` method will automatically support `fitnessapp://tab/chat` with no further changes
    - File: `FitnessApp/Core/Navigation/AppRouter.swift`
    - _Requirements: 1.3_

  - [ ] 10.2 Add `chatTab` to `MainTabView.swift`
    - Add `private var chatTab: some View` computed property: `NavigationStack { ChatView() }` tagged `.tabItem { Label("Chat", systemImage: "message.fill") }.tag(AppRouter.AppTab.chat)`
    - Add `chatTab` to the `TabView` body after `profileTab` (sixth position)
    - File: `FitnessApp/App/MainTabView.swift`
    - _Requirements: 1.1, 1.2_

  - [ ]* 10.3 Write unit tests for `AppRouter` chat tab
    - `AppTab.chat.rawValue == "chat"`
    - `handleDeepLink(URL(string: "fitnessapp://tab/chat")!)` sets `selectedTab == .chat`
    - _Requirements: 1.3_

- [ ] 11. Wire settings — SettingsView modification
  - [ ] 11.1 Add `NavigationLink` to `APIKeySettingsView` in `SettingsView.swift`
    - Add a `NavigationLink` to `APIKeySettingsView` inside the `workoutSection` (or a new "AI" section if preferred for clarity), using `listRowContent(icon: "key.fill", title: "AI Coach API Key", subtitle: "Configure GLM API access", trailingChevron: true).padding(.vertical, 14)` as the label
    - Apply `.buttonStyle(.plain)` to the `NavigationLink`
    - File: `FitnessApp/Features/Profile/SettingsView.swift`
    - _Requirements: 7.1_

- [ ] 12. Final checkpoint — Full integration
  - Build the project and confirm zero compile errors. Verify the Chat tab appears as the sixth tab with `message.fill` icon. Verify navigating to Settings → "AI Coach API Key" opens `APIKeySettingsView`. Ensure all tests pass. Ask the user if questions arise.

- [ ] 13. Integration and accessibility tests
  - [ ]* 13.1 Write integration test: GLMService sends correct request shape
    - Use `URLProtocol` mock to intercept the outbound request
    - Verify POST to `https://api.z.ai/api/paas/v4/chat/completions`
    - Verify `Authorization: Bearer <key>` header is present
    - Verify `timeoutIntervalForRequest == 30`
    - _Requirements: 4.1, 4.4, 4.5_

  - [ ]* 13.2 Write integration test: ContextBuilder integrates with live stores
    - Call `ContextBuilder().buildContext()` with `WorkoutGoalsStore.shared` populated
    - Verify the returned string is non-empty and contains "PULSE AI"
    - _Requirements: 3.1, 3.3_

  - [ ]* 13.3 Write integration test: MainTabView renders 6 tabs including Chat
    - Render `MainTabView` in a test host with `AppRouter` injected
    - Verify the tab bar contains exactly 6 items and the sixth item is labelled "Chat"
    - _Requirements: 1.1_

  - [ ]* 13.4 Write UI accessibility tests
    - Verify send button has `accessibilityIdentifier == "chat.sendButton"`
    - Verify message text field has `accessibilityIdentifier == "chat.inputField"`
    - Verify clear chat button has `accessibilityIdentifier == "chat.clearButton"`
    - Verify typing indicator has `accessibilityIdentifier == "chat.typingIndicator"`
    - Verify each `ChatBubbleView` has an `accessibilityLabel` containing the role and content
    - _Requirements: 8.6_

---

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP delivery
- All property-based tests use **SwiftCheck** with a minimum of 100 iterations per property
- Tag format for each property test: `// Feature: ai-chatbot-integration, Property N: <property text>`
- `GLMService.swift` must never contain `import SwiftUI` — this is a hard architectural constraint (Requirement 8.4)
- Use `.onChange(of:perform:)` (iOS 16 form) everywhere in `ChatView` — the two-parameter `.onChange(of:initial:)` form is iOS 17+ only
- `CalorieGoalViewModel` is instantiated fresh inside `ContextBuilder.buildContext()` — it is not a singleton
- The GLM API key is stored exclusively under Keychain key `"glm.apiKey"` — never hardcoded
- Conversation history is in-memory only; no CoreData or UserDefaults persistence for chat messages

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2"] },
    { "id": 1, "tasks": ["1.3", "2.1"] },
    { "id": 2, "tasks": ["2.2", "2.3", "3.1"] },
    { "id": 3, "tasks": ["3.2", "3.3", "3.4", "3.5", "5.1"] },
    { "id": 4, "tasks": ["5.2", "5.3", "5.4", "5.5", "5.6", "5.7", "5.8", "5.9", "7.1"] },
    { "id": 5, "tasks": ["7.2", "7.3", "8.1"] },
    { "id": 6, "tasks": ["7.4", "8.2", "8.3", "8.4", "8.5", "10.1"] },
    { "id": 7, "tasks": ["10.2", "11.1"] },
    { "id": 8, "tasks": ["10.3", "13.1", "13.2", "13.3", "13.4"] }
  ]
}
```
