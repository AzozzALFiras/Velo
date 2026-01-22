//
//  UnifiedVersionsSectionView.swift
//  Velo
//
//  Unified versions management view.
//

import SwiftUI

struct UnifiedVersionsSectionView: View {
    let app: ApplicationDefinition
    @ObservedObject var state: ApplicationState
    @ObservedObject var viewModel: ApplicationDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Current Version
            currentVersionCard

            // Installed Versions
            if !state.installedVersions.isEmpty {
                installedVersionsSection
            }

            // Available Versions
            if !state.availableVersions.isEmpty {
                availableVersionsSection
            }
        }
    }

    private var currentVersionCard: some View {
        HStack(spacing: 16) {
            Image(systemName: "number.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(Color(hex: app.themeColor) ?? .green)

            VStack(alignment: .leading, spacing: 4) {
                Text("Active Version")
                    .font(.caption)
                    .foregroundStyle(.gray)

                Text(state.activeVersion.isEmpty ? "Not detected" : state.activeVersion)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }

            Spacer()
        }
        .padding(20)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var installedVersionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Installed Versions")
                .font(.headline)
                .foregroundStyle(.white)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 12) {
                ForEach(state.installedVersions, id: \.self) { version in
                    installedVersionChip(version)
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func installedVersionChip(_ version: String) -> some View {
        HStack(spacing: 8) {
            Text(version)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)

            if version == state.activeVersion {
                Text("Active")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.2))
                    .foregroundStyle(.green)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(version == state.activeVersion ? Color.green.opacity(0.1) : Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var availableVersionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Available for Installation")
                .font(.headline)
                .foregroundStyle(.white)

            ForEach(state.availableVersions) { version in
                availableVersionRow(version)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func availableVersionRow(_ version: CapabilityVersion) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
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

                if let usage = version.recommendedUsage {
                    Text(usage)
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            }

            Spacer()

            installButton(for: version)
        }
        .padding(.vertical, 10)
    }

    private func installButton(for version: CapabilityVersion) -> some View {
        let isInstalled = state.installedVersions.contains(version.version) ||
                          state.version.contains(version.version)
        let isInstalling = state.isInstallingVersion && state.installingVersionName == version.version

        return Group {
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
                        .lineLimit(1)
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
    }

    private func stabilityColor(_ stability: String) -> Color {
        switch stability.lowercased() {
        case "stable": return .green
        case "mainline", "lts": return .blue
        case "legacy", "eol": return .orange
        default: return .gray
        }
    }
}
