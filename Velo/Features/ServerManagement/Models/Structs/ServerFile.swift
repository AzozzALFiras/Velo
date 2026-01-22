import Foundation

public struct ServerFileItem: Identifiable, Hashable, Codable {
    public let id = UUID()
    public var name: String
    public var path: String
    public var isDirectory: Bool
    public var sizeBytes: Int64
    public var permissions: String // e.g., "755"
    public var modificationDate: Date
    public var owner: String
    
    public init(name: String, path: String, isDirectory: Bool, sizeBytes: Int64, permissions: String, modificationDate: Date, owner: String) {
        self.name = name
        self.path = path
        self.isDirectory = isDirectory
        self.sizeBytes = sizeBytes
        self.permissions = permissions
        self.modificationDate = modificationDate
        self.owner = owner
    }
    
    public var numericPermissions: Int {
        Int(permissions) ?? 644
    }
    
    // Symbolic representation helper (e.g., rwxr-xr-x)
    public var symbolicPermissions: String {
        let p = numericPermissions
        let owner = formatTrip(p / 100)
        let group = formatTrip((p / 10) % 10)
        let world = formatTrip(p % 10)
        return (isDirectory ? "d" : "-") + owner + group + world
    }
    
    private func formatTrip(_ n: Int) -> String {
        let r = (n & 4) != 0 ? "r" : "-"
        let w = (n & 2) != 0 ? "w" : "-"
        let x = (n & 1) != 0 ? "x" : "-"
        return r + w + x
    }
    
    public var sizeString: String {
        if isDirectory { return "--" }
        return ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
    
    public var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: modificationDate)
    }

    public var shortDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: modificationDate)
    }

    /// File extension (lowercase, without dot)
    public var fileExtension: String {
        (name as NSString).pathExtension.lowercased()
    }

    /// Whether this file is a text-based file that can be edited
    public var isTextFile: Bool {
        guard !isDirectory else { return false }

        let textExtensions = [
            // Code files
            "php", "js", "ts", "tsx", "jsx", "py", "rb", "go", "rs", "java", "kt", "cpp", "c", "h", "m", "cs", "swift", "vue", "svelte",
            // Config files
            "json", "yaml", "yml", "toml", "xml", "ini", "conf", "cfg", "env", "htaccess", "plist", "properties",
            // Document files
            "md", "txt", "rtf", "html", "htm", "css", "scss", "sass", "less",
            // Script files
            "sh", "bash", "zsh", "fish", "ps1", "bat", "cmd",
            // Log files
            "log",
            // Data files
            "csv", "sql"
        ]

        return textExtensions.contains(fileExtension)
    }

    /// Maximum file size for editing (1MB)
    public static let maxEditableSize: Int64 = 1_000_000

    /// Whether this file can be safely edited (text file and within size limit)
    public var isEditable: Bool {
        isTextFile && sizeBytes <= Self.maxEditableSize
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: ServerFileItem, rhs: ServerFileItem) -> Bool {
        lhs.id == rhs.id
    }
}

public struct FileUploadTask: Identifiable {
    public let id = UUID()
    public let fileName: String
    public var progress: Double // 0.0 to 1.0
    public var isCompleted: Bool = false
    public var isFailed: Bool = false
    
    public init(fileName: String, progress: Double, isCompleted: Bool = false, isFailed: Bool = false) {
        self.fileName = fileName
        self.progress = progress
        self.isCompleted = isCompleted
        self.isFailed = isFailed
    }
    
    public var progressPercentage: Int {
        Int(progress * 100)
    }
}
