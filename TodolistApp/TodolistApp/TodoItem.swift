//
//  TodoItem.swift
//  TodolistApp
//

import Foundation
import FirebaseFirestore

enum Priority: String, CaseIterable, Codable {
    case low    = "low"
    case medium = "medium"
    case high   = "high"

    var displayName: String {
        switch self {
        case .low:    return "Low"
        case .medium: return "Medium"
        case .high:   return "High"
        }
    }

    var icon: String {
        switch self {
        case .low:    return "arrow.down"
        case .medium: return "minus"
        case .high:   return "arrow.up"
        }
    }
}

enum Recurrence: String, CaseIterable, Codable {
    case oneTime = "oneTime"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"

    var displayName: String {
        switch self {
        case .oneTime: return "One Time"
        case .daily:   return "Daily"
        case .weekly:  return "Weekly"
        case .monthly: return "Monthly"
        }
    }

    var shortName: String {
        switch self {
        case .oneTime: return "Once"
        case .daily:   return "Daily"
        case .weekly:  return "Weekly"
        case .monthly: return "Monthly"
        }
    }

    var icon: String {
        switch self {
        case .oneTime: return "1.circle"
        case .daily:   return "repeat"
        case .weekly:  return "repeat.circle"
        case .monthly: return "calendar"
        }
    }
}

struct TodoItem: Identifiable, Codable {
    @DocumentID var id: String?
    var title: String
    var description: String
    var isCompleted: Bool
    var priority: Priority
    var recurrence: Recurrence = .oneTime
    var dueDate: Date?
    var createdAt: Date
    var updatedAt: Date
}
