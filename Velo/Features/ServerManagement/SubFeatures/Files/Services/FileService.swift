//
//  FileService.swift
//  Velo
//
//  Service layer for server file system operations.
//  Handles all SSH-based file operations with proper error handling.
//

import Foundation

@MainActor
final class FileService {
    static let shared = FileService()

    private let sshBase = SSHBaseService.shared

    private init() {}

    // MARK: - File Listing

    /// Lists files in a directory with full metadata using a single optimized command
    func listFiles(at path: String, via session: TerminalViewModel) async -> Result<[ServerFileItem], FileServiceError> {
        let safePath = path.replacingOccurrences(of: "'", with: "'\\''")

        // Use stat-based listing for comprehensive file info
        // Format: name|type|size|perms|owner|mtime
        let command = """
        cd '\(safePath)' 2>/dev/null && ls -1A 2>/dev/null | while read f; do
            stat --printf='%n|%F|%s|%a|%U|%Y\\n' "$f" 2>/dev/null || echo "$f|unknown|0|644|root|0"
        done
        """

        let result = await sshBase.execute(command, via: session, timeout: 30)

        if result.exitCode != 0 && result.output.isEmpty {
            // Try alternative for macOS/BSD stat
            let bsdCommand = """
            cd '\(safePath)' 2>/dev/null && ls -1A 2>/dev/null | while read f; do
                if [ -d "$f" ]; then
                    t="directory"
                else
                    t="regular file"
                fi
                stat -f '%N|'$t'|%z|%Mp%Lp|%Su|%m' "$f" 2>/dev/null || echo "$f|unknown|0|644|root|0"
            done
            """
            let bsdResult = await sshBase.execute(bsdCommand, via: session, timeout: 30)
            return parseFileList(bsdResult.output, basePath: path)
        }

        return parseFileList(result.output, basePath: path)
    }

    /// Lists files using simple ls for faster response (less metadata)
    func listFilesQuick(at path: String, via session: TerminalViewModel) async -> Result<[ServerFileItem], FileServiceError> {
        let safePath = path.replacingOccurrences(of: "'", with: "'\\''")
        let command = "ls -1AF '\(safePath)' 2>/dev/null"

        let result = await sshBase.execute(command, via: session, timeout: 15)

        guard result.exitCode == 0 || !result.output.isEmpty else {
            return .failure(.listingFailed(path: path, message: "Unable to list directory"))
        }

        let files = result.output
            .components(separatedBy: CharacterSet.newlines)
            .compactMap { line -> ServerFileItem? in
                let name = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !name.isEmpty else { return nil }

                let isDir = name.hasSuffix("/")
                let isLink = name.hasSuffix("@")
                let isExec = name.hasSuffix("*")
                let cleanName = name.trimmingCharacters(in: CharacterSet(charactersIn: "/*@"))

                guard !cleanName.isEmpty else { return nil }

                let fullPath = (path as NSString).appendingPathComponent(cleanName)

                return ServerFileItem(
                    name: cleanName,
                    path: fullPath,
                    isDirectory: isDir,
                    sizeBytes: 0,
                    permissions: isDir ? "755" : "644",
                    modificationDate: Date(),
                    owner: "root"
                )
            }

        return .success(files)
    }

    // MARK: - File Operations

    /// Creates a new directory
    func createDirectory(at path: String, name: String, via session: TerminalViewModel) async -> Result<Void, FileServiceError> {
        let safeName = name.replacingOccurrences(of: "'", with: "'\\''")
            .replacingOccurrences(of: "/", with: "")
        let safePath = path.replacingOccurrences(of: "'", with: "'\\''")
        let fullPath = "\(safePath)/\(safeName)"

        let command = "mkdir -p '\(fullPath)' && echo 'SUCCESS'"
        let result = await sshBase.execute(command, via: session, timeout: 15)

        if result.output.contains("SUCCESS") {
            return .success(())
        }
        return .failure(.operationFailed(operation: "mkdir", message: result.output))
    }

    /// Creates a new empty file
    func createFile(at path: String, name: String, via session: TerminalViewModel) async -> Result<Void, FileServiceError> {
        let safeName = name.replacingOccurrences(of: "'", with: "'\\''")
            .replacingOccurrences(of: "/", with: "")
        let safePath = path.replacingOccurrences(of: "'", with: "'\\''")
        let fullPath = "\(safePath)/\(safeName)"

        let command = "touch '\(fullPath)' && echo 'SUCCESS'"
        let result = await sshBase.execute(command, via: session, timeout: 15)

        if result.output.contains("SUCCESS") {
            return .success(())
        }
        return .failure(.operationFailed(operation: "touch", message: result.output))
    }

