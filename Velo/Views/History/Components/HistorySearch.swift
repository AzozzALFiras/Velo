//
//  HistorySearch.swift
//  Velo
//
//  Created by Velo AI
//

import SwiftUI

// MARK: - Section Tabs
struct SectionTabs: View {
    @Binding var selectedSection: HistorySection
    
    var body: some View {
        HStack(spacing: VeloDesign.Spacing.xs) {
            ForEach(HistorySection.allCases) { section in
                SectionTab(
                    section: section,
                    isSelected: selectedSection == section
                ) {
                    withAnimation(VeloDesign.Animation.quick) {
                        selectedSection = section
                    }
                }
            }
        }
        .padding(.horizontal, VeloDesign.Spacing.md)
        .padding(.bottom, VeloDesign.Spacing.sm)
    }
}

// MARK: - Section Tab
struct SectionTab: View {
    let section: HistorySection
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: VeloDesign.Spacing.xs) {
                Image(systemName: section.icon)
                    .font(.system(size: 10))
                Text(section.rawValue)
                    .font(VeloDesign.Typography.caption)
            }
            .foregroundColor(isSelected ? VeloDesign.Colors.neonCyan : VeloDesign.Colors.textSecondary)
            .padding(.horizontal, VeloDesign.Spacing.sm)
            .padding(.vertical, VeloDesign.Spacing.xs)
            .background(
                Capsule()
                    .fill(isSelected ? VeloDesign.Colors.neonCyan.opacity(0.15) : Color.clear)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? VeloDesign.Colors.neonCyan.opacity(0.3) : Color.clear, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Search Bar
struct SearchBar: View {
    @Binding var query: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: VeloDesign.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundColor(VeloDesign.Colors.textMuted)
            
            TextField("Search commands...", text: $query)
                .font(VeloDesign.Typography.monoSmall)
                .textFieldStyle(.plain)
                .focused($isFocused)
            
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundColor(VeloDesign.Colors.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(VeloDesign.Spacing.sm)
        .background(VeloDesign.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: VeloDesign.Radius.small, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: VeloDesign.Radius.small, style: .continuous)
                .stroke(isFocused ? VeloDesign.Colors.neonCyan.opacity(0.5) : VeloDesign.Colors.glassBorder, lineWidth: 1)
        )
        .padding(.horizontal, VeloDesign.Spacing.md)
        .padding(.bottom, VeloDesign.Spacing.sm)
    }
}
