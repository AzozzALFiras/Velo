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
            
            // Command Input Area
            commandInputArea
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
    
    // MARK: - Command Input Area
    
    private var commandInputArea: some View {
        VStack(spacing: 0) {
            Divider()
                .background(ColorTokens.border)
            
            VStack(spacing: 16) {
                // Quick action buttons - centered with fixedSize
                HStack(spacing: 10) {
                    QuickActionButton(icon: "folder", label: "Files", isPrimary: false) {
                        onShowFiles?()
                    }
                    QuickActionButton(icon: "clock.arrow.circlepath", label: "History", isPrimary: false) {
                        onShowHistory?()
                    }
                    QuickActionButton(icon: "bolt.fill", label: "Shortcuts", isPrimary: false) {
                        onShowShortcuts?()
                    }
                    QuickActionButton(icon: "sparkles", label: "Ask AI", isPrimary: true) {
                        onAskAI?("")
                    }
                }
                .fixedSize()
                
                // Input field - full width
                HStack(spacing: 12) {
                    // Directory indicator
                    HStack(spacing: 6) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(ColorTokens.accentPrimary)
                        
                        Text(displayDirectory)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(ColorTokens.textSecondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(ColorTokens.layer2)
                    .clipShape(Capsule())
                    
                    // Prompt
                    Text("❯")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(isExecuting ? ColorTokens.warning : ColorTokens.accentPrimary)
                    
                    // Text field
                    TextField("Enter command...", text: $inputText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(ColorTokens.textPrimary)
                        .focused($isInputFocused)
                        .disabled(isExecuting)
                        .onSubmit {
                            onExecute?()
                        }
                    
                    // Execute/Loading button
                    if isExecuting {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 32, height: 32)
                    } else {
                        Button {
                            onExecute?()
                        } label: {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(inputText.isEmpty ? ColorTokens.textTertiary : ColorTokens.accentPrimary)
                        }
                        .buttonStyle(.plain)
                        .disabled(inputText.isEmpty)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(ColorTokens.layer1)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            isInputFocused ? ColorTokens.accentPrimary.opacity(0.5) : ColorTokens.border,
                            lineWidth: 1
                        )
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(ColorTokens.layer0)
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

// MARK: - Context Badge

/// Small badge showing project context
private struct ContextBadge: View {
    
    let icon: String
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            
            Text(label)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}

// MARK: - Quick Action Button

/// Button for quick actions above input
private struct QuickActionButton: View {
    
    let icon: String
    let label: String
    var isPrimary: Bool = false
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .fixedSize()
            .foregroundStyle(isPrimary ? ColorTokens.accentSecondary : ColorTokens.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isPrimary 
                    ? ColorTokens.accentSecondary.opacity(isHovered ? 0.2 : 0.12)
                    : (isHovered ? ColorTokens.layer2 : ColorTokens.layer1)
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        isPrimary ? ColorTokens.accentSecondary.opacity(0.3) : ColorTokens.border,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
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
