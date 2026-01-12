//
//  FileActionView.swift
//  Velo
//
//  AI-Powered Terminal - Interactive File Actions
//

import SwiftUI
import QuickLookUI

// MARK: - File Type
enum FileType: String, CaseIterable {
    case image
    case video
    case audio
    case code
    case script
    case archive
    case document
    case application
    case folder
    case other
    
    static func detect(from filename: String) -> FileType {
        let ext = (filename as NSString).pathExtension.lowercased()
        
        switch ext {
        // Images
        case "png", "jpg", "jpeg", "gif", "webp", "heic", "heif", "bmp", "tiff", "svg", "ico":
            return .image
        // Videos
        case "mp4", "mov", "avi", "mkv", "wmv", "m4v", "webm":
            return .video
        // Audio
        case "mp3", "wav", "aac", "flac", "m4a", "ogg", "aiff":
            return .audio
        // Code files
        case "swift", "py", "js", "ts", "jsx", "tsx", "java", "c", "cpp", "h", "m", "go", "rs", "rb", "php", "html", "css", "json", "xml", "yaml", "yml", "md", "sql":
            return .code
        // Executable scripts
        case "sh", "bash", "zsh", "command", "bat", "ps1":
            return .script
        // Archives
        case "zip", "tar", "gz", "rar", "7z", "ipa", "apk", "dmg", "pkg", "deb", "bz2", "xz":
            return .archive
        // Documents
        case "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf", "pages", "numbers", "keynote":
            return .document
        // Applications
        case "app", "exe":
            return .application
        default:
            return .other
        }
    }
    
    var icon: String {
        switch self {
        case .image: return "photo"
        case .video: return "play.rectangle"
        case .audio: return "waveform"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .script: return "terminal"
        case .archive: return "doc.zipper"
        case .document: return "doc.text"
        case .application: return "app"
        case .folder: return "folder"
        case .other: return "doc"
        }
    }
    
    var color: Color {
        switch self {
        case .image: return VeloDesign.Colors.neonPurple
        case .video: return VeloDesign.Colors.error
        case .audio: return VeloDesign.Colors.neonGreen
        case .code: return VeloDesign.Colors.neonCyan
        case .script: return VeloDesign.Colors.warning
        case .archive: return VeloDesign.Colors.info
        case .document: return VeloDesign.Colors.textSecondary
        case .application: return VeloDesign.Colors.neonPurple
        case .folder: return VeloDesign.Colors.neonCyan
        case .other: return VeloDesign.Colors.textMuted
        }
    }
}

// MARK: - File Action
struct FileAction: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    let command: String
    let isDestructive: Bool
    
    init(name: String, icon: String, color: Color = VeloDesign.Colors.textPrimary, command: String, isDestructive: Bool = false) {
        self.name = name
        self.icon = icon
        self.color = color
        self.command = command
        self.isDestructive = isDestructive
    }
}

// MARK: - File Info
struct FileInfo {
    let name: String
    let path: String
    let type: FileType
    let isDirectory: Bool
    let isRemote: Bool  // SSH remote file
    
    init(name: String, path: String, type: FileType, isDirectory: Bool, isRemote: Bool = false) {
        self.name = name
        self.path = path
        self.type = type
        self.isDirectory = isDirectory
        self.isRemote = isRemote
    }
    
