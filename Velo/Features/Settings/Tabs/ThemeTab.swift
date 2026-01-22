//
//  ThemeTab.swift
//  Velo
//
//  Theme management and customization
//

import SwiftUI

struct ThemeTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: VeloDesign.Spacing.xl) {
            // Header
            VStack(alignment: .leading, spacing: VeloDesign.Spacing.xs) {
                Text("theme.title".localized)
                    .font(TypographyTokens.displayMd)
                    .foregroundColor(ColorTokens.textPrimary)

                Text("theme.subtitle".localized)
                    .font(TypographyTokens.bodySm)
                    .foregroundColor(ColorTokens.textSecondary)
            }

            // Existing theme settings view
            ThemeSettingsView()
        }
    }
}

#Preview {
    ThemeTab()
        .frame(width: 600, height: 600)
        .background(ColorTokens.layer0)
}
