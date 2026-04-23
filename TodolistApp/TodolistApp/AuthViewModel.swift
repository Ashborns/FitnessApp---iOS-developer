//
//  AuthViewModel.swift
//  TodolistApp
//

import Foundation
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import GoogleSignIn

@MainActor
class AuthViewModel: ObservableObject {
    @Published var userSession: FirebaseAuth.User?
    @Published var currentUser: AppUser?
    @Published var isLoading    = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()

    init() {
        let firebaseUser = Auth.auth().currentUser
        self.userSession = firebaseUser
        if let user = firebaseUser {
            Task { await fetchUser(uid: user.uid) }
        }
    }

    // MARK: - Email Sign In

    func signIn(email: String, password: String) async {
        isLoading = true; errorMessage = nil
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            self.userSession = result.user
            await fetchUser(uid: result.user.uid)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Email Register

    func createUser(fullName: String, email: String, password: String) async {
        isLoading = true; errorMessage = nil
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            self.userSession = result.user
            let user = AppUser(id: result.user.uid, fullName: fullName, email: email)
            try await db.collection("users").document(user.id).setData([
                "id":       user.id,
                "fullName": user.fullName,
                "email":    user.email
            ])
            self.currentUser = user
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Update Display Name

    func updateName(_ newName: String) async {
        guard let uid = userSession?.uid,
              !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        do {
            try await db.collection("users").document(uid).updateData(["fullName": trimmed])
            if var updated = currentUser {
                updated = AppUser(id: updated.id, fullName: trimmed, email: updated.email)
                self.currentUser = updated
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }


    func signInWithGoogle() {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Firebase not configured."
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        // Get presenting view controller (iOS 16+ compatible)
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? scenes.compactMap { $0 as? UIWindowScene }.first

        guard
            let windowScene = windowScene,
            let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
                      ?? windowScene.windows.first?.rootViewController
        else {
            errorMessage = "Cannot find active window."
            return
        }

        isLoading = true; errorMessage = nil

        // GIDSignIn calls completion on main thread
        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error as NSError? {
                // Code -5 = user cancelled sign-in — don't show error
                if error.code != -5 {
                    self.errorMessage = error.localizedDescription
                }
                self.isLoading = false
                return
            }

            guard
                let user        = result?.user,
                let idToken     = user.idToken?.tokenString
            else {
                self.isLoading = false
                return
            }

            let accessToken = user.accessToken.tokenString
            let credential  = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: accessToken
            )
            let displayName = user.profile?.name
            let email       = user.profile?.email

            Task { await self.finishGoogleSignIn(credential: credential,
                                                  displayName: displayName,
                                                  email: email) }
        }
    }

    private func finishGoogleSignIn(credential: AuthCredential,
                                    displayName: String?,
                                    email: String?) async {
        do {
            let result = try await Auth.auth().signIn(with: credential)
            let uid    = result.user.uid
            self.userSession = result.user

            let doc = try await db.collection("users").document(uid).getDocument()
            if doc.exists {
                await fetchUser(uid: uid)
            } else {
                let name  = displayName ?? result.user.displayName ?? "User"
                let mail  = email ?? result.user.email ?? ""
                let user  = AppUser(id: uid, fullName: name, email: mail)
                try await db.collection("users").document(uid).setData([
                    "id":       user.id,
                    "fullName": user.fullName,
                    "email":    user.email
                ])
                self.currentUser = user
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
        self.isLoading = false
    }

    // MARK: - Sign Out

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        do {
            try Auth.auth().signOut()
            self.userSession = nil
            self.currentUser = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Fetch User

    func fetchUser(uid: String) async {
        do {
            let doc = try await db.collection("users").document(uid).getDocument()

            guard doc.exists else {
                print("⚠️ fetchUser: no Firestore doc — using Auth fallback")
                if let fbUser = Auth.auth().currentUser {
                    self.currentUser = AppUser(
                        id:       uid,
                        fullName: fbUser.displayName ?? fbUser.email ?? "User",
                        email:    fbUser.email ?? ""
                    )
                }
                return
            }

            if let user = try? doc.data(as: AppUser.self) {
                self.currentUser = user; return
            }

            if let data     = doc.data(),
               let fullName = data["fullName"] as? String,
               let email    = data["email"]    as? String {
                self.currentUser = AppUser(id: uid, fullName: fullName, email: email)
            }
        } catch {
            print("❌ fetchUser: \(error.localizedDescription)")
        }
    }
}