    var actions: [FileAction] {
        var actions: [FileAction] = []
        
        if isRemote {
            // SSH Remote Actions
            if isDirectory {
                actions = [
                    FileAction(name: "Open Folder", icon: "folder", color: VeloDesign.Colors.neonCyan, command: "cd \"\(path)\""),
                    FileAction(name: "List Contents", icon: "list.bullet", command: "ls -la \"\(path)\""),
                    FileAction(name: "Copy Path", icon: "doc.on.clipboard", command: "__copy_path__"),
                    FileAction(name: "Copy Name", icon: "textformat", command: "__copy_name__"),
                    FileAction(name: "📥 Download Folder", icon: "arrow.down.circle", color: VeloDesign.Colors.neonGreen, command: "__download_folder__"),
                    FileAction(name: "Rename", icon: "pencil", color: VeloDesign.Colors.warning, command: "__rename__"),
                    FileAction(name: "Get Size", icon: "chart.bar", command: "du -sh \"\(path)\""),
                ]
            } else {
                actions = [
                    FileAction(name: "View", icon: "eye", color: VeloDesign.Colors.neonPurple, command: "cat \"\(path)\""),
                    FileAction(name: "Copy Path", icon: "doc.on.clipboard", command: "__copy_path__"),
                    FileAction(name: "Copy Name", icon: "textformat", command: "__copy_name__"),
                    FileAction(name: "📥 Download File", icon: "arrow.down.circle", color: VeloDesign.Colors.neonGreen, command: "__download_file__"),
                    FileAction(name: "Rename", icon: "pencil", color: VeloDesign.Colors.warning, command: "__rename__"),
                    FileAction(name: "Get Info", icon: "info.circle", command: "ls -la \"\(path)\" && file \"\(path)\""),
                    FileAction(name: "Edit (nano)", icon: "pencil.line", command: "nano \"\(path)\""),
                ]
            }
            // Delete action
            actions.append(FileAction(name: "Delete", icon: "trash", color: VeloDesign.Colors.error, command: "rm -i \"\(path)\"", isDestructive: true))
            
            return actions
        }
        
        // Local file actions (original)
        // Common actions
        actions.append(FileAction(name: "Open", icon: "arrow.up.forward.square", color: VeloDesign.Colors.neonGreen, command: "open \"\(path)\""))
        actions.append(FileAction(name: "Open in Finder", icon: "folder", command: "open -R \"\(path)\""))
        actions.append(FileAction(name: "Copy Path", icon: "doc.on.clipboard", command: "__copy_path__"))
        actions.append(FileAction(name: "Copy Name", icon: "textformat", command: "__copy_name__"))
        
        // Type-specific actions
        switch type {
        case .image:
            actions.insert(FileAction(name: "Preview", icon: "eye", color: VeloDesign.Colors.neonPurple, command: "__preview__"), at: 0)
            actions.append(FileAction(name: "Get Info", icon: "info.circle", command: "file \"\(path)\" && sips -g all \"\(path)\""))
            
        case .video:
            actions.insert(FileAction(name: "Play", icon: "play.fill", color: VeloDesign.Colors.neonGreen, command: "open \"\(path)\""), at: 0)
            actions.append(FileAction(name: "Get Info", icon: "info.circle", command: "mdls \"\(path)\""))
            
        case .audio:
            actions.insert(FileAction(name: "Play", icon: "play.fill", color: VeloDesign.Colors.neonGreen, command: "afplay \"\(path)\""), at: 0)
            
        case .code:
            let ext = (name as NSString).pathExtension.lowercased()
            actions.append(FileAction(name: "View Contents", icon: "doc.text", command: "cat \"\(path)\""))
            actions.append(FileAction(name: "Open in Editor", icon: "pencil", command: "open -e \"\(path)\""))
            
            // Language-specific run commands
            switch ext {
            case "py":
                actions.insert(FileAction(name: "Run Python", icon: "play.fill", color: VeloDesign.Colors.warning, command: "python3 \"\(path)\""), at: 0)
            case "js":
                actions.insert(FileAction(name: "Run Node", icon: "play.fill", color: VeloDesign.Colors.neonGreen, command: "node \"\(path)\""), at: 0)
            case "php":
                actions.insert(FileAction(name: "Run PHP", icon: "play.fill", color: VeloDesign.Colors.neonPurple, command: "php \"\(path)\""), at: 0)
            case "swift":
                actions.insert(FileAction(name: "Run Swift", icon: "play.fill", color: VeloDesign.Colors.warning, command: "swift \"\(path)\""), at: 0)
            case "rb":
                actions.insert(FileAction(name: "Run Ruby", icon: "play.fill", color: VeloDesign.Colors.error, command: "ruby \"\(path)\""), at: 0)
            case "go":
                actions.insert(FileAction(name: "Run Go", icon: "play.fill", color: VeloDesign.Colors.info, command: "go run \"\(path)\""), at: 0)
            default:
                break
            }
            
        case .script:
            let ext = (name as NSString).pathExtension.lowercased()
            switch ext {
            case "sh", "bash":
                actions.insert(FileAction(name: "Run Script", icon: "play.fill", color: VeloDesign.Colors.neonGreen, command: "bash \"\(path)\""), at: 0)
            case "zsh":
                actions.insert(FileAction(name: "Run Script", icon: "play.fill", color: VeloDesign.Colors.neonGreen, command: "zsh \"\(path)\""), at: 0)
            default:
                actions.insert(FileAction(name: "Run Script", icon: "play.fill", color: VeloDesign.Colors.neonGreen, command: "sh \"\(path)\""), at: 0)
            }
            actions.append(FileAction(name: "Make Executable", icon: "lock.open", command: "chmod +x \"\(path)\""))
            actions.append(FileAction(name: "Edit Script", icon: "pencil", command: "open -e \"\(path)\""))
            
        case .archive:
            let ext = (name as NSString).pathExtension.lowercased()
            let baseName = (name as NSString).deletingPathExtension
            let parentDir = (path as NSString).deletingLastPathComponent
            
            switch ext {
            case "zip", "ipa", "apk":
                actions.insert(FileAction(name: "Extract Here", icon: "arrow.down.doc", color: VeloDesign.Colors.neonGreen, command: "unzip -o \"\(path)\" -d \"\(parentDir)\""), at: 0)
                actions.append(FileAction(name: "Extract to Folder", icon: "folder.badge.plus", command: "unzip -o \"\(path)\" -d \"\(parentDir)/\(baseName)\""))
                actions.append(FileAction(name: "List Contents", icon: "list.bullet", command: "unzip -l \"\(path)\""))
            case "tar":
                actions.insert(FileAction(name: "Extract Here", icon: "arrow.down.doc", color: VeloDesign.Colors.neonGreen, command: "tar -xf \"\(path)\" -C \"\(parentDir)\""), at: 0)
                actions.append(FileAction(name: "List Contents", icon: "list.bullet", command: "tar -tf \"\(path)\""))
            case "gz":
                if name.hasSuffix(".tar.gz") {
                    actions.insert(FileAction(name: "Extract Here", icon: "arrow.down.doc", color: VeloDesign.Colors.neonGreen, command: "tar -xzf \"\(path)\" -C \"\(parentDir)\""), at: 0)
                } else {
                    actions.insert(FileAction(name: "Decompress", icon: "arrow.down.doc", color: VeloDesign.Colors.neonGreen, command: "gunzip -k \"\(path)\""), at: 0)
                }
            case "bz2":
                actions.insert(FileAction(name: "Extract Here", icon: "arrow.down.doc", color: VeloDesign.Colors.neonGreen, command: "tar -xjf \"\(path)\" -C \"\(parentDir)\""), at: 0)
            case "dmg":
                actions.insert(FileAction(name: "Mount", icon: "externaldrive.badge.plus", color: VeloDesign.Colors.neonGreen, command: "hdiutil attach \"\(path)\""), at: 0)
            case "pkg":
                actions.insert(FileAction(name: "Install", icon: "arrow.down.app", color: VeloDesign.Colors.warning, command: "sudo installer -pkg \"\(path)\" -target /"), at: 0)
            default:
                break
            }
            
        case .document:
            let ext = (name as NSString).pathExtension.lowercased()
            if ext == "pdf" {
                actions.append(FileAction(name: "Preview PDF", icon: "eye", command: "qlmanage -p \"\(path)\""))
            }
            
        case .application:
            actions.insert(FileAction(name: "Launch", icon: "play.fill", color: VeloDesign.Colors.neonGreen, command: "open -a \"\(path)\""), at: 0)
            actions.append(FileAction(name: "Show Contents", icon: "folder", command: "open \"\(path)/Contents\""))
            
        case .folder:
            actions = [
                FileAction(name: "Open Folder", icon: "folder", color: VeloDesign.Colors.neonCyan, command: "cd \"\(path)\""),
                FileAction(name: "Open in Finder", icon: "arrow.up.forward.square", command: "open \"\(path)\""),
                FileAction(name: "List Contents", icon: "list.bullet", command: "ls -la \"\(path)\""),
                FileAction(name: "Copy Path", icon: "doc.on.clipboard", command: "__copy_path__"),
                FileAction(name: "Get Size", icon: "chart.bar", command: "du -sh \"\(path)\""),
            ]
            
        case .other:
            actions.append(FileAction(name: "Get Info", icon: "info.circle", command: "file \"\(path)\" && ls -la \"\(path)\""))
        }
        
        // Delete action (always last)
        actions.append(FileAction(name: "Delete", icon: "trash", color: VeloDesign.Colors.error, command: "rm -i \"\(path)\"", isDestructive: true))
        
        return actions
    }
}

