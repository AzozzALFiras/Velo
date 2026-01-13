//
//  VeloTheme.swift
//  Velo
//
//  AI-Powered Terminal - Theme System
//

import SwiftUI

// MARK: - Velo Theme
struct VeloTheme: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var isBuiltIn: Bool
    var colorScheme: ColorScheme
    var fontScheme: FontScheme
    
    init(
        id: UUID = UUID(),
        name: String,
        isBuiltIn: Bool = false,
        colorScheme: ColorScheme,
        fontScheme: FontScheme
    ) {
        self.id = id
        self.name = name
        self.isBuiltIn = isBuiltIn
        self.colorScheme = colorScheme
        self.fontScheme = fontScheme
    }
    
    // MARK: - Color Scheme
    struct ColorScheme: Codable, Hashable {
        // Primary Colors
        var neonCyan: String
        var neonPurple: String
        var neonGreen: String
        
        // Backgrounds
        var deepSpace: String
        var darkSurface: String
        var cardBackground: String
        var elevatedSurface: String
        
        // Text
        var textPrimary: String
        var textSecondary: String
        var textMuted: String
        
        // Semantic
        var success: String
        var warning: String
        var error: String
        var info: String
        
        // Glass Effects
        var glassWhiteOpacity: Double
        var glassBorderOpacity: Double
        var glassHighlightOpacity: Double
        
        // Convert hex strings to Color
        func color(for keyPath: KeyPath<ColorScheme, String>) -> Color {
            Color(hex: self[keyPath: keyPath])
        }
        
        func glassWhite() -> Color {
            Color.white.opacity(glassWhiteOpacity)
        }
        
        func glassBorder() -> Color {
            Color.white.opacity(glassBorderOpacity)
        }
        
        func glassHighlight() -> Color {
            Color.white.opacity(glassHighlightOpacity)
        }
    }
    
    // MARK: - Font Scheme
    struct FontScheme: Codable, Hashable {
        var monoFontName: String
        var monoFontSize: CGFloat
        
        var headlineFontName: String
        var headlineFontSize: CGFloat
        
        var bodyFontSize: CGFloat
        var captionFontSize: CGFloat
        
        // Computed font properties
        func monoFont() -> Font {
            if monoFontName == "System Monospaced" {
                return .system(size: monoFontSize, design: .monospaced)
            }
            return .custom(monoFontName, size: monoFontSize)
        }
        
        func monoSmall() -> Font {
            if monoFontName == "System Monospaced" {
                return .system(size: captionFontSize, design: .monospaced)
            }
            return .custom(monoFontName, size: captionFontSize)
        }
        
        func monoLarge() -> Font {
            if monoFontName == "System Monospaced" {
                return .system(size: headlineFontSize, design: .monospaced)
            }
            return .custom(monoFontName, size: headlineFontSize)
        }
        
        func headline() -> Font {
            if headlineFontName == "System Rounded" {
                return .system(size: headlineFontSize, design: .rounded).weight(.semibold)
            }
            return .custom(headlineFontName, size: headlineFontSize).weight(.semibold)
        }
        
        func subheadline() -> Font {
            if headlineFontName == "System Rounded" {
                return .system(size: bodyFontSize, design: .rounded)
            }
            return .custom(headlineFontName, size: bodyFontSize)
        }
        
        func caption() -> Font {
            if headlineFontName == "System Rounded" {
                return .system(size: captionFontSize, design: .rounded)
            }
            return .custom(headlineFontName, size: captionFontSize)
        }
    }
}

// MARK: - Built-in Themes
extension VeloTheme {
    static let neonDark = VeloTheme(
        name: "Neon Dark",
        isBuiltIn: true,
        colorScheme: ColorScheme(
            neonCyan: "4AA9FF",         // Refined - toned down from 00F5FF
            neonPurple: "9B59FF",       // Refined - toned down from BF40BF
            neonGreen: "10B981",        // Refined - replaced with professional green
            deepSpace: "0A0A0F",        // Updated to match ColorTokens.layer0
            darkSurface: "14141B",      // Updated to match ColorTokens.layer1
            cardBackground: "1C1C26",   // Updated to match ColorTokens.layer2
            elevatedSurface: "252530",  // Updated to match ColorTokens.layer3
            textPrimary: "F8FAFC",      // Updated to match ColorTokens.textPrimary
            textSecondary: "94A3B8",    // Updated to match ColorTokens.textSecondary
            textMuted: "64748B",        // Updated to match ColorTokens.textTertiary
            success: "10B981",          // Updated to match ColorTokens.success
            warning: "F59E0B",          // Updated to match ColorTokens.warning
            error: "EF4444",            // Updated to match ColorTokens.error
            info: "3B82F6",             // Updated to match ColorTokens.info
            glassWhiteOpacity: 0.05,
            glassBorderOpacity: 0.1,
            glassHighlightOpacity: 0.15
        ),
        fontScheme: FontScheme(
            monoFontName: "System Monospaced",
            monoFontSize: 14,           // Updated to match TypographyTokens.Scale.base
            headlineFontName: "System Rounded",
            headlineFontSize: 18,       // Updated to match TypographyTokens.Scale.lg
            bodyFontSize: 14,           // Updated to match TypographyTokens.Scale.base
            captionFontSize: 11         // Updated to match TypographyTokens.Scale.xs
        )
    )
    
