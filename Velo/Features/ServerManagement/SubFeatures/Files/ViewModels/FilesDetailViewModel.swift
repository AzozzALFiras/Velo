//
//  FilesDetailViewModel.swift
//  Velo
//
//  Main ViewModel for the Files feature.
//  Logic is split into extensions in ViewModels/Files/ directory.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class FilesDetailViewModel: ObservableObject {

    // MARK: - Dependencies

    weak var session: TerminalViewModel?
    let fileService = FileService.shared

    // MARK: - Published State

    // Navigation
    @Published var currentPath: String = "/"
    @Published var pathHistory: [String] = ["/"]
    @Published var historyIndex: Int = 0
    @Published var selectedSection: FilesSection = .browser

    // File List
    @Published var files: [ServerFileItem] = []
    @Published var selectedFiles: Set<UUID> = []
    @Published var isLoading: Bool = false

    // Sorting & Filtering
    @Published var sortOption: FileSortOption = .name
    @Published var sortDirection: SortDirection = .ascending
    @Published var searchQuery: String = ""
    @Published var viewMode: FileViewMode = .list
    @Published var showHiddenFiles: Bool = false

    // Quick Access
    @Published var quickAccessLocations: [QuickAccessLocation] = QuickAccessLocation.defaultLocations
    @Published var favoriteLocations: [QuickAccessLocation] = []
    @Published var recentPaths: [String] = []

    // Transfers
    @Published var activeTransfers: [FileTransferTask] = []
    @Published var completedTransfers: [FileTransferTask] = []

    // Clipboard
    @Published var clipboard: FileClipboard?

    // Detail Panel
    @Published var showInfoPanel: Bool = false
    @Published var selectedFileInfo: ExtendedFileInfo?

    // Dialogs
    @Published var showCreateFolderDialog: Bool = false
    @Published var showCreateFileDialog: Bool = false
    @Published var showRenameDialog: Bool = false
    @Published var showPermissionsDialog: Bool = false
    @Published var showDeleteConfirmation: Bool = false
    @Published var showEditorDialog: Bool = false
    @Published var fileToRename: ServerFileItem?
    @Published var fileToModify: ServerFileItem?
    @Published var fileToEdit: ServerFileItem?
    @Published var filesToDelete: [ServerFileItem] = []

    // Messages
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var isPerformingAction: Bool = false

    // MARK: - Computed Properties

    var filteredAndSortedFiles: [ServerFileItem] {
        var result = files

        // Filter hidden files
        if !showHiddenFiles {
            result = result.filter { !$0.name.hasPrefix(".") }
        }

        // Filter by search query
        if !searchQuery.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchQuery)
            }
        }

        // Sort
        result.sort { file1, file2 in
            // Directories always first
            if file1.isDirectory != file2.isDirectory {
                return file1.isDirectory
            }

            let comparison: Bool
            switch sortOption {
            case .name:
                comparison = file1.name.localizedLowercase < file2.name.localizedLowercase
            case .size:
                comparison = file1.sizeBytes < file2.sizeBytes
            case .modified:
                comparison = file1.modificationDate < file2.modificationDate
            case .type:
                let ext1 = file1.name.components(separatedBy: ".").last ?? ""
                let ext2 = file2.name.components(separatedBy: ".").last ?? ""
                comparison = ext1.localizedLowercase < ext2.localizedLowercase
            }

            return sortDirection == .ascending ? comparison : !comparison
        }

        return result
    }

    var selectedFile: ServerFileItem? {
        guard selectedFiles.count == 1,
              let id = selectedFiles.first else { return nil }
        return files.first { $0.id == id }
    }

    var canNavigateBack: Bool {
        historyIndex > 0
    }

    var canNavigateForward: Bool {
        historyIndex < pathHistory.count - 1
    }

    var pathComponents: [(name: String, path: String)] {
        var components: [(name: String, path: String)] = []
        let parts = currentPath.components(separatedBy: "/").filter { !$0.isEmpty }

        components.append((name: "/", path: "/"))

        var currentBuiltPath = ""
        for part in parts {
            currentBuiltPath += "/" + part
            components.append((name: part, path: currentBuiltPath))
        }

        return components
    }

    var hasActiveTransfers: Bool {
        !activeTransfers.isEmpty
    }

    var transferProgress: Double {
        guard !activeTransfers.isEmpty else { return 0 }
        let total = activeTransfers.reduce(0.0) { $0 + $1.progress }
        return total / Double(activeTransfers.count)
    }

    // MARK: - Init

    init(session: TerminalViewModel? = nil) {
        self.session = session
    }

    // MARK: - Data Loading

    func loadData() async {
        await loadFiles()
    }

    func loadFiles() async {
        guard session != nil else { return }
        isLoading = true
        errorMessage = nil

        let result = await fileService.listFiles(at: currentPath, via: session!)

        switch result {
        case .success(let loadedFiles):
            self.files = loadedFiles
        case .failure(let error):
            // Try quick listing as fallback
            let quickResult = await fileService.listFilesQuick(at: currentPath, via: session!)
            switch quickResult {
            case .success(let loadedFiles):
                self.files = loadedFiles
            case .failure:
                self.errorMessage = error.localizedDescription
                self.files = []
            }
        }

        isLoading = false
    }

    func refresh() async {
        await loadFiles()
    }

    // MARK: - Navigation

    func navigateTo(path: String) {
        guard path != currentPath else { return }

        // Trim history if we're not at the end
        if historyIndex < pathHistory.count - 1 {
            pathHistory = Array(pathHistory.prefix(historyIndex + 1))
        }

        currentPath = path
        pathHistory.append(path)
        historyIndex = pathHistory.count - 1
        selectedFiles.removeAll()

        // Add to recent
        addToRecent(path)

        Task { await loadFiles() }
    }

    func navigateTo(file: ServerFileItem) {
        guard file.isDirectory else { return }
        navigateTo(path: file.path)
    }

    func navigateBack() {
        guard canNavigateBack else { return }
        historyIndex -= 1
        currentPath = pathHistory[historyIndex]
        selectedFiles.removeAll()
        Task { await loadFiles() }
    }

    func navigateForward() {
        guard canNavigateForward else { return }
        historyIndex += 1
        currentPath = pathHistory[historyIndex]
        selectedFiles.removeAll()
        Task { await loadFiles() }
    }

    func navigateUp() {
        let parentPath = (currentPath as NSString).deletingLastPathComponent
        if parentPath.isEmpty {
            navigateTo(path: "/")
        } else {
            navigateTo(path: parentPath)
        }
    }

    func jumpToPath(_ path: String) {
        navigateTo(path: path)
    }

    // MARK: - Selection

    func selectFile(_ file: ServerFileItem, exclusive: Bool = true) {
        if exclusive {
            selectedFiles = [file.id]
        } else {
            if selectedFiles.contains(file.id) {
                selectedFiles.remove(file.id)
            } else {
                selectedFiles.insert(file.id)
            }
        }
    }

    func selectAll() {
        selectedFiles = Set(filteredAndSortedFiles.map { $0.id })
    }

    func deselectAll() {
        selectedFiles.removeAll()
    }

    func toggleSelection(_ file: ServerFileItem) {
        selectFile(file, exclusive: false)
    }

    // MARK: - Editor

    func initiateEdit(for file: ServerFileItem) {
        guard file.isEditable else { return }
        fileToEdit = file
        showEditorDialog = true
    }

    // MARK: - Recent & Favorites

    private func addToRecent(_ path: String) {
        recentPaths.removeAll { $0 == path }
        recentPaths.insert(path, at: 0)
        if recentPaths.count > 20 {
            recentPaths = Array(recentPaths.prefix(20))
        }
    }

    func addToFavorites(path: String, name: String) {
        guard !favoriteLocations.contains(where: { $0.path == path }) else { return }
        let location = QuickAccessLocation(name: name, path: path, icon: "star.fill")
        favoriteLocations.append(location)
    }

    func removeFromFavorites(_ location: QuickAccessLocation) {
        favoriteLocations.removeAll { $0.id == location.id }
    }

    // MARK: - Messages

    func showSuccess(_ message: String) {
        successMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            self?.successMessage = nil
        }
    }

    func showError(_ message: String) {
        errorMessage = message
    }

    func clearError() {
        errorMessage = nil
    }

    func clearSuccess() {
        successMessage = nil
    }
}
