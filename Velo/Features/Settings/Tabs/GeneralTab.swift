//
//  GeneralTab.swift
//  Velo
//
//  General settings and preferences
//

import SwiftUI

struct GeneralTab: View {
    // Preferences
    @AppStorage("autoOpenHistory") private var autoOpenHistory = true
    @AppStorage("autoOpenAIPanel") private var autoOpenAIPanel = true

    // Features
    @AppStorage("isInteractiveOutputEnabled") private var isInteractiveOutputEnabled = true
    @AppStorage("isDeepFileParsingEnabled") private var isDeepFileParsingEnabled = true
    @AppStorage("autoLSafterCD") private var autoLSafterCD = false

    var body: some View {
        VStack(alignment: .leading, spacing: VeloDesign.Spacing.xl) {
            // Header
            VStack(alignment: .leading, spacing: VeloDesign.Spacing.xs) {
                Text("general.title".localized)
                    .font(TypographyTokens.displayMd)
                    .foregroundColor(ColorTokens.textPrimary)

                Text("general.subtitle".localized)
                    .font(TypographyTokens.bodySm)
                    .foregroundColor(ColorTokens.textSecondary)
            }

            // UI Preferences Section
            VStack(alignment: .leading, spacing: VeloDesign.Spacing.md) {
                SectionHeader(title: "general.interface".localized)

                VStack(spacing: 0) {
                    ToggleRow(
                        title: "general.autoOpenHistory".localized,
                        subtitle: "general.autoOpenHistoryDesc".localized,
                        isOn: $autoOpenHistory
                    )

                    Divider()
                        .background(ColorTokens.borderSubtle)
                        .padding(.horizontal, VeloDesign.Spacing.md)

                    ToggleRow(
                        title: "general.autoOpenAI".localized,
                        subtitle: "general.autoOpenAIDesc".localized,
                        isOn: $autoOpenAIPanel
                    )
                }
                .padding(VeloDesign.Spacing.md)
                .elevated(.low)
            }

            // Terminal Features Section
            VStack(alignment: .leading, spacing: VeloDesign.Spacing.md) {
                SectionHeader(title: "general.terminalFeatures".localized)

                VStack(spacing: 0) {
                    ToggleRow(
                        title: "general.interactiveOutput".localized,
                        subtitle: "general.interactiveOutputDesc".localized,
                        isOn: $isInteractiveOutputEnabled
                    )

                    Divider()
                        .background(ColorTokens.borderSubtle)
                        .padding(.horizontal, VeloDesign.Spacing.md)

                    ToggleRow(
                        title: "general.deepFileParsing".localized,
                        subtitle: "general.deepFileParsingDesc".localized,
                        isOn: $isDeepFileParsingEnabled
                    )

                    Divider()
                        .background(ColorTokens.borderSubtle)
                        .padding(.horizontal, VeloDesign.Spacing.md)

                    ToggleRow(
                        title: "general.autoLSafterCD".localized,
                        subtitle: "general.autoLSafterCDDesc".localized,
                        isOn: $autoLSafterCD
                    )
                }
                .padding(VeloDesign.Spacing.md)
                .elevated(.low)
            }

            Spacer()
        }
    }
}

#Preview {
    GeneralTab()
        .frame(width: 600, height: 600)
        .background(ColorTokens.layer0)
}