// MARK: - Interactive File View
struct InteractiveFileView: View {
    let filename: String
    let currentDirectory: String
    let onAction: (String) -> Void
    let isSSHSession: Bool  // NEW: indicates remote file
    
    @State private var isHovered = false
    @State private var showingMenu = false
    @State private var showingRenameSheet = false
    @State private var showingSavePanel = false
    @State private var newName = ""
    
    init(filename: String, currentDirectory: String, onAction: @escaping (String) -> Void, isSSHSession: Bool = false) {
        self.filename = filename
        self.currentDirectory = currentDirectory
        self.onAction = onAction
        self.isSSHSession = isSSHSession
    }
    
    var fileInfo: FileInfo {
        let path: String
        if filename.hasPrefix("/") {
            path = filename
        } else if filename.hasPrefix("~") {
            path = (filename as NSString).expandingTildeInPath
        } else {
            path = (currentDirectory as NSString).appendingPathComponent(filename)
        }
        
        let isDir = filename.hasSuffix("/")
        let type: FileType = isDir ? .folder : FileType.detect(from: filename)
        return FileInfo(name: filename, path: path, type: type, isDirectory: isDir, isRemote: isSSHSession)
    }
    
    var body: some View {
        HStack(spacing: VeloDesign.Spacing.xs) {
            // File icon
            Image(systemName: fileInfo.type.icon)
                .font(.system(size: 10))
                .foregroundColor(fileInfo.type.color)
            
            // Filename
            Text(filename)
                .font(VeloDesign.Typography.monoFont)
                .foregroundColor(isHovered ? VeloDesign.Colors.neonCyan : VeloDesign.Colors.textPrimary)
            
            // Remote indicator for SSH
            if isSSHSession {
                Image(systemName: "network")
                    .font(.system(size: 8))
                    .foregroundColor(VeloDesign.Colors.neonPurple.opacity(0.7))
            }
        }
        .padding(.horizontal, VeloDesign.Spacing.xs)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? VeloDesign.Colors.neonCyan.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isHovered ? VeloDesign.Colors.neonCyan.opacity(0.3) : Color.clear, lineWidth: 0.5)
        )
        .onHover { hovering in
            withAnimation(VeloDesign.Animation.quick) {
                isHovered = hovering
            }
        }
        .simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    showingMenu = true
                }
        )
        .popover(isPresented: $showingMenu, arrowEdge: .bottom) {
            FileActionMenu(
                fileInfo: fileInfo,
                onAction: { action in
                    showingMenu = false
                    handleAction(action)
                }
            )
        }
        .sheet(isPresented: $showingRenameSheet) {
            RenameSheet(
                currentName: fileInfo.name,
                isRemote: isSSHSession,
                onRename: { newName in
                    if isSSHSession {
                        onAction("mv \"\(fileInfo.path)\" \"\((fileInfo.path as NSString).deletingLastPathComponent)/\(newName)\"")
                    } else {
                        onAction("mv \"\(fileInfo.path)\" \"\((fileInfo.path as NSString).deletingLastPathComponent)/\(newName)\"")
                    }
                }
            )
        }
    }
    
    private func handleAction(_ action: FileAction) {
        switch action.command {
        case "__copy_path__":
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(fileInfo.path, forType: .string)
        case "__copy_name__":
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(fileInfo.name, forType: .string)
        case "__preview__":
            let url = URL(fileURLWithPath: fileInfo.path)
            NSWorkspace.shared.open(url)
        case "__rename__":
            showingRenameSheet = true
        case "__download_file__", "__download_folder__":
            showSSHDownloadDialog()
        default:
            onAction(action.command)
        }
    }
    
    private func showSSHDownloadDialog() {
        let savePanel = NSSavePanel()
        savePanel.title = "Save to Local"
        savePanel.nameFieldStringValue = fileInfo.name
        savePanel.canCreateDirectories = true
        savePanel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
        
        savePanel.begin { response in
            if response == .OK, let url = savePanel.url {
                // Build scp command - user needs to replace with their SSH connection
                // Format: scp user@host:remote_path local_path
                let localPath = url.path
                let remotePath = fileInfo.path
                
                // For folder, use -r flag
                let scpFlag = fileInfo.isDirectory ? "-r " : ""
                
                // Display a message about the download command
                // In real implementation, we'd need SSHConnection context
                let downloadCommand = "# Run in a new terminal:\n# scp \(scpFlag)USER@HOST:\"\(remotePath)\" \"\(localPath)\""
                
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(downloadCommand, forType: .string)
                
                // Show notification
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!)
            }
        }
    }
}

