//
//  DockerPanel.swift
//  Velo
//
//  Dashboard Redesign - Docker Management Panel
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

// MARK: - Stat Item
private struct StatItem: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(ColorTokens.textTertiary)
                .textCase(.uppercase)
            
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color)
        }
    }
}

// MARK: - Container Card
private struct ContainerCard: View {
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

// MARK: - Support Components
private struct DockerStatBadge: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(color.opacity(0.8))
            
            Text(value)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

private struct DockerActionButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                Text(label)
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}
