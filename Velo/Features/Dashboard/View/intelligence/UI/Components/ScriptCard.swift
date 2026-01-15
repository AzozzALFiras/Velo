//
//  ScriptCard.swift
//  Velo
//
//  Intelligence Feature - Script Card Component
//  Displays an auto-script with expandable commands and run action.
//

import SwiftUI

// MARK: - Script Card

struct ScriptCard: View {

    let script: AutoScript
    let onRun: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: "scroll")
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.accentSecondary)

                Text(script.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ColorTokens.textPrimary)

                Spacer()

                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .buttonStyle(.plain)
            }

            // Commands preview
            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(script.commands, id: \.self) { command in
                        Text(command)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                }
                .padding(8)
                .background(ColorTokens.layer0)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            // Actions
            HStack(spacing: 8) {
                Button(action: onRun) {
                    Label("Run", systemImage: "play.fill")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(ColorTokens.success)

                Button {} label: {
                    Label("Edit", systemImage: "pencil")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(ColorTokens.textSecondary)

                Spacer()
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(ColorTokens.layer2)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
