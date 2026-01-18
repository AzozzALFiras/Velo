//
//  FilesViewModel.swift
//  Velo
//
//  Legacy ViewModel wrapper for backward compatibility.
//  New implementation is in FilesDetailViewModel.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class FilesViewModel: ObservableObject {

    // MARK: - Dependencies
    weak var session: TerminalViewModel?
    private let fileService = FileService.shared

    // MARK: - Published State
    @Published var files: [ServerFileItem] = []
    @Published var currentPath: String = "/"
    @Published var pathStack: [String] = ["/"]
    @Published var activeUploads: [FileUploadTask] = []
    @Published var isLoading = false
    @Published var error: String?

    // MARK: - Init

    init(session: TerminalViewModel? = nil) {
        self.session = session
    }

    // MARK: - File Operations

    func loadFiles() async {
        guard let session = session else { return }
        isLoading = true

        let result = await fileService.listFiles(at: currentPath, via: session)

        switch result {
        case .success(let loadedFiles):
            self.files = loadedFiles
        case .failure(let error):
            // Fallback to quick listing
            let quickResult = await fileService.listFilesQuick(at: currentPath, via: session)
            switch quickResult {
            case .success(let loadedFiles):
                self.files = loadedFiles
            case .failure:
                self.error = error.localizedDescription
                self.files = []
            }
        }

        isLoading = false
    }

    func navigateTo(folder: ServerFileItem) {
        guard folder.isDirectory else { return }
        currentPath = folder.path
        pathStack.append(currentPath)
        Task { await loadFiles() }
    }

    func navigateBack() {
        guard pathStack.count > 1 else { return }
        pathStack.removeLast()
        currentPath = pathStack.last ?? "/"
        Task { await loadFiles() }
    }

    func jumpToPath(_ path: String) {
        currentPath = path
        pathStack = [path]
        Task { await loadFiles() }
    }

    func deleteFile(_ file: ServerFileItem) async -> Bool {
        guard let session = session else { return false }

        let result = await fileService.delete(file: file, via: session)

        switch result {
        case .success:
            await loadFiles()
            return true
        case .failure:
            return false
        }
    }

    func renameFile(_ file: ServerFileItem, to newName: String) async -> Bool {
        guard let session = session else { return false }

        let result = await fileService.rename(file: file, to: newName, via: session)

        switch result {
        case .success:
            await loadFiles()
            return true
        case .failure:
            return false
        }
    }

    func updatePermissions(_ file: ServerFileItem, to permissions: String) async -> Bool {
        guard let session = session else { return false }

        let result = await fileService.changePermissions(file: file, permissions: permissions, via: session)

        switch result {
        case .success:
            await loadFiles()
            return true
        case .failure:
            return false
        }
    }

    func updateOwner(_ file: ServerFileItem, to owner: String) async -> Bool {
        guard let session = session else { return false }

        let result = await fileService.changeOwner(file: file, owner: owner, via: session)

        switch result {
        case .success:
            await loadFiles()
            return true
        case .failure:
            return false
        }
    }

    func startMockUpload(fileName: String) {
        let task = FileUploadTask(fileName: fileName, progress: 0.1)
        activeUploads.append(task)

        // Mock progress
        Task {
            for i in 1...10 {
                try? await Task.sleep(nanoseconds: 500_000_000)
                if let index = activeUploads.firstIndex(where: { $0.id == task.id }) {
                    activeUploads[index].progress = Double(i) / 10.0
                    if i == 10 {
                        activeUploads[index].isCompleted = true
                    }
                }
            }
            // Cleanup after delay
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            activeUploads.removeAll { $0.id == task.id }
        }
    }
}