    /// Deletes a file or directory
    func delete(file: ServerFileItem, via session: TerminalViewModel) async -> Result<Void, FileServiceError> {
        let safePath = file.path.replacingOccurrences(of: "'", with: "'\\''")
        let command = "rm -rf '\(safePath)' && echo 'SUCCESS'"

        let result = await sshBase.execute(command, via: session, timeout: 30)

        if result.output.contains("SUCCESS") {
            return .success(())
        }
        return .failure(.deleteFailed(path: file.path, message: result.output))
    }

    /// Renames a file or directory
    func rename(file: ServerFileItem, to newName: String, via session: TerminalViewModel) async -> Result<String, FileServiceError> {
        let safeName = newName.replacingOccurrences(of: "'", with: "'\\''")
            .replacingOccurrences(of: "/", with: "")
        let safeOldPath = file.path.replacingOccurrences(of: "'", with: "'\\''")
        let parentPath = (file.path as NSString).deletingLastPathComponent
        let newPath = (parentPath as NSString).appendingPathComponent(safeName)
        let safeNewPath = newPath.replacingOccurrences(of: "'", with: "'\\''")

        let command = "mv '\(safeOldPath)' '\(safeNewPath)' && echo 'SUCCESS'"
        let result = await sshBase.execute(command, via: session, timeout: 15)

        if result.output.contains("SUCCESS") {
            return .success(newPath)
        }
        return .failure(.renameFailed(oldName: file.name, newName: newName, message: result.output))
    }

    /// Changes file permissions
    func changePermissions(file: ServerFileItem, permissions: String, recursive: Bool = false, via session: TerminalViewModel) async -> Result<Void, FileServiceError> {
        guard permissions.count == 3, Int(permissions) != nil else {
            return .failure(.invalidPermissions(permissions))
        }

        let safePath = file.path.replacingOccurrences(of: "'", with: "'\\''")
        let recursiveFlag = recursive && file.isDirectory ? "-R " : ""
        let command = "chmod \(recursiveFlag)\(permissions) '\(safePath)' && echo 'SUCCESS'"

        let result = await sshBase.execute(command, via: session, timeout: 30)

        if result.output.contains("SUCCESS") {
            return .success(())
        }
        return .failure(.permissionChangeFailed(path: file.path, message: result.output))
    }

