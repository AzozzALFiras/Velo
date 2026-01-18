//
//  FilesDetailView.swift
//  Velo
//
//  Main container view for the Files feature.
//  Combines sidebar navigation with the main file browser.
//

import SwiftUI

struct FilesDetailView: View {
    @StateObject private var viewModel: FilesDetailViewModel
    var onDismiss: (() -> Void)?

    init(session: TerminalViewModel?, onDismiss: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: FilesDetailViewModel(session: session))
        self.onDismiss = onDismiss
    }

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            FilesSidebarView(viewModel: viewModel, onDismiss: onDismiss)

            Divider()
                .background(ColorTokens.borderSubtle)

            // Main content
            mainContentView

            // Info Panel (optional)
            if viewModel.showInfoPanel, let info = viewModel.selectedFileInfo {
                Divider()
                    .background(ColorTokens.borderSubtle)

                FileInfoPanel(info: info, viewModel: viewModel)
                    .transition(.move(edge: .trailing))
            }
        }
        .background(ColorTokens.layer0)
        .task {
            await viewModel.loadData()
        }
        .animation(.spring(response: 0.3), value: viewModel.showInfoPanel)

        // Dialogs
        .sheet(isPresented: $viewModel.showCreateFolderDialog) {
            CreateFolderDialog(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showCreateFileDialog) {
            CreateFileDialog(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showRenameDialog) {
            if let file = viewModel.fileToRename {
                RenameDialog(file: file, viewModel: viewModel)
            }
        }
        .sheet(isPresented: $viewModel.showPermissionsDialog) {
            if let file = viewModel.fileToModify {
                PermissionsDialog(file: file, viewModel: viewModel)
            }
        }
        .sheet(isPresented: $viewModel.showDeleteConfirmation) {
            DeleteConfirmationDialog(files: viewModel.filesToDelete, viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showEditorDialog) {
            if let file = viewModel.fileToEdit {
                FileEditorView(file: file, viewModel: viewModel)
            }
        }

        // Transfer overlay
        .overlay(alignment: .bottom) {
            if viewModel.hasActiveTransfers {
                TransferOverlayView(viewModel: viewModel)
            }
        }

        // Toast messages
        .overlay(alignment: .top) {
            VStack(spacing: 8) {
                if let error = viewModel.errorMessage {
                    ToastView(message: error, type: .error) {
                        viewModel.clearError()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                if let success = viewModel.successMessage {
                    ToastView(message: success, type: .success) {
                        viewModel.clearSuccess()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.top, 20)
        }
        .animation(.spring(response: 0.3), value: viewModel.errorMessage)
        .animation(.spring(response: 0.3), value: viewModel.successMessage)
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContentView: some View {
        VStack(spacing: 0) {
            // Section header
            HStack {
                Text(sectionTitle)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(ColorTokens.textPrimary)

                Spacer()

                if viewModel.isLoading || viewModel.isPerformingAction {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(ColorTokens.textSecondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()
                .background(ColorTokens.borderSubtle)

            // Section content
            Group {
                switch viewModel.selectedSection {
                case .browser:
                    FilesBrowserView(viewModel: viewModel)
                case .favorites:
                    favoritesView
                case .recent:
                    recentView
                case .transfers:
                    TransfersSectionView(viewModel: viewModel)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var sectionTitle: String {
        switch viewModel.selectedSection {
        case .browser:
            return "files.section.browser".localized
        case .favorites:
            return "files.section.favorites".localized
        case .recent:
            return "files.section.recent".localized
        case .transfers:
            return "files.section.transfers".localized
        }
    }

    // MARK: - Favorites View

    private var favoritesView: some View {
        VStack(spacing: 0) {
            if viewModel.favoriteLocations.isEmpty {
                emptyStateView(
                    icon: "star",
                    title: "files.favorites.empty.title".localized,
                    message: "files.favorites.empty.message".localized
                )
            } else {
                List {
                    ForEach(viewModel.favoriteLocations) { location in
                        Button(action: {
                            viewModel.navigateTo(path: location.path)
                            viewModel.selectedSection = .browser
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: location.icon)
                                    .font(.system(size: 16))
                                    .foregroundStyle(ColorTokens.accentPrimary)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(location.name)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(ColorTokens.textPrimary)

                                    Text(location.path)
                                        .font(.system(size: 11))
                                        .foregroundStyle(ColorTokens.textTertiary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                Button(action: {
                                    viewModel.removeFromFavorites(location)
                                }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(ColorTokens.textTertiary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Recent View

    private var recentView: some View {
        VStack(spacing: 0) {
            if viewModel.recentPaths.isEmpty {
                emptyStateView(
                    icon: "clock",
                    title: "files.recent.empty.title".localized,
                    message: "files.recent.empty.message".localized
                )
            } else {
                List {
                    ForEach(viewModel.recentPaths, id: \.self) { path in
                        Button(action: {
                            viewModel.navigateTo(path: path)
                            viewModel.selectedSection = .browser
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "folder")
                                    .font(.system(size: 16))
                                    .foregroundStyle(ColorTokens.textSecondary)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text((path as NSString).lastPathComponent.isEmpty ? "/" : (path as NSString).lastPathComponent)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(ColorTokens.textPrimary)

                                    Text(path)
                                        .font(.system(size: 11))
                                        .foregroundStyle(ColorTokens.textTertiary)
                                        .lineLimit(1)
                                }

                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Empty State

    private func emptyStateView(icon: String, title: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundStyle(ColorTokens.textTertiary)

            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ColorTokens.textSecondary)

            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(ColorTokens.textTertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Toast View

private struct ToastView: View {
    let message: String
    let type: ToastType
    let onDismiss: () -> Void

    enum ToastType {
        case success
        case error

        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .error: return "exclamationmark.triangle.fill"
            }
        }

        var color: Color {
            switch self {
            case .success: return ColorTokens.success
            case .error: return ColorTokens.error
            }
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: type.icon)
                .foregroundStyle(type.color)

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ColorTokens.textPrimary)

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(type.color.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 10, y: 5)
        .padding(.horizontal, 20)
    }
}
