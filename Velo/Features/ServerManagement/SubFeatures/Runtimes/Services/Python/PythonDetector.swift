//
//  PythonDetector.swift
//  Velo
//
//  Detects Python installation and configuration.
//

import Foundation

/// Detects Python installation and configuration
struct PythonDetector {
    private let sshService = SSHBaseService.shared

    func isInstalled(via session: TerminalViewModel) async -> Bool {
        let result = await sshService.execute("which python3 2>/dev/null", via: session, timeout: 5)
        let path = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return !path.isEmpty && path.hasPrefix("/")
    }

    func getBinaryPath(via session: TerminalViewModel) async -> String? {
        let result = await sshService.execute("which python3", via: session, timeout: 5)
        let path = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }

    func isPipInstalled(via session: TerminalViewModel) async -> Bool {
        let result = await sshService.execute("which pip3 2>/dev/null", via: session, timeout: 5)
        return !result.output.isEmpty
    }

    func getPipVersion(via session: TerminalViewModel) async -> String? {
        let result = await sshService.execute("pip3 --version 2>/dev/null", via: session, timeout: 5)
        let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return output.isEmpty ? nil : output
    }
}
