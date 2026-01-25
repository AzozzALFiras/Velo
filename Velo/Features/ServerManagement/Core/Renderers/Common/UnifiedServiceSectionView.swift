//
//  UnifiedServiceSectionView.swift
//  Velo
//
//  Unified service control view for all applications.
//

import SwiftUI

struct UnifiedServiceSectionView: View {
    let app: ApplicationDefinition
    @ObservedObject var state: ApplicationState
    @ObservedObject var viewModel: ApplicationDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Status Card
            statusCard

            // Info Cards
            infoCardsGrid

            // Available Versions Section
            if !state.availableVersions.isEmpty && app.capabilities.contains(.multiVersion) {
                versionsSection
            }
        }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Status")
                    .font(.caption)
                    .foregroundStyle(.gray)

                if app.capabilities.contains(.controllable) {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(state.isRunning ? Color.green : Color.red)
                            .frame(width: 12, height: 12)
                            .shadow(color: state.isRunning ? .green : .red, radius: 4)

                        Text(state.isRunning ? "Running" : "Stopped")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                } else {
                     HStack(spacing: 8) {
                        Circle()
                            .fill(state.version.isEmpty || state.version == "Not Installed" ? Color.red : Color.green)
                            .frame(width: 12, height: 12)
                            .shadow(color: state.version.isEmpty || state.version == "Not Installed" ? .red : .green, radius: 4)

                        Text(state.version.isEmpty || state.version == "Not Installed" ? "Not Installed" : "Installed")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                    }
                }
            }

            Spacer()

            // Action Buttons (only for controllable services)
            if app.capabilities.contains(.controllable) {
                HStack(spacing: 12) {
                    if state.isRunning {
                        actionButton(title: "Stop", icon: "stop.fill", color: .red) {
                            await viewModel.stopService()
                        }
                    } else {
                        actionButton(title: "Start", icon: "play.fill", color: .green) {
                            await viewModel.startService()
                        }
                    }

                    actionButton(title: "Restart", icon: "arrow.clockwise", color: .orange) {
                        await viewModel.restartService()
                    }

                    actionButton(title: "Reload", icon: "arrow.triangle.2.circlepath", color: .blue) {
                        await viewModel.reloadService()
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Info Cards

    private var infoCardsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            infoCard(
                title: "Version",
                value: state.version.isEmpty ? "Checking..." : state.version,
                icon: "number"
            )

            infoCard(
                title: "Binary Path",
                value: state.binaryPath.isEmpty ? "..." : state.binaryPath,
                icon: "terminal"
            )

            infoCard(
                title: "Config Path",
                value: state.configPath.isEmpty ? "..." : state.configPath,
                icon: "doc.text"
            )

            if app.capabilities.contains(.multiVersion) {
                infoCard(
                    title: "Available Versions",
                    value: "\(state.availableVersions.count)",
                    icon: "square.stack.3d.up"
                )
            }
        }
    }

    // MARK: - Versions Section

    private var versionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Available Versions")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()
            }

            ForEach(state.availableVersions) { version in
                versionRow(version: version)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Components

    private func versionRow(version: CapabilityVersion) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("\(app.name) \(version.version)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)

                    Text(version.stability)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(stabilityColor(version.stability).opacity(0.2))
                        .foregroundStyle(stabilityColor(version.stability))
                        .clipShape(Capsule())

                    if version.isDefault {
                        Text("Recommended")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    }
                }
            }

            Spacer()

            let isInstalled = state.version.contains(version.version) ||
                              state.installedVersions.contains(version.version)
            let isInstalling = state.isInstallingVersion && state.installingVersionName == version.version

            if isInstalled {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                    Text("Installed")
                        .font(.caption)
                }
                .foregroundStyle(.green)
            } else if isInstalling {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text(state.installStatus.isEmpty ? "Installing..." : state.installStatus)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            } else {
                Button {
                    Task {
                        await viewModel.installVersion(version)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 10))
                        Text("Install")
                            .font(.caption)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.blue.opacity(0.8))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(state.isInstallingVersion)
            }
        }
        .padding(.vertical, 8)
    }

    private func stabilityColor(_ stability: String) -> Color {
        switch stability.lowercased() {
        case "stable": return .green
        case "mainline": return .blue
        case "legacy": return .orange
        default: return .gray
        }
    }

    private func actionButton(title: String, icon: String, color: Color, action: @escaping () async -> Void) -> some View {
        Button {
            Task {
                await action()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(color.opacity(0.8))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isPerformingAction)
    }

    private func infoCard(title: String, value: String, icon: String) -> some View {
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
                    .font(.system(size: 13, weight: .medium))
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
