//
//  GitHUD.swift
//  Velo
//
//  Dashboard Redesign - Git Status HUD
//  Displays current branch, sync status, and quick actions
//

import SwiftUI

// MARK: - Git HUD

/// Displays Git repository status as a compact HUD at top of workspace
struct GitHUD: View {
    
    let contextManager: ContextManager
    var onSync: (() -> Void)?
    var onBranchTap: (() -> Void)?
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Git icon
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ColorTokens.accentSecondary)
            
            // Branch name
            Button {
                onBranchTap?()
            } label: {
                HStack(spacing: 6) {
                    Text(contextManager.gitBranch)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(ColorTokens.textPrimary)
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
            .buttonStyle(.plain)
            
            Divider()
                .frame(height: 16)
                .background(ColorTokens.border)
            
            // Status indicators
            HStack(spacing: 8) {
                // Behind count
                if contextManager.behindCount > 0 {
                    StatusBadge(
                        icon: "arrow.down",
                        count: contextManager.behindCount,
                        color: ColorTokens.info
                    )
                }
                
                // Ahead count
                if contextManager.aheadCount > 0 {
                    StatusBadge(
                        icon: "arrow.up",
                        count: contextManager.aheadCount,
                        color: ColorTokens.success
                    )
                }
                
                // Modified count
                if contextManager.modifiedCount > 0 {
                    StatusBadge(
                        icon: "pencil",
                        count: contextManager.modifiedCount,
                        color: ColorTokens.warning
                    )
                }
                
                // Staged count
                if contextManager.stagedCount > 0 {
                    StatusBadge(
                        icon: "checkmark",
                        count: contextManager.stagedCount,
                        color: ColorTokens.success
                    )
                }
                
                // Clean status
                if !contextManager.hasGitChanges && !contextManager.needsSync {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(ColorTokens.success)
                        
                        Text("Clean")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                }
            }
            
            Spacer()
            
            // Sync button (if needed)
            if contextManager.needsSync {
                Button {
                    onSync?()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 11, weight: .semibold))
                        
                        Text("Sync")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundStyle(ColorTokens.accentPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(ColorTokens.accentPrimary.opacity(0.15))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            
            // Refresh button
            Button {
                Task {
                    await contextManager.refreshGitStatus()
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .buttonStyle(.plain)
            .help("Refresh Git status")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(ColorTokens.layer1)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(ColorTokens.border, lineWidth: 1)
        )
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Status Badge

/// Small badge showing an icon and count
private struct StatusBadge: View {
    let icon: String
    let count: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            
            Text("\(count)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
        }
        .foregroundStyle(color)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Preview with context manager
        GitHUD(
            contextManager: {
                let manager = ContextManager()
                // Note: Preview state would be set here in real usage
                return manager
            }()
        )
        .padding()
    }
    .frame(width: 500)
    .background(ColorTokens.layer0)
}
