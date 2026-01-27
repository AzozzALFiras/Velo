//
//  NginxVersionResolver.swift
//  Velo
//
//  Handles Nginx version detection and parsing.
//

import Foundation

struct NginxVersionResolver {
    private let baseService = ServerAdminService.shared

    /// Get the installed Nginx version
    func getVersion(via session: TerminalViewModel) async -> String? {
        let result = await baseService.execute("nginx -v 2>&1 | head -1", via: session, timeout: 10)
        return parseVersion(from: result.output)
    }

    /// Get detailed version information (including build options)
    func getDetailedVersion(via session: TerminalViewModel) async -> String? {
        let result = await baseService.execute("nginx -V 2>&1 | head -1", via: session, timeout: 10)
        return result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }

    /// Get list of loaded modules
    func getLoadedModules(via session: TerminalViewModel) async -> [String] {
        let result = await baseService.execute("nginx -V 2>&1 | grep -oE 'with-[a-zA-Z0-9_-]+' | sort -u", via: session, timeout: 10)
        return result.output.components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    /// Parse version number from nginx -v output
    /// Example: "nginx version: nginx/1.18.0 (Ubuntu)" -> "1.18.0"
    private func parseVersion(from output: String) -> String? {
        let cleaned = output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        // Try to extract version number
        let patterns = [
            "nginx/([0-9]+\\.[0-9]+\\.[0-9]+)",
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
