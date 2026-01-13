//
//  InteractiveOutputLineView.swift
//  Velo
//
//  Created by Velo AI
//

import SwiftUI

// MARK: - Utilities
fileprivate extension String {
    func cleanANSI() -> String {
        var cleaned = self
        // Remove ESC sequences
        cleaned = cleaned.replacingOccurrences(of: "\u{1B}\\[[0-9;?]*[a-zA-Z]", with: "", options: .regularExpression)
        // Remove OSC sequences (]0; ]1; etc.)  
        cleaned = cleaned.replacingOccurrences(of: "\\]\\d+;[^\\x07\\n]*", with: "", options: .regularExpression)
        // Remove user@host: patterns
        cleaned = cleaned.replacingOccurrences(of: "[a-zA-Z0-9_-]+@[a-zA-Z0-9_-]+:", with: "", options: .regularExpression)
        // Remove remaining control characters
        cleaned = cleaned.replacingOccurrences(of: "\u{1B}", with: "")
        cleaned = cleaned.replacingOccurrences(of: "\u{07}", with: "")
        // Remove shell prompts patterns
        cleaned = cleaned.replacingOccurrences(of: "^[~\\/][^#$]*[#$]\\s*$", with: "", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Interactive Output Line View
/// Parses output lines to detect files and make them interactive
struct InteractiveOutputLineView: View {
    let line: OutputLine
    let searchQuery: String
    let currentDirectory: String
    let isInteractive: Bool
    let isDeepParsing: Bool
    let isSSHSession: Bool
    let sshConnectionString: String?
    let remoteWorkingDirectory: String?
    let fetchedFileContent: String?
    let fetchingFilePath: String?
    let onFileAction: (String) -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(alignment: .top, spacing: VeloDesign.Spacing.sm) {
            // Line indicator
            if line.isError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9))
                    .foregroundColor(VeloDesign.Colors.error)
            }
            
            // Interactive content
            InteractiveLineContent(
                text: line.text,
                attributedText: line.attributedText,
                isError: line.isError,
                currentDirectory: currentDirectory,
                isInteractive: isInteractive,
                isDeepParsing: isDeepParsing,
                isSSHSession: isSSHSession,
                sshConnectionString: sshConnectionString,
                remoteWorkingDirectory: remoteWorkingDirectory,
                fetchedFileContent: fetchedFileContent,
                fetchingFilePath: fetchingFilePath,
                onFileAction: onFileAction
            )
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, VeloDesign.Spacing.xs)
        .padding(.vertical, 1)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? VeloDesign.Colors.glassWhite : Color.clear)
        )
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Copy Line") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(line.text, forType: .string)
            }
        }
    }
}

// MARK: - Interactive Line Content
struct InteractiveLineContent: View {
    let text: String
    let attributedText: AttributedString
    let isError: Bool
    let currentDirectory: String
    let isInteractive: Bool
    let isDeepParsing: Bool
    let isSSHSession: Bool
    let sshConnectionString: String?
    let remoteWorkingDirectory: String?
    let fetchedFileContent: String?
    let fetchingFilePath: String?
    let onFileAction: (String) -> Void
    
    var isLikelyFilePath: Bool {
        // 1. Explicit paths
        if text.hasPrefix("/") || text.hasPrefix("~") || text.hasPrefix("./") || text.hasPrefix("../") { return true }
        
        // 2. Files with extensions (containing .)
        // Exclude colons (headers), urls, and very long lines
        if text.contains(".") && !text.contains(":") && !text.contains("http") && text.count < 150 {
            return true
        }
        
        // 3. Single words (could be directories or files without extension)
        // Check for spaces.
        if !text.contains(" ") && !text.contains(":") && text.count < 60 {
            return true
        }
        
        return false
    }
    
