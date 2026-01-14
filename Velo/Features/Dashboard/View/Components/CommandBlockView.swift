//
//  CommandBlockView.swift
//  Velo
//
//  Dashboard Redesign - Complete Command Block View
//  Combines header and output into a cohesive block
//

import SwiftUI

// MARK: - Command Block View

/// Complete view for a command block with header and output
struct CommandBlockView: View {
    
    let block: CommandBlock
    var onAction: ((BlockAction) -> Void)?
    var onAskAI: ((String) -> Void)?
    var onRetry: (() -> Void)?
    
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Block Header
            BlockHeader(block: block) { action in
                handleAction(action)
            }
            
            // Block Output (if any)
            if !block.output.isEmpty {
                Divider()
                    .background(ColorTokens.borderSubtle)
                
                BlockOutput(
                    block: block,
                    onAskAI: onAskAI
                )
            }
        }
        .background(blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
        )
        .shadow(color: shadowColor, radius: isHovered ? 8 : 4, y: 2)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    // MARK: - Styling
    
    private var blockBackground: some View {
        ColorTokens.layer1
    }
    
    private var borderColor: Color {
        if block.isError {
            return ColorTokens.error.opacity(0.3)
        } else if block.isRunning {
            return ColorTokens.warning.opacity(0.3)
        } else if isHovered {
            return ColorTokens.borderHover
        } else {
            return ColorTokens.border
        }
    }
    
    private var shadowColor: Color {
        if block.isError {
            return ColorTokens.error.opacity(0.1)
        } else {
            return Color.black.opacity(0.15)
        }
    }
    
    // MARK: - Actions
    
    private func handleAction(_ action: BlockAction) {
        switch action {
        case .retry:
            onRetry?()
        case .copy:
            copyCommand()
        case .copyOutput:
            copyOutput()
        case .explain:
            onAskAI?("Explain this command and its output: \(block.command)")
        case .fix:
            let errorLines = block.output.filter { $0.isError }.map { $0.text }.joined(separator: "\n")
            onAskAI?("How do I fix this error?\n\nCommand: \(block.command)\n\nError:\n\(errorLines)")
        case .delete, .pin:
            onAction?(action)
        }
    }
    
    private func copyCommand() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(block.command, forType: .string)
    }
    
    private func copyOutput() {
        let output = block.output.map { $0.text }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(output, forType: .string)
    }
}

// MARK: - Block List View

/// A list of command blocks with proper spacing
struct BlockListView: View {
    
    let blocks: [CommandBlock]
    var onAction: ((CommandBlock, BlockAction) -> Void)?
    var onAskAI: ((String) -> Void)?
    var onRetry: ((CommandBlock) -> Void)?
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(blocks) { block in
                        CommandBlockView(
                            block: block,
                            onAction: { action in
                                onAction?(block, action)
                            },
                            onAskAI: onAskAI,
                            onRetry: {
                                onRetry?(block)
                            }
                        )
                        .frame(minWidth: 400)
                        .id(block.id)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .onChange(of: blocks.count) { _, _ in
                // Scroll to latest block
                if let lastBlock = blocks.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastBlock.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

// MARK: - Empty State

/// Empty state when no blocks exist
struct BlocksEmptyState: View {
    
    var body: some View {
        VStack(spacing: 24) {
            // Terminal icon with glow effect
            ZStack {
                // Glow
                Circle()
                    .fill(ColorTokens.accentPrimary.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .blur(radius: 20)
                
                // Icon container
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(ColorTokens.layer2)
                    .frame(width: 80, height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(ColorTokens.border, lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: "terminal")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [ColorTokens.accentPrimary, ColorTokens.accentSecondary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
            }
            
            VStack(spacing: 8) {
                Text("Ready to Run Commands")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(ColorTokens.textPrimary)
                    .fixedSize(horizontal: true, vertical: false)
                
                Text("Type a command below or use keyboard shortcuts")
                    .font(.system(size: 13))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .fixedSize(horizontal: true, vertical: false)
            }
            
            // Keyboard hints - fixed layout
            HStack(spacing: 20) {
                keyboardHint(key: "⌘N", label: "New Tab")
                keyboardHint(key: "⌘K", label: "Clear")
                keyboardHint(key: "↑", label: "History")
            }
            .fixedSize()
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func keyboardHint(key: String, label: String) -> some View {
        HStack(spacing: 6) {
            Text(key)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(ColorTokens.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(ColorTokens.layer2)
                .clipShape(RoundedRectangle(cornerRadius: 5))
            
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .fixedSize()
    }
}

// MARK: - Preview

#Preview("Command Block - Success") {
    let block = CommandBlock(
        command: "git status",
        output: [
            OutputLine(text: "On branch main"),
            OutputLine(text: "Your branch is up to date with 'origin/main'."),
            OutputLine(text: ""),
            OutputLine(text: "nothing to commit, working tree clean"),
        ],
        status: .success,
        exitCode: 0,
        startTime: Date().addingTimeInterval(-2.3),
        endTime: Date()
    )
    
    return CommandBlockView(block: block) { action in
        print("Action: \(action)")
    } onAskAI: { query in
        print("Ask AI: \(query)")
    }
    .padding()
    .background(ColorTokens.layer0)
}

#Preview("Command Block - Error") {
    let block = CommandBlock(
        command: "npm install nonexistent-package",
        output: [
            OutputLine(text: "npm ERR! code E404", isError: true),
            OutputLine(text: "npm ERR! 404 Not Found - GET https://registry.npmjs.org/nonexistent-package", isError: true),
            OutputLine(text: "npm ERR! 404 'nonexistent-package@latest' is not in this registry.", isError: true),
            OutputLine(text: "npm ERR! A complete log of this run can be found in:"),
            OutputLine(text: "npm ERR!     /Users/foo/.npm/_logs/2024-01-15_debug.log"),
        ],
        status: .error,
        exitCode: 1,
        startTime: Date().addingTimeInterval(-1.2),
        endTime: Date()
    )
    
    return CommandBlockView(block: block) { action in
        print("Action: \(action)")
    } onAskAI: { query in
        print("Ask AI: \(query)")
    }
    .padding()
    .background(ColorTokens.layer0)
}

#Preview("Command Block - Running") {
    let block = CommandBlock(
        command: "npm install",
        output: [
            OutputLine(text: "⠋ Resolving dependencies..."),
        ],
        status: .running,
        startTime: Date().addingTimeInterval(-3.0)
    )
    
    return CommandBlockView(block: block)
        .padding()
        .background(ColorTokens.layer0)
}

#Preview("Block List") {
    let blocks = [
        CommandBlock(
            command: "cd ~/projects/velo",
            status: .success,
            startTime: Date().addingTimeInterval(-10),
            endTime: Date().addingTimeInterval(-9.8)
        ),
        CommandBlock(
            command: "git status",
            output: [
                OutputLine(text: "On branch main"),
                OutputLine(text: "nothing to commit, working tree clean"),
            ],
            status: .success,
            startTime: Date().addingTimeInterval(-8),
            endTime: Date().addingTimeInterval(-7.5)
        ),
        CommandBlock(
            command: "npm run build",
            output: [
                OutputLine(text: "Building..."),
                OutputLine(text: "✓ Compiled successfully"),
            ],
            status: .success,
            startTime: Date().addingTimeInterval(-5),
            endTime: Date().addingTimeInterval(-2)
        ),
    ]
    
    return BlockListView(blocks: blocks)
        .frame(width: 700, height: 500)
        .background(ColorTokens.layer0)
}
