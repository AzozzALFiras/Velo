//
//  TypographyTokens.swift
//  Velo
//
//  Typography System with Consistent Scale
//  Replaces ad-hoc font sizing with structured hierarchy
//

import SwiftUI

enum TypographyTokens {

    // MARK: - Type Scale (1.25 Ratio)

    /// Type scale sizes
    enum Scale {
        static let xs: CGFloat = 11
        static let sm: CGFloat = 12
        static let base: CGFloat = 14
        static let md: CGFloat = 16
        static let lg: CGFloat = 18
        static let xl: CGFloat = 22
        static let xxl: CGFloat = 28
    }

    // MARK: - Monospace Stack (Terminal Output)

    /// Default monospace font (14pt)
    static let mono = Font.system(size: Scale.base, design: .monospaced)

    /// Small monospace font (12pt) - for metadata, timestamps
    static let monoSm = Font.system(size: Scale.sm, design: .monospaced)

    /// Large monospace font (16pt) - for emphasized code
    static let monoLg = Font.system(size: Scale.md, design: .monospaced)

    // MARK: - UI Stack (Interface Elements)

    /// Display large (28pt, bold) - for hero sections
    static let displayLg = Font.system(size: Scale.xxl, weight: .bold, design: .rounded)

    /// Display medium (22pt, semibold) - for section headers
    static let displayMd = Font.system(size: Scale.xl, weight: .semibold, design: .rounded)

    /// Heading (18pt, semibold) - for subsection titles
    static let heading = Font.system(size: Scale.lg, weight: .semibold, design: .rounded)

    /// Subheading (16pt, medium) - for card titles
    static let subheading = Font.system(size: Scale.md, weight: .medium, design: .rounded)

    /// Body (14pt, regular) - for general content
    static let body = Font.system(size: Scale.base, weight: .regular, design: .rounded)

    /// Body small (12pt, regular) - for secondary content
    static let bodySm = Font.system(size: Scale.sm, weight: .regular, design: .rounded)

    /// Caption (11pt, regular) - for metadata, labels
    static let caption = Font.system(size: Scale.xs, weight: .regular, design: .rounded)

    // MARK: - Emphasis Variants

    /// Body bold - for emphasis within paragraphs
    static let bodyBold = Font.system(size: Scale.base, weight: .semibold, design: .rounded)

    /// Caption medium - for emphasized metadata
    static let captionMedium = Font.system(size: Scale.xs, weight: .medium, design: .rounded)

    // MARK: - Line Heights

    /// Line height multipliers for different content types
    enum LineHeight {
        /// Tight - for headings and compact UI (1.25)
        static let tight: CGFloat = 1.25

        /// Normal - for body text (1.5)
        static let normal: CGFloat = 1.5

        /// Relaxed - for long-form content (1.75)
        static let relaxed: CGFloat = 1.75
    }
}

// MARK: - Backwards Compatibility Layer

extension TypographyTokens {
    /// Maps old VeloDesign.Typography to new token system
    /// These should eventually be migrated to direct token usage
    enum Legacy {
        static var monoFont: Font { mono }
        static var monoSmall: Font { monoSm }
        static var monoLarge: Font { monoLg }
        static var headline: Font { heading }
        static var subheadline: Font { subheading }
        static var caption: Font { TypographyTokens.caption }
    }
}

// MARK: - Custom Text Styles

extension View {
    /// Apply consistent line height to text
    func lineHeight(_ multiplier: CGFloat, fontSize: CGFloat) -> some View {
        self.lineSpacing((fontSize * multiplier) - fontSize)
    }
}
