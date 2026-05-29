# Requirements Document

## Introduction

This feature adds an AI-powered fitness coaching chatbot to the PULSE FitnessApp. The chatbot communicates with the GLM API (z.ai, OpenAI-compatible REST endpoint) and is context-aware of the user's live in-app data — including workout history, rep goals, streaks, calorie intake/burn, and AI-generated workout recommendations. Users can ask natural-language questions about exercise selection, rep targets, calorie goals, and progress. The chatbot is accessible via a dedicated Chat tab in the main tab bar. The API key is stored securely in the iOS Keychain and is never hardcoded.

---

## Glossary

- **Chatbot**: The AI-powered conversational interface within the app.
- **ChatViewModel**: The ObservableObject ViewModel that manages chat state, context assembly, and API communication.
- **ChatMessage**: A value type representing a single message in the conversation (role: user or assistant, content: string, timestamp).
- **ContextBuilder**: The component responsible for assembling the structured fitness context snapshot from in-app data sources.
- **FitnessContext**: A structured snapshot of the user's current fitness data passed to the GLM API as a system prompt.
- **GLMService**: The networking layer that sends requests to the GLM API endpoint and decodes responses.
- **GLMAPIKey**: The Bearer token used to authenticate with the GLM API, stored in the Keychain under a fixed key.
- **KeychainWrapper**: The existing secure storage utility (`Core/Keychain/KeychainWrapper.swift`).
- **WorkoutGoalsStore**: The existing store tracking `dailyRepGoal`, `todayReps`, `currentStreak`, `bestStreak`, and `last7Days()`.
- **CalorieGoalViewModel**: The existing ViewModel tracking `dailyGoal`, `consumed`, and `burned` calorie values.
- **WorkoutRecommendationEngine**: The existing engine that generates workout type and duration recommendations.
- **HealthKitManager**: The existing manager that fetches today's active energy burned from HealthKit.
- **WorkoutLog**: The CoreData entity representing a completed workout session (type, duration, date).
- **APIKeySettingsView**: The settings sub-view where the user enters and saves the GLM API key.
- **ChatView**: The main SwiftUI view for the chat interface.
- **System Prompt**: The initial message sent to the GLM API that establishes the AI's role and injects the FitnessContext.
- **Message Turn**: One user ChatMessage paired with one assistant ChatMessage (2 items total). Used to define the 20-turn history cap.

---

## Requirements

### Requirement 1: Dedicated Chat Tab

**User Story:** As a user, I want a dedicated Chat tab in the main tab bar, so that I can access the AI fitness coach from anywhere in the app.

#### Acceptance Criteria

1. THE MainTabView SHALL display a "Chat" tab with the system image `message.fill` as the sixth tab in the tab bar, positioned after the existing five tabs (Home, Workout, Camera, Calories, Profile).
2. WHEN the user taps the Chat tab, THE ChatView SHALL be presented wrapped in a `NavigationStack` as the root view of that tab, with no other view pushed on the stack.
3. THE AppRouter SHALL include a `chat` case with raw string value `"chat"` in its `AppTab` enum, enabling deep links via the URL `fitnessapp://tab/chat` to programmatically select the Chat tab.

---

### Requirement 2: Chat Conversation Interface

**User Story:** As a user, I want a scrollable chat interface with distinct message bubbles for my messages and the AI's responses, so that I can read the conversation clearly.

#### Acceptance Criteria

1. THE ChatView SHALL display a vertically scrollable list of ChatMessage items, with user messages right-aligned and assistant messages left-aligned.
2. THE ChatView SHALL display a text input field and a send button at the bottom of the screen.
3. WHEN the user taps the send button or submits the text field, THE ChatView SHALL scroll to the most recently added message automatically AND SHALL clear the text input field.
4. WHILE a response is being fetched from the GLM API, THE ChatView SHALL display a typing indicator (e.g., animated ellipsis) in the assistant message position. IF the API call fails, THEN THE ChatView SHALL dismiss the typing indicator and display the error message in its place.
5. THE ChatView SHALL use only colors defined in `Color+Theme.swift` (no hardcoded hex values).
6. WHEN the conversation message list is empty, THE ChatView SHALL display a welcome message prompting the user to ask a fitness question.
7. THE ChatView SHALL provide a "Clear Chat" button that removes all ChatMessage items from the current in-memory session list; cleared messages SHALL NOT be persisted or recoverable after clearing.
8. WHEN the user taps the send button or submits the text field and the input text is empty or contains only whitespace, THE ChatView SHALL NOT send a message and SHALL NOT call the GLM API.
9. THE text input field SHALL enforce a maximum of 1000 characters; WHEN the user attempts to type beyond 1000 characters, THE ChatView SHALL prevent additional input and MAY display a character count indicator.

