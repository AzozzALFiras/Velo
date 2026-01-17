//
//  SSHFileTransferService.swift
//  Velo
//
//  SSH File Transfer Service
//  Handles SCP command building, upload/download coordination
//

import Foundation
import AppKit
import Combine

// MARK: - SSH File Transfer Service

/// Service for SSH file transfer operations
@MainActor
final class SSHFileTransferService: ObservableObject {

    // MARK: - Published State
    @Published var isUploading = false
    @Published var isDownloading = false
    @Published var uploadFileName = ""
    @Published var uploadProgress: Double = 0.0
    @Published var uploadStartTime: Date?

    // MARK: - SCP Command Building

    /// Build an SCP upload command
    /// - Parameters:
    ///   - localPath: Local file path
    ///   - remotePath: Remote destination path
    ///   - sshConnectionString: SSH connection string (user@host)
    ///   - isDirectory: Whether the source is a directory
    /// - Returns: SCP command string
    static func buildUploadCommand(
        localPath: String,
        remotePath: String,
        sshConnectionString: String,
        isDirectory: Bool
    ) -> String {
        let escapedLocalPath = localPath.replacingOccurrences(of: "'", with: "'\\''")
        let escapedRemotePath = remotePath.replacingOccurrences(of: "'", with: "'\\''")
        let recursiveFlag = isDirectory ? "-r " : ""

        return "scp \(recursiveFlag)'\(escapedLocalPath)' \(sshConnectionString):'\(escapedRemotePath)'"
    }

    /// Build an SCP download command
    /// - Parameters:
    ///   - remotePath: Remote file path
    ///   - localPath: Local destination path
    ///   - sshConnectionString: SSH connection string (user@host)
    ///   - isDirectory: Whether the source is a directory
    /// - Returns: SCP command string
    static func buildDownloadCommand(
        remotePath: String,
        localPath: String,
        sshConnectionString: String,
        isDirectory: Bool
    ) -> String {
        let escapedLocalPath = localPath.replacingOccurrences(of: "'", with: "'\\''")
        let escapedRemotePath = remotePath.replacingOccurrences(of: "'", with: "'\\''")
        let recursiveFlag = isDirectory ? "-r " : ""

        return "scp \(recursiveFlag)\(sshConnectionString):'\(escapedRemotePath)' '\(escapedLocalPath)'"
    }

    // MARK: - Download Dialog

    /// Show download dialog for SSH file
    /// - Parameters:
    ///   - fileName: Name of the file to download
    ///   - remotePath: Remote path of the file
    ///   - isDirectory: Whether it's a directory
    ///   - sshConnectionString: SSH connection string
    ///   - onDownload: Callback with the SCP command to execute
    static func showDownloadDialog(
        fileName: String,
        remotePath: String,
        isDirectory: Bool,
        sshConnectionString: String,
        onDownload: @escaping (String) -> Void
    ) {
        if isDirectory {
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
                    let folderName = (remotePath as NSString).lastPathComponent
                    let localPath = (url.path as NSString).appendingPathComponent(folderName)
                    let cleanedRemotePath = Self.cleanPath(remotePath)

                    let command = Self.buildDownloadCommand(
                        remotePath: cleanedRemotePath,
                        localPath: localPath,
                        sshConnectionString: sshConnectionString,
                        isDirectory: true
                    )
                    onDownload("__download_scp__:\(command)")
                }
            }
        } else {
            let savePanel = NSSavePanel()
            savePanel.title = "Save to Local"
            savePanel.nameFieldStringValue = fileName
            savePanel.canCreateDirectories = true
            savePanel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first

            savePanel.begin { response in
                if response == .OK, let url = savePanel.url {
                    let cleanedRemotePath = Self.cleanPath(remotePath)

                    let command = Self.buildDownloadCommand(
                        remotePath: cleanedRemotePath,
                        localPath: url.path,
                        sshConnectionString: sshConnectionString,
                        isDirectory: false
                    )
                    onDownload("__download_scp__:\(command)")
                }
            }
        }
    }

    // MARK: - File Drop Handling

    /// Handle files dropped for SSH upload
    /// - Parameters:
    ///   - urls: Local file URLs to upload
    ///   - destinationPath: Remote destination directory
    ///   - sshConnectionString: SSH connection string
    ///   - onUpload: Callback with the SCP command to execute
    static func handleFileDrop(
        urls: [URL],
        destinationPath: String,
        sshConnectionString: String,
        onUpload: @escaping (String) -> Void
    ) {
        for url in urls {
            let filename = url.lastPathComponent
            let destinationFullPath = (destinationPath as NSString).appendingPathComponent(filename)

            // Check if source is a directory
            var isDirectory: ObjCBool = false
            let isDir = FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue

            let command = buildUploadCommand(
                localPath: url.path,
                remotePath: destinationFullPath,
                sshConnectionString: sshConnectionString,
                isDirectory: isDir
            )

            onUpload("__upload_scp__:\(command)")
        }
    }

    // MARK: - Helpers

    /// Clean path by removing ANSI sequences and trailing slashes
    static func cleanPath(_ path: String) -> String {
        var cleaned = path

        // Remove ANSI/OSC sequences
        let controlChars = CharacterSet(charactersIn: "\u{0001}"..."\u{001F}").subtracting(CharacterSet(charactersIn: "\n\t"))
        cleaned = cleaned.components(separatedBy: controlChars).joined()
        cleaned = cleaned.replacingOccurrences(of: "]\\d+;[^\n]*", with: "", options: .regularExpression)
        cleaned = cleaned.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        // Remove trailing slash
        if cleaned.hasSuffix("/") {
            cleaned = String(cleaned.dropLast())
        }

        return cleaned
    }
}
