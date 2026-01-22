//
//  SSHRemoteBrowserService.swift
//  Velo
//
//  SSH Remote Browser Service
//  Handles remote directory listing via SSH
//

import Foundation
import Combine

// MARK: - SSH Remote Browser Service

/// Service for browsing remote directories via SSH
@MainActor
final class SSHRemoteBrowserService: ObservableObject {

    // MARK: - Published State
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Private
    private var sshLSProcess: PTYProcess?

    // MARK: - Remote Directory Loading

    /// Load contents of a remote directory via SSH
    /// - Parameters:
    ///   - path: Remote directory path
    ///   - sshHost: SSH connection string (user@host)
    /// - Returns: Array of parsed file items
    func loadRemoteDirectory(_ path: String, sshHost: String) async -> [SSHRemoteFileItem] {
        isLoading = true
        defer { isLoading = false }

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
                        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                            self?.sshLSProcess?.write(pwd + "\n")
                        }
                        passwordInjected = true
                    }
                }
            }

            self.sshLSProcess = pty

            let escapedPath = targetDirectory.replacingOccurrences(of: "'", with: "'\\''")
            let lsCommand = "ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 \(sshHost) \"echo '\(delimiter)'; ls -1ap --color=never '\(escapedPath)'\""

            var env = Foundation.ProcessInfo.processInfo.environment
            env["SSH_ASKPASS"] = ""

            do {
                try pty.execute(
                    command: lsCommand,
                    environment: env,
                    workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path
                )

                DispatchQueue.global().async { [weak self] in
                    let exitCode = pty.waitForExit()

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
                        let cleaned = accumulatedOutput.replacingOccurrences(of: lsCommand, with: "")
                        continuation.resume(returning: (cleaned, nil))
                    }
                }
            } catch {
                continuation.resume(returning: ("", error))
            }
        }

        if let error = result.1 {
            errorMessage = error.localizedDescription
            return []
        }

        let output = result.0
        if output.count < 10000 || output.contains(delimiter) {
            return parseRemoteOutput(output: output, path: path, sshHost: sshHost)
        }

        return []
    }

    // MARK: - Output Parsing

    /// Parse remote ls output into file items
    private func parseRemoteOutput(output: String, path: String, sshHost: String) -> [SSHRemoteFileItem] {
        // Clean ANSI/OSC sequences
        var cleanedOutput = output
        cleanedOutput = cleanedOutput.replacingOccurrences(of: "\u{1B}\\][^\u{07}\u{1B}]*[\u{07}]", with: "", options: .regularExpression)
        cleanedOutput = cleanedOutput.replacingOccurrences(of: "\u{1B}\\][^\u{07}\u{1B}]*\\u{1B}\\\\", with: "", options: .regularExpression)
        cleanedOutput = cleanedOutput.replacingOccurrences(of: "\u{1B}\\[[0-9;?]*[a-zA-Z]", with: "", options: .regularExpression)
        cleanedOutput = cleanedOutput.replacingOccurrences(of: "\u{1B}", with: "")
        cleanedOutput = cleanedOutput.replacingOccurrences(of: "\u{07}", with: "")

        let lines = cleanedOutput.components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { line in
                !line.isEmpty &&
                line != "./" &&
                line != "../" &&
                !line.contains("Welcome to") &&
                !line.contains("Last login:") &&
                !line.hasPrefix("ls -") &&
                !line.contains("root@") &&
                !line.contains("[")
            }

        return lines.map { line -> SSHRemoteFileItem in
            let isDir = line.hasSuffix("/")
            let name = isDir ? String(line.dropLast()) : line

            let separator = path.hasSuffix("/") ? "" : "/"
            let fullPath = "\(path)\(separator)\(name)"

            return SSHRemoteFileItem(
                id: "ssh:\(sshHost):\(fullPath)",
                name: name,
                path: fullPath,
                isDirectory: isDir
            )
        }.sorted { (a, b) in
            if a.isDirectory != b.isDirectory {
                return a.isDirectory
            }
            return a.name.lowercased() < b.name.lowercased()
        }
    }

    // MARK: - Cleanup

    func cancelCurrentOperation() {
        sshLSProcess = nil
    }
}

// MARK: - SSH Remote File Item

/// Represents a file or directory on a remote SSH server
struct SSHRemoteFileItem: Identifiable, Hashable {
    let id: String
    let name: String
    let path: String
    let isDirectory: Bool

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: SSHRemoteFileItem, rhs: SSHRemoteFileItem) -> Bool {
        lhs.id == rhs.id
    }
}
