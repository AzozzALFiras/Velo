//
//  FilesTab.swift
//  Velo
//
//  Intelligence Feature - Files Tab
//  File explorer with breadcrumbs and SSH support.
//

import SwiftUI

// MARK: - Files Tab

struct FilesTab: View {

    @StateObject private var fileManager = FileExplorerManager()

    let currentDirectory: String
    let isSSH: Bool
    let sshConnectionString: String?
    let parsedTerminalItems: [String]

    // Upload state
    var isUploading: Bool = false
    var uploadFileName: String = ""
    var uploadStartTime: Date? = nil
    var uploadProgress: Double = 0.0

    // Actions
    var onEditFile: ((String) -> Void)?
    var onChangeDirectory: ((String) -> Void)?
    var onRunCommand: ((String) -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            // Upload Progress Banner
            if isUploading {
                SSHUploadProgressBanner(
                    fileName: uploadFileName,
                    progress: uploadProgress,
                    startTime: uploadStartTime
                )
            }

            // Breadcrumbs Header
            breadcrumbsHeader

            Divider()
                .background(VeloDesign.Colors.glassBorder)

            // File Explorer
            ScrollView {
                VStack(spacing: 0) {
                    FileExplorerView(
                        manager: fileManager,
                        isSSH: isSSH,
                        sshConnectionString: sshConnectionString,
                        onEdit: { path in onEditFile?(path) },
                        onChangeDirectory: { path in onChangeDirectory?(path) },
                        onRunCommand: { cmd in onRunCommand?(cmd) }
                    )
                    .onAppear {
                        syncWithTerminalItems()
                        fileManager.isSSH = isSSH
                        fileManager.sshConnectionString = sshConnectionString
                        Task { await fileManager.loadDirectory(currentDirectory) }
                    }
                    .onChange(of: currentDirectory) { oldDir, newDir in
                        fileManager.isSSH = isSSH
                        fileManager.sshConnectionString = sshConnectionString
                        Task { await fileManager.loadDirectory(newDir) }
                    }
                    .onChange(of: isSSH) { _, newValue in
                        fileManager.isSSH = newValue
                        Task { await fileManager.loadDirectory(currentDirectory) }
                    }
                    .onChange(of: sshConnectionString) { _, newValue in
                        fileManager.sshConnectionString = newValue
                        Task { await fileManager.loadDirectory(currentDirectory) }
                    }
                    .onChange(of: parsedTerminalItems) { _, _ in
                        syncWithTerminalItems()
                    }
                }
            }
        }
    }

    private var breadcrumbsHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "folder.fill")
                .font(.system(size: 10))
                .foregroundStyle(VeloDesign.Colors.neonCyan)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    let pathParts = currentDirectory.components(separatedBy: "/").filter { !$0.isEmpty }

                    Button {
                        onChangeDirectory?("/")
                    } label: {
                        Text(isSSH ? "/" : "根")
                            .font(VeloDesign.Typography.monoSmall)
                    }
                    .buttonStyle(.plain)

                    ForEach(0..<pathParts.count, id: \.self) { index in
                        Text("/")
                            .font(.system(size: 8))
                            .foregroundStyle(VeloDesign.Colors.textMuted)

                        Button {
                            let targetPath = "/" + pathParts[0...index].joined(separator: "/")
                            onChangeDirectory?(targetPath)
                        } label: {
                            Text(pathParts[index])
                                .font(VeloDesign.Typography.monoSmall)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .foregroundStyle(VeloDesign.Colors.textSecondary)

            Spacer()

            Button {
                Task { await fileManager.loadDirectory(currentDirectory) }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 10))
                    .foregroundStyle(VeloDesign.Colors.textSecondary)
            }
            .buttonStyle(.plain)
            .disabled(fileManager.isLoading)
        }
        .padding(12)
        .background(VeloDesign.Colors.darkSurface)
    }

    private func syncWithTerminalItems() {
        guard isSSH && fileManager.rootItems.isEmpty && !parsedTerminalItems.isEmpty else { return }

        let host = sshConnectionString ?? "host"
        let items = parsedTerminalItems.map { name -> FileItem in
            let isDir = name.hasSuffix("/")
            let cleanName = isDir ? String(name.dropLast()) : name
            let separator = currentDirectory.hasSuffix("/") ? "" : "/"
            let fullPath = "\(currentDirectory)\(separator)\(cleanName)"

            return FileItem(
                id: "terminal-ssh:\(host):\(fullPath)",
                name: cleanName,
                path: fullPath,
                isDirectory: isDir,
                type: isDir ? .folder : FileType.detect(from: cleanName) == .code ? .file : .file,
                children: isDir ? [] : nil,
                size: nil,
                modificationDate: nil
            )
        }.sorted { (a, b) in
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            return a.name.lowercased() < b.name.lowercased()
        }

        if !items.isEmpty {
            fileManager.rootItems = items
        }
    }
}
