//
//  TerminalToolbar.swift
//  Velo
//
//  Created by Velo AI
//

import SwiftUI

struct TerminalToolbar: View {
    let isExecuting: Bool
    let currentDirectory: String
    @Binding var showHistorySidebar: Bool
    @Binding var showInsightPanel: Bool
    let onInterrupt: () -> Void
    let onClear: () -> Void
    
    var body: some View {
        HStack(spacing: VeloDesign.Spacing.md) {
            // Sidebar toggles
            ToolbarButton(
                icon: "sidebar.left",
                isActive: showHistorySidebar,
                color: VeloDesign.Colors.neonCyan
            ) {
                showHistorySidebar.toggle()
            }
            
            Divider()
                .frame(height: 16)
            
            // App title
            HStack(spacing: VeloDesign.Spacing.sm) {
                Image(systemName: "terminal.fill")
                .font(.system(size: 14))
                .foregroundColor(VeloDesign.Colors.neonCyan)
                
                Text("Velo")
                    .font(VeloDesign.Typography.headline)
                    .foregroundColor(VeloDesign.Colors.textPrimary)
                    .fixedSize()
            }
            
            Spacer()
            
            // Current path
            Text(displayPath)
                .font(VeloDesign.Typography.monoSmall)
                .foregroundColor(VeloDesign.Colors.textMuted)
                .lineLimit(1)
            
            Spacer()
            
            // Actions
            if isExecuting {
                ToolbarButton(
                    icon: "stop.fill",
                    isActive: true,
                    color: VeloDesign.Colors.error
                ) {
                    onInterrupt()
                }
            }
            
            ToolbarButton(
                icon: "trash",
                isActive: false,
                color: VeloDesign.Colors.textSecondary
            ) {
                onClear()
            }
            
            Divider()
                .frame(height: 16)
            
            ToolbarButton(
                icon: "sidebar.right",
                isActive: showInsightPanel,
                color: VeloDesign.Colors.neonPurple
            ) {
                showInsightPanel.toggle()
            }
        }
        .padding(.horizontal, VeloDesign.Spacing.lg)
        .padding(.vertical, VeloDesign.Spacing.sm)
        .background(VeloDesign.Colors.cardBackground)
        .overlay(
            Rectangle()
                .fill(VeloDesign.Colors.glassBorder)
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    var displayPath: String {
        let home = NSHomeDirectory()
        if currentDirectory.hasPrefix(home) {
            return "~" + currentDirectory.dropFirst(home.count)
        }
        return currentDirectory
    }
}

// MARK: - Toolbar Button
struct ToolbarButton: View {
    let icon: String
    let isActive: Bool
    let color: Color
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(isActive ? color : VeloDesign.Colors.textSecondary)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill((isActive || isHovered) ? color.opacity(0.15) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
