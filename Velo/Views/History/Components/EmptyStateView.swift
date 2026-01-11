//
//  EmptyStateView.swift
//  Velo
//
//  Created by Velo AI
//

import SwiftUI

// MARK: - Empty State
struct EmptyStateView: View {
    let section: HistorySection
    
    var body: some View {
        VStack(spacing: VeloDesign.Spacing.md) {
            Image(systemName: section.icon)
                .font(.system(size: 32))
                .foregroundColor(VeloDesign.Colors.textMuted)
            
            Text("No commands yet")
                .font(VeloDesign.Typography.subheadline)
                .foregroundColor(VeloDesign.Colors.textSecondary)
            
            Text("Start typing to build your command wall")
                .font(VeloDesign.Typography.caption)
                .foregroundColor(VeloDesign.Colors.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, VeloDesign.Spacing.xxl)
    }
}
