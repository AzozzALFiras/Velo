//
//  FileItemRow.swift
//  Velo
//
//  Intelligence Feature - File Item Row
//  Displays a file or folder in the file explorer with actions.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - File Type Enum

enum FileType {
    case folder
    case swift
    case python
    case javascript
    case typescript
    case json
    case yaml
    case markdown
    case html
    case css
    case image
    case video
    case audio
    case archive
    case executable
    case config
    case text
    case unknown
    
    var icon: String {
        switch self {
        case .folder: return "folder.fill"
        case .swift: return "swift"
        case .python: return "terminal"
        case .javascript, .typescript: return "curlybraces"
        case .json, .yaml: return "doc.text"
        case .markdown: return "doc.richtext"
        case .html, .css: return "globe"
        case .image: return "photo"
        case .video: return "film"
        case .audio: return "music.note"
        case .archive: return "archivebox"
        case .executable: return "terminal"
        case .config: return "gearshape"
        case .text: return "doc.text"
        case .unknown: return "doc"
        }
    }
    
    var color: Color {
        switch self {
        case .folder: return .blue
        case .swift: return .orange
        case .python: return .yellow
        case .javascript: return .yellow
        case .typescript: return .blue
        case .json: return .green
        case .yaml: return .pink
        case .markdown: return .purple
        case .html: return .orange
        case .css: return .cyan
        case .image: return .green
        case .video: return .red
        case .audio: return .pink
        case .archive: return .brown
        case .executable: return .red
        case .config: return .gray
        case .text: return .secondary
        case .unknown: return .secondary
        }
    }
    
    static func detect(from filename: String) -> FileType {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return .swift
        case "py": return .python
        case "js": return .javascript
        case "ts", "tsx": return .typescript
        case "json": return .json
        case "yml", "yaml": return .yaml
        case "md", "markdown": return .markdown
        case "html", "htm": return .html
        case "css", "scss", "sass": return .css
        case "png", "jpg", "jpeg", "gif", "svg", "webp": return .image
        case "mp4", "mov", "avi", "mkv": return .video
        case "mp3", "wav", "aac", "m4a": return .audio
        case "zip", "tar", "gz", "rar", "7z": return .archive
        case "sh", "bash", "zsh": return .executable
        case "conf", "ini", "env", "plist": return .config
        case "txt", "log": return .text
        default: return .unknown
        }
    }
}

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
                TextField("files.menu.rename".localized, text: $newName)
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
                            .help("files.menu.edit".localized)
                    }
                    if isSSH {
                        Image(systemName: "arrow.down.circle")
                            .help("files.menu.download".localized)
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
                    Text("files.none".localized)
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
                Label(item.isDirectory ? (item.isExpanded ? "files.menu.collapse".localized : "files.menu.expand".localized) : "files.menu.edit".localized,
                      systemImage: item.isDirectory ? (item.isExpanded ? "chevron.down" : "chevron.right") : "pencil")
            }

            Divider()

            if !isSSH {
                Button {
                    NSWorkspace.shared.open(URL(fileURLWithPath: item.path))
                } label: {
                    Label("files.menu.openDefault".localized, systemImage: "arrow.up.forward.square")
                }

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: item.path)])
                } label: {
                    Label("files.menu.showFinder".localized, systemImage: "folder")
                }
            }

            if item.isDirectory {
                Button {
                    onRunCommand("cd \"\(item.path)\"")
                } label: {
                    Label("files.menu.cd".localized, systemImage: "terminal")
                }

                Button {
                    onRunCommand("ls -la \"\(item.path)\"")
                } label: {
                    Label("files.menu.list".localized, systemImage: "list.bullet")
                }
            } else {
                Button {
                    onRunCommand("cat \"\(item.path)\"")
                } label: {
                    Label("files.menu.viewCat".localized, systemImage: "eye")
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
                    Label("files.menu.download".localized, systemImage: "arrow.down.circle")
                }

                Button {
                    onRunCommand("du -sh \"\(item.path)\"")
                } label: {
                    Label("files.menu.getSize".localized, systemImage: "chart.bar")
                }

                Divider()
            }

            Button {
                newName = item.name
                showingRename = true
            } label: {
                Label("files.menu.rename".localized, systemImage: "pencil.line")
            }

            Button {
                onRunCommand("__copy_name__:\(item.name)")
            } label: {
                Label("files.menu.copyName".localized, systemImage: "textformat")
            }

            Button {
                onRunCommand("__copy_path__:\(item.path)")
            } label: {
                Label("files.menu.copyPath".localized, systemImage: "doc.on.clipboard")
            }

            Divider()

            Button {
                onChangeDirectory(item.path)
            } label: {
                Label("files.menu.changeCwd".localized, systemImage: "arrow.right.circle")
            }
            .disabled(!item.isDirectory)

            Button {
                showingInfo = true
            } label: {
                Label("files.menu.getInfo".localized, systemImage: "info.circle")
            }

            Divider()

            Button(role: .destructive) {
                onRunCommand("rm -i \"\(item.path)\"")
            } label: {
                Label("files.menu.delete".localized, systemImage: "trash")
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
