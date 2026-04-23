//
//  TodoViewModel.swift
//  TodolistApp
//

import Foundation
import FirebaseFirestore

@MainActor
class TodoViewModel: ObservableObject {
    @Published var todos: [TodoItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var listener: ListenerRegistration?
    private let db = Firestore.firestore()

    // MARK: - Real-time Listener

    func startListening(userId: String) {
        guard !userId.isEmpty else { return }
        listener?.remove()
        isLoading = true
        listener = db
            .collection("users").document(userId)
            .collection("todos")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                self.isLoading = false
                if let error = error {
                    self.errorMessage = error.localizedDescription; return
                }
                self.todos = (snapshot?.documents ?? []).compactMap {
                    try? $0.data(as: TodoItem.self)
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        todos = []
    }

    // MARK: - Add

    func addTodo(userId: String,
                 title: String,
                 description: String,
                 priority: Priority,
                 recurrence: Recurrence,
                 dueDate: Date?) {
        let todo = TodoItem(
            title: title,
            description: description,
            isCompleted: false,
            priority: priority,
            recurrence: recurrence,
            dueDate: dueDate,
            createdAt: Date(),
            updatedAt: Date()
        )
        do {
            try db.collection("users").document(userId)
                .collection("todos").addDocument(from: todo)
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Update

    func updateTodo(userId: String, todo: TodoItem) {
        guard let id = todo.id else { return }
        var updated = todo
        updated.updatedAt = Date()
        do {
            try db.collection("users").document(userId)
                .collection("todos").document(id).setData(from: updated)
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Delete

    func deleteTodo(userId: String, todoId: String) {
        db.collection("users").document(userId)
            .collection("todos").document(todoId).delete()
    }

    // MARK: - Toggle Complete (with recurring reset logic)

    func toggleComplete(userId: String, todo: TodoItem) {
        var updated = todo
        updated.updatedAt = Date()

        if !todo.isCompleted && todo.recurrence != .oneTime {
            // Marking a recurring task as DONE → reset it for the next cycle
            // instead of permanently completing it
            updated.isCompleted = true
            updateTodo(userId: userId, todo: updated)

            // Schedule a reset for the next recurrence period
            let nextDue = nextDueDate(from: todo.dueDate ?? Date(), recurrence: todo.recurrence)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                var reset = todo
                reset.isCompleted = false
                reset.dueDate = nextDue
                reset.updatedAt = Date()
                self.updateTodo(userId: userId, todo: reset)
            }
        } else {
            updated.isCompleted.toggle()
            updateTodo(userId: userId, todo: updated)
        }
    }

    // MARK: - Helpers

    private func nextDueDate(from date: Date, recurrence: Recurrence) -> Date {
        let cal = Calendar.current
        switch recurrence {
        case .daily:   return cal.date(byAdding: .day,   value: 1,  to: date) ?? date
        case .weekly:  return cal.date(byAdding: .day,   value: 7,  to: date) ?? date
        case .monthly: return cal.date(byAdding: .month, value: 1,  to: date) ?? date
        case .oneTime: return date
        }
    }
}
