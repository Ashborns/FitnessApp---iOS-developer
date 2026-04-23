//
//  ThemeManager.swift
//  TodolistApp
//

import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case amethyst, ocean, emerald, sunset, rose, arctic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .amethyst: return "Amethyst"
        case .ocean:    return "Ocean"
        case .emerald:  return "Emerald"
        case .sunset:   return "Sunset"
        case .rose:     return "Rose"
        case .arctic:   return "Arctic"
        }
    }

    var accent: Color {
        switch self {
        case .amethyst: return Color(hex: "7B61FF")
        case .ocean:    return Color(hex: "3B82F6")
        case .emerald:  return Color(hex: "10B981")
        case .sunset:   return Color(hex: "F59E0B")
        case .rose:     return Color(hex: "F43F5E")
        case .arctic:   return Color(hex: "06B6D4")
        }
    }

    var accentLight: Color {
        switch self {
        case .amethyst: return Color(hex: "A78BFA")
        case .ocean:    return Color(hex: "93C5FD")
        case .emerald:  return Color(hex: "6EE7B7")
        case .sunset:   return Color(hex: "FCD34D")
        case .rose:     return Color(hex: "FDA4AF")
        case .arctic:   return Color(hex: "67E8F9")
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .amethyst: return [Color(hex: "7B61FF"), Color(hex: "A855F7"), Color(hex: "C084FC")]
        case .ocean:    return [Color(hex: "2563EB"), Color(hex: "3B82F6"), Color(hex: "60A5FA")]
        case .emerald:  return [Color(hex: "059669"), Color(hex: "10B981"), Color(hex: "34D399")]
        case .sunset:   return [Color(hex: "D97706"), Color(hex: "F59E0B"), Color(hex: "FBBF24")]
        case .rose:     return [Color(hex: "E11D48"), Color(hex: "F43F5E"), Color(hex: "FB7185")]
        case .arctic:   return [Color(hex: "0891B2"), Color(hex: "06B6D4"), Color(hex: "22D3EE")]
        }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var horizontalGradient: LinearGradient {
        LinearGradient(colors: Array(gradientColors.prefix(2)), startPoint: .leading, endPoint: .trailing)
    }
}

class ThemeManager: ObservableObject {
    @AppStorage("selectedTheme") private var stored: String = AppTheme.amethyst.rawValue

    var current: AppTheme {
        get { AppTheme(rawValue: stored) ?? .amethyst }
        set { stored = newValue.rawValue; objectWillChange.send() }
    }

    var accent: Color { current.accent }
    var accentLight: Color { current.accentLight }
    var gradient: LinearGradient { current.gradient }
    var hGradient: LinearGradient { current.horizontalGradient }
}
