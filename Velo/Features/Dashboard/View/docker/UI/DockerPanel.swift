//
//  DockerPanel.swift
//  Velo
//
//  Docker Feature - Main Panel Entry Point
//  Visual container management replacing 'docker ps' and other CLI commands.
//

import SwiftUI

struct DockerPanel: View {
    let manager: DockerManager

    @State private var searchText = ""
    @State private var selectedContainerId: String? = nil

    var filteredContainers: [DockerContainer] {
        if searchText.isEmpty {
            return manager.containers
        }
        return manager.containers.filter {
            $0.name.lowercased().contains(searchText.lowercased()) ||
            $0.image.lowercased().contains(searchText.lowercased())
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            panelHeader

            Divider()
                .background(ColorTokens.border)

            // Stats Row
            statsRow

            Divider()
                .background(ColorTokens.borderSubtle)

            // Container List
            if manager.containers.isEmpty && !manager.isRefreshing {
                emptyState
            } else {
                containerList
            }
        }
        .background(ColorTokens.layer0)
    }

    // MARK: - Components

    private var panelHeader: some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(ColorTokens.info)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Docker Management")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(ColorTokens.textPrimary)

                    Text("\(manager.containers.count) Containers Total")
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }

            Spacer()

            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.textTertiary)

                TextField("Filter containers...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(ColorTokens.layer2)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .frame(width: 200)

            Button {
                manager.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.textSecondary)
                    .rotationEffect(.degrees(manager.isRefreshing ? 360 : 0))
                    .animation(manager.isRefreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: manager.isRefreshing)
            }
            .buttonStyle(.plain)
            .padding(.leading, 8)
        }
        .padding(16)
    }

    private var statsRow: some View {
        HStack(spacing: 24) {
            StatItem(label: "Running", value: "\(manager.containers.filter { $0.status == .running }.count)", color: ColorTokens.success)
            StatItem(label: "Stopped", value: "\(manager.containers.filter { $0.status == .stopped }.count)", color: ColorTokens.textTertiary)
            StatItem(label: "CPU Total", value: "2.4%", color: ColorTokens.accentPrimary)
            StatItem(label: "Memory", value: "1.2 GB", color: ColorTokens.accentSecondary)

            Spacer()

            Button {
                // Future: Open Docker Desktop or help
            } label: {
                Text("Compose Up")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(ColorTokens.accentPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ColorTokens.layer1.opacity(0.5))
    }

    private var containerList: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 16) {
                ForEach(filteredContainers) { container in
                    ContainerCard(
                        container: container,
                        onStart: { manager.startContainer(container.id) },
                        onStop: { manager.stopContainer(container.id) },
                        onRestart: { manager.restartContainer(container.id) }
                    )
                }
            }
            .padding(16)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "shippingbox")
                .font(.system(size: 48))
                .foregroundStyle(ColorTokens.textTertiary)

            VStack(spacing: 8) {
                Text("No Containers Found")
                    .font(.system(size: 16, weight: .bold))

                Text("Make sure Docker is running on your system.")
                    .font(.system(size: 13))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .multilineTextAlignment(.center)
            }

            Button("Refresh Now") {
                manager.refresh()
            }
            .buttonStyle(.borderedProminent)
            .tint(ColorTokens.accentPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
