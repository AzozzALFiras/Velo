//
//  PostgreSQLVersionResolver.swift
//  Velo
//
//  Handles PostgreSQL version detection and parsing.
//

import Foundation

struct PostgreSQLVersionResolver {
    private let baseService = SSHBaseService.shared

    /// Get the installed PostgreSQL version
    func getVersion(via session: TerminalViewModel) async -> String? {
        let result = await baseService.execute("psql --version 2>/dev/null | head -1", via: session, timeout: 10)
        return parseVersion(from: result.output)
    }

    /// Get the server version (may differ from client)
    func getServerVersion(via session: TerminalViewModel) async -> String? {
        let result = await baseService.execute(
            "sudo -u postgres psql -t -c 'SELECT version();' 2>/dev/null | head -1",
            via: session, timeout: 10
        )
        return parseVersion(from: result.output)
    }

    /// Get list of installed PostgreSQL versions
    func getInstalledVersions(via session: TerminalViewModel) async -> [String] {
        // Check /etc/postgresql directory (Debian/Ubuntu)
        let debianResult = await baseService.execute("ls -1 /etc/postgresql/ 2>/dev/null | grep -E '^[0-9]'", via: session, timeout: 10)
        let debianVersions = debianResult.output.components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if !debianVersions.isEmpty {
            return debianVersions.sorted { compareVersions($0, $1) == .orderedDescending }
        }

        // Check RHEL/CentOS style
        let rhelResult = await baseService.execute("ls -1 /usr/pgsql-*/bin/psql 2>/dev/null | grep -oE '[0-9]+' | sort -u", via: session, timeout: 10)
        return rhelResult.output.components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted { compareVersions($0, $1) == .orderedDescending }
    }

    /// Parse version number from psql --version output
    /// Example: "psql (PostgreSQL) 14.7 (Ubuntu 14.7-0ubuntu0.22.04.1)" -> "14.7"
    private func parseVersion(from output: String) -> String? {
        let cleaned = output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        // Try to extract version number
        let patterns = [
            "PostgreSQL\\)?\\s*([0-9]+\\.[0-9]+)",
            "([0-9]+\\.[0-9]+\\.[0-9]+)",
            "([0-9]+\\.[0-9]+)"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: cleaned, options: [], range: NSRange(cleaned.startIndex..., in: cleaned)),
               let range = Range(match.range(at: 1), in: cleaned) {
                return String(cleaned[range])
            }
        }

        return nil
    }

    /// Compare two version strings
    func compareVersions(_ v1: String, _ v2: String) -> ComparisonResult {
        let parts1 = v1.split(separator: ".").compactMap { Int($0) }
        let parts2 = v2.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(parts1.count, parts2.count) {
            let p1 = i < parts1.count ? parts1[i] : 0
            let p2 = i < parts2.count ? parts2[i] : 0

            if p1 < p2 { return .orderedAscending }
            if p1 > p2 { return .orderedDescending }
        }

        return .orderedSame
    }
}
