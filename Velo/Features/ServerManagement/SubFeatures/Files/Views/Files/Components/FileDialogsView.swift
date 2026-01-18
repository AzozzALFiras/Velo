//
//  FileDialogsView.swift
//  Velo
//
//  Dialog components for file operations: create, rename, permissions, delete.
//

import SwiftUI

// MARK: - Create Folder Dialog

struct CreateFolderDialog: View {
    @ObservedObject var viewModel: FilesDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var folderName: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 20))
                    .foregroundStyle(ColorTokens.accentPrimary)

                Text("files.createFolder.title".localized)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(ColorTokens.textPrimary)
            }

            // Location info
            VStack(alignment: .leading, spacing: 4) {
                Text("files.createFolder.location".localized)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ColorTokens.textTertiary)

                Text(viewModel.currentPath)
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            // Name input
            VStack(alignment: .leading, spacing: 8) {
                Text("files.createFolder.name".localized)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ColorTokens.textTertiary)

                TextField("files.createFolder.placeholder".localized, text: $folderName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .padding(10)
                    .background(ColorTokens.layer2)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(ColorTokens.border, lineWidth: 1)
                    )
                    .focused($isFocused)
            }

            // Actions
            HStack {
                Spacer()

                Button("common.cancel".localized) {
                    dismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ColorTokens.textSecondary)

                Button("common.create".localized) {
                    Task {
                        let success = await viewModel.createFolder(name: folderName)
                        if success { dismiss() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(ColorTokens.accentPrimary)
                .disabled(folderName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 380)
        .background(ColorTokens.layer1)
        .onAppear { isFocused = true }
    }
}

// MARK: - Create File Dialog

struct CreateFileDialog: View {
    @ObservedObject var viewModel: FilesDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var fileName: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 20))
                    .foregroundStyle(ColorTokens.accentPrimary)

                Text("files.createFile.title".localized)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(ColorTokens.textPrimary)
            }

            // Location info
            VStack(alignment: .leading, spacing: 4) {
                Text("files.createFile.location".localized)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ColorTokens.textTertiary)

                Text(viewModel.currentPath)
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            // Name input
            VStack(alignment: .leading, spacing: 8) {
                Text("files.createFile.name".localized)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ColorTokens.textTertiary)

                TextField("files.createFile.placeholder".localized, text: $fileName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .padding(10)
                    .background(ColorTokens.layer2)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(ColorTokens.border, lineWidth: 1)
                    )
                    .focused($isFocused)
            }

            // Actions
            HStack {
                Spacer()

                Button("common.cancel".localized) {
                    dismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ColorTokens.textSecondary)

                Button("common.create".localized) {
                    Task {
                        let success = await viewModel.createFile(name: fileName)
                        if success { dismiss() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(ColorTokens.accentPrimary)
                .disabled(fileName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 380)
        .background(ColorTokens.layer1)
        .onAppear { isFocused = true }
    }
}

// MARK: - Rename Dialog

struct RenameDialog: View {
    let file: ServerFileItem
    @ObservedObject var viewModel: FilesDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var newName: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: "pencil")
                    .font(.system(size: 20))
                    .foregroundStyle(ColorTokens.accentPrimary)

                Text("files.rename.title".localized)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(ColorTokens.textPrimary)
            }

            // Current name
            VStack(alignment: .leading, spacing: 8) {
                Text("files.rename.current".localized)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ColorTokens.textTertiary)

                HStack(spacing: 8) {
                    Image(systemName: file.isDirectory ? "folder.fill" : "doc.fill")
                        .foregroundStyle(ColorTokens.accentPrimary)

                    Text(file.name)
                        .font(.system(size: 13))
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ColorTokens.layer2.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // New name input
            VStack(alignment: .leading, spacing: 8) {
                Text("files.rename.new".localized)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ColorTokens.textTertiary)

                TextField("files.rename.placeholder".localized, text: $newName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .padding(10)
                    .background(ColorTokens.layer2)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(ColorTokens.border, lineWidth: 1)
                    )
                    .focused($isFocused)
            }

            // Actions
            HStack {
                Spacer()

                Button("common.cancel".localized) {
                    dismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ColorTokens.textSecondary)

                Button("files.rename.action".localized) {
                    Task {
                        let success = await viewModel.renameFile(file, to: newName)
                        if success { dismiss() }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(ColorTokens.accentPrimary)
                .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty || newName == file.name)
            }
        }
        .padding(24)
        .frame(width: 400)
        .background(ColorTokens.layer1)
        .onAppear {
            newName = file.name
            isFocused = true
        }
    }
}

// MARK: - Permissions Dialog

struct PermissionsDialog: View {
    let file: ServerFileItem
    @ObservedObject var viewModel: FilesDetailViewModel
    @Environment(\.dismiss) private var dismiss

