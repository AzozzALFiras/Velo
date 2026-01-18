//
//  FilesModels.swift
//  Velo
//
//  Models and enums for the Files feature.
//  Provides type-safe representations for file operations and UI state.
//

import Foundation

// MARK: - Files Section Navigation

enum FilesSection: String, CaseIterable, Identifiable {
    case browser = "Browser"
    case favorites = "Favorites"
    case recent = "Recent"
    case transfers = "Transfers"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .browser: return "folder"
        case .favorites: return "star"
        case .recent: return "clock"
        case .transfers: return "arrow.up.arrow.down"
        }
    }

    var localizedTitle: String {
        switch self {
        case .browser: return "files.section.browser".localized
        case .favorites: return "files.section.favorites".localized
        case .recent: return "files.section.recent".localized
        case .transfers: return "files.section.transfers".localized
        }
    }
}

// MARK: - Quick Access Locations

struct QuickAccessLocation: Identifiable, Equatable, Codable {
    let id: UUID
    let name: String
    let path: String
    let icon: String
    let isSystem: Bool

    init(id: UUID = UUID(), name: String, path: String, icon: String, isSystem: Bool = false) {
        self.id = id
        self.name = name
        self.path = path
        self.icon = icon
        self.isSystem = isSystem
    }

    static let defaultLocations: [QuickAccessLocation] = [
        QuickAccessLocation(name: "Root", path: "/", icon: "externaldrive", isSystem: true),
        QuickAccessLocation(name: "Home", path: "~", icon: "house", isSystem: true),
        QuickAccessLocation(name: "Web Root", path: "/var/www", icon: "globe", isSystem: true),
        QuickAccessLocation(name: "Nginx Sites", path: "/etc/nginx/sites-available", icon: "server.rack", isSystem: true),
        QuickAccessLocation(name: "Logs", path: "/var/log", icon: "doc.text", isSystem: true),
        QuickAccessLocation(name: "Temp", path: "/tmp", icon: "clock.arrow.circlepath", isSystem: true)
    ]
}

// MARK: - File Sort Options

enum FileSortOption: String, CaseIterable, Identifiable {
    case name = "Name"
    case size = "Size"
    case modified = "Modified"
    case type = "Type"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .name: return "textformat"
        case .size: return "internaldrive"
        case .modified: return "calendar"
        case .type: return "doc"
        }
    }
}

enum SortDirection {
    case ascending
    case descending

    mutating func toggle() {
        self = self == .ascending ? .descending : .ascending
    }
}

// MARK: - File View Mode

enum FileViewMode: String, CaseIterable {
    case list = "List"
    case grid = "Grid"
    case columns = "Columns"

    var icon: String {
        switch self {
        case .list: return "list.bullet"
        case .grid: return "square.grid.2x2"
        case .columns: return "rectangle.split.3x1"
        }
    }
}

// MARK: - File Operations

enum FileOperation: Identifiable, Equatable {
    case upload(files: [URL], destination: String)
    case download(file: ServerFileItem, localPath: URL)
    case delete(file: ServerFileItem)
    case rename(file: ServerFileItem, newName: String)
    case move(file: ServerFileItem, destination: String)
    case copy(file: ServerFileItem, destination: String)
    case changePermissions(file: ServerFileItem, permissions: String)
    case changeOwner(file: ServerFileItem, owner: String, group: String)
    case createFolder(path: String, name: String)
    case createFile(path: String, name: String)

    var id: String {
        switch self {
        case .upload(let files, let dest): return "upload-\(files.count)-\(dest)"
        case .download(let file, _): return "download-\(file.id)"
        case .delete(let file): return "delete-\(file.id)"
        case .rename(let file, let name): return "rename-\(file.id)-\(name)"
        case .move(let file, let dest): return "move-\(file.id)-\(dest)"
        case .copy(let file, let dest): return "copy-\(file.id)-\(dest)"
        case .changePermissions(let file, let perms): return "chmod-\(file.id)-\(perms)"
        case .changeOwner(let file, let owner, _): return "chown-\(file.id)-\(owner)"
        case .createFolder(let path, let name): return "mkdir-\(path)-\(name)"
        case .createFile(let path, let name): return "touch-\(path)-\(name)"
        }
    }

    var displayName: String {
        switch self {
        case .upload: return "files.operation.upload".localized
        case .download: return "files.operation.download".localized
        case .delete: return "files.operation.delete".localized
        case .rename: return "files.operation.rename".localized
        case .move: return "files.operation.move".localized
        case .copy: return "files.operation.copy".localized
        case .changePermissions: return "files.operation.permissions".localized
        case .changeOwner: return "files.operation.owner".localized
        case .createFolder: return "files.operation.createFolder".localized
        case .createFile: return "files.operation.createFile".localized
        }
    }

    var icon: String {
        switch self {
        case .upload: return "arrow.up.doc"
        case .download: return "arrow.down.doc"
        case .delete: return "trash"
        case .rename: return "pencil"
        case .move: return "arrow.right.doc.on.clipboard"
        case .copy: return "doc.on.doc"
        case .changePermissions: return "lock.shield"
        case .changeOwner: return "person.badge.key"
        case .createFolder: return "folder.badge.plus"
        case .createFile: return "doc.badge.plus"
        }
    }
}

