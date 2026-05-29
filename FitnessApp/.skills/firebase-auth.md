# Skill: Firebase / Google Auth
# Project: FitnessCoach iOS App
# Target: iOS 16.4 / Xcode 14.0 / Swift 5.7
# Read this before writing any authentication code in this project.

---

## Setup Steps (Agent 1 must complete these in order)

### Step 1 — Firebase Console
1. Go to https://console.firebase.google.com
2. Create a new project named "FitnessCoach"
3. Add an iOS app with your bundle ID (e.g. com.yourname.FitnessCoach)
4. Download `GoogleService-Info.plist`
5. Place it at: `FitnessCoach/Supporting Files/GoogleService-Info.plist`
6. In Xcode: add the file to the target (check "Add to target: FitnessCoach")

### Step 2 — Enable Auth methods in Firebase Console
Authentication → Sign-in method → Enable:
- Email/Password
- Google

### Step 3 — Install SDKs via Swift Package Manager
In Xcode: File → Add Packages

Add Firebase iOS SDK:
```
https://github.com/firebase/firebase-ios-sdk
```
Select these packages:
- FirebaseAuth
- FirebaseAnalytics (optional but recommended)

Add Google Sign-In SDK:
```
https://github.com/google/GoogleSignIn-iOS
```
Select:
- GoogleSignIn

### Step 4 — URL Scheme (required for Google Sign-In)
In Xcode: select FitnessCoach target → Info tab → URL Types → add:
- URL Schemes: paste the `REVERSED_CLIENT_ID` value from GoogleService-Info.plist
  (looks like: com.googleusercontent.apps.XXXXXXXXX-XXXXXXXXXXXXXXXXXXXXXXX)

Without this, Google Sign-In silently fails after the browser redirect.

### Step 5 — AppDelegate / App init
```swift
import Firebase
import GoogleSignIn

@main
struct FitnessCoachApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
```

---

## AuthManager

```swift
import FirebaseAuth
import GoogleSignIn
import Foundation

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var currentUser: User?          // Firebase User
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    private init() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
                self?.isAuthenticated = user != nil
            }
        }
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Email / Password

    func signInWithEmail(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signUpWithEmail(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await Auth.auth().createUser(withEmail: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetPassword(email: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Google Sign-In

    func signInWithGoogle() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Firebase client ID not found."
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        // Get the top-most view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            errorMessage = "Could not find root view controller."
            return
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Google sign-in failed: missing ID token."
                return
            }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            try await Auth.auth().signIn(with: credential)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sign Out

    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

---

## KeychainWrapper

Store only tokens and sensitive strings. Do not store full User objects.

```swift
import Security
import Foundation

struct KeychainWrapper {

    static func save(key: String, value: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary) // delete old value first
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func load(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else { return nil }
        return string
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// Key constants for this project
extension KeychainWrapper {
    static let firebaseTokenKey = "fc.firebase.token"
}
```

---

## Auth Flow (UI)

```
App Launch
    └─ AuthManager.isAuthenticated?
         ├─ true  → HomeView
         └─ false → OnboardingView
                        └─ LoginView / SignUpView
                               ├─ Google Sign-In button (primary)
                               └─ Email + Password fields (secondary)
                                        └─ "Forgot password?" → resetPassword()
```

---

## Rules

- Never hardcode Firebase API keys in source code — all come from GoogleService-Info.plist
- GoogleService-Info.plist must be in .gitignore — never commit it
- Firebase UID is the source of truth for user identity across the app
- AuthManager is the single owner of auth state — no other class reads `Auth.auth().currentUser` directly
