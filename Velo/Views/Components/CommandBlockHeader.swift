//
//  CommandBlockHeader.swift
//  Velo
//
//  AI-Powered Terminal - Interactive Command Header
//

import SwiftUI

struct CommandBlockHeader: View, Equatable {
    let activeCommand: String
    let isExecuting: Bool
    let startTime: Date?
    let currentDirectory: String
    let onInterrupt: () -> Void
    let onRerun: () -> Void
    let onClear: () -> Void
    let onCopy: () -> Void
    
    // Equatable conformance to prevent unnecessary redraws
    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.activeCommand == rhs.activeCommand &&
               lhs.isExecuting == rhs.isExecuting &&
               lhs.startTime == rhs.startTime &&
               lhs.currentDirectory == rhs.currentDirectory
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Left: Status & Metadata
            HStack(spacing: VeloDesign.Spacing.md) {
                // Timer / Status Icon
                if isExecuting, let startTime = startTime {
                    TimelineView(.periodic(from: .now, by: 0.1)) { context in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(VeloDesign.Colors.neonGreen)
                                .frame(width: 6, height: 6)
                                .opacity(sin(context.date.timeIntervalSinceReferenceDate * 5) * 0.5 + 0.5)
                            
                            Text(timeString(from: startTime, to: context.date))
                                .font(VeloDesign.Typography.monoFont.weight(.medium))
                                .foregroundColor(VeloDesign.Colors.neonGreen)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(VeloDesign.Colors.neonGreen.opacity(0.1))
                    .cornerRadius(4)
                } else if !isExecuting && !activeCommand.isEmpty {
                    // Finished state (just icon)
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(VeloDesign.Colors.textMuted)
                        .font(.caption)
                }
                
                // Directory
                HStack(spacing: 4) {
                    Image(systemName: "folder.fill")
                        .font(.caption)
                    Text(shortenPath(currentDirectory))
                }
                .foregroundColor(VeloDesign.Colors.textSecondary)
                .font(VeloDesign.Typography.monoFont)
                
                // Divider
                Rectangle()
                    .fill(VeloDesign.Colors.glassBorder)
                    .frame(width: 1, height: 16)
                    
                // Command
                Text(activeCommand)
                    .font(VeloDesign.Typography.monoFont.weight(.bold))
                    .foregroundColor(VeloDesign.Colors.textPrimary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Right: Actions
            HStack(spacing: VeloDesign.Spacing.sm) {
                if isExecuting {
                    // Stop Button
                    Button(action: onInterrupt) {
                        HStack(spacing: 4) {
                            Image(systemName: "stop.fill")
                            Text("Stop")
                        }
                        .font(VeloDesign.Typography.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                } else {
                    // Restart Button
                    Button(action: onRerun) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(IconButton())
                    .help("Rerun Command")
                }
                
                // Copy Output
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(IconButton())
                .help("Copy Output")
                
                // Clear
                Button(action: onClear) {
                    Image(systemName: "trash")
                }
                .buttonStyle(IconButton())
                .help("Clear Output")
            }
        }
        .padding(.horizontal, VeloDesign.Spacing.md)
        .padding(.vertical, VeloDesign.Spacing.sm)
        .background(VeloDesign.Colors.cardBackground.opacity(0.8))
        .overlay(
            Rectangle()
                .fill(VeloDesign.Colors.glassBorder)
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    // Helper to format time
    private func timeString(from start: Date, to current: Date) -> String {
        let interval = current.timeIntervalSince(start)
        if interval < 60 {
            return String(format: "%.1fs", interval)
        } else {
            let minutes = Int(interval) / 60
            let seconds = Int(interval) % 60
            return String(format: "%dm %02ds", minutes, seconds)
        }
    }
    
    private func shortenPath(_ path: String) -> String {
        return (path as NSString).abbreviatingWithTildeInPath
    }
}

// Simple Icon Button Style
struct IconButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14))
            .foregroundColor(configuration.isPressed ? VeloDesign.Colors.textPrimary : VeloDesign.Colors.textSecondary)
            .padding(6)
            .background(configuration.isPressed ? VeloDesign.Colors.glassBorder : Color.clear)
            .cornerRadius(4)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}
