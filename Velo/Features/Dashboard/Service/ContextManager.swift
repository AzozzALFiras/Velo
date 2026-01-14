//
//  ContextManager.swift
//  Velo
//
//  Dashboard Redesign - Context Detection Service
//  Detects Git, Docker, npm, and other project contexts
//

import SwiftUI
import Foundation

// MARK: - Git Status

/// Represents the state of a Git repository
enum GitStatus: String, Sendable {
    case clean
    case dirty
    case conflict
    case unknown
    
    var icon: String {
        switch self {
        case .clean: return "checkmark.circle"
        case .dirty: return "pencil.circle"
        case .conflict: return "exclamationmark.triangle"
        case .unknown: return "questionmark.circle"
        }
    }
    
    var color: Color {
        switch self {
        case .clean: return ColorTokens.success
        case .dirty: return ColorTokens.warning
        case .conflict: return ColorTokens.error
        case .unknown: return ColorTokens.textTertiary
        }
    }
}

// MARK: - Context Manager

/// Observable service that detects project context (Git, Docker, npm, etc.)
/// Uses Swift 6 Observation framework for high-performance reactivity
@Observable
@MainActor
final class ContextManager {
    
    // MARK: - Git Context
    
    var isGitRepository: Bool = false
    var gitBranch: String = ""
    var gitStatus: GitStatus = .unknown
    var hasUncommittedChanges: Bool = false
    var aheadCount: Int = 0
    var behindCount: Int = 0
    var stagedCount: Int = 0
    var modifiedCount: Int = 0
    var untrackedCount: Int = 0
    
    // File lists for panels
    var stagedFiles: [String] = []
    var modifiedFiles: [String] = []
    var untrackedFiles: [String] = []
    
    // MARK: - Project Context
    
    var isDockerProject: Bool = false
    var hasPackageJson: Bool = false
    var hasCargoToml: Bool = false
    var hasPodfile: Bool = false
    var hasGemfile: Bool = false
    
    // MARK: - Current State
    
    private(set) var currentDirectory: String = ""
    private(set) var isUpdating: Bool = false
    
    // MARK: - Computed Properties
    
    var gitSummary: String {
        guard isGitRepository else { return "" }
        
        var parts: [String] = []
        if aheadCount > 0 { parts.append("↑\(aheadCount)") }
        if behindCount > 0 { parts.append("↓\(behindCount)") }
        if modifiedCount > 0 { parts.append("●\(modifiedCount)") }
        if stagedCount > 0 { parts.append("✓\(stagedCount)") }
        
        return parts.joined(separator: " ")
    }
    
    var hasGitChanges: Bool {
        stagedCount > 0 || modifiedCount > 0 || untrackedCount > 0
    }
    
    var needsSync: Bool {
        aheadCount > 0 || behindCount > 0
    }
    
    // MARK: - Update Context
    
    /// Updates the context for the given directory
    func updateContext(for directory: String) async {
        guard directory != currentDirectory else { return }
        
        currentDirectory = directory
        isUpdating = true
        
        // Run all detections concurrently
        async let gitCheck = detectGitRepository(directory)
        async let dockerComposeCheck = detectFileExists(directory, filename: "docker-compose.yml")
        async let dockerfileCheck = detectFileExists(directory, filename: "Dockerfile")
        async let npmCheck = detectFileExists(directory, filename: "package.json")
        async let cargoCheck = detectFileExists(directory, filename: "Cargo.toml")
        async let podCheck = detectFileExists(directory, filename: "Podfile")
        async let gemCheck = detectFileExists(directory, filename: "Gemfile")
        
        // Await all results
        isGitRepository = await gitCheck
        let hasDockerCompose = await dockerComposeCheck
        let hasDockerfile = await dockerfileCheck
        isDockerProject = hasDockerCompose || hasDockerfile
        hasPackageJson = await npmCheck
        hasCargoToml = await cargoCheck
        hasPodfile = await podCheck
        hasGemfile = await gemCheck
        
        // If Git repo, get detailed status
        if isGitRepository {
            await updateGitStatus(directory)
        } else {
            resetGitState()
        }
        
        isUpdating = false
    }
    
