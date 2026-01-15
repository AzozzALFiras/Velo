//
//  GitCommandService.swift
//  Velo
//
//  Git Feature - Command Execution Service
//  Handles git CLI operations (commit, stage, unstage, etc.)
//

import Foundation

// MARK: - Git Command Service

/// Service for executing git commands in a given directory
struct GitCommandService {

    /// Execute a git command in the specified directory
    /// - Parameters:
    ///   - command: The full command string to execute
    ///   - directory: The working directory for the command
    static func execute(_ command: String, in directory: String) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-c", command]
                process.currentDirectoryURL = URL(fileURLWithPath: directory)

                do {
                    try process.run()
                    process.waitUntilExit()
                } catch {
                    print("Git command failed: \(error)")
                }

                continuation.resume()
            }
        }
    }

    /// Stage all changes and commit with the given message
    /// - Parameters:
    ///   - message: The commit message
    ///   - directory: The working directory
    static func commit(message: String, in directory: String) async {
        let escapedMessage = message.replacingOccurrences(of: "\"", with: "\\\"")
        await execute("git add -A && git commit -m \"\(escapedMessage)\"", in: directory)
    }

    /// Stage a specific file
    /// - Parameters:
    ///   - path: The file path to stage
    ///   - directory: The working directory
    static func stage(file path: String, in directory: String) async {
        await execute("git add \"\(path)\"", in: directory)
    }

    /// Unstage a specific file
    /// - Parameters:
    ///   - path: The file path to unstage
    ///   - directory: The working directory
    static func unstage(file path: String, in directory: String) async {
        await execute("git restore --staged \"\(path)\"", in: directory)
    }

    /// Pull changes from remote
    /// - Parameter directory: The working directory
    static func pull(in directory: String) async {
        await execute("git pull", in: directory)
    }

    /// Push changes to remote
    /// - Parameter directory: The working directory
    static func push(in directory: String) async {
        await execute("git push", in: directory)
    }

    /// Sync (pull then push) changes with remote
    /// - Parameter directory: The working directory
    static func sync(in directory: String) async {
        await execute("git pull && git push", in: directory)
    }
}
