//
//  LoginView.swift
//  TodolistApp
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var theme: ThemeManager
    @State private var email = ""
    @State private var password = ""
    @State private var showRegister = false
    @State private var logoScale = 0.6
    @FocusState private var focusedField: Field?
    enum Field { case email, password }

    var body: some View {
        ZStack {
            AppBG()
            Circle().fill(theme.accent.opacity(0.08)).frame(width: 300).blur(radius: 80).offset(x: -100, y: -300)
            Circle().fill(theme.accentLight.opacity(0.05)).frame(width: 250).blur(radius: 60).offset(x: 150, y: 100)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Logo
                    VStack(spacing: 14) {
                        ZStack {
                            Circle().fill(theme.gradient).frame(width: 86, height: 86)
                                .shadow(color: theme.accent.opacity(0.5), radius: 24, y: 8)
                            Image(systemName: "checklist")
                                .font(.system(size: 36, weight: .bold)).foregroundColor(.white)
                        }
                        .scaleEffect(logoScale)
                        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) { logoScale = 1 } }
                        Text("TodoList").font(.system(size: 34, weight: .bold, design: .rounded)).foregroundColor(.white)
                        Text("Organize your life beautifully").font(.subheadline).foregroundColor(.textSecondary)
                    }.padding(.top, 80).padding(.bottom, 44)

                    // Form
                    VStack(spacing: 18) {
                        inputField("Email", icon: "envelope", text: $email, field: .email, placeholder: "you@gmail.com", keyboard: .emailAddress)
                        secureInput("Password", icon: "lock.fill", text: $password, field: .password)

                        if let msg = authVM.errorMessage {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill"); Text(msg)
                            }.font(.caption).foregroundColor(.priorityHigh)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button {
                            Task { await authVM.signIn(email: email, password: password) }
                        } label: {
                            btnLabel("Sign In", loading: authVM.isLoading)
                        }
                        .disabled(authVM.isLoading || email.isEmpty || password.isEmpty)
                        .padding(.top, 4)

                        // ── Divider ──────────────────────────────
                        HStack(spacing: 12) {
                            Rectangle().frame(height: 1).foregroundColor(.glassStroke)
                            Text("or").font(.caption).foregroundColor(.textSecondary)
                            Rectangle().frame(height: 1).foregroundColor(.glassStroke)
                        }

                        // ── Continue with Google ─────────────────
                        Button {
                            authVM.signInWithGoogle()
                        } label: {
                            HStack(spacing: 10) {
                                // Google "G" icon using SF Symbol fallback
                                Image(systemName: "globe")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                                if authVM.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Continue with Google")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                            }
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .glassCard(cornerRadius: 14)
                        }
                        .disabled(authVM.isLoading)
                    }
                    .padding(24).glassCard(cornerRadius: 28).padding(.horizontal, 20)

                    Button { authVM.errorMessage = nil; showRegister = true } label: {
                        HStack(spacing: 4) {
                            Text("Don't have an account?").foregroundColor(.textSecondary)
                            Text("Sign Up").foregroundColor(theme.accentLight).fontWeight(.semibold)
                        }.font(.subheadline)
                    }.padding(.top, 28).padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showRegister) { RegisterView().environmentObject(authVM).environmentObject(theme) }
        .onTapGesture { focusedField = nil }
    }

    private func inputField(_ label: String, icon: String, text: Binding<String>, field: Field, placeholder: String, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon).font(.caption.weight(.semibold)).foregroundColor(.textSecondary)
            TextField(placeholder, text: text).keyboardType(keyboard).autocapitalization(.none)
                .focused($focusedField, equals: field).padding().foregroundColor(.white)
                .background(Color.appCardHighlight).cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(focusedField == field ? theme.accent : Color.glassStroke, lineWidth: 1))
        }
    }
    private func secureInput(_ label: String, icon: String, text: Binding<String>, field: Field) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(label, systemImage: icon).font(.caption.weight(.semibold)).foregroundColor(.textSecondary)
            SecureField("••••••••", text: text).focused($focusedField, equals: field)
                .padding().foregroundColor(.white)
                .background(Color.appCardHighlight).cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(focusedField == field ? theme.accent : Color.glassStroke, lineWidth: 1))
        }
    }
    private func btnLabel(_ text: String, loading: Bool) -> some View {
        Group { if loading { ProgressView().tint(.white) } else { Text(text).font(.headline).foregroundColor(.white) } }
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(theme.hGradient).cornerRadius(14)
            .shadow(color: theme.accent.opacity(0.4), radius: 16, y: 8)
    }
}