    /// Refresh Git status without full context update
    func refreshGitStatus() async {
        guard isGitRepository else { return }
        await updateGitStatus(currentDirectory)
    }
    
    // MARK: - Git Detection
    
    private func detectGitRepository(_ path: String) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let gitPath = (path as NSString).appendingPathComponent(".git")
                let exists = FileManager.default.fileExists(atPath: gitPath)
                
                // Also check parent directories
                if !exists {
                    var currentPath = path
                    while currentPath != "/" {
                        currentPath = (currentPath as NSString).deletingLastPathComponent
                        let parentGitPath = (currentPath as NSString).appendingPathComponent(".git")
                        if FileManager.default.fileExists(atPath: parentGitPath) {
                            continuation.resume(returning: true)
                            return
                        }
                    }
                }
                
                continuation.resume(returning: exists)
            }
        }
    }
    
    private func updateGitStatus(_ path: String) async {
        // Get branch name
        gitBranch = await runGitCommand(["rev-parse", "--abbrev-ref", "HEAD"], in: path)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Get status counts
        let statusOutput = await runGitCommand(["status", "--porcelain"], in: path)
        parseGitStatusOutput(statusOutput)
        
        // Get ahead/behind counts
        let aheadBehind = await runGitCommand(
            ["rev-list", "--left-right", "--count", "@{upstream}...HEAD"],
            in: path
        )
        parseAheadBehind(aheadBehind)
        
        // Determine overall status
        if modifiedCount > 0 || stagedCount > 0 || untrackedCount > 0 {
            gitStatus = .dirty
            hasUncommittedChanges = true
        } else {
            gitStatus = .clean
            hasUncommittedChanges = false
        }
    }
    
    private func parseGitStatusOutput(_ output: String) {
        stagedCount = 0
        modifiedCount = 0
        untrackedCount = 0
        
        stagedFiles = []
        modifiedFiles = []
        untrackedFiles = []
        
        for line in output.components(separatedBy: "\n") where !line.isEmpty {
            let index = line.prefix(2)
            let path = String(line.dropFirst(3))
            
            // Staged changes (first character)
            if let first = index.first, first != " " && first != "?" {
                stagedCount += 1
                stagedFiles.append(path)
            }
            
            // Modified/unstaged changes (second character)
            if index.count > 1 {
                let second = index[index.index(after: index.startIndex)]
                if second == "M" || second == "D" {
                    modifiedCount += 1
                    modifiedFiles.append(path)
                }
            }
            
            // Untracked files
            if index.hasPrefix("??") {
                untrackedCount += 1
                untrackedFiles.append(path)
            }
        }
    }
    
    private func parseAheadBehind(_ output: String) {
        let parts = output.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
        
        if parts.count >= 2 {
            behindCount = Int(parts[0]) ?? 0
            aheadCount = Int(parts[1]) ?? 0
        } else {
            behindCount = 0
            aheadCount = 0
        }
    }
    
    private func resetGitState() {
        gitBranch = ""
        gitStatus = .unknown
        hasUncommittedChanges = false
        aheadCount = 0
        behindCount = 0
        stagedCount = 0
        modifiedCount = 0
        untrackedCount = 0
    }
    
    // MARK: - File Detection
    
    private func detectFileExists(_ directory: String, filename: String) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let filePath = (directory as NSString).appendingPathComponent(filename)
                let exists = FileManager.default.fileExists(atPath: filePath)
                continuation.resume(returning: exists)
            }
        }
    }
    
    // MARK: - Shell Execution
    
    private func runGitCommand(_ args: [String], in directory: String) async -> String {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                let pipe = Pipe()
                
                process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                process.arguments = args
                process.currentDirectoryURL = URL(fileURLWithPath: directory)
                process.standardOutput = pipe
                process.standardError = FileHandle.nullDevice
                
                do {
                    try process.run()
                    process.waitUntilExit()
                    
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""
                    continuation.resume(returning: output)
                } catch {
                    continuation.resume(returning: "")
                }
            }
        }
    }
}
