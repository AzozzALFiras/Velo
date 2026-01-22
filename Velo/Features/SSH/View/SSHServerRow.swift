//
//  SSHServerRow.swift
//  Velo
//
//  SSH Server Row Component
//  Displays an SSH connection in the sidebar list
//

import SwiftUI

// MARK: - SSH Server Row

/// Row for an SSH connection in the sidebar
struct SSHServerRow: View {

    let connection: SSHConnection
    let onConnect: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onConnect) {
            HStack(spacing: 8) {
                // Icon
                Image(systemName: connection.icon)
                    .font(.system(size: 11))
                    .foregroundStyle(connection.color)
                    .frame(width: 16)

                // Name
                VStack(alignment: .leading, spacing: 1) {
                    Text(connection.name)
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.textSecondary)
                        .lineLimit(1)

                    Text("\(connection.username)@\(connection.host)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(ColorTokens.textTertiary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(isHovered ? ColorTokens.layer2 : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SSHServerRow(
        connection: SSHConnection(
            name: "Production Server",
            host: "192.168.1.100",
            port: 22,
            username: "root"
        ),
        onConnect: {}
    )
    .frame(width: 240)
    .padding()
    .background(ColorTokens.layer1)
}