// MARK: - Rename Sheet
struct RenameSheet: View {
    let currentName: String
    let isRemote: Bool
    let onRename: (String) -> Void
    
    @State private var newName: String = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: VeloDesign.Spacing.lg) {
            // Header
            HStack {
                Image(systemName: isRemote ? "network" : "doc")
                    .foregroundColor(VeloDesign.Colors.neonCyan)
                Text("Rename")
                    .font(VeloDesign.Typography.headline)
                    .foregroundColor(VeloDesign.Colors.textPrimary)
            }
            
            VStack(alignment: .leading, spacing: VeloDesign.Spacing.sm) {
                Text("Current: \(currentName)")
                    .font(VeloDesign.Typography.caption)
                    .foregroundColor(VeloDesign.Colors.textMuted)
                
                TextField("New name", text: $newName)
                    .textFieldStyle(.roundedBorder)
                    .font(VeloDesign.Typography.monoFont)
            }
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Rename") {
                    if !newName.isEmpty {
                        onRename(newName)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(VeloDesign.Colors.neonCyan)
                .disabled(newName.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
        .background(VeloDesign.Colors.darkSurface)
        .onAppear {
            newName = currentName
        }
    }
}

// MARK: - File Action Menu
struct FileActionMenu: View {
    let fileInfo: FileInfo
    let onAction: (FileAction) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: VeloDesign.Spacing.sm) {
                Image(systemName: fileInfo.type.icon)
                    .font(.system(size: 14))
                    .foregroundColor(fileInfo.type.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(fileInfo.name)
                        .font(VeloDesign.Typography.monoSmall)
                        .foregroundColor(VeloDesign.Colors.textPrimary)
                        .lineLimit(1)
                    
                    Text(fileInfo.type.rawValue.capitalized)
                        .font(.system(size: 9))
                        .foregroundColor(VeloDesign.Colors.textMuted)
                }
            }
            .padding(VeloDesign.Spacing.md)
            
            Divider()
                .background(VeloDesign.Colors.glassBorder)
            
            // Actions
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(fileInfo.actions) { action in
                        FileActionRow(action: action) {
                            onAction(action)
                        }
                    }
                }
            }
            .frame(maxHeight: 300)
        }
        .frame(width: 220)
        .background(VeloDesign.Colors.darkSurface)
    }
}

