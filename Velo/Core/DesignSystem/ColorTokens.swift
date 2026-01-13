//
//  ColorTokens.swift
//  Velo
//
//  Refined Minimalism Color System
//  Replaces heavy glassmorphism with sophisticated, accessible color palette
//

import SwiftUI

enum ColorTokens {

    // MARK: - Layer System (Background → Overlay)

    /// Deep background layer (darkest)
    static let layer0 = Color(hex: "0A0A0F")

    /// Surface layer (cards, panels)
    static let layer1 = Color(hex: "14141B")

    /// Elevated surface layer (raised cards, modals)
    static let layer2 = Color(hex: "1C1C26")

    /// Overlay layer (dropdowns, tooltips)
    static let layer3 = Color(hex: "252530")

    // MARK: - Accent Colors (Refined)

    /// Primary accent - Refined cyan (toned down from #00F5FF)
    static let accentPrimary = Color(hex: "4AA9FF")

    /// Secondary accent - Refined purple (toned down from #BF40BF)
    static let accentSecondary = Color(hex: "9B59FF")

    /// Tertiary accent - Refined teal
    static let accentTertiary = Color(hex: "2DD4BF")

    // MARK: - Semantic Colors

    /// Success state - Green
    static let success = Color(hex: "10B981")

    /// Warning state - Amber
    static let warning = Color(hex: "F59E0B")

    /// Error state - Red
    static let error = Color(hex: "EF4444")

    /// Info state - Blue
    static let info = Color(hex: "3B82F6")

    // MARK: - Text Hierarchy

    /// Primary text - Highest contrast
    static let textPrimary = Color(hex: "F8FAFC")

    /// Secondary text - Medium contrast
    static let textSecondary = Color(hex: "94A3B8")

    /// Tertiary text - Lower contrast
    static let textTertiary = Color(hex: "64748B")

    /// Disabled text - Lowest contrast
    static let textDisabled = Color(hex: "475569")

    // MARK: - Interactive States

    /// Default interactive element color
    static let interactive = Color(hex: "4AA9FF")

    /// Hover state
    static let interactiveHover = Color(hex: "60B5FF")

    /// Active/pressed state
    static let interactiveActive = Color(hex: "3A93E6")

    /// Disabled state
    static let interactiveDisabled = Color(hex: "2D3748")

    // MARK: - Borders

    /// Default border color
    static let border = Color(hex: "2D2D3A")

    /// Hover border color
    static let borderHover = Color(hex: "3D3D4A")

    /// Focus border color (matches interactive)
    static let borderFocus = Color(hex: "4AA9FF")

    /// Subtle border for dividers
    static let borderSubtle = Color(hex: "1E1E2A")
}

// MARK: - Backwards Compatibility Layer

extension ColorTokens {
    /// Maps old glassmorphism colors to new layer system
    /// These should eventually be migrated away from
    enum Legacy {
        static var deepSpace: Color { layer0 }
        static var darkSurface: Color { layer1 }
        static var cardBackground: Color { layer2 }
        static var elevatedSurface: Color { layer3 }

        static var neonCyan: Color { accentPrimary }
        static var neonPurple: Color { accentSecondary }
        static var neonGreen: Color { success }

        static var glassWhite: Color { Color.white.opacity(0.05) }
        static var glassBorder: Color { border }
        static var glassHighlight: Color { Color.white.opacity(0.08) }
    }
}


