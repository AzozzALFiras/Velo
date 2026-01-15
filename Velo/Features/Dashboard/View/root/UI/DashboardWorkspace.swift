//
//  DashboardWorkspace.swift
//  Velo
//
//  Dashboard Redesign - Main Workspace Area
//  Contains Git HUD, Tab Bar, Command Blocks, and Input
//

import SwiftUI

// MARK: - Dashboard Workspace

/// Main workspace containing terminal content with Git HUD and command blocks
struct DashboardWorkspace: View {
    
    // Observed state
    let contextManager: ContextManager
    let blocks: [CommandBlock]
    
    // Bindings
    @Binding var inputText: String
    @Binding var isExecuting: Bool
    
    // Current state
    var currentDirectory: String
    
    // Actions
    var onExecute: (() -> Void)?
    var onBlockAction: ((CommandBlock, BlockAction) -> Void)?
    var onRetryBlock: ((CommandBlock) -> Void)?
    var onAskAI: ((String) -> Void)?
    var onOpenPath: ((String) -> Void)?
    var onSync: (() -> Void)?
    var onBranchSwitch: (() -> Void)?
    var onShowShortcuts: (() -> Void)?
    var onShowFiles: (() -> Void)?
    var onShowHistory: (() -> Void)?
    
    // Internal state
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Git HUD (if in Git repo)
            if contextManager.isGitRepository {
                GitHUD(
                    contextManager: contextManager,
                    onSync: onSync,
                    onBranchTap: onBranchSwitch
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }
            
            // Context badges (Docker, npm, etc.)
            if hasProjectContext {
                contextBadges
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
            
            // Command Blocks
            ZStack {
                if blocks.isEmpty {
                    BlocksEmptyState()
                } else {
                    BlockListView(
                        blocks: blocks,
                        onAction: onBlockAction,
                        onAskAI: onAskAI,
                        onOpenPath: onOpenPath,
                        onRetry: onRetryBlock
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(ColorTokens.layer0)
        .onChange(of: currentDirectory) { _, newDir in
            Task {
                await contextManager.updateContext(for: newDir)
            }
        }
        .onAppear {
            Task {
                await contextManager.updateContext(for: currentDirectory)
            }
        }
    }
    
    // MARK: - Context Badges
    
    private var hasProjectContext: Bool {
        contextManager.isDockerProject || 
        contextManager.hasPackageJson || 
        contextManager.hasCargoToml
    }
    
    @ViewBuilder
    private var contextBadges: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if contextManager.isDockerProject {
                    ContextBadge(icon: "shippingbox", label: "Docker", color: ColorTokens.info)
                }
                
                if contextManager.hasPackageJson {
                    ContextBadge(icon: "shippingbox.fill", label: "npm", color: ColorTokens.error)
                }
                
                if contextManager.hasCargoToml {
                    ContextBadge(icon: "gear", label: "Cargo", color: ColorTokens.warning)
                }
                
                if contextManager.hasPodfile {
                    ContextBadge(icon: "cube", label: "CocoaPods", color: ColorTokens.accentSecondary)
                }
            }
        }
    }
    
    // Computed display directory
    private var displayDirectory: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var display = currentDirectory.replacingOccurrences(of: home, with: "~")
        
        // Show last 2 components if too long
        let components = display.components(separatedBy: "/")
        if components.count > 3 {
            display = "~/.../\(components.suffix(2).joined(separator: "/"))"
        }
        
        return display
    }
}

// MARK: - Preview

#Preview {
    let contextManager = ContextManager()
    
    return DashboardWorkspace(
        contextManager: contextManager,
        blocks: [
            CommandBlock(
                command: "git status",
                output: [
                    OutputLine(text: "On branch main"),
                    OutputLine(text: "nothing to commit, working tree clean"),
                ],
                status: .success,
                startTime: Date().addingTimeInterval(-2),
                endTime: Date()
            ),
            CommandBlock(
                command: "npm install",
                output: [
                    OutputLine(text: "added 150 packages in 3.2s"),
                ],
                status: .success,
                startTime: Date().addingTimeInterval(-5),
                endTime: Date().addingTimeInterval(-2)
            )
        ],
        inputText: .constant(""),
        isExecuting: .constant(false),
        currentDirectory: "/Users/developer/projects/velo"
    )
    .frame(width: 800, height: 600)
}
