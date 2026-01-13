//
//  DesignSystem.swift
//  Velo
//
//  AI-Powered Terminal - Futuristic Design System
//

import SwiftUI

// MARK: - Design Tokens
enum VeloDesign {
    
    // MARK: - Theme-Aware Dynamic Colors (Preferred)
    class ThemeAware {
        nonisolated(unsafe) static var themeManager: ThemeManager?
        
        static var Colors: ColorsProtocol {
            if let manager = themeManager {
                return ThemeColors(theme: manager.currentThemeSnapshot)
            }
            return StaticColors()
        }
        
        static var Typography: TypographyProtocol {
            if let manager = themeManager {
                return ThemeFonts(theme: manager.currentThemeSnapshot)
            }
            return StaticTypography()
        }
    }
    
    // MARK: - Colors (Now delegates to ThemeAware)
    enum Colors {
        // Primary
        static var neonCyan: Color { ThemeAware.Colors.neonCyan }
        static var neonPurple: Color { ThemeAware.Colors.neonPurple }
        static var neonGreen: Color { ThemeAware.Colors.neonGreen }
        
        // Backgrounds
        static var deepSpace: Color { ThemeAware.Colors.deepSpace }
        static var darkSurface: Color { ThemeAware.Colors.darkSurface }
        static var cardBackground: Color { ThemeAware.Colors.cardBackground }
        static var elevatedSurface: Color { ThemeAware.Colors.elevatedSurface }
        
        // Text
        static var textPrimary: Color { ThemeAware.Colors.textPrimary }
        static var textSecondary: Color { ThemeAware.Colors.textSecondary }
        static var textMuted: Color { ThemeAware.Colors.textMuted }
        
        // Semantic
        static var success: Color { ThemeAware.Colors.success }
        static var warning: Color { ThemeAware.Colors.warning }
        static var error: Color { ThemeAware.Colors.error }
        static var info: Color { ThemeAware.Colors.info }
        
        // Glass
        static var glassWhite: Color { ThemeAware.Colors.glassWhite }
        static var glassBorder: Color { ThemeAware.Colors.glassBorder }
        static var glassHighlight: Color { ThemeAware.Colors.glassHighlight }
    }
    
    // MARK: - Typography (Now delegates to ThemeAware)
    enum Typography {
        static var monoFont: Font { ThemeAware.Typography.monoFont }
        static var monoSmall: Font { ThemeAware.Typography.monoSmall }
        static var monoLarge: Font { ThemeAware.Typography.monoLarge }
        
        static var headline: Font { ThemeAware.Typography.headline }
        static var subheadline: Font { ThemeAware.Typography.subheadline }
        static var caption: Font { ThemeAware.Typography.caption }
    }
    
