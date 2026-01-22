//
//  FilesSidebarView.swift
//  Velo
//
//  Sidebar navigation for the Files feature.
//  Shows quick access locations, favorites, and recent paths.
//

import SwiftUI

struct FilesSidebarView: View {
    @ObservedObject var viewModel: FilesDetailViewModel
    var onDismiss: (() -> Void)?

    @State private var isHoveringAdd: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            headerSection

            Divider()
                .background(Color.white.opacity(0.1))

            // Navigation Sections
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Quick Access
                    quickAccessSection

                    // Favorites
                    favoritesSection

                    // Recent
                    recentSection
                }
                .padding(.vertical, 16)
            }

            Spacer()

            // Transfer Status
            if viewModel.hasActiveTransfers {
                transferStatusSection
            }
        }
        .frame(width: 220)
        .background(Color.white.opacity(0.02))
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Back button
            if let onDismiss = onDismiss {
                Button(action: onDismiss) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text("files.back".localized)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(ColorTokens.textSecondary)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 8)
            }

            // Title
            HStack(spacing: 10) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(ColorTokens.accentPrimary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("files.title".localized)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(ColorTokens.textPrimary)

                    Text(viewModel.currentPath)
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.textTertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .padding(20)
    }

    // MARK: - Quick Access

    private var quickAccessSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("files.quickAccess".localized)

            VStack(spacing: 2) {
                ForEach(viewModel.quickAccessLocations) { location in
                    SidebarLocationRow(
                        name: location.name,
                        icon: location.icon,
                        isSelected: viewModel.currentPath == location.path
                    ) {
                        let resolvedPath = location.path == "~" ? "/root" : location.path
                        viewModel.navigateTo(path: resolvedPath)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Favorites

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionHeader("files.favorites".localized)

                Spacer()

                Button(action: {
                    let name = (viewModel.currentPath as NSString).lastPathComponent
                    let displayName = name.isEmpty ? "Root" : name
                    viewModel.addToFavorites(path: viewModel.currentPath, name: displayName)
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(isHoveringAdd ? ColorTokens.accentPrimary : ColorTokens.textTertiary)
                }
                .buttonStyle(.plain)
                .onHover { isHoveringAdd = $0 }
                .help("files.addFavorite".localized)
            }
            .padding(.trailing, 12)

            if viewModel.favoriteLocations.isEmpty {
                Text("files.favorites.empty".localized)
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .padding(.leading, 16)
                    .padding(.top, 4)
            } else {
                VStack(spacing: 2) {
                    ForEach(viewModel.favoriteLocations) { location in
                        SidebarLocationRow(
                            name: location.name,
                            icon: location.icon,
                            isSelected: viewModel.currentPath == location.path,
                            onRemove: {
                                viewModel.removeFromFavorites(location)
                            }
                        ) {
                            viewModel.navigateTo(path: location.path)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Recent

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("files.recent".localized)

            if viewModel.recentPaths.isEmpty {
                Text("files.recent.empty".localized)
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .padding(.leading, 16)
                    .padding(.top, 4)
            } else {
                VStack(spacing: 2) {
                    ForEach(viewModel.recentPaths.prefix(8), id: \.self) { path in
                        SidebarLocationRow(
                            name: (path as NSString).lastPathComponent.isEmpty ? "/" : (path as NSString).lastPathComponent,
                            icon: "clock",
                            isSelected: viewModel.currentPath == path
                        ) {
                            viewModel.navigateTo(path: path)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
    }

    // MARK: - Transfer Status

    private var transferStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .background(Color.white.opacity(0.1))

            HStack(spacing: 8) {
                // Progress indicator
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 2)
                        .frame(width: 24, height: 24)

                    Circle()
                        .trim(from: 0, to: viewModel.transferProgress)
                        .stroke(ColorTokens.accentPrimary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 24, height: 24)
                        .rotationEffect(.degrees(-90))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("files.transfers.active".localized(viewModel.activeTransfers.count))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(ColorTokens.textPrimary)

                    Text("\(Int(viewModel.transferProgress * 100))%")
                        .font(.system(size: 10))
                        .foregroundStyle(ColorTokens.textTertiary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(ColorTokens.textTertiary)
            .padding(.leading, 16)
    }
}

// MARK: - Sidebar Location Row

private struct SidebarLocationRow: View {
    let name: String
    let icon: String
    let isSelected: Bool
    var onRemove: (() -> Void)?
    let action: () -> Void

    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? ColorTokens.accentPrimary : ColorTokens.textSecondary)
                    .frame(width: 18)

                Text(name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? ColorTokens.textPrimary : ColorTokens.textSecondary)
                    .lineLimit(1)

                Spacer()

                if isHovered, let onRemove = onRemove {
                    Button(action: onRemove) {
                        Image(systemName: "xmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.white.opacity(0.08) : (isHovered ? Color.white.opacity(0.04) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
