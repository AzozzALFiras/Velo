//
//  FilesDetailViewModel+Transfer.swift
//  Velo
//
//  File transfer methods for FilesDetailViewModel.
//

import Foundation
import AppKit

extension FilesDetailViewModel {

    // MARK: - Upload

    func initiateUpload() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.prompt = "files.upload.select".localized

        if panel.runModal() == .OK {
            Task {
                await uploadFiles(panel.urls)
            }
        }
    }

    func uploadFiles(_ urls: [URL]) async {
        for url in urls {
            await uploadFile(url)
        }
    }

    func uploadFile(_ url: URL) async {
        let fileName = url.lastPathComponent
        let remotePath = (currentPath as NSString).appendingPathComponent(fileName)

        // Create transfer task
        var task = FileTransferTask(
            fileName: fileName,
            filePath: remotePath,
            isUpload: true,
            totalBytes: (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) } ?? 0
        )

        activeTransfers.append(task)

        // Simulate upload progress (real implementation would use SFTP)
        for i in 1...10 {
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

            if let index = activeTransfers.firstIndex(where: { $0.id == task.id }) {
                let progress = Double(i) / 10.0
                activeTransfers[index].state = .inProgress(progress: progress)
                activeTransfers[index].transferredBytes = Int64(Double(task.totalBytes) * progress)
            }
        }

        // Mark as completed
        if let index = activeTransfers.firstIndex(where: { $0.id == task.id }) {
            activeTransfers[index].state = .completed
            task = activeTransfers[index]

            // Move to completed after delay
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            activeTransfers.removeAll { $0.id == task.id }
            completedTransfers.insert(task, at: 0)

            // Keep only last 50 completed transfers
            if completedTransfers.count > 50 {
                completedTransfers = Array(completedTransfers.prefix(50))
            }
        }

        // Refresh file list
        await loadFiles()
    }

    // MARK: - Download

    func initiateDownload(for file: ServerFileItem) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = file.name
        panel.prompt = "files.download.save".localized

        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await downloadFile(file, to: url)
            }
        }
    }

    func downloadFile(_ file: ServerFileItem, to localURL: URL) async {
        // Create transfer task
        var task = FileTransferTask(
            fileName: file.name,
            filePath: file.path,
            isUpload: false,
            totalBytes: file.sizeBytes
        )

        activeTransfers.append(task)

        // Simulate download progress (real implementation would use SFTP)
        for i in 1...10 {
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

            if let index = activeTransfers.firstIndex(where: { $0.id == task.id }) {
                let progress = Double(i) / 10.0
                activeTransfers[index].state = .inProgress(progress: progress)
                activeTransfers[index].transferredBytes = Int64(Double(task.totalBytes) * progress)
            }
        }

        // Mark as completed
        if let index = activeTransfers.firstIndex(where: { $0.id == task.id }) {
            activeTransfers[index].state = .completed
            task = activeTransfers[index]

            // Move to completed after delay
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            activeTransfers.removeAll { $0.id == task.id }
            completedTransfers.insert(task, at: 0)

            // Keep only last 50 completed transfers
            if completedTransfers.count > 50 {
                completedTransfers = Array(completedTransfers.prefix(50))
            }
        }

        showSuccess("files.success.downloaded".localized(file.name))
    }

    func downloadSelectedFiles() {
        let filesToDownload = files.filter { selectedFiles.contains($0.id) }

        if filesToDownload.count == 1, let file = filesToDownload.first {
            initiateDownload(for: file)
        } else if filesToDownload.count > 1 {
            // For multiple files, ask for directory
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.prompt = "files.download.selectFolder".localized

            if panel.runModal() == .OK, let folderURL = panel.url {
                Task {
                    for file in filesToDownload {
                        let localURL = folderURL.appendingPathComponent(file.name)
                        await downloadFile(file, to: localURL)
                    }
                }
            }
        }
    }

    // MARK: - Transfer Management

    func cancelTransfer(_ task: FileTransferTask) {
        if let index = activeTransfers.firstIndex(where: { $0.id == task.id }) {
            activeTransfers[index].state = .cancelled
            activeTransfers.remove(at: index)
        }
    }

    func cancelAllTransfers() {
        for i in activeTransfers.indices {
            activeTransfers[i].state = .cancelled
        }
        activeTransfers.removeAll()
    }

    func clearCompletedTransfers() {
        completedTransfers.removeAll()
    }

    func retryTransfer(_ task: FileTransferTask) async {
        // Remove from completed
        completedTransfers.removeAll { $0.id == task.id }

        // Re-initiate based on type
        if task.isUpload {
            // Would need to store the original URL - simplified for now
            showError("files.error.retryNotAvailable".localized)
        } else {
            // For downloads, use stored path
            if let file = files.first(where: { $0.path == task.filePath }) {
                initiateDownload(for: file)
            }
        }
    }
}
