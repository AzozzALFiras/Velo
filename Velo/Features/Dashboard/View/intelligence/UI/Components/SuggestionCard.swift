//
//  SuggestionCard.swift
//  Velo
//
//  Intelligence Feature - Suggestion Card Component
//  Displays an AI suggestion with run action.
//

import SwiftUI

// MARK: - Suggestion Card

struct SuggestionCard: View {

    let suggestion: SuggestionItem
    let onRun: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onRun) {
            HStack(spacing: 10) {
                Text(suggestion.command)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "play.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(ColorTokens.success)
                    .opacity(isHovered ? 1 : 0)
            }
            .padding(10)
            .background(isHovered ? ColorTokens.layer2 : ColorTokens.layer1)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(ColorTokens.border, lineWidth: 1)
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
