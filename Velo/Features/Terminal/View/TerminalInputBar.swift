//
//  TerminalInputBar.swift
//  Velo
//
//  Workspace Redesign - Simplified Terminal Input Bar
//  Clean, fast command input experience
//

import SwiftUI

// MARK: - Terminal Input Bar

struct TerminalInputBar: View {
    
    // Bindings
    @Binding var inputText: String
    @Binding var isExecuting: Bool
    
    // Context information
    let currentDirectory: String
    let isGitRepository: Bool
    let hasDocker: Bool
    
    // Actions
    var onExecute: () -> Void
    var onShowFiles: () -> Void
    var onShowHistory: () -> Void
    var onShowShortcuts: () -> Void
    var onAskAI: (String) -> Void
    
    // Internal state
    @FocusState private var isInputFocused: Bool
    @State private var showToolbar = false
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(ColorTokens.border)
            
            HStack(spacing: 12) {
                // Directory Badge - tap to show files
                Button(action: onShowFiles) {
                    HStack(spacing: 5) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 9))
                        Text(displayDirectory)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                    }
                    .foregroundStyle(ColorTokens.accentPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(ColorTokens.accentPrimary.opacity(0.1))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                
                // Prompt indicator
                Text("❯")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(isExecuting ? ColorTokens.warning : ColorTokens.accentPrimary)
                
                // Input field - large and prominent
                TextField("commandBar.placeholder".localized, text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundStyle(ColorTokens.textPrimary)
                    .focused($isInputFocused)
                    .onSubmit { onExecute() }
                
                // Quick actions (compact)
                HStack(spacing: 6) {
                    MiniActionButton(icon: "clock.arrow.circlepath", action: onShowHistory)
                    MiniActionButton(icon: "bolt.fill", action: onShowShortcuts)
                    MiniActionButton(icon: "sparkles", isPrimary: true) { onAskAI("") }
                }
                
                // Execute button
                if isExecuting {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 28, height: 28)
                } else {
                    Button(action: onExecute) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(inputText.isEmpty ? ColorTokens.textTertiary : ColorTokens.accentPrimary)
                    }
                    .buttonStyle(.plain)
                    .disabled(inputText.isEmpty)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(ColorTokens.layer0)
        }
    }
    
    // Compact directory display
    private var displayDirectory: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var display = currentDirectory.replacingOccurrences(of: home, with: "~")
        
        // Show only last folder name for brevity
        if let lastComponent = display.components(separatedBy: "/").last, !lastComponent.isEmpty {
            return lastComponent
        }
        return display
    }
}

// MARK: - Mini Action Button

private struct MiniActionButton: View {
    let icon: String
    var isPrimary: Bool = false
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isPrimary ? ColorTokens.accentSecondary : ColorTokens.textSecondary)
                .frame(width: 26, height: 26)
                .background(isHovered ? ColorTokens.layer2 : Color.clear)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
