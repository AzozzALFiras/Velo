//
//  GitFileRow.swift
//  Velo
//
//  Git Feature - File Row Component
//  Displays a file in staged/unstaged/untracked sections.
//

import SwiftUI

// MARK: - Git File Row

struct GitFileRow: View {
    let path: String
    let color: Color

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc")
                .font(.system(size: 11))
                .foregroundStyle(ColorTokens.textTertiary)

            Text((path as NSString).lastPathComponent)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ColorTokens.textPrimary)

            Text((path as NSString).deletingLastPathComponent)
                .font(.system(size: 10))
                .foregroundStyle(ColorTokens.textTertiary)
                .lineLimit(1)

            Spacer()

            if isHovered {
                HStack(spacing: 2) {
                    GitFileActionButton(icon: "eye", color: ColorTokens.accentPrimary) {}
                    GitFileActionButton(icon: "plus", color: ColorTokens.success) {}
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovered ? ColorTokens.layer2.opacity(0.5) : Color.clear)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}
