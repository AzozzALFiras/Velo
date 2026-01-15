//
//  ErrorCard.swift
//  Velo
//
//  Intelligence Feature - Error Card Component
//  Displays an error with explain and fix actions.
//

import SwiftUI

// MARK: - Error Card

struct ErrorCard: View {

    let error: ErrorItem
    let onExplain: () -> Void
    let onFix: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Error text
            Text(error.message)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(ColorTokens.error)
                .lineLimit(3)

            // Metadata
            HStack {
                Text(error.timestamp, style: .relative)
                    .font(.system(size: 10))
                    .foregroundStyle(ColorTokens.textTertiary)

                Spacer()

                HStack(spacing: 8) {
                    Button("Explain", action: onExplain)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ColorTokens.accentSecondary)

                    Button("Fix", action: onFix)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ColorTokens.accentPrimary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(ColorTokens.error.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(ColorTokens.error.opacity(0.2), lineWidth: 1)
        )
    }
}