    // MARK: - Spacing
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }
    
    // MARK: - Radius
    enum Radius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 10
        static let large: CGFloat = 14
        static let xl: CGFloat = 20
    }
    
    // MARK: - Shadows
    enum Shadows {
        static func glow(color: Color, radius: CGFloat = 20) -> some View {
            Circle()
                .fill(color.opacity(0.3))
                .blur(radius: radius)
        }
        
        static let cardShadow = Color.black.opacity(0.5)
    }
    
    // MARK: - Animations
    enum Animation {
        static let quick = SwiftUI.Animation.easeOut(duration: 0.15)
        static let smooth = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let spring = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.7)
        static let bounce = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.6)
    }
    
    // MARK: - Gradients
    enum Gradients {
        static let cyanPurple = LinearGradient(
            colors: [Colors.neonCyan, Colors.neonPurple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let glassShimmer = LinearGradient(
            colors: [
                Color.white.opacity(0.1),
                Color.white.opacity(0.05),
                Color.white.opacity(0.1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let darkFade = LinearGradient(
            colors: [Colors.deepSpace, Colors.deepSpace.opacity(0)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Glassmorphism Modifier
struct GlassmorphismModifier: ViewModifier {
    var cornerRadius: CGFloat = VeloDesign.Radius.medium
    var borderOpacity: Double = 0.1
    var blurRadius: CGFloat = 20
    var glowColor: Color? = nil
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Blur background
                    VeloDesign.Colors.cardBackground.opacity(0.6)
                    
                    // Glass layer
                    VeloDesign.Gradients.glassShimmer
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(borderOpacity), lineWidth: 1)
            )
            .shadow(color: VeloDesign.Shadows.cardShadow, radius: 10, y: 5)
            .overlay(
                Group {
                    if let glow = glowColor {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(glow.opacity(0.3), lineWidth: 1)
                            .blur(radius: 4)
                    }
                }
            )
    }
}

extension View {
    func glassCard(
        cornerRadius: CGFloat = VeloDesign.Radius.medium,
        borderOpacity: Double = 0.1,
        glowColor: Color? = nil
    ) -> some View {
        modifier(GlassmorphismModifier(
            cornerRadius: cornerRadius,
            borderOpacity: borderOpacity,
            glowColor: glowColor
        ))
    }
}

// MARK: - Glow Effect Modifier
struct GlowModifier: ViewModifier {
    let color: Color
    let radius: CGFloat
    let isActive: Bool
    
    func body(content: Content) -> some View {
        content
            .shadow(color: isActive ? color.opacity(0.5) : .clear, radius: radius / 2)
            .shadow(color: isActive ? color.opacity(0.3) : .clear, radius: radius)
    }
}

extension View {
    func glow(_ color: Color, radius: CGFloat = 10, isActive: Bool = true) -> some View {
        modifier(GlowModifier(color: color, radius: radius, isActive: isActive))
    }
}

// MARK: - Neon Border Modifier
struct NeonBorderModifier: ViewModifier {
    let color: Color
    let cornerRadius: CGFloat
    let isActive: Bool
    
    @State private var animationPhase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        isActive ? color : Color.clear,
                        lineWidth: 1.5
                    )
                    .blur(radius: isActive ? 2 : 0)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        isActive ? color : Color.clear,
                        lineWidth: 1
                    )
            )
    }
}

extension View {
    func neonBorder(
        _ color: Color,
        cornerRadius: CGFloat = VeloDesign.Radius.medium,
        isActive: Bool = true
    ) -> some View {
        modifier(NeonBorderModifier(color: color, cornerRadius: cornerRadius, isActive: isActive))
    }
}

// MARK: - Hover Effect Modifier
struct HoverEffectModifier: ViewModifier {
    @State private var isHovered = false
    let scaleAmount: CGFloat
    let glowColor: Color
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? scaleAmount : 1.0)
            .glow(glowColor, radius: 15, isActive: isHovered)
            .animation(VeloDesign.Animation.quick, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

extension View {
    func hoverEffect(
        scale: CGFloat = 1.02,
        glowColor: Color = VeloDesign.Colors.neonCyan
    ) -> some View {
        modifier(HoverEffectModifier(scaleAmount: scale, glowColor: glowColor))
    }
}

// MARK: - Status Indicator
struct StatusDot: View {
    let status: CommandStatus
    
    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: 8, height: 8)
            .glow(status.color, radius: 5)
    }
}

enum CommandStatus {
    case success, error, running, idle
    
    var color: Color {
        switch self {
        case .success: return VeloDesign.Colors.success
        case .error: return VeloDesign.Colors.error
        case .running: return VeloDesign.Colors.warning
        case .idle: return VeloDesign.Colors.textMuted
        }
    }
}

// MARK: - Icon Button Style
struct IconButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(VeloDesign.Spacing.sm)
            .background(
                Circle()
                    .fill(color.opacity(configuration.isPressed ? 0.3 : 0.1))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(VeloDesign.Animation.quick, value: configuration.isPressed)
    }
}

// MARK: - Pill Tag
struct PillTag: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(VeloDesign.Typography.caption)
            .foregroundColor(color)
            .padding(.horizontal, VeloDesign.Spacing.sm)
            .padding(.vertical, VeloDesign.Spacing.xs)
            .background(
                Capsule()
                    .fill(color.opacity(0.15))
            )
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.3), lineWidth: 0.5)
            )
    }
}

