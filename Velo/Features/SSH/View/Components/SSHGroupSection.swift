//
//  SSHGroupSection.swift
//  Velo
//
//  Collapsible SSH connection group section
//

import SwiftUI

struct SSHGroupSection: View {
    let group: SSHConnectionGroup?
    let connections: [SSHConnection]
    let onEdit: (SSHConnection) -> Void
    let onDelete: (SSHConnection) -> Void

    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Group header
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(ColorTokens.textTertiary)
                        .frame(width: 16)

                    if let group = group {
                        Image(systemName: group.icon)
                            .foregroundColor(group.color)
                    } else {
                        Image(systemName: "tray")
                            .foregroundColor(ColorTokens.textTertiary)
                    }

                    Text(group?.name ?? "Ungrouped")
                        .font(TypographyTokens.caption)
                        .foregroundColor(ColorTokens.textSecondary)

                    Text("(\(connections.count))")
                        .font(TypographyTokens.caption)
                        .foregroundColor(ColorTokens.textTertiary)

                    Spacer()
                }
                .padding(.horizontal, VeloDesign.Spacing.sm)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            // Connections
            if isExpanded {
                ForEach(connections) { connection in
                    SSHConnectionRow(
                        connection: connection,
                        onEdit: { onEdit(connection) },
                        onDelete: { onDelete(connection) }
                    )
                }
            }
        }
        .background(ColorTokens.layer1.opacity(0.5))
        .cornerRadius(VeloDesign.Radius.small)
    }
}
