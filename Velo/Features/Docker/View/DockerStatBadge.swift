//
//  DockerStatBadge.swift
//  Velo
//
//  Docker Feature - Stat Badge Component
//  Compact badge for CPU/Memory display on container cards.
//

import SwiftUI

// MARK: - Docker Stat Badge

struct DockerStatBadge: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color.opacity(0.8))

            Text(value)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
