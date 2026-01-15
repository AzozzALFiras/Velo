//
//  GitStatusBadge.swift
//  Velo
//
//  Git Feature - Status Badge Component
//  Small badge showing an icon and count for git status indicators.
//

import SwiftUI

// MARK: - Git Status Badge

struct GitStatusBadge: View {
    let icon: String
    let count: Int
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))

            Text("\(count)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
        }
        .foregroundStyle(color)
    }
}
