import SwiftUI

/// Main chat interface for the AI fitness coach.
/// All business logic lives in `ChatViewModel`; this view contains only layout & binding.
struct ChatView: View {

    /// Optional callback invoked when an openCamera action is triggered.
    /// If provided, the caller is responsible for dismissing this view first,
    /// then opening the camera. Used when ChatView is presented as a fullScreenCover.
    var onCameraRequested: ((ExerciseType?) -> Void)? = nil

    @StateObject private var viewModel = ChatViewModel()
    @EnvironmentObject private var router: AppRouter
    @FocusState private var inputFocused: Bool
    @Environment(\.dismiss) private var dismiss

    private let maxCharacters = 1000

    var body: some View {
        NavigationStack {
            ZStack {
                Color.themeBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    messageList
                    inputBar
                }
            }
            .navigationTitle("PULSE AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .accessibilityLabel("Close chat")
                    .accessibilityIdentifier("chat.closeButton")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.clearChat()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.themePrimary)
                    }
                    .accessibilityLabel("Clear chat")
                    .accessibilityIdentifier("chat.clearButton")
                }
            }
            .alert("Error", isPresented: errorBinding) {
                Button("OK", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if visibleMessages.isEmpty && !viewModel.isSending {
                        welcomeView
                    } else {
                        ForEach(visibleMessages) { message in
                            ChatBubbleView(message: message, onAction: { payload in
                                handleAction(payload)
                            }, onRetry: {
                                viewModel.retryLastFailed()
                            })
                                .id(message.id)
                        }
                    }

                    if viewModel.isSending {
                        typingIndicator
                            .id("typing-indicator")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
            }
            .onChange(of: viewModel.messages.count) { _ in
                scrollToBottom(proxy)
            }
            .onChange(of: viewModel.isSending) { _ in
                scrollToBottom(proxy)
            }
        }
    }

    /// Messages excluding system-role entries (system prompt is never shown).
    private var visibleMessages: [ChatMessage] {
        viewModel.messages.filter { $0.role != .system }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        if viewModel.isSending {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo("typing-indicator", anchor: .bottom)
            }
        } else if let last = visibleMessages.last {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    // MARK: - Welcome View

    private var welcomeView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.themePrimary.opacity(0.12))
                    .frame(width: 80, height: 80)
                Image(systemName: BrandTokens.logoSymbol)
                    .font(.system(size: 36))
                    .foregroundStyle(Color.brandGradient)
            }
            Text("Ask your AI coach")
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundColor(.primary)
            Text("I know your reps, streaks, calories, and workout history. Ask me anything about your fitness.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(.top, 60)
        .accessibilityIdentifier("chat.welcome")
    }

    // MARK: - Typing Indicator

    private var typingIndicator: some View {
        HStack {
            TypingDots()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.themeSurface)
                .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall, style: .continuous))
            Spacer(minLength: 40)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("PULSE AI is typing")
        .accessibilityIdentifier("chat.typingIndicator")
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider().background(Color.themeBorder)
            HStack(spacing: 10) {
                TextField("Ask about your fitness…", text: $viewModel.inputText, axis: .vertical)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1...4)
                    .focused($inputFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.themeSurface)
                    .clipShape(RoundedRectangle(cornerRadius: .cornerRadiusSmall, style: .continuous))
                    .onChange(of: viewModel.inputText) { newValue in
                        if newValue.count > maxCharacters {
                            viewModel.inputText = String(newValue.prefix(maxCharacters))
                        }
                    }
                    .accessibilityLabel("Message input")
                    .accessibilityIdentifier("chat.inputField")

                Button {
                    inputFocused = false
                    Task { await viewModel.sendMessage() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(sendDisabled ? AnyShapeStyle(Color.secondary) : AnyShapeStyle(Color.brandGradient))
                }
                .disabled(sendDisabled)
                .accessibilityLabel("Send message")
                .accessibilityIdentifier("chat.sendButton")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var sendDisabled: Bool {
        viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending
    }

    // MARK: - Actions

    private func handleAction(_ payload: ChatActionPayload) {
        switch payload.actionType {
        case .openCamera:
            let exercise: ExerciseType? = payload.exercise.flatMap { ExerciseType(rawValue: $0) }
            if let onCameraRequested {
                // Dipresentasikan sebagai fullScreenCover — harus dismiss dulu
                // sebelum camera bisa ditampilkan (iOS tidak bisa 2 fullScreenCover bersamaan)
                onCameraRequested(exercise)
            } else {
                // Tampil sebagai tab biasa — langsung buka camera
                if let exercise {
                    router.openCamera(with: exercise)
                } else {
                    router.openCamera()
                }
            }
        case .viewWorkout:
            router.selectedTab = .workout
        case .setGoal:
            router.selectedTab = .calories
        }
    }

    // MARK: - Bindings

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

// MARK: - Typing Dots Animation

private struct TypingDots: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 6, height: 6)
                    .opacity(phase == index ? 1.0 : 0.3)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.4).repeatForever()) {
                // animation driver
            }
            Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { _ in
                phase = (phase + 1) % 3
            }
        }
    }
}

#if DEBUG
struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView()
            .preferredColorScheme(.dark)
    }
}
#endif
