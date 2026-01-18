//
//  FileRowView.swift
//  Velo
//
//  Individual file row component for the file browser.
//

import SwiftUI

struct FileRowView: View {
    let file: ServerFileItem
    let isSelected: Bool
    @ObservedObject var viewModel: FilesDetailViewModel

    @State private var isHovered: Bool = false

    private var fileType: FileTypeCategory {
        FileTypeCategory.from(fileName: file.name, isDirectory: file.isDirectory)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Selection checkbox
            checkboxColumn

            // Name with icon
            nameColumn
                .frame(maxWidth: .infinity, alignment: .leading)

            // Size
            Text(file.sizeString)
                .font(.system(size: 11))
                .foregroundStyle(ColorTokens.textSecondary)
                .frame(width: 60, alignment: .trailing)

            // Permissions
            permissionsColumn
                .frame(width: 50, alignment: .leading)
                .padding(.leading, 8)

            // Owner
            Text(file.owner)
                .font(.system(size: 11))
                .foregroundStyle(ColorTokens.textSecondary)
                .lineLimit(1)
                .frame(width: 50, alignment: .leading)

            // Modified date
            Text(file.shortDateString)
                .font(.system(size: 11))
                .foregroundStyle(ColorTokens.textTertiary)
                .frame(width: 60, alignment: .leading)

            // Actions
            actionsColumn
                .frame(width: 40)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(rowBackground)
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.selectFile(file)
        }
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded {
                    if file.isDirectory {
                        viewModel.navigateTo(file: file)
                    } else if file.isEditable {
                        viewModel.initiateEdit(for: file)
                    } else {
                        Task { await viewModel.loadFileInfo(for: file) }
                    }
                }
        )
        .contextMenu {
            contextMenuContent
        }
    }

    // MARK: - Columns
    
    private var checkboxColumn: some View {
        Button(action: {
            viewModel.toggleSelection(file)
        }) {
            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                .font(.system(size: 12))
                .foregroundStyle(isSelected ? ColorTokens.accentPrimary : ColorTokens.textTertiary)
        }
        .buttonStyle(.plain)
        .frame(width: 36)
        .opacity(isHovered || isSelected ? 1 : 0)
    }

    private var nameColumn: some View {
        HStack(spacing: 8) {
            // File icon
            Image(systemName: fileType.icon)
                .font(.system(size: 14))
                .foregroundStyle(Color(hex: fileType.color))
                .frame(width: 18)

            // File name
            Text(file.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ColorTokens.textPrimary)
                .lineLimit(1)

            // Editable indicator
            if file.isEditable && isHovered {
                Image(systemName: "pencil")
                    .font(.system(size: 9))
                    .foregroundStyle(ColorTokens.textTertiary)
            }

            // Directory indicator
            if file.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(ColorTokens.textTertiary)
            }
        }
    }

    private var permissionsColumn: some View {
        Text(file.permissions)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(ColorTokens.accentPrimary)
    }

    private var actionsColumn: some View {
        Group {
            if isHovered {
                Menu {
                    contextMenuContent
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.textSecondary)
                        .frame(width: 24, height: 22)
                        .background(ColorTokens.layer2)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .menuStyle(.borderlessButton)
            }
        }
    }

    // MARK: - Background

    private var rowBackground: Color {
        if isSelected {
            return ColorTokens.accentPrimary.opacity(0.12)
        }
        if isHovered {
            return Color.white.opacity(0.02)
        }
        return Color.clear
    }

    // MARK: - Context Menu

    @ViewBuilder
    private var contextMenuContent: some View {
        if file.isDirectory {
            Button(action: { viewModel.navigateTo(file: file) }) {
                Label("files.menu.open".localized, systemImage: "folder")
            }
        } else {
            Button(action: { viewModel.initiateDownload(for: file) }) {
                Label("files.menu.download".localized, systemImage: "arrow.down.circle")
            }

            if file.isEditable {
                Button(action: { viewModel.initiateEdit(for: file) }) {
                    Label("files.menu.edit".localized, systemImage: "pencil")
                }
            }
        }

        Divider()

        Button(action: {
            Task { await viewModel.loadFileInfo(for: file) }
        }) {
            Label("files.menu.info".localized, systemImage: "info.circle")
        }

        Divider()

        Button(action: { viewModel.initiateRename(for: file) }) {
            Label("files.menu.rename".localized, systemImage: "pencil")
        }

        Button(action: { viewModel.initiatePermissionsEdit(for: file) }) {
            Label("files.menu.permissions".localized, systemImage: "lock.shield")
        }

        Divider()

        // Clipboard actions
        Button(action: {
            viewModel.selectFile(file)
            viewModel.copyToClipboard()
        }) {
            Label("files.menu.copy".localized, systemImage: "doc.on.doc")
        }

        Button(action: {
            viewModel.selectFile(file)
            viewModel.cutToClipboard()
        }) {
            Label("files.menu.cut".localized, systemImage: "scissors")
        }

        if viewModel.clipboard != nil && !viewModel.clipboard!.isEmpty && file.isDirectory {
            Button(action: {
                Task { await viewModel.pasteFromClipboard() }
            }) {
                Label("files.menu.paste".localized, systemImage: "doc.on.clipboard")
            }
        }

        Divider()

        // Copy path
        Button(action: {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(file.path, forType: .string)
            viewModel.showSuccess("files.success.pathCopied".localized)
        }) {
            Label("files.menu.copyPath".localized, systemImage: "link")
        }

        Divider()

        Button(role: .destructive, action: {
            viewModel.filesToDelete = [file]
            viewModel.showDeleteConfirmation = true
        }) {
            Label("files.menu.delete".localized, systemImage: "trash")
        }
    }
}

