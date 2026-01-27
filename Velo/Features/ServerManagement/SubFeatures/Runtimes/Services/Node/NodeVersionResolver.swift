//
//  NodeVersionResolver.swift
//  Velo
//
//  Manages Node.js version detection and switching.
//

import Foundation

/// Manages Node.js version detection and switching
struct NodeVersionResolver {
    private let sshService = ServerAdminService.shared
    private let detector = NodeDetector()

    var detectionStrategy: VersionDetectionStrategy {
        .versionManager(tool: "nvm", command: "source ~/.nvm/nvm.sh && nvm ls")
    }

    var switchStrategy: VersionSwitchStrategy {
        .versionManager(tool: "nvm", command: "source ~/.nvm/nvm.sh && nvm use {VERSION}")
    }

    func getActiveVersion(via session: TerminalViewModel) async -> String? {
        let result = await sshService.execute("node --version 2>&1 | sed 's/v//'", via: session, timeout: 5)
        let version = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return version.isEmpty ? nil : version
    }

    func getInstalledVersions(via session: TerminalViewModel) async -> [String] {
        // Check if nvm is installed
        let hasNvm = await detector.isNvmInstalled(via: session)

        if hasNvm {
            // Use nvm to list versions
            return await VersionManagementService.detectVersions(
                using: detectionStrategy,
                via: session
            )
        } else {
            // Fallback: check /usr/bin for node binaries
            let binaryStrategy = VersionDetectionStrategy.binaryPattern(pattern: "node*")
            return await VersionManagementService.detectVersions(
                using: binaryStrategy,
                via: session
            )
        }
    }

    func switchVersion(to version: String, via session: TerminalViewModel) async throws -> Bool {
        let hasNvm = await detector.isNvmInstalled(via: session)

        if hasNvm {
            return try await VersionManagementService.switchVersion(
                to: version,
                using: switchStrategy,
                via: session
            )
        } else {
            // Fallback: use update-alternatives if available
            let altStrategy = VersionSwitchStrategy.updateAlternatives(
                binary: "node",
                path: "/usr/bin"
            )
            return try await VersionManagementService.switchVersion(
                to: version,
                using: altStrategy,
                via: session
            )
        }
    }
}