---

### Requirement 3: Context-Aware System Prompt

**User Story:** As a user, I want the AI to know my current fitness data before I say anything, so that its answers are relevant to my actual progress and goals.

#### Acceptance Criteria

1. WHEN the user sends a message, THE ContextBuilder SHALL assemble a FitnessContext snapshot containing: today's rep count, daily rep goal, current streak, best streak, last 7 days of rep data, calorie daily goal, calories consumed today, calories burned today, the top 3 workout recommendations (type and duration), and up to 5 most recent WorkoutLog entries (type, duration, date) — including fewer than 5 if that is all that exists.
2. THE GLMService SHALL prepend the FitnessContext as a system-role message before the conversation history in every API request.
3. THE System Prompt SHALL instruct the AI to act as a personal fitness coach named "PULSE AI", to reference the provided data when answering, and to keep responses to 150 words or fewer unless the user explicitly requests a longer explanation.
4. IF HealthKit data is unavailable (authorization denied or fetch throws an error), THEN THE ContextBuilder SHALL substitute a value of 0 kcal for burned calories and include the note "HealthKit data unavailable" in the FitnessContext.
5. IF CoreData returns no WorkoutLog entries, THEN THE ContextBuilder SHALL include the note "No workout history recorded." in the FitnessContext.
6. WHEN CoreData returns one or more WorkoutLog entries, THE ContextBuilder SHALL include a note in the FitnessContext stating the count (e.g., "5 recent workout entries found.").
7. IF the CoreData fetch for WorkoutLog entries throws an error, THEN THE ContextBuilder SHALL include the note "Workout history unavailable." in the FitnessContext and SHALL NOT propagate the error to the caller.

---

### Requirement 4: GLM API Communication

**User Story:** As a user, I want the chatbot to send my messages to the GLM API and display the AI's response, so that I receive intelligent fitness coaching.

#### Acceptance Criteria

1. WHEN the user sends a message, THE GLMService SHALL send an HTTP POST request to `https://api.z.ai/api/paas/v4/chat/completions` with the model set to `glm-4-flash`, the full conversation history (system prompt + prior turns + new user message), and a `Bearer` Authorization header using the stored GLMAPIKey.
2. WHEN the GLM API returns HTTP 200, THE GLMService SHALL decode the JSON response body and extract the assistant's reply text from `choices[0].message.content`. IF the field is missing or decoding fails, THEN THE ChatViewModel SHALL display the message "Failed to parse AI response.", re-enable the input field, and remove the typing indicator.
3. IF the GLM API returns an HTTP error status (4xx or 5xx), THEN THE ChatViewModel SHALL display an error message identifying the HTTP status code (e.g., "Request failed (401). Check your API key."), re-enable the input field, and remove the typing indicator.
4. IF the network request does not complete within 30 seconds, THEN THE ChatViewModel SHALL display the message "Request timed out. Please try again.", re-enable the input field, and remove the typing indicator.
5. THE GLMService SHALL use `URLSession` with Swift concurrency (`async/await`) and SHALL NOT use callback-based networking.
6. THE ChatViewModel SHALL append the user's ChatMessage to the conversation list immediately upon submission, before the API response is received.

---

### Requirement 5: Secure API Key Storage

**User Story:** As a user, I want my GLM API key stored securely on my device, so that it is never exposed in the app bundle or source code.

#### Acceptance Criteria

1. THE GLMService SHALL always call `KeychainWrapper.load(key: "glm.apiKey")` to retrieve the GLMAPIKey at the time of each API request, regardless of whether a key is expected to be present.
2. THE APIKeySettingsView SHALL provide a `SecureField` for the user to enter the GLMAPIKey. THE Save button SHALL be disabled WHEN the field is empty or contains only whitespace. WHEN the user taps Save with a non-empty value, THE view SHALL call `KeychainWrapper.save(key: "glm.apiKey", value:)`.
3. IF the GLMAPIKey is not present in the Keychain when the user attempts to send a message, THEN THE ChatViewModel SHALL NOT call the GLM API and SHALL display an alert directing the user to navigate to Settings → "AI Coach API Key" to configure the key.
4. THE GLMAPIKey SHALL NOT be hardcoded anywhere in the source code, including test files and configuration files.
5. WHEN `KeychainWrapper.save` succeeds, THE APIKeySettingsView SHALL display the confirmation text "Key saved ✓" for 3 seconds, then hide it, without echoing the key value.
6. IF `KeychainWrapper.save` returns a failure result, THEN THE APIKeySettingsView SHALL display the error message "Failed to save key. Please try again." without echoing the key value.

---

### Requirement 6: Conversation History Management

