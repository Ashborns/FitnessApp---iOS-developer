//
//  AddTodoView.swift
//  TodolistApp
//

import SwiftUI

struct AddTodoView: View {
    @EnvironmentObject var todoVM: TodoViewModel
    @EnvironmentObject var theme: ThemeManager
    @Environment(\.dismiss) var dismiss
    let userId: String
    var editingTodo: TodoItem? = nil

    @State private var title       = ""
    @State private var description = ""
    @State private var priority    = Priority.medium
    @State private var recurrence  = Recurrence.oneTime
    @State private var hasDueDate  = false
    @State private var dueDate     = Date().addingTimeInterval(3600)
    @FocusState private var focusTitle: Bool
    private var isEditing: Bool { editingTodo != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBG()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {

                        // Title
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Title", systemImage: "pencil")
                                .font(.caption.weight(.semibold)).foregroundColor(.textSecondary)
                            TextField("What needs to be done?", text: $title)
                                .focused($focusTitle).padding().foregroundColor(.white)
                                .background(Color.appCardHighlight).cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.glassStroke, lineWidth: 1))
                        }

                        // Description
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Note", systemImage: "text.alignleft")
                                .font(.caption.weight(.semibold)).foregroundColor(.textSecondary)
                            ZStack(alignment: .topLeading) {
                                if description.isEmpty {
                                    Text("Add details...").foregroundColor(.textSecondary)
                                        .padding(.horizontal, 16).padding(.vertical, 14)
                                }
                                TextEditor(text: $description)
                                    .frame(minHeight: 80).scrollContentBackground(.hidden)
                                    .padding(.horizontal, 12).padding(.vertical, 8).foregroundColor(.white)
                            }
                            .background(Color.appCardHighlight).cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.glassStroke, lineWidth: 1))
                        }

                        // Priority
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Priority", systemImage: "flag.fill")
                                .font(.caption.weight(.semibold)).foregroundColor(.textSecondary)
                            HStack(spacing: 8) {
                                ForEach(Priority.allCases, id: \.self) { p in
                                    Button {
                                        withAnimation(.spring(response: 0.3)) { priority = p }
                                    } label: {
                                        HStack(spacing: 5) {
                                            Image(systemName: p.icon).font(.caption2.weight(.bold))
                                            Text(p.displayName).font(.caption.weight(.semibold))
                                        }
                                        .foregroundColor(priority == p ? .white : .textSecondary)
                                        .frame(maxWidth: .infinity).padding(.vertical, 11)
                                        .background(priority == p ? pColor(p).opacity(0.25) : Color.appCard)
                                        .cornerRadius(10)
                                        .overlay(RoundedRectangle(cornerRadius: 10)
                                            .stroke(priority == p ? pColor(p) : Color.glassStroke, lineWidth: 1))
                                    }
                                }
                            }
                        }

                        // Recurrence
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Repeat", systemImage: "repeat")
                                .font(.caption.weight(.semibold)).foregroundColor(.textSecondary)
                            HStack(spacing: 8) {
                                ForEach(Recurrence.allCases, id: \.self) { r in
                                    Button {
                                        withAnimation(.spring(response: 0.3)) { recurrence = r }
                                    } label: {
                                        VStack(spacing: 4) {
                                            Image(systemName: r.icon)
                                                .font(.system(size: 14, weight: .bold))
                                            Text(r.shortName).font(.system(size: 10, weight: .semibold))
                                        }
                                        .foregroundColor(recurrence == r ? .white : .textSecondary)
                                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                                        .background(recurrence == r ? theme.accent.opacity(0.25) : Color.appCard)
                                        .cornerRadius(10)
                                        .overlay(RoundedRectangle(cornerRadius: 10)
                                            .stroke(recurrence == r ? theme.accent : Color.glassStroke, lineWidth: 1))
                                    }
                                }
                            }
                        }

                        // Due Date
                        VStack(alignment: .leading, spacing: 10) {
                            Toggle(isOn: $hasDueDate.animation(.spring(response: 0.3))) {
                                Label("Due Date", systemImage: "calendar")
                                    .font(.caption.weight(.semibold)).foregroundColor(.textSecondary)
                            }.tint(theme.accent)

                            if hasDueDate {
                                DatePicker("", selection: $dueDate, in: Date()...,
                                           displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.graphical).tint(theme.accent)
                                    .padding(12).glassCard(cornerRadius: 16).colorScheme(.dark)
                                    .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(isEditing ? "Edit Task" : "New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundColor(.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") { save(); dismiss() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                        .font(.headline).foregroundColor(theme.accentLight)
                }
            }
        }
        .onAppear {
            if let t = editingTodo {
                title = t.title
                description = t.description
                priority = t.priority
                recurrence = t.recurrence
                if let d = t.dueDate { dueDate = d; hasDueDate = true }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { focusTitle = true }
        }
    }

    private func save() {
        let t = title.trimmingCharacters(in: .whitespaces)
        if var todo = editingTodo {
            todo.title = t; todo.description = description
            todo.priority = priority; todo.recurrence = recurrence
            todo.dueDate = hasDueDate ? dueDate : nil
            todoVM.updateTodo(userId: userId, todo: todo)
        } else {
            todoVM.addTodo(userId: userId, title: t, description: description,
                           priority: priority, recurrence: recurrence,
                           dueDate: hasDueDate ? dueDate : nil)
        }
    }

    private func pColor(_ p: Priority) -> Color {
        switch p {
        case .high: return .priorityHigh
        case .medium: return .priorityMedium
        case .low: return .priorityLow
        }
    }
}
