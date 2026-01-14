//
//  FileSystemManager.swift
//  Velo
//
//  Dashboard - File System Navigation & Management
//

import Foundation
import SwiftUI
import Combine

/// Types of files recognized by the dashboard explorer
public enum IntelligenceFileType: String, Codable {
    case file, folder, image, video
}

/// Represents a file or folder in the dashboard explorer
struct FileItem: Identifiable, Hashable {
    let id: String // Absolute path
    let name: String
    let path: String
    let isDirectory: Bool
    let type: IntelligenceFileType
    var isExpanded: Bool = false
    var children: [FileItem]? = nil
    
    var size: Int64?
    var modificationDate: Date?
    
    // For hashable/equatable
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
class FileExplorerManager: ObservableObject {
    @Published var rootItems: [FileItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // SSH support
    var isSSH: Bool = false
    var sshConnectionString: String? = nil
    
    private let fileManager = FileManager.default
    private var sshLSProcess: PTYProcess?
    
    /// Load files for a specific directory
    func loadDirectory(_ path: String, into item: FileItem? = nil) async {
        isLoading = true
        defer { isLoading = false }
        
        if isSSH, let host = sshConnectionString {
            await loadRemoteDirectory(path, sshHost: host, into: item)
            return
        }
        
        // Local logic (existing)
        do {
            let urls = try fileManager.contentsOfDirectory(at: URL(fileURLWithPath: path),
                                                           includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
                                                           options: [.skipsHiddenFiles])
            
            let loadedItems = urls.map { url -> FileItem in
                let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey])
                let isDir = resourceValues?.isDirectory ?? false
                let name = url.lastPathComponent
                let fullPath = url.path
                
                return FileItem(
                    id: fullPath,
                    name: name,
                    path: fullPath,
                    isDirectory: isDir,
                    type: isDir ? .folder : detectType(from: name),
                    children: isDir ? [] : nil,
                    size: Int64(resourceValues?.fileSize ?? 0),
                    modificationDate: resourceValues?.contentModificationDate
                )
            }.sorted { (a, b) in
                if a.isDirectory != b.isDirectory {
                    return a.isDirectory // Folders first
                }
                return a.name.lowercased() < b.name.lowercased()
            }
            
            if let targetItem = item {
                // Update children of an existing item
                if let index = findItemIndex(path: targetItem.path) {
                    // Update the tree
                    updateChildren(at: index, with: loadedItems)
                }
            } else {
                rootItems = loadedItems
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func loadRemoteDirectory(_ path: String, sshHost: String, into item: FileItem? = nil) async {
        print("📂 [FileExplorer] Loading remote directory: '\(path)' via \(sshHost)")
        
        let targetDirectory = path.isEmpty ? "~" : path
        let delimiter = "---VELO-FILES-START---"
        
        // Find saved password if available
        var passwordToInject: String?
        let userHostParts = sshHost.components(separatedBy: "@")
        let username = userHostParts.first ?? ""
        let host = userHostParts.last ?? ""
        
        // Use SSHManager to look up connection and password
        let manager = SSHManager()
        if let conn = manager.connections.first(where: { $0.host == host && $0.username == username }) {
            if let pwd = manager.getPassword(for: conn) {
                print("🔑 [FileExplorer] Found password for \(sshHost)")
                passwordToInject = pwd
            }
        }
        
        let result = await withCheckedContinuation { (continuation: CheckedContinuation<(String, Error?), Never>) in
            var accumulatedOutput = ""
            var passwordInjected = false
            
            let pty = PTYProcess { [weak self] text in
                accumulatedOutput += text
                
                // Handle password prompt injection
                let lowerText = text.lowercased()
                if !passwordInjected && (lowerText.contains("password:") || lowerText.contains("passphrase:")) {
                    if let pwd = passwordToInject {
                        print("🔐 [FileExplorer] Injecting password for directory load")
                        // Wait a tiny bit for the prompt to be fully ready
                        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                            self?.sshLSProcess?.write(pwd + "\n")
                        }
                        passwordInjected = true
                    }
                }
            }
            
            self.sshLSProcess = pty
            
            let escapedPath = targetDirectory.replacingOccurrences(of: "'", with: "'\\''")
            // Use ls -1ap for clear listing with file types.
            let lsCommand = "ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \(sshHost) \"echo '\(delimiter)'; ls -1ap --color=never '\(escapedPath)'\""
            
            var env = ProcessInfo.processInfo.environment
            env["SSH_ASKPASS"] = ""
            
            do {
                try pty.execute(
                    command: lsCommand,
                    environment: env,
                    workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path
                )
                
                DispatchQueue.global().async { [weak self] in
                    let exitCode = pty.waitForExit()
                    print("📝 [FileExplorer] SSH ls exited with code: \(exitCode)")
                    
                    self?.sshLSProcess = nil
                    
                    if exitCode != 0 {
                        let errorMsg = accumulatedOutput.lowercased().contains("permission denied") 
                            ? "Permission denied (password). Ensure credentials are saved in SSH Settings."
                            : "SSH exit code \(exitCode)"
                        continuation.resume(returning: (accumulatedOutput, NSError(domain: "VeloSSH", code: Int(exitCode), userInfo: [NSLocalizedDescriptionKey: errorMsg])))
                        return
                    }
                    
                    // Split by delimiter to ignore banners/prompts
                    if let range = accumulatedOutput.range(of: delimiter) {
                        let actualOutput = String(accumulatedOutput[range.upperBound...])
                        continuation.resume(returning: (actualOutput, nil))
                    } else {
                        // If delimiter didn't appear, return what we have
                        let cleaned = accumulatedOutput.replacingOccurrences(of: lsCommand, with: "")
                        continuation.resume(returning: (cleaned, nil))
                    }
                }
            } catch {
                continuation.resume(returning: ("", error))
            }
        }
        
        if let error = result.1 {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
            return
        }
        
        let output = result.0
        // We always parse if the command succeeded, to allow for empty directories.
        // We only skip if the output is suspiciously large and delimiter-less (likely a banner mess).
        if output.count < 10000 {
            await parseAndUpdateItems(output: output, path: path, sshHost: sshHost, item: item)
        } else if output.contains(delimiter) {
            await parseAndUpdateItems(output: output, path: path, sshHost: sshHost, item: item)
        }
    }
    
    private func parseAndUpdateItems(output: String, path: String, sshHost: String, item: FileItem?) async {
        // Clean ANSI/OSC sequences aggressively
        var cleanedOutput = output
        // Remove OSC sequences: BEL or ST terminated
        cleanedOutput = cleanedOutput.replacingOccurrences(of: "\u{1B}\\][^\u{07}\u{1B}]*[\u{07}]", with: "", options: .regularExpression)
        cleanedOutput = cleanedOutput.replacingOccurrences(of: "\u{1B}\\][^\u{07}\u{1B}]*\\u{1B}\\\\", with: "", options: .regularExpression)
        // Remove CSI sequences (colors, etc.)
        cleanedOutput = cleanedOutput.replacingOccurrences(of: "\u{1B}\\[[0-9;?]*[a-zA-Z]", with: "", options: .regularExpression)
        // Remove naked ESC and BEL
        cleanedOutput = cleanedOutput.replacingOccurrences(of: "\u{1B}", with: "")
        cleanedOutput = cleanedOutput.replacingOccurrences(of: "\u{07}", with: "")
        
        let lines = cleanedOutput.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { line in
                // Extremely important: filter out terminal junk
                !line.isEmpty && 
                line != "./" && 
                line != "../" && 
                !line.contains("Welcome to") &&
                !line.contains("Last login:") &&
                !line.hasPrefix("ls -") &&
                !line.contains("root@") && // Avoid prompts appearing as files
                !line.contains("[") // Simple check for bracketed prompts
            }
        
        print("📂 [FileExplorer] Parsed \(lines.count) items for \(path)")
        
        let loadedItems = lines.map { line -> FileItem in
            let isDir = line.hasSuffix("/")
            let name = isDir ? String(line.dropLast()) : line
            
            let separator = path.hasSuffix("/") ? "" : "/"
            let fullPath = "\(path)\(separator)\(name)"
            
            return FileItem(
                id: "ssh:\(sshHost):\(fullPath)",
                name: name,
                path: fullPath,
                isDirectory: isDir,
                type: isDir ? .folder : detectType(from: name),
                children: isDir ? [] : nil,
                size: nil,
                modificationDate: nil
            )
        }.sorted { (a, b) in
            if a.isDirectory != b.isDirectory {
                return a.isDirectory
            }
            return a.name.lowercased() < b.name.lowercased()
        }
        
        await MainActor.run {
            if let targetItem = item {
                if let index = findItemIndex(path: targetItem.path) {
                    updateChildren(at: index, with: loadedItems)
                }
            } else {
                rootItems = loadedItems
            }
        }
    }
    
    private func findItemIndex(path: String, in items: [FileItem]? = nil) -> [Int]? {
        let list = items ?? rootItems
        for (index, item) in list.enumerated() {
            if item.path == path {
                return [index]
            }
            if let children = item.children, let subIndex = findItemIndex(path: path, in: children) {
                return [index] + subIndex
            }
        }
        return nil
    }
    
    private func updateChildren(at index: [Int], with newChildren: [FileItem]) {
        // Implementation for updating nested item children
        // For simplicity in SwiftUI, it's often better to use a flat structure or nested Observables
        // But for this use case, we'll update the rootItems tree
        rootItems = updatedTree(items: rootItems, at: index, with: newChildren)
    }
    
    private func updatedTree(items: [FileItem], at index: [Int], with newChildren: [FileItem]) -> [FileItem] {
        var copy = items
        guard !index.isEmpty else { return items }
        
        let first = index[0]
        if index.count == 1 {
            var item = copy[first]
            item.children = newChildren
            copy[first] = item
        } else {
            var item = copy[first]
            if let children = item.children {
                item.children = updatedTree(items: children, at: Array(index.dropFirst()), with: newChildren)
                copy[first] = item
            }
        }
        return copy
    }
    
    func toggleExpansion(path: String) {
        rootItems = toggledTree(items: rootItems, path: path)
    }
    
    private func toggledTree(items: [FileItem], path: String) -> [FileItem] {
        var copy = items
        for i in 0..<copy.count {
            if copy[i].path == path {
                copy[i].isExpanded.toggle()
                // If it was expanded, load children if empty
                if copy[i].isExpanded && (copy[i].children == nil || copy[i].children!.isEmpty) {
                    let taskPath = path
                    let taskItem = copy[i]
                    Task {
                        await loadDirectory(taskPath, into: taskItem)
                    }
                }
                return copy
            }
            if let children = copy[i].children {
                let updatedChildren = toggledTree(items: children, path: path)
                if updatedChildren != children {
                    copy[i].children = updatedChildren
                    return copy
                }
            }
        }
        return copy
    }
    
    private func detectType(from filename: String) -> IntelligenceFileType {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "png", "jpg", "jpeg", "gif", "webp", "svg": return .image
        case "mp4", "mov", "avi": return .video
        case "swift", "py", "js", "ts", "php", "html", "css", "json", "md": return .file
        default: return .file
        }
    }
    
    // Actions
    func rename(item: FileItem, to newName: String) {
        let newPath = (item.path as NSString).deletingLastPathComponent + "/" + newName
        do {
            try fileManager.moveItem(atPath: item.path, toPath: newPath)
            // Reload parent or update tree
            // To keep it simple, we reload root for now or the parent if we tracked it
            // For now let's just refresh everything or update the item in place
            refreshTree()
        } catch {
            errorMessage = "Rename failed: \(error.localizedDescription)"
        }
    }
    
    func refreshTree() {
        // Ideally reload what's expanded, but for now just reload root
        // This is a placeholder for better sync logic
    }
}
