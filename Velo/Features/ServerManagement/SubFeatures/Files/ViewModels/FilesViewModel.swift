//
//  FilesViewModel.swift
//  Velo
//
//  Modular ViewModel for server file system management.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class FilesViewModel: ObservableObject {
    
    // MARK: - Dependencies
    weak var session: TerminalViewModel?
    private let sshBase = SSHBaseService.shared
    
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
        
        // Execute optimized ls command
        let result = await sshBase.execute("ls -1F '\(currentPath)' 2>/dev/null", via: session)
        let lines = result.output.components(separatedBy: CharacterSet.newlines)
        
        self.files = lines.compactMap { line -> ServerFileItem? in
            let name = line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            guard !name.isEmpty else { return nil }
            let isDir = name.hasSuffix("/")
            let cleanName = isDir ? String(name.dropLast()) : name
            return ServerFileItem(
                name: cleanName,
                path: "\(currentPath)/\(cleanName)".replacingOccurrences(of: "//", with: "/"),
                isDirectory: isDir,
                sizeBytes: 0,
                permissions: "755",
                modificationDate: Date(),
                owner: "root"
            )
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
        let cmd = "sudo rm -rf '\(file.path)' && echo 'DELETED'"
        let result = await sshBase.execute(cmd, via: session)
        
        if result.output.contains("DELETED") {
            await loadFiles()
            return true
        }
        return false
    }
    
    func renameFile(_ file: ServerFileItem, to newName: String) async -> Bool {
        guard let session = session else { return false }
        let newPath = (file.path as NSString).deletingLastPathComponent + "/" + newName
        let cmd = "sudo mv '\(file.path)' '\(newPath)' && echo 'RENAMED'"
        let result = await sshBase.execute(cmd, via: session)
        
        if result.output.contains("RENAMED") {
            await loadFiles()
            return true
        }
        return false
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
