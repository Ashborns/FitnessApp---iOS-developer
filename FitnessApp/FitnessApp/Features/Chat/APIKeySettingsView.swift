import SwiftUI

/// Settings screen for entering, updating, and removing the GLM API key.
/// All state is local `@State`; the Keychain is the single source of truth.
struct APIKeySettingsView: View {

    private static let keychainKey = "glm.apiKey"

    @State private var keyInput: String = ""
    @State private var keyStatus: String = "Not configured"
    @State private var feedbackMessage: String?

    var body: some View {
        ZStack(alignment: .top) {
            Color.themeBackground.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    statusRow
                    keyEntrySection
                    actionButtons
                    if let feedback = feedbackMessage {
                        feedbackRow(feedback)
                    }
                    infoFooter
                    Spacer().frame(height: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
        }
        .navigationTitle("AI Coach API Key")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: refreshStatus)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("GLM API Access")
                .font(.system(size: 26, weight: .black, design: .rounded))
                .foregroundColor(.primary)
                .tracking(-0.5)
            Text("Your key is stored securely in the device Keychain and never leaves your phone.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Status Row

    private var statusRow: some View {
        HStack(spacing: 10) {
            Image(systemName: keyStatus == "Configured ✓" ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(keyStatus == "Configured ✓" ? .themePrimary : .secondary)
            Text(keyStatus)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: .cornerRadiusSmall)
                .fill(Color.themeSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: .cornerRadiusSmall)
                        .stroke(Color.themeBorder, lineWidth: 1)
                )
        )
        .accessibilityIdentifier("apikey.status")
        .accessibilityLabel("API key status: \(keyStatus)")
    }

    // MARK: - Key Entry

    private var keyEntrySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("API KEY")
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(.secondary)
                .tracking(1.5)
            SecureField("Paste your GLM API key", text: $keyInput)
                .textContentType(.password)
                .autocorrectionDisabled(true)
                .textInputAutocapitalization(.never)
                .font(.system(size: 15, weight: .medium))
                .padding(.vertical, 12)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.themeBorder).frame(height: 1)
                }
                .accessibilityIdentifier("apikey.input")
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: saveKey) {
                Text("Save Key")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        Capsule().fill(saveDisabled ? AnyShapeStyle(Color.themeBorder) : AnyShapeStyle(Color.brandGradient))
                    )
            }
            .buttonStyle(.plain)
            .disabled(saveDisabled)
            .accessibilityIdentifier("apikey.saveButton")

            Button(action: removeKey) {
                Text("Remove Key")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.themeError)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("apikey.removeButton")
        }
    }

    private var saveDisabled: Bool {
        keyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Feedback

    private func feedbackRow(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(text.contains("✓") ? .themePrimary : .themeError)
            .accessibilityIdentifier("apikey.feedback")
    }

    // MARK: - Info Footer

    private var infoFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("HOW TO GET A KEY")
                .font(.system(size: 10, weight: .heavy))
                .foregroundColor(.secondary)
                .tracking(1.5)
            Text("Sign up at z.ai, create an API key for the GLM-4-Flash model, and paste it above.")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func refreshStatus() {
        if KeychainWrapper.load(key: Self.keychainKey) != nil {
            keyStatus = "Configured ✓"
        } else {
            keyStatus = "Not configured"
        }
    }

    private func saveKey() {
        let value = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }

        let success = KeychainWrapper.save(key: Self.keychainKey, value: value)
        if success {
            keyStatus = "Configured ✓"
            keyInput = ""
            showFeedback("Key saved ✓")
        } else {
            showFeedback("Failed to save key. Please try again.")
        }
    }

    private func removeKey() {
        let success = KeychainWrapper.delete(key: Self.keychainKey)
        if success {
            keyStatus = "Not configured"
            showFeedback("Key removed")
        } else {
            showFeedback("Failed to remove key. Please try again.")
        }
    }

    private func showFeedback(_ message: String) {
        feedbackMessage = message
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if feedbackMessage == message {
                feedbackMessage = nil
            }
        }
    }
}

#if DEBUG
struct APIKeySettingsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            APIKeySettingsView()
        }
        .preferredColorScheme(.dark)
    }
}
#endif