// MARK: - File Grid Item (for Grid View)

struct FileGridItemView: View {
    let file: ServerFileItem
    let isSelected: Bool
    @ObservedObject var viewModel: FilesDetailViewModel

    @State private var isHovered: Bool = false

    private var fileType: FileTypeCategory {
        FileTypeCategory.from(fileName: file.name, isDirectory: file.isDirectory)
    }

    var body: some View {
        VStack(spacing: 6) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: fileType.color).opacity(0.1))
                    .frame(width: 56, height: 56)

                Image(systemName: fileType.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(Color(hex: fileType.color))
            }

            // Name
            Text(file.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ColorTokens.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(height: 28)

            // Size
            Text(file.sizeString)
                .font(.system(size: 9))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .frame(width: 90, height: 110)
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? ColorTokens.accentPrimary.opacity(0.12) : (isHovered ? Color.white.opacity(0.04) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? ColorTokens.accentPrimary.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
        .onHover { isHovered = $0 }
        .onTapGesture {
            viewModel.selectFile(file)
        }
        .simultaneousGesture(
            TapGesture(count: 2)
                .onEnded {
                    if file.isDirectory {
                        viewModel.navigateTo(file: file)
                    } else if file.isEditable {
                        viewModel.initiateEdit(for: file)
                    }
                }
        )
        .contextMenu {
            if file.isDirectory {
                Button(action: { viewModel.navigateTo(file: file) }) {
                    Label("files.menu.open".localized, systemImage: "folder")
                }
            } else {
                Button(action: { viewModel.initiateDownload(for: file) }) {
                    Label("files.menu.download".localized, systemImage: "arrow.down.circle")
                }

                if file.isEditable {
                    Button(action: { viewModel.initiateEdit(for: file) }) {
                        Label("files.menu.edit".localized, systemImage: "pencil")
                    }
                }
            }

            Divider()

            Button(action: { viewModel.initiateRename(for: file) }) {
                Label("files.menu.rename".localized, systemImage: "pencil")
            }

            Button(role: .destructive, action: {
                viewModel.filesToDelete = [file]
                viewModel.showDeleteConfirmation = true
            }) {
                Label("files.menu.delete".localized, systemImage: "trash")
            }
        }
    }
}

// MARK: - File Column Row (for Column View)

struct FileColumnRowView: View {
    let file: ServerFileItem
    let isSelected: Bool
    @ObservedObject var viewModel: FilesDetailViewModel

    @State private var isHovered: Bool = false

    private var fileType: FileTypeCategory {
        FileTypeCategory.from(fileName: file.name, isDirectory: file.isDirectory)
    }

    var body: some View {
        HStack(spacing: 8) {
            // Icon
            Image(systemName: fileType.icon)
                .font(.system(size: 14))
                .foregroundStyle(isSelected ? Color.white : Color(hex: fileType.color))
                .frame(width: 18)

            // Name
            Text(file.name)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.white : ColorTokens.textPrimary)
                .lineLimit(1)

            Spacer()

            // Chevron for directories
            if file.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.8) : ColorTokens.textTertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? ColorTokens.accentPrimary : (isHovered ? Color.white.opacity(0.04) : Color.clear))
        )
        .onHover { isHovered = $0 }
        .onTapGesture {
            viewModel.selectFile(file)
            if file.isDirectory {
                viewModel.navigateTo(file: file)
            }
        }
    }
}