    // Is this a multi-column file list?
    var isMultiColumnFileList: Bool {
        // Must have multiple words
        let words = text.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard words.count > 1 else { return false }
        
        // Count how many look like explicit files (have extensions or slashes or specific chars)
        let fileLikeCount = words.filter { 
            ($0.contains(".") && !$0.hasSuffix(".")) || // Extension, ignore end-of-sentence dot
            $0.contains("/") ||
            $0.contains("_") || 
            $0.contains("-") ||
            // Also accept alphanumeric words that are clearly not English sentences if there are many of them
            ($0.rangeOfCharacter(from: .letters) != nil && $0.rangeOfCharacter(from: .decimalDigits) != nil)
        }.count
        
        // If we have many short words (like 'ls' output), it's likely a file list
        // LS output usually doesn't have "is", "the", "and" etc.
        let stopWords = ["the", "is", "at", "on", "in", "of", "and", "to", "a", "error", "warning", "failed"]
        let hasStopWords = words.contains { stopWords.contains($0.lowercased()) }
        if hasStopWords { return false }
        
        // If more than 25% look like files, or we have > 3 items and no stop words
        if Double(fileLikeCount) / Double(words.count) > 0.25 { return true }
        
        // Fallback: if we have > 2 items, no stop words, and avg length is small (file names)
        if words.count > 2 {
            let avgLength = Double(words.reduce(0) { $0 + $1.count }) / Double(words.count)
            if avgLength < 20 { return true }
        }
        
        return false
    }

