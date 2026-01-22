//
//  SystemInfoBar.swift
//  Velo
//
//  Root Feature - System Info Bar Component
//  Compact system information bar showing CPU, RAM, Disk.
//

import SwiftUI

// MARK: - System Info Bar

/// Compact system information bar
struct SystemInfoBar: View {

    let monitor: SystemMonitor
    var isSSH: Bool = false
    var serverName: String? = nil

    var body: some View {
        HStack(spacing: 16) {
            // Host indicator
            HStack(spacing: 6) {
                Image(systemName: isSSH ? "server.rack" : "laptopcomputer")
                    .font(.system(size: 10))
                    .foregroundStyle(isSSH ? ColorTokens.success : ColorTokens.accentPrimary)

                Text(serverName ?? monitor.hostname)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ColorTokens.textPrimary)
                    .lineLimit(1)
            }

            Divider()
                .frame(height: 14)

            // CPU
            StatPill(
                icon: "cpu",
                label: "system.cpu".localized,
                value: String(format: "%.0f%%", monitor.cpuUsage * 100),
                color: colorForUsage(monitor.cpuUsage)
            )

            // Memory
            StatPill(
                icon: "memorychip",
                label: "system.memory".localized,
                value: String(format: "%.0f%%", monitor.memoryUsage * 100),
                color: colorForUsage(monitor.memoryUsage)
            )

            // Disk
            StatPill(
                icon: "internaldrive",
                label: "system.disk".localized,
                value: String(format: "%.0f%%", monitor.diskUsage * 100),
                color: colorForUsage(monitor.diskUsage)
            )

            // Uptime
            if !monitor.uptime.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                    Text(monitor.uptime)
                        .font(.system(size: 10))
                }
                .foregroundStyle(ColorTokens.textTertiary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(ColorTokens.layer1)
    }

    private func colorForUsage(_ usage: Double) -> Color {
        if usage > 0.9 {
            return ColorTokens.error
        } else if usage > 0.7 {
            return ColorTokens.warning
        } else {
            return ColorTokens.success
        }
    }
}

// MARK: - Stat Pill

struct StatPill: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
        .help("\(label): \(value)")
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        SystemInfoBar(monitor: SystemMonitor())

        Divider()

        SystemInfoBar(
            monitor: SystemMonitor(),
            isSSH: true,
            serverName: "production-server"
        )
    }
    .frame(width: 600)
}
