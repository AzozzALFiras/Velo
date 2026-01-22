//
//  SSHFilePromiseProvider.swift
//  Velo
//
//  File Promise Provider for SSH Drag-Out
//  Uses NSFilePromiseProviderDelegate for proper macOS Finder integration
//

import AppKit
import UniformTypeIdentifiers

/// Delegate for handling SSH file promise operations
final class SSHFilePromiseDelegate: NSObject, NSFilePromiseProviderDelegate {
    
    let remotePath: String
    let fileName: String
    let isDirectory: Bool
    let sshConnectionString: String
    let downloadTrigger: (String) -> Void
    
    /// Dedicated operation queue for file operations
    private let fileOperationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.qualityOfService = .userInitiated
        queue.maxConcurrentOperationCount = 1
        queue.name = "com.velo.ssh-file-promise"
        return queue
    }()
    
    /// Destination URL in temp directory
    var destinationURL: URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("VeloDragExport", isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir.appendingPathComponent(fileName)
    }
    
    init(
        remotePath: String,
        fileName: String,
        isDirectory: Bool,
        sshConnectionString: String,
        downloadTrigger: @escaping (String) -> Void
    ) {
        self.remotePath = remotePath
        self.fileName = fileName
        self.isDirectory = isDirectory
        self.sshConnectionString = sshConnectionString
        self.downloadTrigger = downloadTrigger
        super.init()
    }
    
    // MARK: - NSFilePromiseProviderDelegate
    
    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
        print("🚀 [FilePromise] Finder requesting filename: \(fileName)")
        return fileName
    }
    
    func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, writePromiseTo url: URL, completionHandler: @escaping (Error?) -> Void) {
        print("🚀 [FilePromise] Finder requesting file at: \(url.path)")
        print("🚀 [FilePromise] Remote path: \(remotePath)")
        
        // Clear any existing file at destination
        try? FileManager.default.removeItem(at: destinationURL)
        
        // Build SCP command
        let flag = isDirectory ? "-r " : ""
        let escapedLocal = destinationURL.path.replacingOccurrences(of: "'", with: "'\\''")
        let escapedRemote = remotePath.replacingOccurrences(of: "'", with: "'\\''")
        let scpCommand = "scp \(flag)\(sshConnectionString):'\(escapedRemote)' '\(escapedLocal)'"
        
        print("🚀 [FilePromise] Executing SCP: \(scpCommand)")
        
        // Trigger download via the main thread callback
        DispatchQueue.main.async {
            self.downloadTrigger("__download_scp__:\(scpCommand)")
        }
        
        // Poll for download completion
        let startTime = Date()
        let timeout: TimeInterval = 300 // 5 minutes
        let pollInterval: TimeInterval = 0.3
        
        while true {
            // Check if file/directory exists and has content
            let exists = FileManager.default.fileExists(atPath: destinationURL.path)
            var hasContent = false
            
            if exists {
                if isDirectory {
                    // For directories, check if it has any contents
                    let contents = try? FileManager.default.contentsOfDirectory(atPath: destinationURL.path)
                    hasContent = (contents?.count ?? 0) > 0
                } else {
                    // For files, check if size > 0
                    let attrs = try? FileManager.default.attributesOfItem(atPath: destinationURL.path)
                    if let size = attrs?[.size] as? UInt64, size > 0 {
                        hasContent = true
                    }
                }
            }
            
            if hasContent {
                print("🚀 [FilePromise] Download complete!")
                break
            }
            
            // Timeout check
            if Date().timeIntervalSince(startTime) > timeout {
                print("🚀 [FilePromise] Download timeout!")
                completionHandler(NSError(
                    domain: "Velo",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Download timeout after 5 minutes"]
                ))
                return
            }
            
            // Wait before next poll
            Thread.sleep(forTimeInterval: pollInterval)
        }
        
        // Move/copy file to the Finder-requested URL
        do {
            try FileManager.default.moveItem(at: destinationURL, to: url)
            print("🚀 [FilePromise] File delivered to Finder: \(url.path)")
            completionHandler(nil)
        } catch {
            print("🚀 [FilePromise] Failed to deliver file: \(error)")
            completionHandler(error)
        }
    }
    
    func operationQueue(for filePromiseProvider: NSFilePromiseProvider) -> OperationQueue {
        return fileOperationQueue
    }
}

/// Factory for creating SSH file promise providers
enum SSHFilePromiseFactory {
    
    /// Creates an NSFilePromiseProvider configured for SSH drag-out
    static func createProvider(
        remotePath: String,
        fileName: String,
        isDirectory: Bool,
        sshConnectionString: String,
        downloadTrigger: @escaping (String) -> Void
    ) -> (NSFilePromiseProvider, SSHFilePromiseDelegate) {
        // Determine UTI
        let uti: String
        if isDirectory {
            uti = UTType.folder.identifier
        } else {
            let ext = (fileName as NSString).pathExtension
            if let type = UTType(filenameExtension: ext) {
                uti = type.identifier
            } else {
                uti = UTType.item.identifier
            }
        }
        
        // Create delegate (must be retained)
        let delegate = SSHFilePromiseDelegate(
            remotePath: remotePath,
            fileName: fileName,
            isDirectory: isDirectory,
            sshConnectionString: sshConnectionString,
            downloadTrigger: downloadTrigger
        )
        
        // Create provider
        let provider = NSFilePromiseProvider(fileType: uti, delegate: delegate)
        
        return (provider, delegate)
    }
}
