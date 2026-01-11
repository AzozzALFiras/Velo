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
    @Binding var showSettings: Bool
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
                
                Text("VELO")
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(VeloDesign.Gradients.cyanPurple)
                    .fixedSize()
            }
            .padding(.trailing, 10)
            
            Spacer()
            
            // Current path
            HStack {
                Text(displayPath)
                    .font(VeloDesign.Typography.monoSmall)
                    .foregroundColor(VeloDesign.Colors.textMuted)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(4)
            }
            
            Spacer()
            
            // Actions Cluster
            HStack(spacing: 8) {
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
                
                // Settings Bar Button
                Button(action: { showSettings.toggle() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 11))
                        Text("Settings")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(showSettings ? VeloDesign.Colors.neonCyan : VeloDesign.Colors.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(showSettings ? VeloDesign.Colors.neonCyan.opacity(0.15) : Color.white.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(showSettings ? VeloDesign.Colors.neonCyan.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(4)
            .background(Color.black.opacity(0.2))
            .cornerRadius(8)
            
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
