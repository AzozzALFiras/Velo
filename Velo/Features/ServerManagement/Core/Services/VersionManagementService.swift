//
//  VersionManagementService.swift
//  Velo
//
//  Generic utilities for version management across all services.
//

import Foundation

/// Generic utilities for version management across all services
struct VersionManagementService {

    private static let sshService = SSHBaseService.shared

    // MARK: - Version Detection

    /// Detect versions using a strategy
    static func detectVersions(
        using strategy: VersionDetectionStrategy,
        via session: TerminalViewModel
    ) async -> [String] {
        switch strategy {
        case .directoryBased(let path, let pattern):
            return await detectFromDirectory(path: path, pattern: pattern, via: session)

        case .updateAlternatives(let name):
            return await detectFromUpdateAlternatives(name: name, via: session)

        case .versionManager(let tool, let command):
            return await detectFromVersionManager(tool: tool, command: command, via: session)

        case .packageManager(let pattern):
            return await detectFromPackageManager(pattern: pattern, via: session)

        case .binaryPattern(let pattern):
            return await detectFromBinaryPattern(pattern: pattern, via: session)
        }
    }

    // MARK: - Version Switching

    /// Switch version using a strategy
    static func switchVersion(
        to version: String,
        using strategy: VersionSwitchStrategy,
        via session: TerminalViewModel
    ) async throws -> Bool {
        switch strategy {
        case .updateAlternatives(let binary, let path):
            return await switchViaUpdateAlternatives(binary: binary, path: path, version: version, via: session)

        case .symlink(let from, let to):
            return await switchViaSymlink(from: from, to: to, version: version, via: session)

        case .versionManager(let tool, let command):
            return await switchViaVersionManager(tool: tool, command: command, version: version, via: session)
        }
    }

    // MARK: - Version Comparison

    /// Compare two semantic version strings
    static func compareVersions(_ v1: String, _ v2: String) -> ComparisonResult {
        let components1 = extractVersionComponents(from: v1)
        let components2 = extractVersionComponents(from: v2)

        for (c1, c2) in zip(components1, components2) {
            if c1 < c2 { return .orderedAscending }
            if c1 > c2 { return .orderedDescending }
        }

        if components1.count < components2.count { return .orderedAscending }
        if components1.count > components2.count { return .orderedDescending }

        return .orderedSame
    }

    /// Sort versions from newest to oldest
    static func sortVersions(_ versions: [String]) -> [String] {
        return versions.sorted { compareVersions($0, $1) == .orderedDescending }
    }

    // MARK: - Private Implementation

    private static func detectFromDirectory(path: String, pattern: String, via session: TerminalViewModel) async -> [String] {
        let command = "ls -1 '\(path)' 2>/dev/null | grep -E '\(pattern)' | sort -V -r"
        let result = await sshService.execute(command, via: session, timeout: 10)
        return result.output
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func detectFromUpdateAlternatives(name: String, via session: TerminalViewModel) async -> [String] {
        let command = "update-alternatives --list \(name) 2>/dev/null | grep -oE '[0-9]+\\.[0-9]+' | sort -V -r | uniq"
        let result = await sshService.execute(command, via: session, timeout: 10)
        return result.output
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func detectFromVersionManager(tool: String, command: String, via session: TerminalViewModel) async -> [String] {
        // Check if version manager is installed
        let checkResult = await sshService.execute("which \(tool) 2>/dev/null", via: session, timeout: 5)
        guard !checkResult.output.isEmpty else { return [] }

        // Execute version list command
        let result = await sshService.execute(command, via: session, timeout: 15)
        return parseVersionManagerOutput(result.output, tool: tool)
    }

    private static func detectFromPackageManager(pattern: String, via session: TerminalViewModel) async -> [String] {
        let command = "dpkg -l 2>/dev/null | grep -E '\(pattern)' | awk '{print $3}' | grep -oE '[0-9]+\\.[0-9]+' | sort -V -r | uniq"
        let result = await sshService.execute(command, via: session, timeout: 10)
        return result.output
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func detectFromBinaryPattern(pattern: String, via session: TerminalViewModel) async -> [String] {
        let command = "ls -1 /usr/bin/\(pattern) 2>/dev/null | grep -oE '[0-9]+\\.[0-9]+' | sort -V -r | uniq"
        let result = await sshService.execute(command, via: session, timeout: 10)
        return result.output
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func switchViaUpdateAlternatives(binary: String, path: String, version: String, via session: TerminalViewModel) async -> Bool {
        let fullPath = "\(path)/\(binary)\(version)"
        let command = "sudo update-alternatives --set \(binary) \(fullPath)"
        let result = await sshService.execute(command, via: session, timeout: 15)
        return result.exitCode == 0
    }

    private static func switchViaSymlink(from: String, to: String, version: String, via session: TerminalViewModel) async -> Bool {
        let targetPath = "\(to)/\(version)"
        let command = "sudo ln -sf '\(targetPath)' '\(from)'"
        let result = await sshService.execute(command, via: session, timeout: 10)
        return result.exitCode == 0
    }

    private static func switchViaVersionManager(tool: String, command: String, version: String, via session: TerminalViewModel) async -> Bool {
        let fullCommand = command.replacingOccurrences(of: "{VERSION}", with: version)
        let result = await sshService.execute(fullCommand, via: session, timeout: 15)
        return result.exitCode == 0
    }

    private static func parseVersionManagerOutput(_ output: String, tool: String) -> [String] {
        // Tool-specific parsing
        switch tool {
        case "nvm":
            // Parse: v18.17.0, v16.20.1, etc.
            return output
                .split(separator: "\n")
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .compactMap { line in
                    if let match = line.range(of: "v?[0-9]+\\.[0-9]+\\.[0-9]+", options: .regularExpression) {
                        return String(line[match]).replacingOccurrences(of: "v", with: "")
                    }
                    return nil
                }
        case "pyenv":
            // Parse: 3.11.4, 3.10.12, etc.
            return output
                .split(separator: "\n")
                .map { String($0).trimmingCharacters(in: .whitespaces) }
                .filter { $0.range(of: "^[0-9]+\\.[0-9]+", options: .regularExpression) != nil }
        default:
            return []
        }
    }

    private static func extractVersionComponents(from version: String) -> [Int] {
        let cleaned = version.replacingOccurrences(of: "v", with: "")
        return cleaned
            .split(separator: ".")
            .compactMap { Int($0) }
    }
}
