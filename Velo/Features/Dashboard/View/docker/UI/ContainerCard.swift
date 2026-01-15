//
//  ContainerCard.swift
//  Velo
//
//  Docker Feature - Container Card Component
//  Displays a Docker container with status, image, ports, and actions.
//

import SwiftUI

// MARK: - Container Card

struct ContainerCard: View {
    let container: DockerContainer
    let onStart: () -> Void
    let onStop: () -> Void
    let onRestart: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Card Header
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(container.status.color)
                        .frame(width: 8, height: 8)
                        .shadow(color: container.status.color.opacity(0.5), radius: 4)

                    Text(container.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(ColorTokens.textPrimary)
                }

                Spacer()

                Text(container.id.prefix(8))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(ColorTokens.textTertiary)
            }

            // Card Content
            VStack(alignment: .leading, spacing: 8) {
                infoRow(icon: "tag", label: "Image", value: container.image)
                infoRow(icon: "network", label: "Ports", value: container.ports.joined(separator: ", "))

                HStack(spacing: 16) {
                    DockerStatBadge(label: "CPU", value: "\(container.cpuUsage)%", color: ColorTokens.accentPrimary)
                    DockerStatBadge(label: "MEM", value: container.memoryUsage, color: ColorTokens.accentSecondary)
                }
                .padding(.top, 4)
            }

            Divider()
                .background(ColorTokens.borderSubtle)

            // Actions
            HStack(spacing: 8) {
                if container.status == .running {
                    DockerActionButton(icon: "stop.fill", label: "Stop", color: ColorTokens.error, action: onStop)
                } else {
                    DockerActionButton(icon: "play.fill", label: "Start", color: ColorTokens.success, action: onStart)
                }

                DockerActionButton(icon: "arrow.clockwise", label: "Restart", color: ColorTokens.warning, action: onRestart)

                Spacer()

                Menu {
                    Button(action: {}) { Label("View Logs", systemImage: "doc.text") }
                    Button(action: {}) { Label("Execute Shell", systemImage: "terminal") }
                    Divider()
                    Button(role: .destructive, action: {}) { Label("Remove", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14))
                        .foregroundStyle(ColorTokens.textTertiary)
                        .frame(width: 28, height: 28)
                        .background(ColorTokens.layer2)
                        .clipShape(Circle())
                }
                .menuStyle(.button)
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(ColorTokens.layer1)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isHovered ? ColorTokens.accentPrimary.opacity(0.3) : ColorTokens.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(isHovered ? 0.3 : 0.1), radius: 10, x: 0, y: 5)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundStyle(ColorTokens.textTertiary)
                .frame(width: 14)

            Text(label + ":")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ColorTokens.textTertiary)

            Text(value)
                .font(.system(size: 11))
                .foregroundStyle(ColorTokens.textSecondary)
                .lineLimit(1)
        }
    }
}
