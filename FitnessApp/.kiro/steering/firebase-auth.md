---
inclusion: fileMatch
fileMatchPattern: "**/Auth/**,**/Keychain/**,**/FitnessAppApp.swift"
---

# Firebase & Google Auth — FitnessApp

## Setup Requirements

1. `GoogleService-Info.plist` must be in the Xcode target
2. Firebase iOS SDK added via SPM: FirebaseAuth
3. GoogleSignIn-iOS SDK v7.x added via SPM
4. URL Scheme: paste `REVERSED_CLIENT_ID` from GoogleService-Info.plist into URL Types

## App Entry Point

```swift
import Firebase
import GoogleSignIn

@main
struct FitnessAppApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
```

## AuthManager Pattern

```swift
@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isAuthenticated: Bool = false
    @Published var currentUserID: String?
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    private init() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.isAuthenticated = user != nil
                self?.currentUserID = user?.uid
            }
        }
    }
}
```

## Google Sign-In Flow

```swift
func signInWithGoogle() async {
    guard let clientID = FirebaseApp.app()?.options.clientID else { return }
    let config = GIDConfiguration(clientID: clientID)
    GIDSignIn.sharedInstance.configuration = config

    guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let rootVC = windowScene.windows.first?.rootViewController else { return }

    let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
    guard let idToken = result.user.idToken?.tokenString else { return }
    let credential = GoogleAuthProvider.credential(
        withIDToken: idToken,
        accessToken: result.user.accessToken.tokenString
    )
    try await Auth.auth().signIn(with: credential)
}
```

## KeychainWrapper Pattern

```swift
struct KeychainWrapper {
    static func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func load(key: String) -> String? { /* ... */ }
    static func delete(key: String) -> Bool { /* ... */ }
}
```

## Rules

- Firebase UID is the source of truth for user identity
- AuthManager is the single owner of auth state
- Never hardcode Firebase API keys — all from GoogleService-Info.plist
- GoogleService-Info.plist must be in .gitignore
