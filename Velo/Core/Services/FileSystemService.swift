//
//  FileSystemService.swift
//  Velo
//
//  Unified file system abstraction for local and remote (SSH) operations
//

import Foundation

// MARK: - File System Item Model

struct FileSystemItem: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let path: String
    let type: ItemType
    let size: Int64?
    let permissions: String?
    let modifiedDate: Date?
    let isHidden: Bool

    enum ItemType: Equatable {
        case file(extension: String?)
        case directory
        case symlink(target: String)
    }

    // MARK: - Icon Detection

    var icon: String {
        switch type {
        case .directory:
            return "folder.fill"
        case .file(let ext):
            return iconForExtension(ext) ?? "doc.fill"
        case .symlink:
            return "link"
        }
    }

    private func iconForExtension(_ ext: String?) -> String? {
        guard let ext = ext?.lowercased() else { return nil }

        switch ext {
        // Programming languages
        case "swift": return "swift"
        case "js", "jsx", "ts", "tsx": return "curlybraces"
        case "py": return "curlybraces"
        case "rb": return "curlybraces"
        case "go": return "curlybraces"
        case "rs": return "curlybraces"
        case "java", "kt": return "curlybraces"
        case "c", "cpp", "h", "hpp": return "curlybraces"
        case "php": return "curlybraces"

        // Data formats
        case "json": return "doc.text.fill"
        case "xml", "yaml", "yml": return "doc.text.fill"
        case "toml", "ini", "conf", "cfg": return "doc.text.fill"
        case "csv": return "tablecells"

        // Documents
        case "md", "markdown": return "doc.plaintext"
        case "txt", "text": return "doc.plaintext"
        case "pdf": return "doc.fill"
        case "doc", "docx": return "doc.text"

        // Images
        case "jpg", "jpeg": return "photo.fill"
        case "png": return "photo.fill"
        case "gif": return "photo.fill"
        case "svg": return "photo.fill"
        case "bmp", "tiff": return "photo.fill"
        case "ico": return "photo.fill"

        // Video
        case "mp4", "mov", "avi": return "film.fill"
        case "mkv", "webm": return "film.fill"

        // Audio
        case "mp3", "wav", "m4a": return "music.note"
        case "aac", "flac": return "music.note"

        // Archives
        case "zip": return "doc.zipper"
        case "tar", "gz", "bz2": return "doc.zipper"
        case "7z", "rar": return "doc.zipper"

        // Executables
        case "app", "exe": return "app.fill"
        case "dmg": return "internaldrive"
        case "pkg": return "shippingbox.fill"

        // Shell scripts
        case "sh", "bash", "zsh": return "terminal.fill"

        default:
            return "doc.fill"
        }
    }

    // MARK: - Helpers

    var isDirectory: Bool {
        if case .directory = type {
            return true
        }
        return false
    }

    var fileExtension: String? {
        if case .file(let ext) = type {
            return ext
        }
        return nil
    }
}

// MARK: - File System Service Protocol

@MainActor
protocol FileSystemService {
    /// List contents of a directory
    func listDirectory(_ path: String) async throws -> [FileSystemItem]

    /// Change current directory and return new path
    func changeDirectory(_ path: String) async throws -> String

    /// Get current working directory
    func getCurrentDirectory() async throws -> String

    /// Create a new directory
    func createDirectory(_ path: String) async throws

    /// Read file contents
    func readFile(_ path: String) async throws -> Data

    /// Write data to file
    func writeFile(_ path: String, content: Data) async throws

    /// Delete a file or directory
    func deleteItem(_ path: String) async throws

    /// Move/rename an item
    func moveItem(from: String, to: String) async throws

    /// Copy an item
    func copyItem(from: String, to: String) async throws

    /// Get metadata for an item
    func getItemInfo(_ path: String) async throws -> FileSystemItem

    /// Check if item exists
    func exists(_ path: String) async throws -> Bool
}

// MARK: - File System Errors

enum FileSystemError: Error, LocalizedError {
    case notFound(String)
    case permissionDenied(String)
    case alreadyExists(String)
    case notADirectory(String)
    case invalidPath(String)
    case operationFailed(String)
    case connectionError(String)

    var errorDescription: String? {
        switch self {
        case .notFound(let path):
            return "File or directory not found: \(path)"
        case .permissionDenied(let path):
            return "Permission denied: \(path)"
        case .alreadyExists(let path):
            return "Item already exists: \(path)"
        case .notADirectory(let path):
            return "Not a directory: \(path)"
        case .invalidPath(let path):
            return "Invalid path: \(path)"
        case .operationFailed(let message):
            return "Operation failed: \(message)"
        case .connectionError(let message):
            return "Connection error: \(message)"
        }
    }
}

// MARK: - Local File System Implementation

@MainActor
class LocalFileSystemService: FileSystemService {
    private let fileManager = FileManager.default

    func listDirectory(_ path: String) async throws -> [FileSystemItem] {
        let expandedPath = NSString(string: path).expandingTildeInPath

        guard fileManager.fileExists(atPath: expandedPath) else {
            throw FileSystemError.notFound(path)
        }

        let contents = try fileManager.contentsOfDirectory(atPath: expandedPath)

        var items: [FileSystemItem] = []
        for item in contents {
            let fullPath = (expandedPath as NSString).appendingPathComponent(item)

            if let fileItem = try? createFileSystemItem(path: fullPath, name: item) {
                items.append(fileItem)
            }
        }

        return items.sorted { item1, item2 in
            // Directories first, then files
            if item1.isDirectory != item2.isDirectory {
                return item1.isDirectory
            }
            return item1.name.localizedCaseInsensitiveCompare(item2.name) == .orderedAscending
        }
    }