    var body: some View {
        // Simple logic for now: check if it looks like a key-value pair or file
        if text.contains(":") && !text.contains("http") && !text.contains("://") && text.count < 100 {
            KeyValueLineView(text: text)
        } else if isDeepParsing && isMultiColumnFileList {
            if isInteractive {
                TokenizedFileListView(
                    text: text,
                    currentDirectory: currentDirectory,
                    isSSHSession: isSSHSession,
                    sshConnectionString: sshConnectionString,
                    remoteWorkingDirectory: remoteWorkingDirectory,
                    fetchedFileContent: fetchedFileContent,
                    fetchingFilePath: fetchingFilePath,
                    onFileAction: onFileAction
                )
            } else {
                Text(text)
                    .font(VeloDesign.Typography.monoSmall)
                    .foregroundColor(VeloDesign.Colors.textPrimary)
            }
        } else if isDeepParsing && isLikelyFilePath {
            // Likely a file path
            if isInteractive {
                FilePathLineView(
                    path: text,
                    currentDirectory: currentDirectory,
                    isSSHSession: isSSHSession,
                    sshConnectionString: sshConnectionString,
                    remoteWorkingDirectory: remoteWorkingDirectory,
                    onFileAction: onFileAction
                )
            } else {
                // Non-interactive path
                Text(text)
                    .font(VeloDesign.Typography.monoSmall)
                    .foregroundColor(VeloDesign.Colors.textPrimary)
            }
        } else {
            // Standard text (or ANSI parsed)
            HStack(alignment: .top, spacing: 8) {
                Text(attributedText)
                    .font(VeloDesign.Typography.monoSmall)
                    .foregroundColor(isError ? VeloDesign.Colors.error : VeloDesign.Colors.textPrimary)
                    .lineLimit(nil)
                    .textSelection(.enabled)
                
                if isError {
                    Button(action: {
                        NotificationCenter.default.post(
                            name: .askAI,
                            object: nil,
                            userInfo: ["query": "Explain this error: \(text)"]
                        )
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                            Text("Ask AI")
                        }
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(VeloDesign.Colors.neonPurple)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(VeloDesign.Colors.neonPurple.opacity(0.1))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(VeloDesign.Colors.neonPurple.opacity(0.3), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Key Value Line View
struct KeyValueLineView: View {
    let text: String
    
    var body: some View {
        let parts = text.split(separator: ":", maxSplits: 1).map(String.init)
        if parts.count == 2 {
            HStack(spacing: 4) {
                Text(parts[0] + ":")
                    .font(VeloDesign.Typography.monoSmall.weight(.medium))
                    .foregroundColor(VeloDesign.Colors.neonCyan)
                
                Text(parts[1])
                    .font(VeloDesign.Typography.monoSmall)
                    .foregroundColor(VeloDesign.Colors.textSecondary)
            }
        } else {
            Text(text)
                .font(VeloDesign.Typography.monoSmall)
                .foregroundColor(VeloDesign.Colors.textPrimary)
        }
    }
}

// MARK: - Tokenized File List View
struct TokenizedFileListView: View {
    let text: String
    let currentDirectory: String
    let isSSHSession: Bool
    let sshConnectionString: String?
    let remoteWorkingDirectory: String?
    let fetchedFileContent: String?
    let fetchingFilePath: String?
    let onFileAction: (String) -> Void
    
    var body: some View {
        if isSSHSession {
            // SSH: Vertical list layout with icons (like local view)
            SSHFileListView(
                text: text,
                currentDirectory: currentDirectory,
                sshConnectionString: sshConnectionString,
                remoteWorkingDirectory: remoteWorkingDirectory,
                fetchedFileContent: fetchedFileContent,
                fetchingFilePath: fetchingFilePath,
                onFileAction: onFileAction
            )
        } else {
            // Local: Horizontal inline layout
            HStack(spacing: 0) {
                let tokens = parseLine(text)
                
                ForEach(tokens) { token in
                    if token.isWhitespace {
                        Text(token.text)
                            .font(VeloDesign.Typography.monoSmall)
                            .fixedSize(horizontal: true, vertical: false)
                    } else {
                        InteractiveFileView(
                            filename: token.text,
                            currentDirectory: currentDirectory,
                            onAction: onFileAction,
                            isSSHSession: false,
                            sshConnectionString: nil,
                            remoteWorkingDirectory: nil,
                            style: .inline
                        )
                    }
                }
            }
        }
    }
    
    struct Token: Identifiable {
        let id = UUID()
        let text: String
        let isWhitespace: Bool
    }
    
    private func parseLine(_ line: String) -> [Token] {
        var tokens: [Token] = []
        let scanner = Scanner(string: line)
        scanner.charactersToBeSkipped = nil
        
        while !scanner.isAtEnd {
            if let whitespace = scanner.scanCharacters(from: .whitespaces) {
                tokens.append(Token(text: whitespace, isWhitespace: true))
            } else if let word = scanner.scanUpToCharacters(from: .whitespaces) {
                tokens.append(Token(text: word, isWhitespace: false))
            } else {
                _ = scanner.scanCharacter()
            }
        }
        return tokens
    }
}

// MARK: - SSH File List View (Vertical Layout)
struct SSHFileListView: View {
    let text: String
    let currentDirectory: String
    let sshConnectionString: String?
    let remoteWorkingDirectory: String?
    let fetchedFileContent: String?
    let fetchingFilePath: String?
    let onFileAction: (String) -> Void
    
    private var fileItems: [String] {
        // Split by BOTH whitespace AND newlines to handle all cases
        let separators = CharacterSet.whitespacesAndNewlines
        let items = text.components(separatedBy: separators)
            .map { $0.cleanANSI() }
            .filter { isValidFileItem($0) }
        
        // Remove duplicates while preserving order
        var seen = Set<String>()
        return items.filter { item in
            if seen.contains(item) {
                return false
            }
            seen.insert(item)
            return true
        }
    }
    
    private func isValidFileItem(_ item: String) -> Bool {
        let trimmed = item.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Must have at least 1 character
        guard !trimmed.isEmpty else { return false }
        
        // Skip very short items
        guard trimmed.count >= 2 else { return false }
        
        // Skip common error message words
        let errorWords = ["ls:", "cannot", "access", "No", "such", "file", "or", "directory", "error", "Error", "failed", "Failed", "Permission", "denied", "not", "found", "command"]
        if errorWords.contains(trimmed) || errorWords.contains(trimmed.lowercased()) { return false }
        
        // Skip items ending with : (like "ls:")
        if trimmed.hasSuffix(":") && !trimmed.hasPrefix("/") { return false }
        
        // Skip ANSI/control sequence patterns
        if trimmed.contains("]0;") || trimmed.contains("]1;") || trimmed.contains("]2;") { return false }
        if trimmed.hasPrefix("]") { return false }
        if trimmed.hasPrefix("[") && trimmed.contains(";") { return false }
        
        // Skip shell escape sequences like $'\n\n' or 'text'
        if trimmed.contains("$'") { return false }
        if trimmed.contains("'\\n") { return false }
        if trimmed.contains("\\n'") { return false }
        if trimmed.hasPrefix("'") && trimmed.hasSuffix("'") { return false }
        // Skip items starting with ' (shell quoting)
        if trimmed.hasPrefix("'") { return false }
        
        // Skip prompts (contain @ and # or $)
        if trimmed.contains("@") && (trimmed.contains("#") || trimmed.contains("$")) { return false }
        
        // Skip items with @ and : that look like prompts (e.g., "root@mail:")
        if trimmed.contains("@") && trimmed.contains(":") { return false }
        
        // Skip internal commands
        if trimmed.hasPrefix("__") { return false }
        
        // Skip items that contain literal newline sequences
        if trimmed.contains("\\n") { return false }
        if trimmed.contains("\n") { return false }
        
        // Skip items that start with control characters
        if let first = trimmed.first, first.asciiValue ?? 0 < 32 { return false }
        
        return true
    }
    
    private func cleanRemoteCWD() -> String {
        guard let cwd = remoteWorkingDirectory else { 
            print("📂 [SSHFileList] cleanRemoteCWD - original: nil")
            return "" 
        }
        print("📂 [SSHFileList] cleanRemoteCWD - original: '\(cwd)'")
        var cleaned = cwd.cleanANSI()
        print("📂 [SSHFileList] cleanRemoteCWD - after ANSI clean: '\(cleaned)'")
        // Remove trailing slash to prevent double slashes
        if cleaned.hasSuffix("/") && cleaned.count > 1 {
            cleaned = String(cleaned.dropLast())
        }
        print("📂 [SSHFileList] cleanRemoteCWD - final: '\(cleaned)'")
        return cleaned
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(fileItems, id: \.self) { item in
                SSHFileRowView(
                    filename: item,
                    currentDirectory: currentDirectory,
                    sshConnectionString: sshConnectionString,
                    remoteWorkingDirectory: cleanRemoteCWD(),
                    fetchedFileContent: fetchedFileContent,
                    fetchingFilePath: fetchingFilePath,
                    onFileAction: onFileAction
                )
            }
        }
    }
}

struct RemoteEditorConfig: Identifiable {
    let id = UUID()
    let filename: String
    let remotePath: String
    let sshConnectionString: String
    let content: String
}

// MARK: - SSH File Row View
struct SSHFileRowView: View {
    let filename: String
    let currentDirectory: String
    let sshConnectionString: String?
    let remoteWorkingDirectory: String?
    let fetchedFileContent: String?
    let fetchingFilePath: String?
    let onFileAction: (String) -> Void
    
    @State private var isHovered = false
    @State private var showingMenu = false
    @State private var editorConfig: RemoteEditorConfig?
    @State private var isLoadingContent = false
    
    private var isFolder: Bool {
        // Folder if: trailing slash OR no file extension
        filename.hasSuffix("/") || !filename.contains(".")
    }
    
    private var displayName: String {
        // Remove trailing slash for display
        filename.hasSuffix("/") ? String(filename.dropLast()) : filename
    }
    
    private var icon: String {
        if isFolder {
            return "folder.fill"
        }
        // Detect file type icon
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "png", "jpg", "jpeg", "gif", "webp", "heic", "svg", "ico":
            return "photo.fill"
        case "mp4", "mov", "avi", "mkv", "m4v", "webm":
            return "play.rectangle.fill"
        case "mp3", "wav", "aac", "flac", "m4a":
            return "waveform"
        case "swift", "py", "js", "ts", "java", "c", "cpp", "go", "rs", "rb", "php", "html", "css", "json", "xml", "yaml", "yml":
            return "doc.text.fill"
        case "sh", "bash", "zsh", "command":
            return "terminal.fill"
        case "zip", "tar", "gz", "rar", "7z", "dmg", "pkg":
            return "doc.zipper"
        case "pdf":
            return "doc.richtext.fill"
        default:
            return "doc.fill"
        }
    }
    
    private var iconColor: Color {
        if isFolder {
            return VeloDesign.Colors.neonCyan
        }
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "png", "jpg", "jpeg", "gif", "webp", "heic", "svg":
            return VeloDesign.Colors.neonPurple
        case "mp4", "mov", "avi", "mkv":
            return VeloDesign.Colors.error
        case "swift", "py", "js", "ts", "java":
            return VeloDesign.Colors.neonGreen
        case "sh", "bash", "zsh":
            return VeloDesign.Colors.warning
        case "zip", "tar", "gz", "dmg":
            return VeloDesign.Colors.info
        default:
            return VeloDesign.Colors.textSecondary
        }
    }
    
    var body: some View {
        HStack(spacing: VeloDesign.Spacing.sm) {
            // File/Folder Icon
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(iconColor)
                .frame(width: 16)
            
            // Filename
            Text(displayName)
                .font(VeloDesign.Typography.monoSmall)
                .foregroundColor(isHovered ? VeloDesign.Colors.neonCyan : VeloDesign.Colors.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, VeloDesign.Spacing.sm)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isHovered ? VeloDesign.Colors.neonCyan.opacity(0.1) : Color.clear)
        )
        .onHover { hovering in
            withAnimation(VeloDesign.Animation.quick) {
                isHovered = hovering
            }
        }
        .onTapGesture {
            showingMenu = true
        }
        .popover(isPresented: $showingMenu, arrowEdge: .trailing) {
            // Use existing file action menu via InteractiveFileView's FileInfo
            FileActionMenu(
                fileInfo: FileInfo(
                    name: filename,
                    path: buildPath(),
                    type: isFolder ? .folder : FileType.detect(from: filename),
                    isDirectory: isFolder,
                    isRemote: true
                ),
                onAction: { action in
                    showingMenu = false
                    handleAction(action)
                }
            )
        }
        .sheet(item: $editorConfig) { config in
            RemoteFileEditorView(
                filename: config.filename,
                remotePath: config.remotePath,
                sshConnectionString: config.sshConnectionString,
                initialContent: config.content,
                onSave: { newContent in
                    saveFileContent(newContent)
                    // Don't close immediately so user can see toast
                    // editorConfig = nil 
                },
                onCancel: {
                    editorConfig = nil
                }
            )
        }
        .onChange(of: fetchedFileContent) { content in
            if isLoadingContent, let content = content {
                // IMPORTANT: Only update if THIS row is the one that requested it
                let currentPath = buildPath()
                if fetchingFilePath == currentPath || fetchingFilePath == filename {
                    isLoadingContent = false
                    
                    // Create config with the new content - triggering presentation
                    var displayNameClean = filename.cleanANSI()
                    if displayNameClean.hasSuffix("/") { displayNameClean = String(displayNameClean.dropLast()) }
                    
                    editorConfig = RemoteEditorConfig(
                        filename: displayNameClean,
                        remotePath: currentPath,
                        sshConnectionString: sshConnectionString ?? "",
                        content: content
                    )
                }
            }
        }
    }
    
    private func buildPath() -> String {
        let cleanFilename = filename.cleanANSI()
        print("📁 [SSHFileRow] buildPath - filename: '\(filename)' -> cleaned: '\(cleanFilename)'")
        print("📁 [SSHFileRow] remoteCWD: '\(remoteWorkingDirectory ?? "nil")'")
        
        if cleanFilename.hasPrefix("/") {
            print("📁 [SSHFileRow] Result (absolute): '\(cleanFilename)'")
            return cleanFilename
        }
        if let remoteCWD = remoteWorkingDirectory, !remoteCWD.isEmpty {
            let cleanCWD = remoteCWD.cleanANSI()
            // Avoid double slashes
            let base: String
            if cleanCWD == "/" {
                base = "/"
            } else if cleanCWD.hasSuffix("/") {
                base = cleanCWD
            } else {
                base = cleanCWD + "/"
            }
            let result = base + cleanFilename
            print("📁 [SSHFileRow] Result (relative): '\(result)'")
            return result
        }
        print("📁 [SSHFileRow] Result (fallback): '\(cleanFilename)'")
        return cleanFilename
    }
    
    
    private func handleAction(_ action: FileAction) {
        let cleanedPath = buildPath()
        let cleanedName = displayName.cleanANSI()
        
        switch action.command {
        case "__copy_path__":
            print("🔧 [SSHFileRow] Copying path to clipboard: '\(cleanedPath)'")
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(cleanedPath, forType: .string)
        case "__copy_name__":
            print("🔧 [SSHFileRow] Copying name to clipboard: '\(cleanedName)'")
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(cleanedName, forType: .string)
        case "__download_file__":
            print("🔧 [SSHFileRow] Opening download dialog for file")
            showDownloadDialog(isFolder: false)
        case "__download_folder__":
            print("🔧 [SSHFileRow] Opening download dialog for folder")
            showDownloadDialog(isFolder: true)
        case "__rename__":
            print("🔧 [SSHFileRow] Opening rename dialog")
            showRenameDialog()
        case "__edit__":
            print("🔧 [SSHFileRow] Opening file editor")
            loadFileForEditing()
        case "__preview__":
            print("🔧 [SSHFileRow] Preview not applicable for remote files")
            break
        default:
            // Only execute if it's a real command (not internal)
            if !action.command.hasPrefix("__") {
                print("🔧 [SSHFileRow] Executing command: '\(action.command)'")
                onFileAction(action.command)
            } else {
                print("⚠️ [SSHFileRow] Skipping internal command: '\(action.command)'")
            }
        }
    }
    
    private func loadFileForEditing() {
        let path = buildPath()
        
        guard let userHost = sshConnectionString, !userHost.isEmpty else {
            print("❌ [SSHFileRow] No SSH connection string available")
            
            // Show error config
            var displayNameClean = filename.cleanANSI()
            if displayNameClean.hasSuffix("/") { displayNameClean = String(displayNameClean.dropLast()) }
            
            editorConfig = RemoteEditorConfig(
                filename: displayNameClean,
                remotePath: path,
                sshConnectionString: "",
                content: "// Error: No SSH connection information available"
            )
            return
        }
        
        isLoadingContent = true
        
        // Request file content via background SSH fetch
        // Format: __fetch_file__:userHost:::path
        let fetchCommand = "__fetch_file__:\(userHost):::\(path)"
        onFileAction(fetchCommand)
        
        // Don't show editor yet - it will be shown via onChange when content arrives
        // This ensures the editor gets the actual content, not a placeholder
    }
    
    private func saveFileContent(_ content: String) {
        let path = buildPath()
        
        guard let userHost = sshConnectionString, !userHost.isEmpty else {
            print("❌ [SSHFileRow] Cannot save: No SSH connection string")
            return
        }
        
        // Use the new robust background save mechanism via TerminalViewModel
        // Format: __save_file_blob__:userHost:::path:::base64Content
        if let data = content.data(using: .utf8) {
            let base64 = data.base64EncodedString()
            let saveCommand = "__save_file_blob__:\(userHost):::\(path):::\(base64)"
            onFileAction(saveCommand)
        } else {
            print("❌ [SSHFileRow] Failed to encode content for saving")
        }
    }
    
    @State private var showingRenameAlert = false
    @State private var newFileName = ""
    
    private func showRenameDialog() {
        let alert = NSAlert()
        alert.messageText = "Rename File"
        alert.informativeText = "Enter new name for '\(displayName.cleanANSI())':"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.stringValue = displayName.cleanANSI()
        alert.accessoryView = textField
        
        if alert.runModal() == .alertFirstButtonReturn {
            let newName = textField.stringValue.trimmingCharacters(in: .whitespaces)
            if !newName.isEmpty && newName != displayName.cleanANSI() {
                let oldPath = buildPath()
                let parentDir = (oldPath as NSString).deletingLastPathComponent
                let newPath = (parentDir as NSString).appendingPathComponent(newName)
                onFileAction("mv \"\(oldPath)\" \"\(newPath)\"")
            }
        }
    }
    
    private func showDownloadDialog(isFolder: Bool) {
        if isFolder {
            let openPanel = NSOpenPanel()
            openPanel.title = "Select Download Destination"
            openPanel.canChooseFiles = false
            openPanel.canChooseDirectories = true
            openPanel.canCreateDirectories = true
            openPanel.allowsMultipleSelection = false
            openPanel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            openPanel.prompt = "Download Here"
            
            openPanel.begin { response in
                if response == .OK, let url = openPanel.url {
                    performSCPDownload(destinationURL: url, isFolder: true)
                }
            }
        } else {
            let savePanel = NSSavePanel()
            savePanel.title = "Save to Local"
            savePanel.nameFieldStringValue = displayName
            savePanel.canCreateDirectories = true
            savePanel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            
            savePanel.begin { response in
                if response == .OK, let url = savePanel.url {
                    performSCPDownload(destinationURL: url, isFolder: false)
                }
            }
        }
    }
    
    private func performSCPDownload(destinationURL: URL, isFolder: Bool) {
        var localPath = destinationURL.path
        var remotePath = buildPath()
        
        // Remove trailing slash from remote path
        if remotePath.hasSuffix("/") {
            remotePath = String(remotePath.dropLast())
        }
        
        let scpFlag = isFolder ? "-r " : ""
        if isFolder {
            let folderName = (remotePath as NSString).lastPathComponent
            localPath = (localPath as NSString).appendingPathComponent(folderName)
        }
        
        let userHost = sshConnectionString ?? "user@host"
        let downloadCommand = "scp \(scpFlag)\(userHost):\"\(remotePath)\" \"\(localPath)\""
        onFileAction("__download_scp__:\(downloadCommand)")
    }
}


// MARK: - File Path Line View
struct FilePathLineView: View {
    let path: String
    let currentDirectory: String
    let isSSHSession: Bool
    let sshConnectionString: String?
    let remoteWorkingDirectory: String?
    let onFileAction: (String) -> Void
    
    var body: some View {
        InteractiveFileView(
            filename: path,
            currentDirectory: currentDirectory,
            onAction: onFileAction,
            isSSHSession: isSSHSession,
            sshConnectionString: sshConnectionString,
            remoteWorkingDirectory: remoteWorkingDirectory
        )
    }
}