// MARK: - File Transfer State

enum TransferState: Equatable {
    case pending
    case inProgress(progress: Double)
    case completed
    case failed(error: String)
    case cancelled

    var isActive: Bool {
        switch self {
        case .pending, .inProgress: return true
        default: return false
        }
    }
}

struct FileTransferTask: Identifiable, Equatable {
    let id: UUID
    let fileName: String
    let filePath: String
    let isUpload: Bool
    let totalBytes: Int64
    var transferredBytes: Int64
    var state: TransferState
    let startTime: Date

    init(
        id: UUID = UUID(),
        fileName: String,
        filePath: String,
        isUpload: Bool,
        totalBytes: Int64 = 0,
        transferredBytes: Int64 = 0,
        state: TransferState = .pending,
        startTime: Date = Date()
    ) {
        self.id = id
        self.fileName = fileName
        self.filePath = filePath
        self.isUpload = isUpload
        self.totalBytes = totalBytes
        self.transferredBytes = transferredBytes
        self.state = state
        self.startTime = startTime
    }

    var progress: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(transferredBytes) / Double(totalBytes)
    }

    var progressPercentage: Int {
        Int(progress * 100)
    }

    var transferredString: String {
        ByteCountFormatter.string(fromByteCount: transferredBytes, countStyle: .file)
    }

    var totalString: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }

    static func == (lhs: FileTransferTask, rhs: FileTransferTask) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - File Type Classification

enum FileTypeCategory {
    case folder
    case document
    case code
    case config
    case image
    case archive
    case log
    case executable
    case other

    var icon: String {
        switch self {
        case .folder: return "folder.fill"
        case .document: return "doc.text.fill"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .config: return "gearshape.fill"
        case .image: return "photo.fill"
        case .archive: return "archivebox.fill"
        case .log: return "doc.plaintext.fill"
        case .executable: return "terminal.fill"
        case .other: return "doc.fill"
        }
    }

    var color: String {
        switch self {
        case .folder: return "4AA9FF"
        case .document: return "94A3B8"
        case .code: return "10B981"
        case .config: return "F59E0B"
        case .image: return "EC4899"
        case .archive: return "8B5CF6"
        case .log: return "64748B"
        case .executable: return "EF4444"
        case .other: return "94A3B8"
        }
    }

    static func from(fileName: String, isDirectory: Bool) -> FileTypeCategory {
        if isDirectory { return .folder }

        let ext = fileName.lowercased().components(separatedBy: ".").last ?? ""

        switch ext {
        // Code files
        case "swift", "js", "ts", "tsx", "jsx", "py", "rb", "go", "rs", "java", "kt", "cpp", "c", "h", "m", "cs", "php", "vue", "svelte":
            return .code

        // Config files
        case "json", "yaml", "yml", "toml", "xml", "ini", "conf", "cfg", "env", "htaccess", "plist":
            return .config

        // Documents
        case "md", "txt", "rtf", "pdf", "doc", "docx", "csv", "html", "htm", "css", "scss", "sass", "less":
            return .document

        // Images
        case "png", "jpg", "jpeg", "gif", "svg", "webp", "ico", "bmp", "tiff":
            return .image

        // Archives
        case "zip", "tar", "gz", "rar", "7z", "bz2", "xz", "tgz":
            return .archive

        // Logs
        case "log":
            return .log

        // Executables/Scripts
        case "sh", "bash", "zsh", "fish", "ps1", "bat", "cmd", "bin":
            return .executable

        default:
            return .other
        }
    }
}

// MARK: - Extended File Info

struct ExtendedFileInfo: Equatable {
    let path: String
    let name: String
    let isDirectory: Bool
    let isSymlink: Bool
    let symlinkTarget: String?
    let sizeBytes: Int64
    let permissions: String
    let numericPermissions: Int
    let owner: String
    let group: String
    let modificationDate: Date
    let accessDate: Date?
    let creationDate: Date?
    let inode: Int?
    let linkCount: Int?
    let mimeType: String?

    var fileType: FileTypeCategory {
        FileTypeCategory.from(fileName: name, isDirectory: isDirectory)
    }

    var sizeString: String {
        if isDirectory { return "--" }
        return ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }

    var symbolicPermissions: String {
        let p = numericPermissions
        let owner = formatTrip(p / 100)
        let group = formatTrip((p / 10) % 10)
        let world = formatTrip(p % 10)
        return (isDirectory ? "d" : (isSymlink ? "l" : "-")) + owner + group + world
    }

    private func formatTrip(_ n: Int) -> String {
        let r = (n & 4) != 0 ? "r" : "-"
        let w = (n & 2) != 0 ? "w" : "-"
        let x = (n & 1) != 0 ? "x" : "-"
        return r + w + x
    }
}

// MARK: - Clipboard State

struct FileClipboard: Equatable {
    enum Operation {
        case copy
        case cut
    }

    let files: [ServerFileItem]
    let operation: Operation
    let sourcePath: String

    var isEmpty: Bool { files.isEmpty }
}