    static let classicDark = VeloTheme(
        name: "Classic Dark",
        isBuiltIn: true,
        colorScheme: ColorScheme(
            neonCyan: "5AC8FA",         // macOS system blue
            neonPurple: "AF52DE",       // macOS system purple
            neonGreen: "30D158",        // macOS system green
            deepSpace: "000000",        // Pure black
            darkSurface: "1C1C1E",      // macOS system gray 6
            cardBackground: "2C2C2E",   // macOS system gray 5
            elevatedSurface: "3A3A3C",  // macOS system gray 4
            textPrimary: "FFFFFF",      // Pure white
            textSecondary: "98989D",    // macOS label secondary
            textMuted: "636366",        // macOS label tertiary
            success: "30D158",          // macOS green
            warning: "FFD60A",          // macOS yellow
            error: "FF453A",            // macOS red
            info: "5AC8FA",             // macOS blue
            glassWhiteOpacity: 0.05,
            glassBorderOpacity: 0.1,
            glassHighlightOpacity: 0.15
        ),
        fontScheme: FontScheme(
            monoFontName: "System Monospaced",
            monoFontSize: 14,           // Updated to match TypographyTokens
            headlineFontName: "System Rounded",
            headlineFontSize: 18,       // Updated to match TypographyTokens
            bodyFontSize: 14,
            captionFontSize: 11
        )
    )
    
    static let light = VeloTheme(
        name: "Light",
        isBuiltIn: true,
        colorScheme: ColorScheme(
            neonCyan: "007AFF",
            neonPurple: "AF52DE",
            neonGreen: "34C759",
            deepSpace: "FFFFFF",
            darkSurface: "F2F2F7",
            cardBackground: "FFFFFF",
            elevatedSurface: "F9F9F9",
            textPrimary: "000000",
            textSecondary: "3C3C43",
            textMuted: "8E8E93",
            success: "34C759",
            warning: "FF9500",
            error: "FF3B30",
            info: "007AFF",
            glassWhiteOpacity: 0.1,
            glassBorderOpacity: 0.15,
            glassHighlightOpacity: 0.2
        ),
        fontScheme: FontScheme(
            monoFontName: "System Monospaced",
            monoFontSize: 14,           // Updated to match TypographyTokens
            headlineFontName: "System Rounded",
            headlineFontSize: 18,       // Updated to match TypographyTokens
            bodyFontSize: 14,
            captionFontSize: 11
        )
    )

    static let cyberpunk = VeloTheme(
        name: "Cyberpunk",
        isBuiltIn: true,
        colorScheme: ColorScheme(
            neonCyan: "00FFFF",
            neonPurple: "FF00FF",
            neonGreen: "39FF14",
            deepSpace: "0D0221",
            darkSurface: "0F084B",
            cardBackground: "26408B",
            elevatedSurface: "A6CFD5",
            textPrimary: "FFFFFF",
            textSecondary: "C2E7D9",
            textMuted: "7A86B6",
            success: "39FF14",
            warning: "FFE600",
            error: "FF006E",
            info: "00FFFF",
            glassWhiteOpacity: 0.08,
            glassBorderOpacity: 0.15,
            glassHighlightOpacity: 0.2
        ),
        fontScheme: FontScheme(
            monoFontName: "System Monospaced",
            monoFontSize: 14,           // Updated to match TypographyTokens
            headlineFontName: "System Rounded",
            headlineFontSize: 18,       // Updated to match TypographyTokens
            bodyFontSize: 14,
            captionFontSize: 11
        )
    )

    static let allBuiltInThemes: [VeloTheme] = [
        .neonDark,
        .classicDark,
        .light,
        .cyberpunk
    ]
}
