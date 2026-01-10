//
//  CommandCardView.swift
//  Velo
//
//  AI-Powered Terminal - Command Card Component
//

import SwiftUI

// MARK: - Command Card View
/// A visually striking card displaying a single command
struct CommandCardView: View {
    let command: CommandModel
    let onRun: () -> Void
    let onEdit: () -> Void
    let onExplain: () -> Void
    
    @State private var isHovered = false
    @State private var showActions = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: VeloDesign.Spacing.sm) {
            // Header
            HStack(spacing: VeloDesign.Spacing.sm) {
                // Context icon
                Image(systemName: command.context.icon)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: command.context.color))
                
                // Timestamp
                Text(command.relativeTimestamp)
                    .font(VeloDesign.Typography.caption)
                    .foregroundColor(VeloDesign.Colors.textMuted)
                
                Spacer()
                
                // Status indicator
                StatusDot(status: command.isSuccess ? .success : .error)
                
                // Duration
                Text(command.formattedDuration)
                    .font(VeloDesign.Typography.monoSmall)
                    .foregroundColor(VeloDesign.Colors.textSecondary)
            }
            
            // Command text
            Text(command.command)
                .font(VeloDesign.Typography.monoFont)
                .foregroundColor(VeloDesign.Colors.textPrimary)
                .lineLimit(2)
                .truncationMode(.tail)
            
            // Actions (visible on hover)
            if isHovered || showActions {
                HStack(spacing: VeloDesign.Spacing.md) {
                    ActionButton(icon: "play.fill", label: "Run", color: VeloDesign.Colors.neonGreen) {
                        onRun()
                    }
                    
                    ActionButton(icon: "pencil", label: "Edit", color: VeloDesign.Colors.neonCyan) {
                        onEdit()
                    }
                    
                    ActionButton(icon: "questionmark.circle", label: "Explain", color: VeloDesign.Colors.neonPurple) {
                        onExplain()
                    }
                    
                    Spacer()
                    
                    // Copy button
                    ActionButton(icon: "doc.on.doc", label: "Copy", color: VeloDesign.Colors.textSecondary) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(command.command, forType: .string)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(VeloDesign.Spacing.md)
        .glassCard(
            cornerRadius: VeloDesign.Radius.medium,
            glowColor: isHovered ? VeloDesign.Colors.neonCyan : nil
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(VeloDesign.Animation.quick, value: isHovered)
        .onHover { hovering in
            withAnimation(VeloDesign.Animation.quick) {
                isHovered = hovering
            }
        }
        .onTapGesture(count: 2) {
            onRun()
        }
        .contextMenu {
            Button("Run") { onRun() }
            Button("Edit") { onEdit() }
            Button("Explain") { onExplain() }
            Divider()
            Button("Copy") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(command.command, forType: .string)
            }
        }
    }
}

// MARK: - Action Button
struct ActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: VeloDesign.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(label)
                    .font(VeloDesign.Typography.caption)
            }
            .foregroundColor(color)
            .padding(.horizontal, VeloDesign.Spacing.sm)
            .padding(.vertical, VeloDesign.Spacing.xs)
            .background(
                Capsule()
                    .fill(color.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : 1.0)
    }
}

// MARK: - Compact Command Card
/// A smaller version for dense lists
struct CompactCommandCard: View {
    let command: CommandModel
    let onSelect: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: VeloDesign.Spacing.sm) {
            // Context icon
            Image(systemName: command.context.icon)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: command.context.color))
                .frame(width: 16)
            
            // Command
            Text(command.command)
                .font(VeloDesign.Typography.monoSmall)
                .foregroundColor(VeloDesign.Colors.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            // Status
            StatusDot(status: command.isSuccess ? .success : .error)
        }
        .padding(.horizontal, VeloDesign.Spacing.sm)
        .padding(.vertical, VeloDesign.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: VeloDesign.Radius.small, style: .continuous)
                .fill(isHovered ? VeloDesign.Colors.elevatedSurface : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onSelect()
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 16) {
        CommandCardView(
            command: CommandModel(
                command: "git push origin main --force",
                output: "Success",
                exitCode: 0,
                duration: 2.5,
                context: .git
            ),
            onRun: {},
            onEdit: {},
            onExplain: {}
        )
        .frame(width: 350)
        
        CompactCommandCard(
            command: CommandModel(
                command: "npm install",
                exitCode: 0,
                context: .npm
            ),
            onSelect: {}
        )
        .frame(width: 350)
    }
    .padding()
    .background(VeloDesign.Colors.deepSpace)
}