    // Permission states
    @State private var ownerRead: Bool = false
    @State private var ownerWrite: Bool = false
    @State private var ownerExecute: Bool = false
    @State private var groupRead: Bool = false
    @State private var groupWrite: Bool = false
    @State private var groupExecute: Bool = false
    @State private var otherRead: Bool = false
    @State private var otherWrite: Bool = false
    @State private var otherExecute: Bool = false

    @State private var octalString: String = ""
    @State private var owner: String = ""
    @State private var group: String = ""
    @State private var recursive: Bool = false

    private let commonOwners = ["root", "www-data", "nginx", "apache", "admin", "nobody"]
    private let commonGroups = ["root", "www-data", "nginx", "apache", "adm", "nogroup"]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: "lock.shield")
                    .font(.system(size: 20))
                    .foregroundStyle(ColorTokens.accentPrimary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("files.permissions.title".localized)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(ColorTokens.textPrimary)

                    Text(file.name)
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }

            // Permission grid
            HStack(alignment: .top, spacing: 16) {
                permissionBox("files.permissions.owner".localized, read: $ownerRead, write: $ownerWrite, execute: $ownerExecute)
                permissionBox("files.permissions.group".localized, read: $groupRead, write: $groupWrite, execute: $groupExecute)
                permissionBox("files.permissions.other".localized, read: $otherRead, write: $otherWrite, execute: $otherExecute)
            }

            // Octal and ownership row
            HStack(spacing: 16) {
                // Octal input
                VStack(alignment: .leading, spacing: 4) {
                    Text("files.permissions.octal".localized)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ColorTokens.textTertiary)

                    TextField("644", text: $octalString)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .frame(width: 60)
                        .padding(8)
                        .background(ColorTokens.layer2)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .onChange(of: octalString) { _, newValue in
                            updateChecksFromOctal(newValue)
                        }
                }

                // Owner picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("files.permissions.ownerLabel".localized)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ColorTokens.textTertiary)

                    Menu {
                        ForEach(commonOwners, id: \.self) { o in
                            Button(o) { owner = o }
                        }
                    } label: {
                        HStack {
                            Text(owner)
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9))
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                        .padding(8)
                        .frame(width: 100)
                        .background(ColorTokens.layer2)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .menuStyle(.borderlessButton)
                }

                // Group picker
                VStack(alignment: .leading, spacing: 4) {
                    Text("files.permissions.groupLabel".localized)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(ColorTokens.textTertiary)

                    Menu {
                        ForEach(commonGroups, id: \.self) { g in
                            Button(g) { group = g }
                        }
                    } label: {
                        HStack {
                            Text(group)
                                .font(.system(size: 12, weight: .medium))
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 9))
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                        .padding(8)
                        .frame(width: 100)
                        .background(ColorTokens.layer2)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .menuStyle(.borderlessButton)
                }

                Spacer()

                // Recursive toggle (for directories)
                if file.isDirectory {
                    Toggle(isOn: $recursive) {
                        Text("files.permissions.recursive".localized)
                            .font(.system(size: 12))
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    .toggleStyle(.checkbox)
                }
            }

            // Actions
            HStack {
                Spacer()

                Button("common.cancel".localized) {
                    dismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ColorTokens.textSecondary)

                Button("common.save".localized) {
                    Task {
                        // Update permissions
                        _ = await viewModel.updatePermissions(file, permissions: octalString, recursive: recursive)

                        // Update owner if changed
                        if owner != file.owner {
                            _ = await viewModel.updateOwner(file, owner: owner, group: group, recursive: recursive)
                        }

                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(ColorTokens.accentPrimary)
            }
        }
        .padding(24)
        .frame(width: 520)
        .background(ColorTokens.layer1)
        .onAppear {
            initializeFromFile()
        }
        .onChange(of: ownerRead) { updateOctalFromChecks() }
        .onChange(of: ownerWrite) { updateOctalFromChecks() }
        .onChange(of: ownerExecute) { updateOctalFromChecks() }
        .onChange(of: groupRead) { updateOctalFromChecks() }
        .onChange(of: groupWrite) { updateOctalFromChecks() }
        .onChange(of: groupExecute) { updateOctalFromChecks() }
        .onChange(of: otherRead) { updateOctalFromChecks() }
        .onChange(of: otherWrite) { updateOctalFromChecks() }
        .onChange(of: otherExecute) { updateOctalFromChecks() }
    }

    private func permissionBox(_ title: String, read: Binding<Bool>, write: Binding<Bool>, execute: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(ColorTokens.textPrimary)

            VStack(alignment: .leading, spacing: 6) {
                Toggle("files.permissions.read".localized, isOn: read)
                Toggle("files.permissions.write".localized, isOn: write)
                Toggle("files.permissions.execute".localized, isOn: execute)
            }
            .toggleStyle(.checkbox)
            .font(.system(size: 12))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ColorTokens.layer2.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(ColorTokens.border, lineWidth: 1)
        )
    }

    private func initializeFromFile() {
        let perms = file.numericPermissions

        let o = perms / 100
        let g = (perms / 10) % 10
        let u = perms % 10

        ownerRead = (o & 4) != 0
        ownerWrite = (o & 2) != 0
        ownerExecute = (o & 1) != 0

        groupRead = (g & 4) != 0
        groupWrite = (g & 2) != 0
        groupExecute = (g & 1) != 0

        otherRead = (u & 4) != 0
        otherWrite = (u & 2) != 0
        otherExecute = (u & 1) != 0

        octalString = file.permissions
        owner = file.owner
        group = file.owner // Default to same as owner
    }

    private func updateOctalFromChecks() {
        let o = (ownerRead ? 4 : 0) + (ownerWrite ? 2 : 0) + (ownerExecute ? 1 : 0)
        let g = (groupRead ? 4 : 0) + (groupWrite ? 2 : 0) + (groupExecute ? 1 : 0)
        let u = (otherRead ? 4 : 0) + (otherWrite ? 2 : 0) + (otherExecute ? 1 : 0)
        let newOctal = "\(o)\(g)\(u)"
        if octalString != newOctal {
            octalString = newOctal
        }
    }

    private func updateChecksFromOctal(_ val: String) {
        guard let perms = Int(val), val.count == 3 else { return }

        let o = perms / 100
        let g = (perms / 10) % 10
        let u = perms % 10

        let nr = (o & 4) != 0
        let nw = (o & 2) != 0
        let nx = (o & 1) != 0
        if ownerRead != nr { ownerRead = nr }
        if ownerWrite != nw { ownerWrite = nw }
        if ownerExecute != nx { ownerExecute = nx }

        let gr = (g & 4) != 0
        let gw = (g & 2) != 0
        let gx = (g & 1) != 0
        if groupRead != gr { groupRead = gr }
        if groupWrite != gw { groupWrite = gw }
        if groupExecute != gx { groupExecute = gx }

        let pr = (u & 4) != 0
        let pw = (u & 2) != 0
        let px = (u & 1) != 0
        if otherRead != pr { otherRead = pr }
        if otherWrite != pw { otherWrite = pw }
        if otherExecute != px { otherExecute = px }
    }
}

