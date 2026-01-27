//
//  MySQLVersionResolver.swift
//  Velo
//
//  Handles MySQL/MariaDB version detection and parsing.
//

import Foundation

struct MySQLVersionResolver {
    private let baseService = ServerAdminService.shared

    /// Get the installed MySQL/MariaDB version
    func getVersion(via session: TerminalViewModel) async -> String? {
        let result = await baseService.execute("mysql --version 2>&1 | head -1", via: session, timeout: 10)
        return parseVersion(from: result.output)
    }

    /// Get detailed version information from server
    func getServerVersion(via session: TerminalViewModel) async -> String? {
        let result = await baseService.execute("mysql -e 'SELECT VERSION()' 2>/dev/null || sudo mysql -e 'SELECT VERSION()' 2>/dev/null | tail -1", via: session, timeout: 10)
        return result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }

    /// Check if this is MariaDB
    func isMariaDB(via session: TerminalViewModel) async -> Bool {
        let result = await baseService.execute("mysql --version 2>&1", via: session, timeout: 10)
        return result.output.lowercased().contains("mariadb")
    }

    /// Get the distribution name (MySQL or MariaDB)
    func getDistributionName(via session: TerminalViewModel) async -> String {
        return await isMariaDB(via: session) ? "MariaDB" : "MySQL"
    }

    /// Parse version number from mysql --version output
    /// Example: "mysql  Ver 8.0.32 for Linux on x86_64 (MySQL Community Server - GPL)" -> "8.0.32"
    /// Example: "mysql  Ver 15.1 Distrib 10.6.12-MariaDB" -> "10.6.12"
    private func parseVersion(from output: String) -> String? {
        let cleaned = output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        // Try to extract MariaDB version first
        if cleaned.lowercased().contains("mariadb") {
            if let regex = try? NSRegularExpression(pattern: "([0-9]+\\.[0-9]+\\.[0-9]+)-MariaDB", options: .caseInsensitive),
               let match = regex.firstMatch(in: cleaned, options: [], range: NSRange(cleaned.startIndex..., in: cleaned)),
               let range = Range(match.range(at: 1), in: cleaned) {
                return String(cleaned[range])
            }
        }

        // Try standard version patterns
        let patterns = [
            "Ver\\s+([0-9]+\\.[0-9]+\\.[0-9]+)",
            "Distrib\\s+([0-9]+\\.[0-9]+\\.[0-9]+)",
            "([0-9]+\\.[0-9]+\\.[0-9]+)",
            "([0-9]+\\.[0-9]+)"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
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
