//
//  FileExplorerView.swift
//  Velo
//
//  Intelligence Feature - File Explorer View
//  Tree view for browsing local and remote files.
//

import SwiftUI

// MARK: - File Explorer View

struct FileExplorerView: View {
    @ObservedObject var manager: FileExplorerManager
    let isSSH: Bool
    let sshConnectionString: String?
    let onEdit: (String) -> Void
    let onChangeDirectory: (String) -> Void
    let onRunCommand: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if manager.isLoading && manager.rootItems.isEmpty {
                loadingState
            } else if manager.rootItems.isEmpty {
                emptyState
            } else {
                fileList
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            handleRootDrop(urls: urls)
            return true
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            Text("Scanning remote files...")
                .font(VeloDesign.Typography.caption)
                .foregroundStyle(VeloDesign.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: isSSH ? "network" : "folder.badge.questionmark")
                .font(.system(size: 24))
                .foregroundStyle(VeloDesign.Colors.textMuted)

            Text(isSSH ? "Unable to list remote files" : "Empty folder")
                .font(VeloDesign.Typography.caption)
                .foregroundStyle(VeloDesign.Colors.textSecondary)

            if isSSH {
                Text("Verify SSH keys or run 'ls' in terminal")
                    .font(.system(size: 9))
                    .foregroundStyle(VeloDesign.Colors.textMuted)

                Button {
                    Task { await manager.loadDirectory(manager.rootItems.isEmpty ? "" : manager.rootItems[0].path) }
                } label: {
                    Text("Retry Connection")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(VeloDesign.Colors.neonCyan.opacity(0.2))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var fileList: some View {
        ForEach(manager.rootItems) { item in
            FileItemRow(
                item: item,
                manager: manager,
                depth: 0,
                isSSH: isSSH,
                sshConnectionString: sshConnectionString,
                onEdit: onEdit,
                onChangeDirectory: onChangeDirectory,
                onRunCommand: onRunCommand
            )
        }
    }

    private func handleRootDrop(urls: [URL]) {
        guard let currentDir = manager.rootItems.first?.path.components(separatedBy: "/").dropLast().joined(separator: "/") else {
            return
        }

        if isSSH {
            SSHFileTransferService.handleFileDrop(
                urls: urls,
                destinationPath: currentDir,
                sshConnectionString: sshConnectionString ?? "user@host",
                onUpload: { command in onRunCommand(command) }
            )
        } else {
            for url in urls {
                let filename = url.lastPathComponent
                let destinationPath = (currentDir as NSString).appendingPathComponent(filename)
                do {
                    let destURL = URL(fileURLWithPath: destinationPath)
                    if FileManager.default.fileExists(atPath: destURL.path) {
                        try FileManager.default.removeItem(at: destURL)
                    }
                    try FileManager.default.copyItem(at: url, to: destURL)
                    Task {
                        await manager.loadDirectory(currentDir)
                    }
                } catch {
                    print("Failed to copy file: \(error)")
                }
            }
        }
    }
}