    func changeDirectory(_ path: String) async throws -> String {
        let expandedPath = NSString(string: path).expandingTildeInPath

        guard fileManager.fileExists(atPath: expandedPath) else {
            throw FileSystemError.notFound(path)
        }

        var isDir: ObjCBool = false
        guard fileManager.fileExists(atPath: expandedPath, isDirectory: &isDir), isDir.boolValue else {
            throw FileSystemError.notADirectory(path)
        }

        return expandedPath
    }

    func getCurrentDirectory() async throws -> String {
        return fileManager.currentDirectoryPath
    }

    func createDirectory(_ path: String) async throws {
        let expandedPath = NSString(string: path).expandingTildeInPath

        try fileManager.createDirectory(atPath: expandedPath, withIntermediateDirectories: true, attributes: nil)
    }

    func readFile(_ path: String) async throws -> Data {
        let expandedPath = NSString(string: path).expandingTildeInPath

        guard let data = fileManager.contents(atPath: expandedPath) else {
            throw FileSystemError.notFound(path)
        }

        return data
    }

    func writeFile(_ path: String, content: Data) async throws {
        let expandedPath = NSString(string: path).expandingTildeInPath

        guard fileManager.createFile(atPath: expandedPath, contents: content, attributes: nil) else {
            throw FileSystemError.operationFailed("Failed to write file")
        }
    }

    func deleteItem(_ path: String) async throws {
        let expandedPath = NSString(string: path).expandingTildeInPath

        try fileManager.removeItem(atPath: expandedPath)
    }

    func moveItem(from: String, to: String) async throws {
        let fromPath = NSString(string: from).expandingTildeInPath
        let toPath = NSString(string: to).expandingTildeInPath

        try fileManager.moveItem(atPath: fromPath, toPath: toPath)
    }

    func copyItem(from: String, to: String) async throws {
        let fromPath = NSString(string: from).expandingTildeInPath
        let toPath = NSString(string: to).expandingTildeInPath

        try fileManager.copyItem(atPath: fromPath, toPath: toPath)
    }

    func getItemInfo(_ path: String) async throws -> FileSystemItem {
        let expandedPath = NSString(string: path).expandingTildeInPath
        let name = (expandedPath as NSString).lastPathComponent

        return try createFileSystemItem(path: expandedPath, name: name)
    }

    func exists(_ path: String) async throws -> Bool {
        let expandedPath = NSString(string: path).expandingTildeInPath
        return fileManager.fileExists(atPath: expandedPath)
    }

    // MARK: - Helpers

    private func createFileSystemItem(path: String, name: String) throws -> FileSystemItem {
        let attributes = try fileManager.attributesOfItem(atPath: path)

        var isDir: ObjCBool = false
        fileManager.fileExists(atPath: path, isDirectory: &isDir)

        let type: FileSystemItem.ItemType
        if isDir.boolValue {
            type = .directory
        } else {
            let ext = (name as NSString).pathExtension
            type = .file(extension: ext.isEmpty ? nil : ext)
        }

        let size = attributes[.size] as? Int64
        let modifiedDate = attributes[.modificationDate] as? Date
        let posixPerms = attributes[.posixPermissions] as? Int
        let permissions = posixPerms.map { String(format: "%o", $0) }
        let isHidden = name.hasPrefix(".")

        return FileSystemItem(
            name: name,
            path: path,
            type: type,
            size: size,
            permissions: permissions,
            modifiedDate: modifiedDate,
            isHidden: isHidden
        )
    }
}

// MARK: - SSH File System Implementation (Stub)

@MainActor
class SSHFileSystemService: FileSystemService {
    // Note: Full implementation will be in Phase 5
    // This is a stub to complete the infrastructure in Phase 1

    func listDirectory(_ path: String) async throws -> [FileSystemItem] {
        throw FileSystemError.operationFailed("SSH implementation pending - Phase 5")
    }

    func changeDirectory(_ path: String) async throws -> String {
        throw FileSystemError.operationFailed("SSH implementation pending - Phase 5")
    }

    func getCurrentDirectory() async throws -> String {
        throw FileSystemError.operationFailed("SSH implementation pending - Phase 5")
    }

    func createDirectory(_ path: String) async throws {
        throw FileSystemError.operationFailed("SSH implementation pending - Phase 5")
    }

    func readFile(_ path: String) async throws -> Data {
        throw FileSystemError.operationFailed("SSH implementation pending - Phase 5")
    }

    func writeFile(_ path: String, content: Data) async throws {
        throw FileSystemError.operationFailed("SSH implementation pending - Phase 5")
    }

    func deleteItem(_ path: String) async throws {
        throw FileSystemError.operationFailed("SSH implementation pending - Phase 5")
    }

    func moveItem(from: String, to: String) async throws {
        throw FileSystemError.operationFailed("SSH implementation pending - Phase 5")
    }

    func copyItem(from: String, to: String) async throws {
        throw FileSystemError.operationFailed("SSH implementation pending - Phase 5")
    }

    func getItemInfo(_ path: String) async throws -> FileSystemItem {
        throw FileSystemError.operationFailed("SSH implementation pending - Phase 5")
    }

    func exists(_ path: String) async throws -> Bool {
        throw FileSystemError.operationFailed("SSH implementation pending - Phase 5")
    }
}
