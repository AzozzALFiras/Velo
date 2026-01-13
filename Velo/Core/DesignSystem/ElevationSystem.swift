//
//  ElevationSystem.swift
//  Velo
//
//  Elevation System - Replaces Glassmorphism
//  Provides depth through subtle shadows instead of heavy blur effects
//

import SwiftUI

// MARK: - Elevation Levels

enum Elevation {
    case flat
    case low
    case medium
    case high
    case overlay

    // MARK: - Shadow Properties

    var shadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        switch self {
        case .flat:
            return (.clear, 0, 0, 0)
        case .low:
            return (Color.black.opacity(0.1), 2, 0, 1)
        case .medium:
            return (Color.black.opacity(0.15), 8, 0, 4)
        case .high:
            return (Color.black.opacity(0.2), 16, 0, 8)
        case .overlay:
            return (Color.black.opacity(0.3), 24, 0, 12)
        }
    }

    // MARK: - Background Colors

    var background: Color {
        switch self {
        case .flat:
            return ColorTokens.layer0
        case .low:
            return ColorTokens.layer1
        case .medium:
            return ColorTokens.layer2
        case .high:
            return ColorTokens.layer3
        case .overlay:
            return ColorTokens.layer3
        }
    }

    // MARK: - Border Color

    var borderColor: Color {
        ColorTokens.border
    }

    // MARK: - Border Width

    var borderWidth: CGFloat {
        switch self {
        case .flat:
            return 0
        case .low, .medium:
            return 1
        case .high, .overlay:
            return 1.5
        }
    }
}

// MARK: - View Modifier

struct ElevatedCard: ViewModifier {
    let elevation: Elevation
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(elevation.background)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(elevation.borderColor, lineWidth: elevation.borderWidth)
            )
            .shadow(
                color: elevation.shadow.color,
                radius: elevation.shadow.radius,
                x: elevation.shadow.x,
                y: elevation.shadow.y
            )
    }
}

// MARK: - View Extension

extension View {
    /// Apply elevation styling to create depth
    /// - Parameters:
    ///   - level: The elevation level (flat, low, medium, high, overlay)
    ///   - cornerRadius: Corner radius for the card (default: 10)
    /// - Returns: Styled view with elevation
    func elevated(_ level: Elevation, cornerRadius: CGFloat = 10) -> some View {
        modifier(ElevatedCard(elevation: level, cornerRadius: cornerRadius))
    }
}

// MARK: - Specialized Elevation Modifiers

extension View {
    /// Apply subtle elevation for inline elements
    func elevatedInline() -> some View {
        self.elevated(.low, cornerRadius: 6)
    }

    /// Apply standard elevation for cards
    func elevatedCard() -> some View {
        self.elevated(.low, cornerRadius: 10)
    }

    /// Apply medium elevation for important cards
    func elevatedPanel() -> some View {
        self.elevated(.medium, cornerRadius: 12)
    }

    /// Apply high elevation for modals and dialogs
    func elevatedModal() -> some View {
        self.elevated(.high, cornerRadius: 14)
    }

    /// Apply maximum elevation for overlays
    func elevatedOverlay() -> some View {
        self.elevated(.overlay, cornerRadius: 14)
    }
}

// MARK: - Migration Helpers

extension View {
    /// Backwards compatible glassCard replacement
    /// Maps old glassCard() calls to new elevated() system
    /// This method should be used during migration phase only
    @available(*, deprecated, message: "Use .elevated(.low) instead")
    func glassCardCompat(
        cornerRadius: CGFloat = 10,
        borderOpacity: Double = 0.1,
        glowColor: Color? = nil
    ) -> some View {
        // Map to closest elevation level
        self.elevated(.low, cornerRadius: cornerRadius)
    }
}
