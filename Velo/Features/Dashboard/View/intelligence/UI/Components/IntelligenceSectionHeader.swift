//
//  IntelligenceSectionHeader.swift
//  Velo
//
//  Intelligence Feature - Section Header Component
//  Header for sections within intelligence panel tabs.
//

import SwiftUI

// MARK: - Section Header

struct IntelligenceSectionHeader: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)

            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(ColorTokens.textSecondary)

            Spacer()
        }
    }
}
