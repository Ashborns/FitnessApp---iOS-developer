//
//  TodolistAppApp.swift
//  TodolistApp
//

import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct TodolistAppApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var todoViewModel = TodoViewModel()
    @StateObject private var themeManager  = ThemeManager()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(todoViewModel)
                .environmentObject(themeManager)
                .preferredColorScheme(.dark)
                // Required for GIDSignIn to handle the OAuth redirect URL
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