**User Story:** As a user, I want the chatbot to remember the context of our conversation within a session, so that I can ask follow-up questions without repeating myself.

#### Acceptance Criteria

1. THE ChatViewModel SHALL maintain the full ordered list of ChatMessage items for the current session in memory as a `@Published` array.
2. WHEN the user sends a new message and prior ChatMessage items exist (excluding the system prompt), THE GLMService SHALL include those prior items as the conversation history in the API request body. IF no prior messages exist, THEN THE GLMService SHALL include exactly zero history items in the request body.
3. IF the in-memory conversation contains more than 20 message turns (where one turn = one user ChatMessage + one assistant ChatMessage = 2 items, i.e., more than 40 ChatMessage items), THEN THE ChatViewModel SHALL send only the most recent 20 turns (40 items) to the API while continuing to display the full history in the UI.
4. WHEN the user taps "Clear Chat", THE ChatViewModel SHALL reset the in-memory message list to an empty array; the next API call SHALL include exactly zero history items (only the system prompt and the new user message).
5. THE ChatViewModel SHALL NOT write conversation history to CoreData, UserDefaults, or any other persistent store; the history SHALL be lost when the app is terminated or the ChatViewModel is deallocated.

---

### Requirement 7: API Key Settings Integration

**User Story:** As a user, I want to enter and update my GLM API key from the app's Settings screen, so that I can configure the chatbot without leaving the app.

#### Acceptance Criteria

1. THE SettingsView SHALL include a `NavigationLink` to the APIKeySettingsView with the label "AI Coach API Key".
2. WHEN the APIKeySettingsView appears (`.onAppear`), THE view SHALL call `KeychainWrapper.load(key: "glm.apiKey")` and display "Not configured" IF the result is `nil`, or "Configured ✓" IF the result is non-nil.
3. WHEN the user saves a new key via APIKeySettingsView, THE KeychainWrapper SHALL overwrite any previously stored value for `"glm.apiKey"` using `KeychainWrapper.save(key:value:)`.
4. THE APIKeySettingsView SHALL provide a "Remove Key" button that calls `KeychainWrapper.delete(key: "glm.apiKey")`.
5. WHEN the user taps "Remove Key" and the delete succeeds, THE APIKeySettingsView SHALL update the displayed status to "Not configured" within one rendering cycle. WHEN the user successfully saves a new key, THE APIKeySettingsView SHALL update the displayed status to "Configured ✓" within one rendering cycle.
6. THE `SecureField` used for key entry in APIKeySettingsView SHALL have `textContentType` set to `.password` so that the system treats the input as sensitive and does not offer autocomplete suggestions.
7. IF `KeychainWrapper.delete` returns a failure result, THEN THE APIKeySettingsView SHALL display the error message "Failed to remove key. Please try again." and SHALL NOT update the displayed status.
8. IF `KeychainWrapper.save` returns a failure result during key update, THEN THE APIKeySettingsView SHALL display the error message "Failed to save key. Please try again." and SHALL NOT update the displayed status to "Configured ✓".

---

### Requirement 8: SwiftUI and Architecture Compliance

**User Story:** As a developer, I want the chatbot feature to follow the app's established SwiftUI and architecture standards, so that the codebase remains consistent and maintainable.

#### Acceptance Criteria

1. THE ChatViewModel SHALL be declared as `@MainActor final class ChatViewModel: ObservableObject` and SHALL use `@Published` properties for all state exposed to the view; no state SHALL be computed or derived inside the `body` property of ChatView.
2. THE ChatView `body` SHALL contain only layout, view composition, and data-binding expressions. It SHALL NOT contain: network calls, CoreData fetch requests, Keychain reads or writes, or conditional branching that determines which API to call. All such logic SHALL reside in ChatViewModel or its dependencies.
3. THE ChatView SHALL use `NavigationStack` for any push navigation within the Chat tab and SHALL NOT use `NavigationView`.
4. THE GLMService SHALL contain no `import SwiftUI` statement, enabling it to be compiled and tested independently of the SwiftUI framework.
5. THE ChatView SHALL use `.onChange(of:perform:)` (iOS 16 form) and SHALL NOT use the two-parameter `.onChange(of:initial:)` form available only on iOS 17+.
6. THE ChatView SHALL provide `accessibilityLabel` and `accessibilityIdentifier` on the following elements as a minimum: the send button, the message text field, the clear chat button, each message bubble (labeled with role and content), and the typing indicator.
7. THE ChatViewModel SHALL expose an `errorMessage: String?` published property; THE ChatView SHALL present a SwiftUI `.alert` modifier bound to a non-nil `errorMessage` value, and SHALL reset `errorMessage` to `nil` when the alert is dismissed.