// MARK: - Delete Confirmation Dialog

struct DeleteConfirmationDialog: View {
    let files: [ServerFileItem]
    @ObservedObject var viewModel: FilesDetailViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: "trash.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(ColorTokens.error)

                Text("files.delete.title".localized)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(ColorTokens.textPrimary)
            }

            // Warning message
            if files.count == 1, let file = files.first {
                if file.isDirectory {
                    Text("files.delete.confirm_folder".localized(file.name))
                        .font(.system(size: 13))
                        .foregroundStyle(ColorTokens.textSecondary)
                } else {
                    Text("files.delete.confirm_file".localized(file.name))
                        .font(.system(size: 13))
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            } else {
                Text("files.delete.confirm_multiple".localized(files.count))
                    .font(.system(size: 13))
                    .foregroundStyle(ColorTokens.textSecondary)
            }

            // File list preview
            if files.count <= 5 {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(files) { file in
                        HStack(spacing: 8) {
                            Image(systemName: file.isDirectory ? "folder.fill" : "doc.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(ColorTokens.textTertiary)

                            Text(file.name)
                                .font(.system(size: 12))
                                .foregroundStyle(ColorTokens.textSecondary)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ColorTokens.layer2.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Warning banner
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(ColorTokens.warning)

                Text("files.delete.warning".localized)
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ColorTokens.warning.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Actions
            HStack {
                Spacer()

                Button("common.cancel".localized) {
                    dismiss()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ColorTokens.textSecondary)

                Button("files.delete.action".localized) {
                    Task {
                        for file in files {
                            _ = await viewModel.deleteFile(file)
                        }
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(ColorTokens.error)
            }
        }
        .padding(24)
        .frame(width: 420)
        .background(ColorTokens.layer1)
    }
}

// MARK: - File Info Panel

struct FileInfoPanel: View {
    let info: ExtendedFileInfo
    @ObservedObject var viewModel: FilesDetailViewModel

    @State private var calculatedSize: Int64?
    @State private var isCalculatingSize: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("files.info.title".localized)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(ColorTokens.textPrimary)

                Spacer()

                Button(action: { viewModel.showInfoPanel = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(ColorTokens.layer2.opacity(0.5))

            Divider()
                .background(ColorTokens.borderSubtle)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Icon and name
                    VStack(spacing: 12) {
                        Image(systemName: info.fileType.icon)
                            .font(.system(size: 40))
                            .foregroundStyle(Color(hex: info.fileType.color))

                        Text(info.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(ColorTokens.textPrimary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)

                    Divider()
                        .background(ColorTokens.borderSubtle)

                    // Details
                    VStack(alignment: .leading, spacing: 12) {
                        infoRow("files.info.type".localized, value: info.isDirectory ? "Folder" : (info.mimeType ?? "File"))

                        infoRow("files.info.size".localized, value: info.isDirectory ? (calculatedSize.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "--") : info.sizeString)

                        if info.isDirectory && calculatedSize == nil {
                            Button("files.info.calculateSize".localized) {
                                Task {
                                    isCalculatingSize = true
                                    if let file = viewModel.files.first(where: { $0.path == info.path }) {
                                        calculatedSize = await viewModel.getDirectorySize(for: file)
                                    }
                                    isCalculatingSize = false
                                }
                            }
                            .font(.system(size: 11))
                            .foregroundStyle(ColorTokens.accentPrimary)
                            .disabled(isCalculatingSize)
                        }

                        infoRow("files.info.path".localized, value: info.path)

                        Divider()
                            .background(ColorTokens.borderSubtle)

                        infoRow("files.info.permissions".localized, value: "\(info.permissions) (\(info.symbolicPermissions))")
                        infoRow("files.info.owner".localized, value: "\(info.owner):\(info.group)")

                        Divider()
                            .background(ColorTokens.borderSubtle)

                        infoRow("files.info.modified".localized, value: formatDate(info.modificationDate))

                        if let accessDate = info.accessDate {
                            infoRow("files.info.accessed".localized, value: formatDate(accessDate))
                        }

                        if info.isSymlink, let target = info.symlinkTarget {
                            Divider()
                                .background(ColorTokens.borderSubtle)
                            infoRow("files.info.linkTarget".localized, value: target)
                        }
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 280)
        .background(ColorTokens.layer1)
    }

    private func infoRow(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(ColorTokens.textTertiary)

            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.textSecondary)
                .textSelection(.enabled)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - File Info Sheet

struct FileInfoSheet: View {
    let info: ExtendedFileInfo
    @ObservedObject var viewModel: FilesDetailViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var calculatedSize: Int64?
    @State private var isCalculatingSize: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            HStack {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(ColorTokens.accentPrimary)

                Text("files.info.title".localized)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(ColorTokens.textPrimary)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
                .buttonStyle(.plain)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Icon and name card
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(hex: info.fileType.color).opacity(0.1))
                                .frame(width: 64, height: 64)

                            Image(systemName: info.fileType.icon)
                                .font(.system(size: 32))
                                .foregroundStyle(Color(hex: info.fileType.color))
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(info.name)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(ColorTokens.textPrimary)
                                .lineLimit(2)

                            Text(info.isDirectory ? "Folder" : (info.mimeType ?? "File"))
                                .font(.system(size: 13))
                                .foregroundStyle(ColorTokens.textTertiary)
                        }
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ColorTokens.layer2.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Detailed Grid
                    VStack(alignment: .leading, spacing: 16) {
                        infoBlock("files.info.size".localized, value: info.isDirectory ? (calculatedSize.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "--") : info.sizeString) {
                            if info.isDirectory && calculatedSize == nil {
                                Button("files.info.calculateSize".localized) {
                                    Task {
                                        isCalculatingSize = true
                                        if let file = viewModel.files.first(where: { $0.path == info.path }) {
                                            calculatedSize = await viewModel.getDirectorySize(for: file)
                                        }
                                        isCalculatingSize = false
                                    }
                                }
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(ColorTokens.accentPrimary)
                                .disabled(isCalculatingSize)
                            }
                        }

                        infoBlock("files.info.path".localized, value: info.path)

                        HStack(spacing: 16) {
                            infoBlock("files.info.permissions".localized, value: "\(info.permissions) (\(info.symbolicPermissions))")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            infoBlock("files.info.owner".localized, value: "\(info.owner):\(info.group)")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Divider()
                            .background(ColorTokens.borderSubtle)

                        HStack(spacing: 16) {
                            infoBlock("files.info.modified".localized, value: formatDate(info.modificationDate))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if let accessDate = info.accessDate {
                                infoBlock("files.info.accessed".localized, value: formatDate(accessDate))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        if info.isSymlink, let target = info.symlinkTarget {
                            infoBlock("files.info.linkTarget".localized, value: target)
                        }
                    }
                }
            }
        }
        .padding(24)
        .frame(width: 450, height: 500)
        .background(ColorTokens.layer1)
    }

    private func infoBlock(_ label: String, value: String, @ViewBuilder extra: () -> some View = { EmptyView() }) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(ColorTokens.textTertiary)
                
                Spacer()
                
                extra()
            }

            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(ColorTokens.textSecondary)
                .textSelection(.enabled)
                .lineLimit(2)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
