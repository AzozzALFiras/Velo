//
//  FileItemRow.swift
//  Velo
//
//  Intelligence Feature - File Item Row
//  Displays a file or folder in the file explorer with actions.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - File Item Row

struct FileItemRow: View {
    let item: FileItem
    @ObservedObject var manager: FileExplorerManager
    let depth: Int
    let isSSH: Bool
    let sshConnectionString: String?
    let onEdit: (String) -> Void
    let onChangeDirectory: (String) -> Void
    let onRunCommand: (String) -> Void

    @State private var isHovered = false
    @State private var showingRename = false
    @State private var showingInfo = false
    @State private var newName = ""
    @State private var isExpandingRemote = false
    @State private var isDropTarget = false

    private var fileType: FileType {
        item.isDirectory ? .folder : FileType.detect(from: item.name)
    }

    var body: some View {
        VStack(spacing: 0) {
            rowView
            childrenView
        }
    }

    private var rowView: some View {
        rowContent
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.1)) {
                    isHovered = hovering
                }
            }
            .onTapGesture {
                if item.isDirectory {
                    toggleExpansion()
                } else {
                    onEdit(item.path)
                }
            }
            .contextMenu {
                fileContextMenu
            }
            .popover(isPresented: $showingInfo) {
                FileInfoPopover(item: item)
            }
            .modifier(FileItemDragDropModifier(
                item: item,
                isSSH: isSSH,
                sshConnectionString: sshConnectionString,
                onRunCommand: onRunCommand,
                handleFileDrop: handleFileDrop,
                createSSHDragItem: createSSHDragItem,
                isDropTarget: $isDropTarget,
                fileType: fileType
            ))
    }

    private var rowContent: some View {
        HStack(spacing: 6) {
            // Indent
            if depth > 0 {
                Rectangle()
                    .fill(VeloDesign.Colors.glassBorder.opacity(0.3))
                    .frame(width: 1)
                    .padding(.leading, CGFloat(depth * 12) - 6)
                    .padding(.trailing, 5)
            }

            // Chevron for folders
            if item.isDirectory {
                ZStack {
                    if isExpandingRemote {
                        ProgressView()
                            .scaleEffect(0.4)
                    } else {
                        Image(systemName: item.isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(VeloDesign.Colors.textMuted)
                    }
                }
                .frame(width: 12)
            } else {
                Spacer().frame(width: 12)
            }

            // Icon
            Image(systemName: fileType.icon)
                .font(.system(size: 11))
                .foregroundStyle(isHovered ? VeloDesign.Colors.textPrimary : fileType.color.opacity(0.8))
                .frame(width: 14)

            // Name
            if showingRename {
                TextField("Rename", text: $newName)
                    .textFieldStyle(.plain)
                    .font(VeloDesign.Typography.monoSmall)
                    .foregroundStyle(VeloDesign.Colors.textPrimary)
                    .onSubmit {
                        manager.rename(item: item, to: newName)
                        showingRename = false
                    }
            } else {
                Text(item.name)
                    .font(VeloDesign.Typography.monoSmall)
                    .foregroundStyle(isHovered ? VeloDesign.Colors.neonCyan : VeloDesign.Colors.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            // Quick actions
            if isHovered && !showingRename {
                HStack(spacing: 8) {
                    if !item.isDirectory {
                        Image(systemName: "pencil")
                            .help("Edit File")
                    }
                    if isSSH {
                        Image(systemName: "arrow.down.circle")
                            .help("Download")
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(VeloDesign.Colors.textMuted)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(isHovered ? VeloDesign.Colors.neonCyan.opacity(0.05) : Color.clear)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var childrenView: some View {
        if item.isExpanded, let children = item.children {
            if children.isEmpty && isSSH {
                HStack {
                    Spacer().frame(width: CGFloat((depth + 1) * 12) + 18)
                    Text("No items found")
                        .font(.system(size: 9))
                        .foregroundStyle(VeloDesign.Colors.textMuted)
                    Spacer()
                }
                .padding(.vertical, 4)
            } else {
                ForEach(children) { child in
                    FileItemRow(
                        item: child,
                        manager: manager,
                        depth: depth + 1,
                        isSSH: isSSH,
                        sshConnectionString: sshConnectionString,
                        onEdit: onEdit,
                        onChangeDirectory: onChangeDirectory,
                        onRunCommand: onRunCommand
                    )
                }
            }
        }
    }

    // MARK: - Actions

    private func toggleExpansion() {
        if isSSH && !item.isExpanded && (item.children == nil || item.children!.isEmpty) {
            isExpandingRemote = true
            Task {
                manager.toggleExpansion(path: item.path)
                try? await Task.sleep(nanoseconds: 500_000_000)
                isExpandingRemote = false
            }
        } else {
            manager.toggleExpansion(path: item.path)
        }
    }

    private func createSSHDragItem() -> NSItemProvider {
        let fileItem = self.item
        let sshHost = sshConnectionString ?? "user@host"
        let isDir = fileItem.isDirectory

        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let destURL = downloadsURL.appendingPathComponent(fileItem.name)

        let flag = isDir ? "-r " : ""
        let escapedLocal = destURL.path.replacingOccurrences(of: "'", with: "'\\''")
        let escapedRemote = fileItem.path.replacingOccurrences(of: "'", with: "'\\''")
        let scpCmd = "__download_scp__:scp \(flag)\(sshHost):'\(escapedRemote)' '\(escapedLocal)'"

        onRunCommand(scpCmd)

        let provider = NSItemProvider()
        provider.suggestedName = fileItem.name
        provider.registerFileRepresentation(
            forTypeIdentifier: isDir ? "public.folder" : "public.item",
            visibility: .all
        ) { completion in
            completion(destURL, false, nil)
            return nil
        }

        return provider
    }

    private func handleFileDrop(urls: [URL], toFolder destinationPath: String) {
        if isSSH {
            SSHFileTransferService.handleFileDrop(
                urls: urls,
                destinationPath: destinationPath,
                sshConnectionString: sshConnectionString ?? "user@host",
                onUpload: { command in onRunCommand(command) }
            )
        } else {
            for url in urls {
                let filename = url.lastPathComponent
                let destinationFullPath = (destinationPath as NSString).appendingPathComponent(filename)
                do {
                    let destURL = URL(fileURLWithPath: destinationFullPath)
                    if FileManager.default.fileExists(atPath: destURL.path) {
                        try FileManager.default.removeItem(at: destURL)
                    }
                    try FileManager.default.copyItem(at: url, to: destURL)
                    Task {
                        await manager.loadDirectory((destinationPath as NSString).deletingLastPathComponent)
                    }
                } catch {
                    print("Failed to copy file: \(error)")
                }
            }
        }
    }

    @ViewBuilder
    private var fileContextMenu: some View {
        Group {
            Button {
                if item.isDirectory {
                    toggleExpansion()
                } else {
                    onEdit(item.path)
                }
            } label: {
                Label(item.isDirectory ? (item.isExpanded ? "Collapse" : "Expand") : "Edit File",
                      systemImage: item.isDirectory ? (item.isExpanded ? "chevron.down" : "chevron.right") : "pencil")
            }

            Divider()

            if !isSSH {
                Button {
                    NSWorkspace.shared.open(URL(fileURLWithPath: item.path))
                } label: {
                    Label("Open with Default App", systemImage: "arrow.up.forward.square")
                }

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
                } label: {
                    Label("Show in Finder", systemImage: "folder")
                }
            }

            if item.isDirectory {
                Button {
                    onRunCommand("cd \"\(item.path)\"")
                } label: {
                    Label("cd to Folder", systemImage: "terminal")
                }

                Button {
                    onRunCommand("ls -la \"\(item.path)\"")
                } label: {
                    Label("List Contents", systemImage: "list.bullet")
                }
            } else {
                Button {
                    onRunCommand("cat \"\(item.path)\"")
                } label: {
                    Label("View Content (cat)", systemImage: "eye")
                }
            }

            Divider()

            if isSSH {
                Button {
                    SSHFileTransferService.showDownloadDialog(
                        fileName: item.name,
                        remotePath: item.path,
                        isDirectory: item.isDirectory,
                        sshConnectionString: sshConnectionString ?? "user@host",
                        onDownload: { command in onRunCommand(command) }
                    )
                } label: {
                    Label("Download...", systemImage: "arrow.down.circle")
                }

                Button {
                    onRunCommand("du -sh \"\(item.path)\"")
                } label: {
                    Label("Get Size", systemImage: "chart.bar")
                }

                Divider()
            }

            Button {
                newName = item.name
                showingRename = true
            } label: {
                Label("Rename", systemImage: "pencil.line")
            }

            Button {
                onRunCommand("__copy_name__:\(item.name)")
            } label: {
                Label("Copy Name", systemImage: "textformat")
            }

            Button {
                onRunCommand("__copy_path__:\(item.path)")
            } label: {
                Label("Copy Path", systemImage: "doc.on.clipboard")
            }

            Divider()

            Button {
                onChangeDirectory(item.path)
            } label: {
                Label("Change CWD to here", systemImage: "arrow.right.circle")
            }
            .disabled(!item.isDirectory)

            Button {
                showingInfo = true
            } label: {
                Label("Get Info", systemImage: "info.circle")
            }

            Divider()

            Button(role: .destructive) {
                onRunCommand("rm -i \"\(item.path)\"")
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Drag and Drop Modifier

struct FileItemDragDropModifier: ViewModifier {
    let item: FileItem
    let isSSH: Bool
    let sshConnectionString: String?
    let onRunCommand: (String) -> Void
    let handleFileDrop: ([URL], String) -> Void
    let createSSHDragItem: () -> NSItemProvider
    @Binding var isDropTarget: Bool
    let fileType: FileType

    func body(content: Content) -> some View {
        content
            .onDrag {
                isSSH ? createSSHDragItem() : NSItemProvider(object: URL(fileURLWithPath: item.path) as NSURL)
            }
            .dropDestination(for: URL.self) { urls, _ in
                if item.isDirectory {
                    handleFileDrop(urls, item.path)
                    return true
                }
                return false
            } isTargeted: { targeted in
                isDropTarget = targeted
            }
            .overlay {
                if isDropTarget {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(VeloDesign.Colors.neonCyan, lineWidth: 2)
                        .background(VeloDesign.Colors.neonCyan.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
    }
}
