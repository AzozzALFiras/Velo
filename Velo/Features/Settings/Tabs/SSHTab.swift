//
//  SSHTab.swift
//  Velo
//
//  SSH connection management
//

import SwiftUI

struct SSHTab: View {
    var body: some View {
        VStack(alignment: .leading, spacing: VeloDesign.Spacing.xl) {
            // Header
            VStack(alignment: .leading, spacing: VeloDesign.Spacing.xs) {
                Text("SSH Connections")
                    .font(TypographyTokens.displayMd)
                    .foregroundColor(ColorTokens.textPrimary)

                Text("Manage remote server connections and credentials")
                    .font(TypographyTokens.bodySm)
                    .foregroundColor(ColorTokens.textSecondary)
            }

            // Existing SSH settings view
            SSHSettingsView()
        }
    }
}

#Preview {
    SSHTab()
        .frame(width: 600, height: 600)
        .background(ColorTokens.layer0)
}
