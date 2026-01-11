//
//  InsightHeader.swift
//  Velo
//
//  Created by Velo AI
//

import SwiftUI

// MARK: - Insight Header
struct InsightHeader: View {
    var body: some View {
        HStack {
            HStack(spacing: VeloDesign.Spacing.sm) {
                Image(systemName: "brain")
                    .font(.system(size: 14))
                    .foregroundColor(VeloDesign.Colors.neonPurple)
                    .glow(VeloDesign.Colors.neonPurple, radius: 8)
                
                Text("AI Insights")
                    .font(VeloDesign.Typography.headline)
                    .foregroundColor(VeloDesign.Colors.textPrimary)
            }
            
            Spacer()
            
            // Status indicator
            CapabilityBadge()
        }
        .padding(VeloDesign.Spacing.md)
    }
}

// MARK: - Capability Badge
struct CapabilityBadge: View {
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(VeloDesign.Colors.neonGreen)
                .frame(width: 6, height: 6)
            Text("Active")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(VeloDesign.Colors.neonGreen)
        }
        .padding(.horizontal, VeloDesign.Spacing.sm)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(VeloDesign.Colors.neonGreen.opacity(0.1))
        )
    }
}

// MARK: - Insight Tab Selector
struct InsightTabSelector: View {
    @Binding var selectedTab: InsightTab
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(InsightTab.allCases) { tab in
                InsightTabButton(
                    tab: tab,
                    isSelected: selectedTab == tab
                ) {
                    withAnimation(VeloDesign.Animation.quick) {
                        selectedTab = tab
                    }
                }
            }
        }
        .padding(.horizontal, VeloDesign.Spacing.md)
        .padding(.bottom, VeloDesign.Spacing.sm)
    }
}

// MARK: - Insight Tab Button
struct InsightTabButton: View {
    let tab: InsightTab
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 12))
                Text(tab.rawValue)
                    .font(.system(size: 10))
            }
            .foregroundColor(isSelected ? VeloDesign.Colors.neonPurple : VeloDesign.Colors.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, VeloDesign.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: VeloDesign.Radius.small)
                    .fill(isSelected ? VeloDesign.Colors.neonPurple.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Insight Tab
enum InsightTab: String, CaseIterable, Identifiable {
    case suggestions = "Suggest"
    case context = "Context"
    case learn = "Learn"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .suggestions: return "lightbulb"
        case .context: return "scope"
        case .learn: return "book"
        }
    }
}
