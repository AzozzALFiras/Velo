//
//  InsightCards.swift
//  Velo
//
//  Created by Velo AI
//

import SwiftUI

struct QuickActionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: VeloDesign.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(color)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(VeloDesign.Typography.caption)
                        .foregroundColor(VeloDesign.Colors.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 9))
                        .foregroundColor(VeloDesign.Colors.textMuted)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(VeloDesign.Colors.textMuted)
            }
            .padding(VeloDesign.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: VeloDesign.Radius.small)
                    .fill(isHovered ? VeloDesign.Colors.elevatedSurface : VeloDesign.Colors.cardBackground)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct RecommendationRow: View {
    let suggestion: CommandSuggestion
    let onSelect: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: VeloDesign.Spacing.sm) {
                Image(systemName: suggestion.source.icon)
                    .font(.system(size: 10))
                    .foregroundColor(VeloDesign.Colors.neonPurple)
                
                Text(suggestion.command)
                    .font(VeloDesign.Typography.monoSmall)
                    .foregroundColor(VeloDesign.Colors.textPrimary)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding(.horizontal, VeloDesign.Spacing.sm)
            .padding(.vertical, VeloDesign.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: VeloDesign.Radius.small)
                    .fill(isHovered ? VeloDesign.Colors.elevatedSurface : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct ContextRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(VeloDesign.Colors.textMuted)
                .frame(width: 16)
            
            Text(label)
                .font(VeloDesign.Typography.caption)
                .foregroundColor(VeloDesign.Colors.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(VeloDesign.Typography.monoSmall)
                .foregroundColor(VeloDesign.Colors.textPrimary)
        }
    }
}

struct PatternRow: View {
    let pattern: String
    let frequency: Int
    
    var body: some View {
        HStack {
            Text(pattern)
                .font(VeloDesign.Typography.caption)
                .foregroundColor(VeloDesign.Colors.textPrimary)
            
            Spacer()
            
            Text("\(frequency)×")
                .font(VeloDesign.Typography.monoSmall)
                .foregroundColor(VeloDesign.Colors.neonPurple)
        }
        .padding(.vertical, 2)
    }
}

struct TipCard: View {
    let emoji: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: VeloDesign.Spacing.sm) {
            Text(emoji)
                .font(.system(size: 16))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(VeloDesign.Typography.caption)
                    .foregroundColor(VeloDesign.Colors.textPrimary)
                Text(description)
                    .font(.system(size: 10))
                    .foregroundColor(VeloDesign.Colors.textMuted)
            }
        }
        .padding(VeloDesign.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: VeloDesign.Radius.small)
                .fill(VeloDesign.Colors.cardBackground)
        )
    }
}
