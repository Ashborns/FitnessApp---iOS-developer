// PULSE Design System — Dark-first, energetic, AI-coach vibe
// Brand: PULSE — Your AI Fitness Coach
// All semantic tokens auto-adapt; dark mode is the primary canvas

import SwiftUI
import UIKit

// MARK: - Brand Tokens

enum BrandTokens {
    static let appName = "PULSE"
    static let tagline = "AI Fitness Coach"
    static let logoSymbol = "bolt.heart.fill"
}

// MARK: - Semantic Color Tokens

extension Color {

    // MARK: Primary — Strava Orange (signature brand color)
    static let themePrimary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.99, green: 0.30, blue: 0.00, alpha: 1.0)  // #FC4C02 — Strava orange
            : UIColor(red: 0.85, green: 0.26, blue: 0.00, alpha: 1.0)  // #D94300
    })

    // MARK: Secondary — Warm Amber
    static let themeSecondary = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.00, green: 0.72, blue: 0.00, alpha: 1.0)  // #FFB800
            : UIColor(red: 0.78, green: 0.52, blue: 0.00, alpha: 1.0)  // #C78500
    })

    // MARK: Accent — Deep Coral (used for coaching highlights)
    static let themeAccent = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.00, green: 0.45, blue: 0.20, alpha: 1.0)  // #FF7333
            : UIColor(red: 0.80, green: 0.30, blue: 0.10, alpha: 1.0)  // #CC4D1A
    })

    // MARK: Background — Pure black
    static let themeBackground = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.00, green: 0.00, blue: 0.00, alpha: 1.0)  // #000000
            : UIColor(red: 0.97, green: 0.96, blue: 0.95, alpha: 1.0)  // #F8F5F2 warm off-white
    })

    // MARK: Surface — Slightly elevated dark
    static let themeSurface = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1.0)  // #141414
            : UIColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1.0)
    })

    // MARK: Surface Elevated — even more raised
    static let themeSurfaceElevated = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1.0)  // #1F1F1F
            : UIColor(red: 0.99, green: 0.98, blue: 0.97, alpha: 1.0)
    })

    // MARK: Border — subtle separators
    static let themeBorder = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 1.0, alpha: 0.10)
            : UIColor(white: 0.0, alpha: 0.08)
    })

    // MARK: Error — Red
    static let themeError = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.00, green: 0.30, blue: 0.30, alpha: 1.0)
            : UIColor(red: 0.78, green: 0.10, blue: 0.10, alpha: 1.0)
    })

    // MARK: Brand Gradient — orange → amber (signature)
    static var brandGradient: LinearGradient {
        LinearGradient(
            colors: [Color.themePrimary, Color.themeSecondary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: Coach Gradient — for camera/coaching highlights
    static var coachGradient: LinearGradient {
        LinearGradient(
            colors: [Color.themeAccent, Color.themePrimary],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Spacing Tokens

extension CGFloat {
    static let spacingSmall: CGFloat = 4
    static let spacingMedium: CGFloat = 8
    static let spacingLarge: CGFloat = 16
    static let spacingExtraLarge: CGFloat = 24
}

// MARK: - Corner Radius Tokens

extension CGFloat {
    static let cornerRadiusSmall: CGFloat = 12
    static let cornerRadiusLarge: CGFloat = 20
    static let cornerRadiusExtraLarge: CGFloat = 28
}
