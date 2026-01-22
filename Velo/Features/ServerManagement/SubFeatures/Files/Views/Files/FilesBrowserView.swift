//
//  FilesBrowserView.swift
//  Velo
//
//  Main file browser view with toolbar, breadcrumbs, and file list.
//

import SwiftUI

struct FilesBrowserView: View {
    @ObservedObject var viewModel: FilesDetailViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Compact Toolbar
            FilesToolbarView(viewModel: viewModel)

            // Breadcrumb
            BreadcrumbView(viewModel: viewModel)

            Divider()
                .background(ColorTokens.borderSubtle)

            // Content based on view mode
            fileContent
        }
        .background(ColorTokens.layer0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - File Content

    @ViewBuilder
    private var fileContent: some View {
        if viewModel.isLoading {
            loadingView
        } else if viewModel.filteredAndSortedFiles.isEmpty {
            emptyView
        } else {
            switch viewModel.viewMode {
            case .list:
                listView
            case .grid:
                gridView
            case .columns:
                columnsView
            }
        }
    }

    // MARK: - List View

    private var listView: some View {
        VStack(spacing: 0) {
            // Table Header
            fileListHeader

            // File List
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.filteredAndSortedFiles) { file in
                        FileRowView(
                            file: file,
                            isSelected: viewModel.selectedFiles.contains(file.id),
                            viewModel: viewModel
                        )

                        Divider()
                            .background(ColorTokens.borderSubtle.opacity(0.5))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Grid View

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 12)
            ], spacing: 12) {
                ForEach(viewModel.filteredAndSortedFiles) { file in
                    FileGridItemView(
                        file: file,
                        isSelected: viewModel.selectedFiles.contains(file.id),
                        viewModel: viewModel
                    )
                }
            }
            .padding(16)
        }
    }

    // MARK: - Columns View

    private var columnsView: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(spacing: 0) {
                // Parent directory column
                if viewModel.currentPath != "/" {
                    columnPane(
                        title: "files.col.parent".localized,
                        files: [],
                        isParent: true
                    )
                    .frame(width: 220)

                    Divider()
                        .background(ColorTokens.borderSubtle)
                }

                // Current directory column
                columnPane(
                    title: currentDirectoryName,
                    files: viewModel.filteredAndSortedFiles,
                    isParent: false
                )
                .frame(width: 260)

                // Selected item preview (if a file is selected)
                if let selectedFile = viewModel.selectedFile, !selectedFile.isDirectory {
                    Divider()
                        .background(ColorTokens.borderSubtle)

                    filePreviewColumn(file: selectedFile)
                        .frame(width: 300)
                }
            }
        }
        .background(ColorTokens.layer0)
    }

    private func columnPane(title: String, files: [ServerFileItem], isParent: Bool) -> some View {
        VStack(spacing: 0) {
            // Column header
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ColorTokens.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(ColorTokens.layer1.opacity(0.5))

            Divider()
                .background(ColorTokens.borderSubtle)

            if isParent {
                // Parent navigation item
                Button(action: { viewModel.navigateUp() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.left")
                            .font(.system(size: 12))
                            .foregroundStyle(ColorTokens.textSecondary)

                        Text("files.columns.parent".localized)
                            .font(.system(size: 12))
                            .foregroundStyle(ColorTokens.textSecondary)

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.03))
                }
                .buttonStyle(.plain)

                Spacer()
            } else {
                // File list
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(files) { file in
                            FileColumnRowView(
                                file: file,
                                isSelected: viewModel.selectedFiles.contains(file.id),
                                viewModel: viewModel
                            )
                        }
                    }
                    .padding(8)
                }
                .scrollIndicators(.never)
            }
        }
        .frame(width: 220)
    }

    private func filePreviewColumn(file: ServerFileItem) -> some View {
        VStack(spacing: 16) {
            Spacer()

            // File icon
            let fileType = FileTypeCategory.from(fileName: file.name, isDirectory: file.isDirectory)
            Image(systemName: fileType.icon)
                .font(.system(size: 48))
                .foregroundStyle(Color(hex: fileType.color))

            // File name
            Text(file.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ColorTokens.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            // File info
            VStack(spacing: 4) {
                Text(file.sizeString)
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.textSecondary)

                Text(file.dateString)
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.textTertiary)
            }

            Spacer()

            // Quick actions
            HStack(spacing: 8) {
                Button(action: { viewModel.initiateDownload(for: file) }) {
                    Label("files.download".localized, systemImage: "arrow.down.circle")
                        .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(ColorTokens.layer2)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                if file.isTextFile {
                    Button(action: { viewModel.initiateEdit(for: file) }) {
                        Label("files.edit".localized, systemImage: "pencil")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(ColorTokens.accentPrimary.opacity(0.2))
                    .foregroundStyle(ColorTokens.accentPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(.bottom, 16)
        }
        .frame(width: 200)
        .background(ColorTokens.layer1.opacity(0.3))
    }

    private var parentDirectoryName: String {
        let parent = (viewModel.currentPath as NSString).deletingLastPathComponent
        return (parent as NSString).lastPathComponent.isEmpty ? "/" : (parent as NSString).lastPathComponent
    }

    private var currentDirectoryName: String {
        let name = (viewModel.currentPath as NSString).lastPathComponent
        return name.isEmpty ? "/" : name
    }

    // MARK: - File List Header (for List View)

    private var fileListHeader: some View {
        HStack(spacing: 0) {
            // Checkbox column
            Rectangle()
                .fill(Color.clear)
                .frame(width: 32)

            // Name
            sortableColumnHeader("files.col.name".localized, option: .name)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)

            // Size
            sortableIconHeader("sdcard.fill", option: .size)
                .frame(width: 60, alignment: .trailing)
                .help("files.col.size".localized)

            // Permissions
            HStack(spacing: 4) {
               Image(systemName: "lock.fill")
                   .font(.system(size: 10))
            }
            .foregroundStyle(ColorTokens.textTertiary)
            .frame(width: 50, alignment: .leading)
            .padding(.leading, 8)
            .help("files.col.permissions".localized)

            // Owner
            HStack(spacing: 4) {
                Image(systemName: "person.fill")
                    .font(.system(size: 10))
            }
            .foregroundStyle(ColorTokens.textTertiary)
            .frame(width: 50, alignment: .leading)
            .help("files.col.owner".localized)

            // Modified
            sortableIconHeader("calendar", option: .modified)
                .frame(width: 60, alignment: .leading)
                .help("files.col.modified".localized)

            // Actions
            Rectangle()
                .fill(Color.clear)
                .frame(width: 40)
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(ColorTokens.textTertiary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(ColorTokens.layer1.opacity(0.4))
        .frame(height: 28)
    }

    private func sortableIconHeader(_ icon: String, option: FileSortOption) -> some View {
        Button(action: {
            if viewModel.sortOption == option {
                viewModel.sortDirection.toggle()
            } else {
                viewModel.sortOption = option
                viewModel.sortDirection = .ascending
            }
        }) {
            HStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 10))

                if viewModel.sortOption == option {
                    Image(systemName: viewModel.sortDirection == .ascending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func sortableColumnHeader(_ title: String, option: FileSortOption) -> some View {
        Button(action: {
            if viewModel.sortOption == option {
                viewModel.sortDirection.toggle()
            } else {
                viewModel.sortOption = option
                viewModel.sortDirection = .ascending
            }
        }) {
            HStack(spacing: 3) {
                Text(title)

                if viewModel.sortOption == option {
                    Image(systemName: viewModel.sortDirection == .ascending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 7, weight: .bold))
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Loading & Empty States

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            Text("files.loading".localized)
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: viewModel.searchQuery.isEmpty ? "folder" : "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(ColorTokens.textTertiary)

            Text(viewModel.searchQuery.isEmpty ? "files.empty".localized : "files.noResults".localized)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ColorTokens.textSecondary)

            if viewModel.searchQuery.isEmpty {
                Button(action: { viewModel.showCreateFolderDialog = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.badge.plus")
                        Text("files.createFolder".localized)
                    }
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ColorTokens.accentPrimary)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Compact Toolbar

struct FilesToolbarView: View {
    @ObservedObject var viewModel: FilesDetailViewModel

    var body: some View {
        HStack(spacing: 8) {
            // Navigation group
            HStack(spacing: 2) {
                ToolbarIconButton(icon: "chevron.left", isEnabled: viewModel.canNavigateBack) {
                    viewModel.navigateBack()
                }
                ToolbarIconButton(icon: "chevron.right", isEnabled: viewModel.canNavigateForward) {
                    viewModel.navigateForward()
                }
                ToolbarIconButton(icon: "chevron.up", isEnabled: viewModel.currentPath != "/") {
                    viewModel.navigateUp()
                }
            }

            Divider()
                .frame(height: 16)
                .background(ColorTokens.borderSubtle)

            // Refresh
            ToolbarIconButton(icon: "arrow.clockwise", isEnabled: true) {
                Task { await viewModel.refresh() }
            }

            Divider()
                .frame(height: 16)
                .background(ColorTokens.borderSubtle)

            // Action buttons group
            HStack(spacing: 2) {
                ToolbarIconButton(icon: "folder.badge.plus", tooltip: "files.newFolder".localized, isEnabled: true) {
                    viewModel.showCreateFolderDialog = true
                }
                ToolbarIconButton(icon: "doc.badge.plus", tooltip: "files.newFile".localized, isEnabled: true) {
                    viewModel.showCreateFileDialog = true
                }
            }

            // Upload button (primary)
            Button(action: { viewModel.initiateUpload() }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.doc")
                        .font(.system(size: 10, weight: .semibold))
                    Text("files.upload".localized)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(ColorTokens.accentPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .buttonStyle(.plain)

            // Selection actions (only show when files selected)
            if !viewModel.selectedFiles.isEmpty {
                Divider()
                    .frame(height: 16)
                    .background(ColorTokens.borderSubtle)

                HStack(spacing: 2) {
                    ToolbarIconButton(icon: "arrow.down.doc", tooltip: "files.download".localized, isEnabled: true) {
                        viewModel.downloadSelectedFiles()
                    }

                    if let file = viewModel.selectedFile, file.isTextFile {
                        ToolbarIconButton(icon: "pencil", tooltip: "files.edit".localized, isEnabled: true) {
                            viewModel.initiateEdit(for: file)
                        }
                    }

                    ToolbarIconButton(icon: "info.circle", tooltip: "files.menu.info".localized, isEnabled: viewModel.selectedFiles.count == 1) {
                        if let file = viewModel.selectedFile {
                            Task { await viewModel.loadFileInfo(for: file) }
                        }
                    }

                    ToolbarIconButton(icon: "trash", tooltip: "files.delete".localized, isEnabled: true, isDestructive: true) {
                        viewModel.confirmAndDeleteSelectedFiles()
                    }
                }

                Text("\(viewModel.selectedFiles.count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(ColorTokens.accentPrimary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(ColorTokens.accentPrimary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            Spacer()

            // Search field (compact)
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundStyle(ColorTokens.textTertiary)

                TextField("files.search".localized, text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))

                if !viewModel.searchQuery.isEmpty {
                    Button(action: { viewModel.searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(width: 160)
            .background(ColorTokens.layer2)
            .clipShape(RoundedRectangle(cornerRadius: 5))

            // View mode picker (compact segmented)
            HStack(spacing: 0) {
                ForEach(FileViewMode.allCases, id: \.self) { mode in
                    Button(action: { viewModel.viewMode = mode }) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(viewModel.viewMode == mode ? ColorTokens.accentPrimary : ColorTokens.textTertiary)
                            .frame(width: 24, height: 22)
                            .background(viewModel.viewMode == mode ? ColorTokens.accentPrimary.opacity(0.15) : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(ColorTokens.layer2)
            .clipShape(RoundedRectangle(cornerRadius: 5))

            // Hidden files toggle
            ToolbarIconButton(
                icon: viewModel.showHiddenFiles ? "eye" : "eye.slash",
                tooltip: viewModel.showHiddenFiles ? "files.hideHidden".localized : "files.showHidden".localized,
                isEnabled: true,
                isActive: viewModel.showHiddenFiles
            ) {
                viewModel.showHiddenFiles.toggle()
                let message = viewModel.showHiddenFiles ? "files.hiddenShown".localized : "files.hiddenHidden".localized
                viewModel.showSuccess(message)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(ColorTokens.layer1.opacity(0.3))
    }
}

// MARK: - Breadcrumb View

struct BreadcrumbView: View {
    @ObservedObject var viewModel: FilesDetailViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(Array(viewModel.pathComponents.enumerated()), id: \.offset) { index, component in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(ColorTokens.textTertiary)
                    }

                    Button(action: {
                        viewModel.navigateTo(path: component.path)
                    }) {
                        Text(component.name)
                            .font(.system(size: 12, weight: index == viewModel.pathComponents.count - 1 ? .semibold : .regular))
                            .foregroundStyle(index == viewModel.pathComponents.count - 1 ? ColorTokens.textPrimary : ColorTokens.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(index == viewModel.pathComponents.count - 1 ? ColorTokens.layer2.opacity(0.8) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(ColorTokens.layer0)
    }
}

// MARK: - Column File Row


// MARK: - Toolbar Icon Button

private struct ToolbarIconButton: View {
    let icon: String
    var tooltip: String? = nil
    let isEnabled: Bool
    var isActive: Bool = false
    var isDestructive: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(foregroundColor)
                .frame(width: 24, height: 22)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { isHovered = $0 }
        .help(tooltip ?? "")
    }

    private var foregroundColor: Color {
        if !isEnabled {
            return ColorTokens.textDisabled
        }
        if isDestructive {
            return ColorTokens.error
        }
        if isActive {
            return ColorTokens.accentPrimary
        }
        return isHovered ? ColorTokens.textPrimary : ColorTokens.textSecondary
    }

    private var backgroundColor: Color {
        if !isEnabled {
            return Color.clear
        }
        if isActive {
            return ColorTokens.accentPrimary.opacity(0.15)
        }
        return isHovered ? Color.white.opacity(0.06) : Color.clear
    }
}
