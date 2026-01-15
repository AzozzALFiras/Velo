//
//  HistoryRow.swift
//  Velo
//
//  Intelligence Feature - History Row Component
//  Displays a command from history with favorite toggle and run action.
//

import SwiftUI

// MARK: - History Row

struct HistoryRow: View {
    let command: CommandModel
    @ObservedObject var historyManager: CommandHistoryManager
    let onRun: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            // Execution icon
            Image(systemName: command.isSuccess ? "terminal" : "exclamationmark.circle")
                .font(.system(size: 10))
                .foregroundStyle(command.isSuccess ? ColorTokens.textTertiary : ColorTokens.error)
                .frame(width: 16)

            // Command
            VStack(alignment: .leading, spacing: 2) {
                Text(command.command)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(2)

                if !command.workingDirectory.isEmpty {
                    Text(command.workingDirectory.components(separatedBy: "/").last ?? "")
                        .font(.system(size: 9))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
            .onTapGesture(perform: onRun)

            Spacer()

            // Actions
            HStack(spacing: 4) {
                Button {
                    historyManager.toggleFavorite(for: command.id)
                } label: {
                    Image(systemName: command.isFavorite ? "star.fill" : "star")
                        .font(.system(size: 11))
                        .foregroundStyle(command.isFavorite ? ColorTokens.warning : ColorTokens.textTertiary)
                }
                .buttonStyle(.plain)

                if isHovered {
                    Button(action: onRun) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(ColorTokens.accentPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(8)
        .background(isHovered ? ColorTokens.layer2 : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}