    /// Changes file owner and group
    func changeOwner(file: ServerFileItem, owner: String, group: String? = nil, recursive: Bool = false, via session: TerminalViewModel) async -> Result<Void, FileServiceError> {
        let safePath = file.path.replacingOccurrences(of: "'", with: "'\\''")
        let safeOwner = owner.replacingOccurrences(of: "'", with: "")
        let ownerGroup = group.map { "\(safeOwner):\($0.replacingOccurrences(of: "'", with: ""))" } ?? safeOwner
        let recursiveFlag = recursive && file.isDirectory ? "-R " : ""

        let command = "chown \(recursiveFlag)\(ownerGroup) '\(safePath)' && echo 'SUCCESS'"
        let result = await sshBase.execute(command, via: session, timeout: 30)

        if result.output.contains("SUCCESS") {
            return .success(())
        }
        return .failure(.ownerChangeFailed(path: file.path, message: result.output))
    }

    /// Copies a file or directory
    func copy(file: ServerFileItem, to destination: String, via session: TerminalViewModel) async -> Result<Void, FileServiceError> {
        let safeSrc = file.path.replacingOccurrences(of: "'", with: "'\\''")
        let safeDest = destination.replacingOccurrences(of: "'", with: "'\\''")
        let recursiveFlag = file.isDirectory ? "-r " : ""

        let command = "cp \(recursiveFlag)'\(safeSrc)' '\(safeDest)' && echo 'SUCCESS'"
        let result = await sshBase.execute(command, via: session, timeout: 60)

        if result.output.contains("SUCCESS") {
            return .success(())
        }
        return .failure(.copyFailed(source: file.path, destination: destination, message: result.output))
    }

    /// Moves a file or directory
    func move(file: ServerFileItem, to destination: String, via session: TerminalViewModel) async -> Result<Void, FileServiceError> {
        let safeSrc = file.path.replacingOccurrences(of: "'", with: "'\\''")
        let safeDest = destination.replacingOccurrences(of: "'", with: "'\\''")

        let command = "mv '\(safeSrc)' '\(safeDest)' && echo 'SUCCESS'"
        let result = await sshBase.execute(command, via: session, timeout: 60)

        if result.output.contains("SUCCESS") {
            return .success(())
        }
        return .failure(.moveFailed(source: file.path, destination: destination, message: result.output))
    }

    // MARK: - File Info

    /// Gets detailed file information
    func getFileInfo(at path: String, via session: TerminalViewModel) async -> Result<ExtendedFileInfo, FileServiceError> {
        let safePath = path.replacingOccurrences(of: "'", with: "'\\''")

        // Try Linux stat first
        let command = """
        stat '\(safePath)' --printf='%n|%F|%s|%a|%U|%G|%Y|%X' 2>/dev/null && echo '' && \
        file --mime-type -b '\(safePath)' 2>/dev/null && \
        readlink '\(safePath)' 2>/dev/null
        """

        let result = await sshBase.execute(command, via: session, timeout: 15)

        // Parse the stat output
        let lines = result.output.components(separatedBy: CharacterSet.newlines)
        guard !lines.isEmpty, lines[0].contains("|") else {
            return .failure(.fileNotFound(path: path))
        }

        let parts = lines[0].components(separatedBy: "|")
        guard parts.count >= 8 else {
            return .failure(.parseError(message: "Invalid stat output"))
        }

        let name = (parts[0] as NSString).lastPathComponent
        let fileType = parts[1]
        let size = Int64(parts[2]) ?? 0
        let perms = parts[3]
        let owner = parts[4]
        let group = parts[5]
        let mtime = Double(parts[6]) ?? 0
        let atime = Double(parts[7]) ?? 0

        let isDirectory = fileType.contains("directory")
        let isSymlink = fileType.contains("symbolic link") || fileType.contains("link")
        let mimeType = lines.count > 1 ? lines[1].trimmingCharacters(in: .whitespacesAndNewlines) : nil
        let symlinkTarget = lines.count > 2 && isSymlink ? lines[2].trimmingCharacters(in: .whitespacesAndNewlines) : nil

        let info = ExtendedFileInfo(
            path: path,
            name: name,
            isDirectory: isDirectory,
            isSymlink: isSymlink,
            symlinkTarget: symlinkTarget,
            sizeBytes: size,
            permissions: perms,
            numericPermissions: Int(perms) ?? 644,
            owner: owner,
            group: group,
            modificationDate: Date(timeIntervalSince1970: mtime),
            accessDate: Date(timeIntervalSince1970: atime),
            creationDate: nil,
            inode: nil,
            linkCount: nil,
            mimeType: mimeType
        )

        return .success(info)
    }

    /// Gets the size of a directory
    func getDirectorySize(at path: String, via session: TerminalViewModel) async -> Result<Int64, FileServiceError> {
        let safePath = path.replacingOccurrences(of: "'", with: "'\\''")
        let command = "du -sb '\(safePath)' 2>/dev/null | cut -f1"

        let result = await sshBase.execute(command, via: session, timeout: 60)
        let sizeStr = result.output.trimmingCharacters(in: .whitespacesAndNewlines)

        if let size = Int64(sizeStr) {
            return .success(size)
        }
        return .failure(.operationFailed(operation: "du", message: "Unable to calculate size"))
    }

    // MARK: - File Content

    /// Reads file content (for small files)
    func readFile(at path: String, maxBytes: Int = 1_000_000, via session: TerminalViewModel) async -> Result<String, FileServiceError> {
        let safePath = path.replacingOccurrences(of: "'", with: "'\\''")
        let command = "head -c \(maxBytes) '\(safePath)' 2>/dev/null"

        let result = await sshBase.execute(command, via: session, timeout: 30)

        if result.exitCode == 0 {
            return .success(result.output)
        }
        return .failure(.readFailed(path: path, message: "Unable to read file"))
    }

    /// Writes content to a file using robust Heredoc
    func writeFile(at path: String, content: String, via session: TerminalViewModel) async -> Result<Void, FileServiceError> {
        // Use the robust writeFile in SSHBaseService (Heredoc)
        let success = await sshBase.writeFile(at: path, content: content, useSudo: true, via: session)

        if success {
            return .success(())
        }
        return .failure(.writeFailed(path: path, message: "Use of Heredoc write failed"))
    }

    // MARK: - Search

    /// Searches for files matching a pattern
    func searchFiles(in path: String, pattern: String, via session: TerminalViewModel) async -> Result<[ServerFileItem], FileServiceError> {
        let safePath = path.replacingOccurrences(of: "'", with: "'\\''")
        let safePattern = pattern.replacingOccurrences(of: "'", with: "'\\''")

        let command = "find '\(safePath)' -maxdepth 5 -name '*\(safePattern)*' -type f 2>/dev/null | head -100"
        let result = await sshBase.execute(command, via: session, timeout: 30)

        let files = result.output
            .components(separatedBy: CharacterSet.newlines)
            .compactMap { line -> ServerFileItem? in
                let filePath = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !filePath.isEmpty else { return nil }

                let name = (filePath as NSString).lastPathComponent
                return ServerFileItem(
                    name: name,
                    path: filePath,
                    isDirectory: false,
                    sizeBytes: 0,
                    permissions: "644",
                    modificationDate: Date(),
                    owner: "root"
                )
            }

        return .success(files)
    }

    // MARK: - Helpers

    /// Checks if a path exists
    func exists(path: String, via session: TerminalViewModel) async -> Bool {
        let safePath = path.replacingOccurrences(of: "'", with: "'\\''")
        let result = await sshBase.execute("test -e '\(safePath)' && echo 'EXISTS'", via: session, timeout: 10)
        return result.output.contains("EXISTS")
    }

    /// Gets available system users for owner selection
    func getSystemUsers(via session: TerminalViewModel) async -> [String] {
        let result = await sshBase.execute("cut -d: -f1 /etc/passwd | sort", via: session, timeout: 15)
        return result.output
            .components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Gets available system groups
    func getSystemGroups(via session: TerminalViewModel) async -> [String] {
        let result = await sshBase.execute("cut -d: -f1 /etc/group | sort", via: session, timeout: 15)
        return result.output
            .components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Private Parsing

    private func parseFileList(_ output: String, basePath: String) -> Result<[ServerFileItem], FileServiceError> {
        var files: [ServerFileItem] = []

        let lines = output.components(separatedBy: CharacterSet.newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let parts = trimmed.components(separatedBy: "|")
            guard parts.count >= 6 else { continue }

            let name = parts[0]
            guard !name.isEmpty, name != ".", name != ".." else { continue }

            let fileType = parts[1].lowercased()
            let isDirectory = fileType.contains("directory") || fileType.contains("dir")
            let size = Int64(parts[2]) ?? 0
            let perms = parts[3]
            let owner = parts[4]
            let mtime = Double(parts[5]) ?? 0

            let fullPath = (basePath as NSString).appendingPathComponent(name)

            files.append(ServerFileItem(
                name: name,
                path: fullPath,
                isDirectory: isDirectory,
                sizeBytes: size,
                permissions: perms,
                modificationDate: Date(timeIntervalSince1970: mtime),
                owner: owner
            ))
        }

        return .success(files)
    }
}

// MARK: - Error Types

enum FileServiceError: Error, LocalizedError {
    case listingFailed(path: String, message: String)
    case fileNotFound(path: String)
    case deleteFailed(path: String, message: String)
    case renameFailed(oldName: String, newName: String, message: String)
    case permissionChangeFailed(path: String, message: String)
    case ownerChangeFailed(path: String, message: String)
    case copyFailed(source: String, destination: String, message: String)
    case moveFailed(source: String, destination: String, message: String)
    case readFailed(path: String, message: String)
    case writeFailed(path: String, message: String)
    case operationFailed(operation: String, message: String)
    case invalidPermissions(String)
    case parseError(message: String)

    var errorDescription: String? {
        switch self {
        case .listingFailed(let path, let msg):
            return "Failed to list '\(path)': \(msg)"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .deleteFailed(let path, let msg):
            return "Failed to delete '\(path)': \(msg)"
        case .renameFailed(let old, let new, let msg):
            return "Failed to rename '\(old)' to '\(new)': \(msg)"
        case .permissionChangeFailed(let path, let msg):
            return "Failed to change permissions on '\(path)': \(msg)"
        case .ownerChangeFailed(let path, let msg):
            return "Failed to change owner of '\(path)': \(msg)"
        case .copyFailed(let src, let dest, let msg):
            return "Failed to copy '\(src)' to '\(dest)': \(msg)"
        case .moveFailed(let src, let dest, let msg):
            return "Failed to move '\(src)' to '\(dest)': \(msg)"
        case .readFailed(let path, let msg):
            return "Failed to read '\(path)': \(msg)"
        case .writeFailed(let path, let msg):
            return "Failed to write '\(path)': \(msg)"
        case .operationFailed(let op, let msg):
            return "Operation '\(op)' failed: \(msg)"
        case .invalidPermissions(let perms):
            return "Invalid permissions: \(perms)"
        case .parseError(let msg):
            return "Parse error: \(msg)"
        }
    }
}
