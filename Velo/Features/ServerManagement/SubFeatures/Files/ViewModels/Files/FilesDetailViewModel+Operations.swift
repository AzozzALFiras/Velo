//
//  FilesDetailViewModel+Operations.swift
//  Velo
//
//  File operation methods for FilesDetailViewModel.
//

import Foundation

extension FilesDetailViewModel {

    // MARK: - Create Operations

    func createFolder(name: String) async -> Bool {
        guard let session = session else { return false }

        isPerformingAction = true
        let result = await fileService.createDirectory(at: currentPath, name: name, via: session)
        isPerformingAction = false

        switch result {
        case .success:
            showSuccess("files.success.folderCreated".localized(name))
            await loadFiles()
            return true
        case .failure(let error):
            showError(error.localizedDescription)
            return false
        }
    }

    func createFile(name: String) async -> Bool {
        guard let session = session else { return false }

        isPerformingAction = true
        let result = await fileService.createFile(at: currentPath, name: name, via: session)
        isPerformingAction = false

        switch result {
        case .success:
            showSuccess("files.success.fileCreated".localized(name))
            await loadFiles()
            return true
        case .failure(let error):
            showError(error.localizedDescription)
            return false
        }
    }

    // MARK: - Delete Operations

    func deleteFile(_ file: ServerFileItem) async -> Bool {
        guard let session = session else { return false }

        isPerformingAction = true
        let result = await fileService.delete(file: file, via: session)
        isPerformingAction = false

        switch result {
        case .success:
            showSuccess("files.success.deleted".localized(file.name))
            selectedFiles.remove(file.id)
            await loadFiles()
            return true
        case .failure(let error):
            showError(error.localizedDescription)
            return false
        }
    }

    func deleteSelectedFiles() async -> Bool {
        let filesToDel = files.filter { selectedFiles.contains($0.id) }
        guard !filesToDel.isEmpty else { return false }

        var allSuccess = true
        for file in filesToDel {
            let success = await deleteFile(file)
            if !success { allSuccess = false }
        }

        return allSuccess
    }

    func confirmAndDeleteSelectedFiles() {
        filesToDelete = files.filter { selectedFiles.contains($0.id) }
        if !filesToDelete.isEmpty {
            showDeleteConfirmation = true
        }
    }

    // MARK: - Rename Operations

    func renameFile(_ file: ServerFileItem, to newName: String) async -> Bool {
        guard let session = session else { return false }
        guard !newName.isEmpty, newName != file.name else { return false }

        isPerformingAction = true
        let result = await fileService.rename(file: file, to: newName, via: session)
        isPerformingAction = false

        switch result {
        case .success:
            showSuccess("files.success.renamed".localized(file.name, newName))
            await loadFiles()
            return true
        case .failure(let error):
            showError(error.localizedDescription)
            return false
        }
    }

    func initiateRename(for file: ServerFileItem) {
        fileToRename = file
        showRenameDialog = true
    }

    // MARK: - Permission Operations

    func updatePermissions(_ file: ServerFileItem, permissions: String, recursive: Bool = false) async -> Bool {
        guard let session = session else { return false }

        isPerformingAction = true
        let result = await fileService.changePermissions(file: file, permissions: permissions, recursive: recursive, via: session)
        isPerformingAction = false

        switch result {
        case .success:
            showSuccess("files.success.permissionsUpdated".localized(file.name))
            await loadFiles()
            return true
        case .failure(let error):
            showError(error.localizedDescription)
            return false
        }
    }

    func updateOwner(_ file: ServerFileItem, owner: String, group: String?, recursive: Bool = false) async -> Bool {
        guard let session = session else { return false }

        isPerformingAction = true
        let result = await fileService.changeOwner(file: file, owner: owner, group: group, recursive: recursive, via: session)
        isPerformingAction = false

        switch result {
        case .success:
            showSuccess("files.success.ownerUpdated".localized(file.name))
            await loadFiles()
            return true
        case .failure(let error):
            showError(error.localizedDescription)
            return false
        }
    }

    func initiatePermissionsEdit(for file: ServerFileItem) {
        fileToModify = file
        showPermissionsDialog = true
    }

    // MARK: - Copy/Move Operations

    func copyFile(_ file: ServerFileItem, to destination: String) async -> Bool {
        guard let session = session else { return false }

        isPerformingAction = true
        let result = await fileService.copy(file: file, to: destination, via: session)
        isPerformingAction = false

        switch result {
        case .success:
            showSuccess("files.success.copied".localized(file.name))
            await loadFiles()
            return true
        case .failure(let error):
            showError(error.localizedDescription)
            return false
        }
    }

    func moveFile(_ file: ServerFileItem, to destination: String) async -> Bool {
        guard let session = session else { return false }

        isPerformingAction = true
        let result = await fileService.move(file: file, to: destination, via: session)
        isPerformingAction = false

        switch result {
        case .success:
            showSuccess("files.success.moved".localized(file.name))
            selectedFiles.remove(file.id)
            await loadFiles()
            return true
        case .failure(let error):
            showError(error.localizedDescription)
            return false
        }
    }

    // MARK: - Clipboard Operations

    func copyToClipboard() {
        let selectedItems = files.filter { selectedFiles.contains($0.id) }
        guard !selectedItems.isEmpty else { return }
        clipboard = FileClipboard(files: selectedItems, operation: .copy, sourcePath: currentPath)
        showSuccess("files.clipboard.copied".localized(selectedItems.count))
    }

    func cutToClipboard() {
        let selectedItems = files.filter { selectedFiles.contains($0.id) }
        guard !selectedItems.isEmpty else { return }
        clipboard = FileClipboard(files: selectedItems, operation: .cut, sourcePath: currentPath)
        showSuccess("files.clipboard.cut".localized(selectedItems.count))
    }

    func pasteFromClipboard() async {
        guard let clipboard = clipboard, !clipboard.isEmpty else { return }

        for file in clipboard.files {
            let destination = (currentPath as NSString).appendingPathComponent(file.name)

            switch clipboard.operation {
            case .copy:
                _ = await copyFile(file, to: destination)
            case .cut:
                _ = await moveFile(file, to: destination)
            }
        }

        // Clear clipboard after cut operation
        if clipboard.operation == .cut {
            self.clipboard = nil
        }
    }

    // MARK: - Info Panel

    func loadFileInfo(for file: ServerFileItem) async {
        guard let session = session else { return }

        let result = await fileService.getFileInfo(at: file.path, via: session)

        switch result {
        case .success(let info):
            selectedFileInfo = info
            showInfoPanel = true
        case .failure(let error):
            showError(error.localizedDescription)
        }
    }

    func getDirectorySize(for file: ServerFileItem) async -> Int64? {
        guard let session = session, file.isDirectory else { return nil }

        let result = await fileService.getDirectorySize(at: file.path, via: session)

        switch result {
        case .success(let size):
            return size
        case .failure:
            return nil
        }
    }
}
