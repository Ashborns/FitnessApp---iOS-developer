//
//  ContentView.swift
//  TodolistApp
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        Group {
            if authVM.userSession != nil {
                HomeView()
                    .environmentObject(authVM)
            } else {
                LoginView()
                    .environmentObject(authVM)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: authVM.userSession != nil)
    }
}
