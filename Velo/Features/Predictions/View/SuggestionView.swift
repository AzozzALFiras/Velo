//
//  SuggestionView.swift
//  Velo
//
//  Created by Velo AI
//

import SwiftUI

// MARK: - Suggestions Dropdown
struct SuggestionsDropdown: View {
    @ObservedObject var viewModel: PredictionViewModel
    let onSelect: (CommandSuggestion) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewModel.suggestions.enumerated()), id: \.element.id) { index, suggestion in
                SuggestionRow(
                    suggestion: suggestion,
                    isSelected: index == viewModel.selectedSuggestionIndex,
                    onSelect: { onSelect(suggestion) }
                )
            }
        }
        .padding(VeloDesign.Spacing.xs)
        .glassCard(cornerRadius: VeloDesign.Radius.medium)
        .padding(.horizontal, VeloDesign.Spacing.lg)
        .padding(.bottom, VeloDesign.Spacing.sm)
    }
}

// MARK: - Suggestion Row
struct SuggestionRow: View {
    let suggestion: CommandSuggestion
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: VeloDesign.Spacing.sm) {
            // Source icon
            Image(systemName: suggestion.source.icon)
                .font(.system(size: 10))
                .foregroundColor(sourceColor)
                .frame(width: 16)
            
            // Command
            Text(suggestion.command)
                .font(VeloDesign.Typography.monoSmall)
                .foregroundColor(VeloDesign.Colors.textPrimary)
                .lineLimit(1)
            
            Spacer()
            
            // Description
            if !suggestion.description.isEmpty {
                Text(suggestion.description)
                    .font(VeloDesign.Typography.caption)
                    .foregroundColor(VeloDesign.Colors.textMuted)
                    .lineLimit(1)
            }
            
            // Tab hint for selected
            if isSelected {
                Text("⇥")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(VeloDesign.Colors.neonCyan)
            }
        }
        .padding(.horizontal, VeloDesign.Spacing.sm)
        .padding(.vertical, VeloDesign.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: VeloDesign.Radius.small, style: .continuous)
                .fill((isSelected || isHovered) ? VeloDesign.Colors.elevatedSurface : Color.clear)
        )
        .neonBorder(VeloDesign.Colors.neonCyan, cornerRadius: VeloDesign.Radius.small, isActive: isSelected)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onSelect()
        }
    }
    
    var sourceColor: Color {
        switch suggestion.source {
        case .recent: return VeloDesign.Colors.info
        case .frequent: return VeloDesign.Colors.warning
        case .sequential: return VeloDesign.Colors.neonPurple
        case .contextual: return VeloDesign.Colors.neonGreen
        case .ai: return VeloDesign.Colors.neonCyan
        }
    }
}
