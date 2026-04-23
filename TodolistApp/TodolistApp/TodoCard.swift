//
//  TodoCard.swift
//  TodolistApp
//

import SwiftUI

struct TodoCard: View {
    @EnvironmentObject var theme: ThemeManager
    let todo: TodoItem
    let onToggle: () -> Void
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 14) {

                // MARK: Checkbox
                Button(action: onToggle) {
                    ZStack {
                        Circle()
                            .fill(todo.isCompleted
                                  ? Color.successGreen.opacity(0.2)
                                  : theme.accent.opacity(0.1))
                            .frame(width: 44, height: 44)

                        Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(todo.isCompleted ? .successGreen : theme.accentLight)
                    }
                }
                .buttonStyle(.plain)

                // MARK: Content
                VStack(alignment: .leading, spacing: 7) {

                    // Title row
                    HStack(spacing: 8) {
                        Text(todo.title)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(todo.isCompleted ? .textSecondary : .white)
                            .strikethrough(todo.isCompleted, color: .textSecondary)
                            .lineLimit(1)

                        // Recurrence badge (only for non-oneTime)
                        if todo.recurrence != .oneTime {
                            HStack(spacing: 4) {
                                Image(systemName: todo.recurrence.icon)
                                    .font(.system(size: 10, weight: .bold))
                                Text(todo.recurrence.displayName)
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .foregroundColor(theme.accentLight)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(theme.accent.opacity(0.18))
                            .cornerRadius(6)
                        }

                        Spacer()

                        // Priority icon
                        Image(systemName: todo.priority.icon)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(colorForPriority(todo.priority))
                    }

                    // Description
                    if !todo.description.isEmpty {
                        Text(todo.description)
                            .font(.system(size: 13))
                            .foregroundColor(.textSecondary)
                            .lineLimit(1)
                    }

                    // Due date
                    if let due = todo.dueDate {
                        HStack(spacing: 5) {
                            Image(systemName: "calendar")
                                .font(.system(size: 11, weight: .semibold))
                            Text(due.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(due.isOverdue && !todo.isCompleted ? .priorityHigh : .textSecondary)
                    }
                }

                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.appCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.glassStroke, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 8, y: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private func colorForPriority(_ priority: Priority) -> Color {
        switch priority {
        case .high:   return .priorityHigh
        case .medium: return .priorityMedium
        case .low:    return .priorityLow
        }
    }
}
