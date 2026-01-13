//
//  SSHConnectionRow.swift
//  Velo
//
//  SSH connection list item component
//

import SwiftUI

struct SSHConnectionRow: View {
    let connection: SSHConnection
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: VeloDesign.Spacing.sm) {
            // Icon
            Image(systemName: connection.icon)
                .font(.system(size: 16))
                .foregroundColor(connection.color)
                .frame(width: 24)

            // Details
            VStack(alignment: .leading, spacing: 2) {
                Text(connection.displayName)
                    .font(TypographyTokens.mono)
                    .foregroundColor(ColorTokens.textPrimary)

                Text(connection.connectionString)
                    .font(TypographyTokens.monoSm)
                    .foregroundColor(ColorTokens.textTertiary)
            }

            Spacer()

            // Auth method badge
            Image(systemName: connection.authMethod.icon)
                .font(.system(size: 12))
                .foregroundColor(ColorTokens.textTertiary)
                .help(connection.authMethod.displayName)

            // Actions (visible on hover)
            if isHovered {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundColor(ColorTokens.accentPrimary)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundColor(ColorTokens.error)
            }
        }
        .padding(.horizontal, VeloDesign.Spacing.md)
        .padding(.vertical, VeloDesign.Spacing.sm)
        .background(isHovered ? ColorTokens.layer2 : Color.clear)
        .cornerRadius(VeloDesign.Radius.small)
        .onHover { isHovered = $0 }
    }
}
