//
//  StatItem.swift
//  Velo
//
//  Docker Feature - Stat Item Component
//  Displays a labeled statistic value with color.
//

import SwiftUI

// MARK: - Stat Item

struct StatItem: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(ColorTokens.textTertiary)
                .textCase(.uppercase)

            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color)
        }
    }
}
