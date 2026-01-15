//
//  SSHSessionIndicator.swift
//  Velo
//
//  SSH Session Indicator
//  Visual indicator for SSH sessions in tabs and sidebar
//

import SwiftUI

// MARK: - SSH Session Indicator

/// Visual indicator showing SSH session status
struct SSHSessionIndicator: View {

    let isActive: Bool
    var size: Size = .small

    enum Size {
        case small  // For tabs
        case medium // For sidebar
        case large  // For headers

        var iconSize: CGFloat {
            switch self {
            case .small: return 10
            case .medium: return 12
            case .large: return 14
            }
        }

        var dotSize: CGFloat {
            switch self {
            case .small: return 6
            case .medium: return 8
            case .large: return 10
            }
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            // Network icon
            Image(systemName: "network")
                .font(.system(size: size.iconSize))
                .foregroundStyle(isActive ? ColorTokens.success : ColorTokens.textTertiary)

            // Connection dot
            Circle()
                .fill(isActive ? ColorTokens.success : ColorTokens.textTertiary.opacity(0.5))
                .frame(width: size.dotSize, height: size.dotSize)
        }
    }
}

// MARK: - SSH Badge

/// Compact SSH badge for inline display
struct SSHBadge: View {

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "network")
                .font(.system(size: 8, weight: .medium))

            Text("SSH")
                .font(.system(size: 8, weight: .bold))
        }
        .foregroundStyle(ColorTokens.success)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(ColorTokens.success.opacity(0.15))
        .clipShape(Capsule())
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Small (tabs)
        HStack {
            Text("Small (tabs):")
            SSHSessionIndicator(isActive: true, size: .small)
            SSHSessionIndicator(isActive: false, size: .small)
        }

        // Medium (sidebar)
        HStack {
            Text("Medium (sidebar):")
            SSHSessionIndicator(isActive: true, size: .medium)
            SSHSessionIndicator(isActive: false, size: .medium)
        }

        // Large (headers)
        HStack {
            Text("Large (headers):")
            SSHSessionIndicator(isActive: true, size: .large)
            SSHSessionIndicator(isActive: false, size: .large)
        }

        // Badge
        HStack {
            Text("Badge:")
            SSHBadge()
        }
    }
    .padding()
    .background(ColorTokens.layer0)
}
