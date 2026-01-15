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
                        .font(.system(size: 14, weight: .medium))

                    if hasNotification {
                        Circle()
                            .fill(ColorTokens.error)
                            .frame(width: 6, height: 6)
                            .offset(x: 4, y: -2)
                    }
                }

                Text(tab.rawValue)
                    .font(.system(size: 9, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? ColorTokens.accentPrimary : ColorTokens.textTertiary)
            .frame(width: 60, height: 44)
            .background(isSelected ? ColorTokens.layer2 : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .help(tab.rawValue)
    }
}
