//
//  NodeDetector.swift
//  Velo
//
//  Detects Node.js installation and configuration.
//

import Foundation

/// Detects Node.js installation and configuration
struct NodeDetector {
    private let sshService = SSHBaseService.shared

    func isInstalled(via session: TerminalViewModel) async -> Bool {
        let result = await sshService.execute("which node 2>/dev/null", via: session, timeout: 5)
        let path = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return !path.isEmpty && path.hasPrefix("/")
    }

    func getBinaryPath(via session: TerminalViewModel) async -> String? {
        let result = await sshService.execute("which node", via: session, timeout: 5)
        let path = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }

    func isNvmInstalled(via session: TerminalViewModel) async -> Bool {
        let result = await sshService.execute("command -v nvm 2>/dev/null", via: session, timeout: 5)
        return !result.output.isEmpty
    }

    func isNpmInstalled(via session: TerminalViewModel) async -> Bool {
        let result = await sshService.execute("which npm 2>/dev/null", via: session, timeout: 5)
        return !result.output.isEmpty
    }
}
