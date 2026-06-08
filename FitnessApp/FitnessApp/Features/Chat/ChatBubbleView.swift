import SwiftUI

/// Renders a single chat message bubble.
/// User messages are right-aligned with a brand-colored background;
/// assistant messages are left-aligned with a surface background.
/// If the assistant message contains an actionPayload, an interactive button
/// is rendered below the text.
/// Error bubbles (isError) are shown with a warning style and retry button.
struct ChatBubbleView: View {

    let message: ChatMessage
    /// Callback when an action button is tapped. Receives the action payload.
    var onAction: ((ChatActionPayload) -> Void)?
    /// Callback when retry is tapped (for error bubbles).
    var onRetry: (() -> Void)?

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
                // Error icon header
                if message.isError {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                        Text("Error")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.orange)
                    }
                }

                // Message content — assistant uses markdown rendering
                Group {
                    if isUser {
                        Text(message.content)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.black)
                    } else {
                        MarkdownTextView(
                            message.content,
                            foregroundColor: message.isError ? .orange : .primary,
                            isUser: false
                        )
                    }
                }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(bubbleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: .cornerRadiusSmall, style: .continuous)
                            .stroke(borderColor, lineWidth: 1)
                    )

                // Action button — only for assistant messages with a payload
                if !isUser && !message.isError, let payload = message.actionPayload {
                    actionButton(for: payload)
                }

                // Retry button — only for error bubbles
                if message.isError && message.retryPayload != nil {
                    retryButton
                }
            }

            if !isUser { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isUser ? "User" : "Assistant"): \(message.content)")
        .accessibilityIdentifier("chat.bubble.\(message.id.uuidString)")
    }

    // MARK: - Action Button

    @ViewBuilder
    private func actionButton(for payload: ChatActionPayload) -> some View {
        Button {
            onAction?(payload)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: payload.iconName)
                    .font(.system(size: 12, weight: .bold))
                Text(payload.buttonLabel)
                    .font(.system(size: 13, weight: .bold))
            }
            .foregroundColor(.black)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.brandGradient)
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall, style: .continuous))
        }
        .accessibilityLabel(payload.buttonLabel)
        .accessibilityIdentifier("chat.action.\(payload.actionType.rawValue)")
    }

    // MARK: - Retry Button

    private var retryButton: some View {
        Button {
            onRetry?()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .bold))
                Text("Retry")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundColor(.orange)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.orange.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall, style: .continuous))
        }
        .accessibilityLabel("Retry send")
        .accessibilityIdentifier("chat.retryBtn")
    }

    // MARK: - Styling

    @ViewBuilder
    private var bubbleBackground: some View {
        if isUser {
            Color.themePrimary
        } else if message.isError {
            Color.orange.opacity(0.1)
        } else {
            Color.themeSurface
        }
    }

    private var borderColor: Color {
        if isUser { return .clear }
        if message.isError { return .orange.opacity(0.4) }
        return Color.themeBorder
    }
}

// MARK: - ChatActionPayload Icon Helper

private extension ChatActionPayload {
    var iconName: String {
        switch actionType {
        case .openCamera:   return "camera.viewfinder"
        case .viewWorkout:  return "figure.run"
        case .setGoal:      return "target"
        }
    }
}

#if DEBUG
struct ChatBubbleView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            ChatBubbleView(message: ChatMessage(role: .user, content: "How many squats should I do today?"))
            ChatBubbleView(message: ChatMessage(role: .assistant, content: "Based on your 50-rep daily goal, aim for 38 more squats!"))
            ChatBubbleView(message: ChatMessage(role: .assistant, content: "Request timed out. Please try again.", isError: true, retryPayload: ChatErrorRetryPayload(userText: "test")))
        }
        .padding()
        .background(Color.themeBackground)
        .preferredColorScheme(.dark)
    }
}
#endif