// MARK: - File Action Row
struct FileActionRow: View {
    let action: FileAction
    let onSelect: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: VeloDesign.Spacing.sm) {
                Image(systemName: action.icon)
                    .font(.system(size: 11))
                    .foregroundColor(action.isDestructive ? VeloDesign.Colors.error : action.color)
                    .frame(width: 16)
                
                Text(action.name)
                    .font(VeloDesign.Typography.caption)
                    .foregroundColor(action.isDestructive ? VeloDesign.Colors.error : VeloDesign.Colors.textPrimary)
                
                Spacer()
            }
            .padding(.horizontal, VeloDesign.Spacing.md)
            .padding(.vertical, VeloDesign.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: VeloDesign.Radius.small)
                    .fill(isHovered ? VeloDesign.Colors.elevatedSurface : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: VeloDesign.Spacing.md) {
        InteractiveFileView(
            filename: "example.png",
            currentDirectory: NSHomeDirectory() + "/Desktop",
            onAction: { _ in }
        )
        
        InteractiveFileView(
            filename: "script.sh",
            currentDirectory: NSHomeDirectory(),
            onAction: { _ in }
        )
        
        InteractiveFileView(
            filename: "archive.zip",
            currentDirectory: NSHomeDirectory(),
            onAction: { _ in }
        )
    }
    .padding()
    .background(VeloDesign.Colors.deepSpace)
}
