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
    
    var body: some View {
        HStack(spacing: 6) {
            // Terminal-style prompt
            promptView
            
            // Command text - no truncation for better readability
            Text(block.command)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(ColorTokens.textPrimary)
                .textSelection(.enabled)
            
            Spacer(minLength: 8)
            
            // Minimal right side: duration + status dot
            HStack(spacing: 8) {
                durationView
                statusDot
            }
        }
        .padding(.leading, 12)
        .padding(.trailing, 20)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
        .contextMenu { contextMenuContent }
    }
    
    // MARK: - Prompt View (Terminal-style)
    
    @ViewBuilder
    private var promptView: some View {
        HStack(spacing: 4) {
            if block.isRunning {
                RunningIndicator()
                    .font(.system(size: 10))
            } else {
                Text("$")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(block.isError ? ColorTokens.error : ColorTokens.success)
            }
        }
        .frame(width: 14)
    }
    
    // MARK: - Status Dot (Minimal)
    
    @ViewBuilder
    private var statusDot: some View {
        if !block.isRunning {
            Circle()
                .fill(block.status.color)
                .frame(width: 6, height: 6)
        }
    }
    
    // MARK: - Duration View
    
    @ViewBuilder
    private var durationView: some View {
        if block.isRunning {
            TimelineView(.animation(minimumInterval: 0.1)) { _ in
                Text(formatDuration(Date().timeIntervalSince(block.startTime)))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(ColorTokens.warning)
            }
        } else if block.status != .idle {
            Text(block.formattedDuration)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(ColorTokens.textTertiary)
        }
    }
    
    // MARK: - Context Menu (All actions here)
    
    @ViewBuilder
    private var contextMenuContent: some View {
        // Primary actions first
        if block.isError {
            Button { onAction?(.fix) } label: {
                Label("Fix", systemImage: "wrench.and.screwdriver")
            }
            Button { onAction?(.explain) } label: {
                Label("Explain", systemImage: "questionmark.circle")
            }
            Divider()
        }
        
        Button { onAction?(.retry) } label: {
            Label("Retry", systemImage: "arrow.clockwise")
        }
        
        Button { onAction?(.copy) } label: {
            Label("Copy Command", systemImage: "doc.on.doc")
        }
        
        Button { onAction?(.copyOutput) } label: {
            Label("Copy Output", systemImage: "doc.on.clipboard")
        }
        
        Divider()
        
        Button(role: .destructive) { onAction?(.delete) } label: {
            Label("Delete", systemImage: "trash")
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
