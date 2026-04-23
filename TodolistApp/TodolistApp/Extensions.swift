//
//  Extensions.swift
//  TodolistApp
//

import SwiftUI

// MARK: - Neutral Colors (theme-independent)

extension Color {
    static let appBackground    = Color(hex: "0A0A1B")
    static let appCard          = Color(hex: "151528")
    static let appCardHighlight = Color(hex: "1C1C38")
    static let textSecondary    = Color(hex: "7878A0")
    static let priorityHigh     = Color(hex: "FF4D6A")
    static let priorityMedium   = Color(hex: "FFB347")
    static let priorityLow      = Color(hex: "4DA6FF")
    static let successGreen     = Color(hex: "34D399")
    static let glassStroke      = Color.white.opacity(0.08)

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a,r,g,b) = (255,(int>>8)*17,(int>>4 & 0xF)*17,(int & 0xF)*17)
        case 6:  (a,r,g,b) = (255, int>>16, int>>8 & 0xFF, int & 0xFF)
        case 8:  (a,r,g,b) = (int>>24, int>>16 & 0xFF, int>>8 & 0xFF, int & 0xFF)
        default: (a,r,g,b) = (255,0,0,0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}

// MARK: - Background Gradient

struct AppBG: View {
    var body: some View {
        LinearGradient(
            colors: [Color(hex: "0A0A1B"), Color(hex: "0F0E24"), Color(hex: "0A0A1B")],
            startPoint: .top, endPoint: .bottom
        ).ignoresSafeArea()
    }
}

// MARK: - Glass Card

struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 20
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.appCard.opacity(0.8))
                    .background(RoundedRectangle(cornerRadius: cornerRadius).fill(.ultraThinMaterial).opacity(0.3))
            )
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(Color.glassStroke, lineWidth: 1))
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius))
    }
}

// MARK: - Date Helpers

extension Date {
    var dueDateFormatted: String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; return f.string(from: self)
    }
    var isOverdue: Bool { self < Date() }
    var isToday: Bool { Calendar.current.isDateInToday(self) }
    var isThisWeek: Bool { Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear) }
    var isThisMonth: Bool { Calendar.current.isDate(self, equalTo: Date(), toGranularity: .month) }
    var relativeDescription: String {
        if isToday { return "Today" }
        if Calendar.current.isDateInTomorrow(self) { return "Tomorrow" }
        if Calendar.current.isDateInYesterday(self) { return "Yesterday" }
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d"; return f.string(from: self)
    }
}
