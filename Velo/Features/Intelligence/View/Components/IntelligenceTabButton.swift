//
//  IntelligenceTabButton.swift
//  Velo
//
//  Intelligence Feature - Tab Button Component
//  Tab button for switching between intelligence panel tabs.
//

import SwiftUI

// MARK: - Tab Button

struct IntelligenceTabButton: View {

    let tab: IntelligenceTab
    let isSelected: Bool
    let hasNotification: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: tab.icon)
                        .font(.system(size: 11, weight: .medium)) // Reduced from 14

                    if hasNotification {
                        Circle()
                            .fill(ColorTokens.error)
                            .frame(width: 5, height: 5)
                            .offset(x: 3, y: -2)
                    }
                }

                Text(tab.label)
                    .font(.system(size: 8, weight: .medium)) // Reduced from 9
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? ColorTokens.accentPrimary : ColorTokens.textTertiary)
            .frame(width: 44, height: 36) // Reduced from 60x44 to be more compact
            .background(isSelected ? ColorTokens.layer2 : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(tab.label)
    }
}
