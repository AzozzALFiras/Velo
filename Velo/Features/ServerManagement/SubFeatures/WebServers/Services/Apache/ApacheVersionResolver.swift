//
//  ApacheVersionResolver.swift
//  Velo
//
//  Handles Apache version detection and parsing.
//

import Foundation

struct ApacheVersionResolver {
    private let baseService = SSHBaseService.shared

    /// Get the installed Apache version
    func getVersion(via session: TerminalViewModel) async -> String? {
        // Try apache2 first (Debian), then httpd (RHEL)
        let result = await baseService.execute("apache2 -v 2>&1 | head -1 || httpd -v 2>&1 | head -1", via: session, timeout: 10)
        return parseVersion(from: result.output)
    }

    /// Get detailed version information
    func getDetailedVersion(via session: TerminalViewModel) async -> String? {
        let result = await baseService.execute("apache2 -V 2>&1 || httpd -V 2>&1", via: session, timeout: 10)
        return result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }

    /// Get list of loaded modules
    func getLoadedModules(via session: TerminalViewModel) async -> [String] {
        let result = await baseService.execute("apache2ctl -M 2>/dev/null || apachectl -M 2>/dev/null", via: session, timeout: 15)
        return result.output.components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("Loaded") && $0.contains("_module") }
    }

    /// Check if a specific module is enabled
    func isModuleEnabled(_ moduleName: String, via session: TerminalViewModel) async -> Bool {
        let modules = await getLoadedModules(via: session)
        return modules.contains { $0.contains(moduleName) }
    }

    /// Parse version number from apache2 -v output
    /// Example: "Server version: Apache/2.4.52 (Ubuntu)" -> "2.4.52"
    private func parseVersion(from output: String) -> String? {
        let cleaned = output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        // Try to extract version number
        let patterns = [
            "Apache/([0-9]+\\.[0-9]+\\.[0-9]+)",
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
}
