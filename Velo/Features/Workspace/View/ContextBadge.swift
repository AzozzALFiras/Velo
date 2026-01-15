//
//  ContextBadge.swift
//  Velo
//
//  Root Feature - Context Badge Component
//  Small badge showing project context (Docker, npm, Cargo, etc.)
//

import SwiftUI

// MARK: - Context Badge

/// Small badge showing project context
struct ContextBadge: View {

    let icon: String
    let label: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))

            Text(label)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}
