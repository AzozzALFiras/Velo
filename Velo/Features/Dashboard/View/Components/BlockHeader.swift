//
//  BlockHeader.swift
//  Velo
//
//  Dashboard Redesign - Command Block Header
//  Shows command, status, duration, and action buttons
//

import SwiftUI

// MARK: - Block Header

/// Header component for command blocks showing command, status, and actions
struct BlockHeader: View {
    
    let block: CommandBlock
    var onAction: ((BlockAction) -> Void)?
    
    @State private var isHovered = false
    @State private var showAllActions = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            statusIcon
            
            // Command text
            Text(block.command)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(ColorTokens.textPrimary)
                .lineLimit(1)
            
            Spacer()
            
            // Duration / Timer
            durationView
            
            // Action buttons (visible on hover or always for errors)
            if isHovered || block.isError {
                actionButtons
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
            
            // More menu
            moreMenu
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(headerBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
    
    // MARK: - Status Icon
    
    @ViewBuilder
    private var statusIcon: some View {
        Group {
            if block.isRunning {
                // Animated running indicator
                RunningIndicator()
            } else {
                Image(systemName: block.status.icon)
            }
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(block.status.color)
    }
    
    // MARK: - Duration View
    
    @ViewBuilder
    private var durationView: some View {
        if block.isRunning {
            // Live timer
            TimelineView(.animation(minimumInterval: 0.1)) { timeline in
                Text(formatDuration(Date().timeIntervalSince(block.startTime)))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(ColorTokens.warning)
            }
        } else if block.status != .idle {
            Text(block.formattedDuration)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(ColorTokens.textTertiary)
        }
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 6) {
            // Primary actions based on status
            ForEach(primaryActions, id: \.self) { action in
                BlockActionButton(action: action, onTap: {
                    onAction?(action)
                })
            }
        }
    }
    
    private var primaryActions: [BlockAction] {
        switch block.status {
        case .error:
            return [.fix, .explain, .retry]
        case .success:
            return [.retry, .copy]
        case .running:
            return []
        case .idle:
            return []
        }
    }
    
    // MARK: - More Menu
    
    private var moreMenu: some View {
        Menu {
            ForEach(BlockAction.actions(for: block.status), id: \.self) { action in
                Button {
                    onAction?(action)
                } label: {
                    Label(action.rawValue, systemImage: action.icon)
                }
            }
            
            Divider()
            
            Button(role: .destructive) {
                onAction?(.delete)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ColorTokens.textTertiary)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(isHovered ? ColorTokens.layer2 : .clear)
                )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }
    
    // MARK: - Background
    
    private var headerBackground: some View {
        Group {
            if block.isError {
                ColorTokens.error.opacity(0.08)
            } else if isHovered {
                ColorTokens.layer2
            } else {
                ColorTokens.layer1
            }
        }
    }
    
    // MARK: - Helpers
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        if duration < 1 {
            return String(format: "%.0fms", duration * 1000)
        } else if duration < 60 {
            return String(format: "%.1fs", duration)
        } else {
            let minutes = Int(duration / 60)
            let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(seconds)s"
        }
    }
}

// MARK: - Running Indicator

/// Animated running indicator with rotation
private struct RunningIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        Image(systemName: "circle.dotted")
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .animation(
                .linear(duration: 1.5)
                .repeatForever(autoreverses: false),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Block Action Button

/// Small action button for block header
private struct BlockActionButton: View {
    
    let action: BlockAction
    let onTap: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: action.icon)
                    .font(.system(size: 10, weight: .semibold))
                
                Text(action.rawValue)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(buttonColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(buttonBackground)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
    
    private var buttonColor: Color {
        switch action {
        case .fix:
            return ColorTokens.accentPrimary
        case .explain:
            return ColorTokens.accentSecondary
        case .retry:
            return ColorTokens.success
        default:
            return ColorTokens.textSecondary
        }
    }
    
    private var buttonBackground: Color {
        isHovered ? buttonColor.opacity(0.15) : buttonColor.opacity(0.08)
    }
}

// MARK: - Preview

#Preview("Success Block") {
    let block = CommandBlock(
        command: "git status",
        status: .success,
        exitCode: 0,
        startTime: Date().addingTimeInterval(-2.3),
        endTime: Date()
    )
    
    return BlockHeader(block: block) { action in
        print("Action: \(action)")
    }
    .padding()
    .background(ColorTokens.layer0)
}

#Preview("Error Block") {
    let block = CommandBlock(
        command: "npm install",
        status: .error,
        exitCode: 1,
        startTime: Date().addingTimeInterval(-5.7),
        endTime: Date()
    )
    
    return BlockHeader(block: block) { action in
        print("Action: \(action)")
    }
    .padding()
    .background(ColorTokens.layer0)
}

#Preview("Running Block") {
    let block = CommandBlock(
        command: "brew install node",
        status: .running,
        startTime: Date().addingTimeInterval(-3.0)
    )
    
    return BlockHeader(block: block) { action in
        print("Action: \(action)")
    }
    .padding()
    .background(ColorTokens.layer0)
}
