//
//  HistoryHeader.swift
//  Velo
//
//  Created by Velo AI
//

import SwiftUI

// MARK: - Wall Header
struct WallHeader: View {
    @ObservedObject var viewModel: HistoryViewModel
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Command Wall")
                    .font(VeloDesign.Typography.headline)
                    .foregroundColor(VeloDesign.Colors.textPrimary)
                
                Text("Your command history")
                    .font(VeloDesign.Typography.caption)
                    .foregroundColor(VeloDesign.Colors.textMuted)
            }
            
            Spacer()
            
            // AI suggestions indicator
            PillTag(text: "AI", color: VeloDesign.Colors.neonPurple)
        }
        .padding(VeloDesign.Spacing.md)
    }
}

// MARK: - Stats Footer
struct StatsFooter: View {
    let todayCount: Int
    let totalCount: Int
    
    var body: some View {
        HStack {
            StatBadge(icon: "calendar", value: "\(todayCount)", label: "today")
            Spacer()
            StatBadge(icon: "terminal", value: "\(totalCount)", label: "total")
        }
        .padding(VeloDesign.Spacing.md)
        .background(VeloDesign.Colors.cardBackground.opacity(0.5))
        .overlay(
            Rectangle()
                .fill(VeloDesign.Colors.glassBorder)
                .frame(height: 1),
            alignment: .top
        )
    }
}

// MARK: - Stat Badge
struct StatBadge: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        HStack(spacing: VeloDesign.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(VeloDesign.Colors.textMuted)
            
            Text(value)
                .font(VeloDesign.Typography.monoSmall)
                .foregroundColor(VeloDesign.Colors.textPrimary)
            
            Text(label)
                .font(VeloDesign.Typography.caption)
                .foregroundColor(VeloDesign.Colors.textMuted)
        }
    }
}
