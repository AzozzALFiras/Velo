//
//  ToggleRow.swift
//  Velo
//
//  Created by Velo AI
//

import SwiftUI

struct ToggleRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(VeloDesign.Typography.subheadline)
                    .foregroundColor(VeloDesign.Colors.textPrimary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(VeloDesign.Typography.caption)
                        .foregroundColor(VeloDesign.Colors.textMuted)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: ColorTokens.accentPrimary))
        }
        .padding(VeloDesign.Spacing.md)
    }
}
