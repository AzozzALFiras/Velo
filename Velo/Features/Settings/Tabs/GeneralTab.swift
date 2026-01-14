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
    
    // Experimental
    @AppStorage("useDashboardUI") private var useDashboardUI = false

    var body: some View {
        VStack(alignment: .leading, spacing: VeloDesign.Spacing.xl) {
            // Header
            VStack(alignment: .leading, spacing: VeloDesign.Spacing.xs) {
                Text("General")
                    .font(TypographyTokens.displayMd)
                    .foregroundColor(ColorTokens.textPrimary)

                Text("Configure general preferences and behavior")
                    .font(TypographyTokens.bodySm)
                    .foregroundColor(ColorTokens.textSecondary)
            }

            // UI Preferences Section
            VStack(alignment: .leading, spacing: VeloDesign.Spacing.md) {
                SectionHeader(title: "Interface")

                VStack(spacing: 0) {
                    ToggleRow(
                        title: "Auto-Open History Panel",
                        subtitle: "Automatically open the command history sidebar when launching Velo.",
                        isOn: $autoOpenHistory
                    )

                    Divider()
                        .background(ColorTokens.borderSubtle)
                        .padding(.horizontal, VeloDesign.Spacing.md)

                    ToggleRow(
                        title: "Auto-Open AI Panel",
                        subtitle: "Automatically open the AI insights panel when launching Velo.",
                        isOn: $autoOpenAIPanel
                    )
                }
                .padding(VeloDesign.Spacing.md)
                .elevated(.low)
            }

            // Terminal Features Section
            VStack(alignment: .leading, spacing: VeloDesign.Spacing.md) {
                SectionHeader(title: "Terminal Features")

                VStack(spacing: 0) {
                    ToggleRow(
                        title: "Interactive Output",
                        subtitle: "Enable clickable file paths and hover effects in terminal output.",
                        isOn: $isInteractiveOutputEnabled
                    )

                    Divider()
                        .background(ColorTokens.borderSubtle)
                        .padding(.horizontal, VeloDesign.Spacing.md)

                    ToggleRow(
                        title: "Deep File Parsing",
                        subtitle: "Scan output for file paths. Disable for better performance on older Macs.",
                        isOn: $isDeepFileParsingEnabled
                    )

                    Divider()
                        .background(ColorTokens.borderSubtle)
                        .padding(.horizontal, VeloDesign.Spacing.md)

                    ToggleRow(
                        title: "Auto-List After CD",
                        subtitle: "Automatically run 'ls' after navigating with 'cd' to refresh suggestions.",
                        isOn: $autoLSafterCD
                    )
                }
                .padding(VeloDesign.Spacing.md)
                .elevated(.low)
            }
            
            // Experimental Section
            VStack(alignment: .leading, spacing: VeloDesign.Spacing.md) {
                SectionHeader(title: "Experimental")

                VStack(spacing: 0) {
                    ToggleRow(
                        title: "New Dashboard UI",
                        subtitle: "Enable the new 3-panel dashboard layout with command blocks, Git HUD, and integrated AI panel. Requires restart.",
                        isOn: $useDashboardUI
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
