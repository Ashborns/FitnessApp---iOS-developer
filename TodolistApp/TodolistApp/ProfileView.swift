//
//  ProfileView.swift
//  TodolistApp
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var todoVM: TodoViewModel
    @EnvironmentObject var theme: ThemeManager

    @State private var showEditName   = false
    @State private var newName        = ""
    @FocusState private var nameFocus: Bool

    private var total:   Int    { todoVM.todos.count }
    private var done:    Int    { todoVM.todos.filter { $0.isCompleted }.count }
    private var pend:    Int    { total - done }
    private var prog:    Double { total == 0 ? 0 : Double(done) / Double(total) }
    private var overdue: Int    { todoVM.todos.filter { !$0.isCompleted && ($0.dueDate?.isOverdue ?? false) }.count }

    var body: some View {
        ZStack {
            AppBG()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // ── Avatar & Name ────────────────────────────────────
                    VStack(spacing: 16) {
                        ZStack {
                            Circle().fill(theme.gradient).frame(width: 90, height: 90)
                                .shadow(color: theme.accent.opacity(0.5), radius: 20, y: 6)
                            Text(authVM.currentUser?.initials ?? "?")
                                .font(.system(size: 32, weight: .bold)).foregroundColor(.white)
                        }

                        VStack(spacing: 4) {
                            // Tappable name row
                            Button {
                                newName = authVM.currentUser?.fullName ?? ""
                                showEditName = true
                            } label: {
                                HStack(spacing: 6) {
                                    Text(authVM.currentUser?.fullName ?? "User")
                                        .font(.title2.weight(.bold)).foregroundColor(.white)
                                    Image(systemName: "pencil")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(theme.accentLight)
                                }
                            }
                            Text(authVM.currentUser?.email ?? "")
                                .font(.subheadline).foregroundColor(.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity).padding(28).glassCard(cornerRadius: 24)
                    .padding(.horizontal, 20).padding(.top, 20)

                    // ── Stats Grid ───────────────────────────────────────
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        tile(icon: "checklist",                    val: "\(total)",  lab: "Total Tasks",  col: theme.accentLight)
                        tile(icon: "checkmark.circle.fill",        val: "\(done)",   lab: "Completed",    col: .successGreen)
                        tile(icon: "clock.arrow.circlepath",       val: "\(pend)",   lab: "Pending",      col: .priorityMedium)
                        tile(icon: "exclamationmark.triangle.fill", val: "\(overdue)",lab: "Overdue",      col: .priorityHigh)
                    }.padding(.horizontal, 20)

                    // ── Completion Bar ───────────────────────────────────
                    VStack(spacing: 14) {
                        HStack {
                            Text("Completion Rate").font(.subheadline.weight(.semibold)).foregroundColor(.white)
                            Spacer()
                            Text("\(Int(prog * 100))%")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(theme.accentLight)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 8).fill(Color.appCardHighlight).frame(height: 10)
                                RoundedRectangle(cornerRadius: 8).fill(theme.hGradient)
                                    .frame(width: geo.size.width * prog, height: 10)
                                    .animation(.spring(response: 0.5), value: prog)
                            }
                        }.frame(height: 10)
                    }.padding(20).glassCard(cornerRadius: 20).padding(.horizontal, 20)

                    // ── Theme Picker ─────────────────────────────────────
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Appearance").font(.subheadline.weight(.semibold)).foregroundColor(.white)
                            Spacer()
                            Text(theme.current.displayName)
                                .font(.caption.weight(.semibold))
                                .foregroundColor(theme.accentLight)
                                .padding(.horizontal, 10).padding(.vertical, 4)
                                .background(theme.accent.opacity(0.15))
                                .cornerRadius(8)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(AppTheme.allCases) { t in
                                    Button {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                            theme.current = t
                                        }
                                    } label: {
                                        themeCard(t)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 2).padding(.vertical, 4)
                        }
                    }
                    .padding(20).glassCard(cornerRadius: 20).padding(.horizontal, 20)

                    // ── Sign Out ─────────────────────────────────────────
                    Button {
                        todoVM.stopListening(); authVM.signOut()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out").font(.headline)
                        }
                        .foregroundColor(.priorityHigh)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(Color.priorityHigh.opacity(0.1)).cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.priorityHigh.opacity(0.25), lineWidth: 1))
                    }
                    .padding(.horizontal, 20).padding(.bottom, 40)
                }
            }
        }
        // ── Edit Name Sheet ──────────────────────────────────────────────
        .sheet(isPresented: $showEditName) {
            editNameSheet
        }
    }

    // MARK: - Edit Name Sheet

    private var editNameSheet: some View {
        NavigationStack {
            ZStack {
                AppBG()
                VStack(spacing: 24) {
                    // Avatar preview
                    ZStack {
                        Circle().fill(theme.gradient).frame(width: 72, height: 72)
                            .shadow(color: theme.accent.opacity(0.4), radius: 16, y: 4)
                        Text(newName.isEmpty
                             ? (authVM.currentUser?.initials ?? "?")
                             : initials(from: newName))
                            .font(.system(size: 26, weight: .bold)).foregroundColor(.white)
                    }
                    .animation(.spring(response: 0.3), value: newName)

                    // Text field
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Display Name", systemImage: "person.fill")
                            .font(.caption.weight(.semibold)).foregroundColor(.textSecondary)
                        TextField("Enter your name", text: $newName)
                            .focused($nameFocus)
                            .padding()
                            .foregroundColor(.white)
                            .background(Color.appCardHighlight)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .stroke(nameFocus ? theme.accent : Color.glassStroke, lineWidth: 1))
                    }

                    Spacer()
                }
                .padding(24)
            }
            .navigationTitle("Edit Name")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showEditName = false }
                        .foregroundColor(.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await authVM.updateName(newName)
                            showEditName = false
                        }
                    }
                    .font(.headline)
                    .foregroundColor(theme.accentLight)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty
                              || newName == authVM.currentUser?.fullName)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { nameFocus = true }
            }
        }
    }

    // MARK: - Helpers

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private func themeCard(_ t: AppTheme) -> some View {
        let isSelected = theme.current == t
        return ZStack(alignment: .bottomLeading) {
            // Gradient background
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(
                    colors: t.gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 100, height: 70)

            // Dark overlay for text readability
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.25))
                .frame(width: 100, height: 70)

            // Theme name
            Text(t.displayName)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.bottom, 10)

            // Selected checkmark
            if isSelected {
                VStack {
                    HStack {
                        Spacer()
                        ZStack {
                            Circle().fill(Color.white).frame(width: 20, height: 20)
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(t.accent)
                        }
                        .padding(8)
                    }
                    Spacer()
                }
                .frame(width: 100, height: 70)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.white : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
        )
        .shadow(color: isSelected ? t.accent.opacity(0.5) : Color.black.opacity(0.2),
                radius: isSelected ? 12 : 4, y: isSelected ? 4 : 2)
        .scaleEffect(isSelected ? 1.05 : 1.0)
    }

    private func tile(icon: String, val: String, lab: String, col: Color) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.caption).foregroundColor(col); Spacer()
                Text(val).font(.system(size: 26, weight: .bold, design: .rounded)).foregroundColor(col)
            }
            HStack { Text(lab).font(.caption).foregroundColor(.textSecondary); Spacer() }
        }.padding(16).glassCard(cornerRadius: 16)
    }
}