// MARK: - Theme Protocols
protocol ColorsProtocol {
    var neonCyan: Color { get }
    var neonPurple: Color { get }
    var neonGreen: Color { get }
    var deepSpace: Color { get }
    var darkSurface: Color { get }
    var cardBackground: Color { get }
    var elevatedSurface: Color { get }
    var textPrimary: Color { get }
    var textSecondary: Color { get }
    var textMuted: Color { get }
    var success: Color { get }
    var warning: Color { get }
    var error: Color { get }
    var info: Color { get }
    var glassWhite: Color { get }
    var glassBorder: Color { get }
    var glassHighlight: Color { get }
}

protocol TypographyProtocol {
    var monoFont: Font { get }
    var monoSmall: Font { get }
    var monoLarge: Font { get }
    var headline: Font { get }
    var subheadline: Font { get }
    var caption: Font { get }
}

// MARK: - Theme-Based Implementations
struct ThemeColors: ColorsProtocol {
    let theme: VeloTheme
    
    var neonCyan: Color { theme.colorScheme.color(for: \.neonCyan) }
    var neonPurple: Color { theme.colorScheme.color(for: \.neonPurple) }
    var neonGreen: Color { theme.colorScheme.color(for: \.neonGreen) }
    var deepSpace: Color { theme.colorScheme.color(for: \.deepSpace) }
    var darkSurface: Color { theme.colorScheme.color(for: \.darkSurface) }
    var cardBackground: Color { theme.colorScheme.color(for: \.cardBackground) }
    var elevatedSurface: Color { theme.colorScheme.color(for: \.elevatedSurface) }
    var textPrimary: Color { theme.colorScheme.color(for: \.textPrimary) }
    var textSecondary: Color { theme.colorScheme.color(for: \.textSecondary) }
    var textMuted: Color { theme.colorScheme.color(for: \.textMuted) }
    var success: Color { theme.colorScheme.color(for: \.success) }
    var warning: Color { theme.colorScheme.color(for: \.warning) }
    var error: Color { theme.colorScheme.color(for: \.error) }
    var info: Color { theme.colorScheme.color(for: \.info) }
    var glassWhite: Color { theme.colorScheme.glassWhite() }
    var glassBorder: Color { theme.colorScheme.glassBorder() }
    var glassHighlight: Color { theme.colorScheme.glassHighlight() }
}

struct ThemeFonts: TypographyProtocol {
    let theme: VeloTheme
    
    var monoFont: Font { theme.fontScheme.monoFont() }
    var monoSmall: Font { theme.fontScheme.monoSmall() }
    var monoLarge: Font { theme.fontScheme.monoLarge() }
    var headline: Font { theme.fontScheme.headline() }
    var subheadline: Font { theme.fontScheme.subheadline() }
    var caption: Font { theme.fontScheme.caption() }
}

// MARK: - Static Fallback Implementations
struct StaticColors: ColorsProtocol {
    var neonCyan: Color { Color(hex: "00F5FF") }
    var neonPurple: Color { Color(hex: "BF40BF") }
    var neonGreen: Color { Color(hex: "00FF88") }
    var deepSpace: Color { Color(hex: "0A0A14") }
    var darkSurface: Color { Color(hex: "12121C") }
    var cardBackground: Color { Color(hex: "1A1A28") }
    var elevatedSurface: Color { Color(hex: "22222F") }
    var textPrimary: Color { Color.white }
    var textSecondary: Color { Color(hex: "A0A0B0") }
    var textMuted: Color { Color(hex: "606070") }
    var success: Color { Color(hex: "00FF88") }
    var warning: Color { Color(hex: "FFD60A") }
    var error: Color { Color(hex: "FF6B6B") }
    var info: Color { Color(hex: "6B9BFF") }
    var glassWhite: Color { Color.white.opacity(0.05) }
    var glassBorder: Color { Color.white.opacity(0.1) }
    var glassHighlight: Color { Color.white.opacity(0.15) }
}

struct StaticTypography: TypographyProtocol {
    var monoFont: Font { Font.system(.body, design: .monospaced) }
    var monoSmall: Font { Font.system(.caption, design: .monospaced) }
    var monoLarge: Font { Font.system(.title3, design: .monospaced) }
    var headline: Font { Font.system(.headline, design: .rounded).weight(.semibold) }
    var subheadline: Font { Font.system(.subheadline, design: .rounded) }
    var caption: Font { Font.system(.caption, design: .rounded) }
}

