//
//  RegisterView.swift
//  TodolistApp
//

import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.dismiss) var dismiss
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @FocusState private var focused: Field?
    enum Field { case name, email, password, confirm }
    private var match: Bool { password == confirmPassword || confirmPassword.isEmpty }

    var body: some View {
        ZStack {
            AppBG()
            Circle().fill(theme.accent.opacity(0.06)).frame(width: 250).blur(radius: 70).offset(x: 120, y: -200)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    HStack {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark").font(.system(size: 13, weight: .bold))
                                .padding(10).foregroundColor(.white)
                                .background(Color.appCardHighlight).clipShape(Circle())
                                .overlay(Circle().stroke(Color.glassStroke, lineWidth: 1))
                        }; Spacer()
                    }.padding(.horizontal, 20).padding(.top, 16)

                    VStack(spacing: 6) {
                        Text("Create Account").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundColor(.white)
                        Text("Start organizing your tasks").font(.subheadline).foregroundColor(.textSecondary)
                    }.padding(.vertical, 28)

                    VStack(spacing: 16) {
                        field("Full Name", icon: "person.fill", text: $fullName, f: .name, ph: "John Doe")
                        field("Email", icon: "envelope", text: $email, f: .email, ph: "you@gmail.com", kb: .emailAddress, ac: .none)
                        secure("Password", icon: "lock.fill", text: $password, f: .password)
                        secure("Confirm", icon: "lock.shield.fill", text: $confirmPassword, f: .confirm)

                        if !match { Text("Passwords do not match").font(.caption).foregroundColor(.priorityHigh) }
                        if let msg = authVM.errorMessage { Text(msg).font(.caption).foregroundColor(.priorityHigh).multilineTextAlignment(.center) }

                        Button {
                            Task { await authVM.createUser(fullName: fullName, email: email, password: password); if authVM.errorMessage == nil { dismiss() } }
                        } label: {
                            Group { if authVM.isLoading { ProgressView().tint(.white) } else { Text("Create Account").font(.headline).foregroundColor(.white) } }
                                .frame(maxWidth: .infinity).frame(height: 52)
                                .background(theme.hGradient).cornerRadius(14)
                                .shadow(color: theme.accent.opacity(0.4), radius: 14, y: 6)
                        }
                        .disabled(authVM.isLoading || !match || fullName.isEmpty || email.isEmpty || password.count < 6)
                        .padding(.top, 4)
                    }
                    .padding(24).glassCard(cornerRadius: 28).padding(.horizontal, 20).padding(.bottom, 40)
                }
            }
        }.onTapGesture { focused = nil }
    }

    @ViewBuilder private func field(_ l: String, icon: String, text: Binding<String>, f: Field, ph: String, kb: UIKeyboardType = .default, ac: UITextAutocapitalizationType = .words) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(l, systemImage: icon).font(.caption.weight(.semibold)).foregroundColor(.textSecondary)
            TextField(ph, text: text).keyboardType(kb).autocapitalization(ac).focused($focused, equals: f)
                .padding().foregroundColor(.white).background(Color.appCardHighlight).cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(focused == f ? theme.accent : Color.glassStroke, lineWidth: 1))
        }
    }
    @ViewBuilder private func secure(_ l: String, icon: String, text: Binding<String>, f: Field) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(l, systemImage: icon).font(.caption.weight(.semibold)).foregroundColor(.textSecondary)
            SecureField("••••••••", text: text).focused($focused, equals: f)
                .padding().foregroundColor(.white).background(Color.appCardHighlight).cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(focused == f ? theme.accent : Color.glassStroke, lineWidth: 1))
        }
    }
}
