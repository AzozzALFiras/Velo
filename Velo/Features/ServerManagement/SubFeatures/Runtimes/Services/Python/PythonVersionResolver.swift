//
//  PythonVersionResolver.swift
//  Velo
//
//  Manages Python version detection and switching.
//

import Foundation

/// Manages Python version detection and switching
struct PythonVersionResolver {
    private let sshService = ServerAdminService.shared

    let detectionStrategy = VersionDetectionStrategy.binaryPattern(pattern: "python3*")
    let switchStrategy = VersionSwitchStrategy.updateAlternatives(
        binary: "python3",
        path: "/usr/bin"
    )

    func getActiveVersion(via session: TerminalViewModel) async -> String? {
        let result = await sshService.execute("python3 --version 2>&1 | awk '{print $2}'", via: session, timeout: 5)
        let version = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        return version.isEmpty ? nil : version
    }

    func getInstalledVersions(via session: TerminalViewModel) async -> [String] {
        // Use generic version management service
        let versions = await VersionManagementService.detectVersions(
            using: detectionStrategy,
            via: session
        )

        // Fallback: also check update-alternatives
        if versions.isEmpty {
            let altStrategy = VersionDetectionStrategy.updateAlternatives(name: "python3")
            return await VersionManagementService.detectVersions(using: altStrategy, via: session)
        }

        return VersionManagementService.sortVersions(versions)
    }

    func switchVersion(to version: String, via session: TerminalViewModel) async throws -> Bool {
        // Try update-alternatives first
        let success = try await VersionManagementService.switchVersion(
            to: version,
            using: switchStrategy,
            via: session
        )

        // Fallback to symlink if update-alternatives fails
        if !success {
            let symlinkStrategy = VersionSwitchStrategy.symlink(
                from: "/usr/bin/python3",
                to: "/usr/bin/python\(version)"
            )
            return try await VersionManagementService.switchVersion(
                to: version,
                using: symlinkStrategy,
                via: session
            )
        }

        return success
    }
}
