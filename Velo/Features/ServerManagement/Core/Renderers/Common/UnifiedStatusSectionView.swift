//
//  UnifiedStatusSectionView.swift
//  Velo
//
//  Unified status/metrics view for all applications.
//

import SwiftUI

struct UnifiedStatusSectionView: View {
    let app: ApplicationDefinition
    @ObservedObject var state: ApplicationState
    @ObservedObject var viewModel: ApplicationDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            HStack {
                Text("Service Status")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    Task {
                        await viewModel.loadSectionData()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                    }
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }

            // Status content based on app type
            switch app.id.lowercased() {
            case "nginx":
                nginxStatusView
            case "mysql", "mariadb":
                mysqlStatusView
            case "php":
                phpFPMStatusView
            default:
                genericStatusView
            }
        }
    }

    // MARK: - Nginx Status

    private var nginxStatusView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let status = state.nginxStatus {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    statusMetric(title: "Active Connections", value: "\(status.activeConnections)", icon: "link")
                    statusMetric(title: "Accepted", value: "\(status.accepts)", icon: "arrow.down.circle")
                    statusMetric(title: "Handled", value: "\(status.handled)", icon: "checkmark.circle")
                    statusMetric(title: "Requests", value: "\(status.requests)", icon: "arrow.right.arrow.left")
                    statusMetric(title: "Reading", value: "\(status.reading)", icon: "eye")
                    statusMetric(title: "Writing", value: "\(status.writing)", icon: "pencil")
                    statusMetric(title: "Waiting", value: "\(status.waiting)", icon: "clock")
                }
            } else {
                noStatusView
            }
        }
    }

    // MARK: - MySQL Status

    private var mysqlStatusView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let status = state.mysqlStatus {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    statusMetric(title: "Version", value: status.version, icon: "number")
                    statusMetric(title: "Uptime", value: status.uptime, icon: "clock")
                    statusMetric(title: "Threads Connected", value: "\(status.threadsConnected)", icon: "person.2")
                    statusMetric(title: "Questions", value: "\(status.questions)", icon: "questionmark.circle")
                    statusMetric(title: "Slow Queries", value: "\(status.slowQueries)", icon: "tortoise")
                    statusMetric(title: "Open Tables", value: "\(status.openTables)", icon: "table")
                }
            } else {
                noStatusView
            }
        }
    }

    // MARK: - PHP-FPM Status

    private var phpFPMStatusView: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let status = state.fpmStatus {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    statusMetric(title: "Pool", value: status.pool, icon: "square.grid.2x2")
                    statusMetric(title: "Process Manager", value: status.processManager, icon: "gearshape.2")
                    statusMetric(title: "Active Processes", value: "\(status.activeProcesses)", icon: "bolt.fill")
                    statusMetric(title: "Idle Processes", value: "\(status.idleProcesses)", icon: "moon")
                    statusMetric(title: "Total Processes", value: "\(status.totalProcesses)", icon: "sum")
                    statusMetric(title: "Accepted Connections", value: "\(status.acceptedConnections)", icon: "checkmark.circle")
                }
            } else {
                noStatusView
            }
        }
    }

    // MARK: - Generic Status

    private var genericStatusView: some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                statusMetric(title: "Status", value: state.isRunning ? "Running" : "Stopped", icon: "power")
                statusMetric(title: "Version", value: state.version.isEmpty ? "Unknown" : state.version, icon: "number")
            }
        }
    }

    // MARK: - No Status View

    private var noStatusView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 40))
                .foregroundStyle(.gray)

            Text("Status information not available")
                .font(.subheadline)
                .foregroundStyle(.gray)

            Text("Enable status endpoint to view metrics")
                .font(.caption)
                .foregroundStyle(.gray.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Components

    private func statusMetric(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color(hex: app.themeColor) ?? .green)
                .frame(width: 36, height: 36)
                .background((Color(hex: app.themeColor) ?? .green).opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.gray)

                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}
