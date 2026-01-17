//
//  PHPVersionResolver.swift
//  Velo
//
//  Handles PHP version detection, listing, and switching.
//

import Foundation

struct PHPVersionResolver {
    private let baseService = SSHBaseService.shared

    /// Get the currently active PHP version
    func getActiveVersion(via session: TerminalViewModel) async -> String? {
        let result = await baseService.execute("php -v 2>/dev/null | head -1 | awk '{print $2}'", via: session, timeout: 10)
        return parseVersion(from: result.output)
    }

    /// Get list of all installed PHP versions
    func getInstalledVersions(via session: TerminalViewModel) async -> [String] {
        // Check /etc/php directory for installed versions
        let result = await baseService.execute("ls -1 /etc/php/ 2>/dev/null | grep -E '^[0-9]'", via: session, timeout: 10)
        let versions = result.output.components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0.first?.isNumber == true }

        if !versions.isEmpty {
            return versions.sorted { compareVersions($0, $1) == .orderedDescending }
        }

        // Fallback: check for php binaries
        let binaryResult = await baseService.execute("ls -1 /usr/bin/php* 2>/dev/null | grep -oE '[0-9]+\\.[0-9]+' | sort -u", via: session, timeout: 10)
        return binaryResult.output.components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted { compareVersions($0, $1) == .orderedDescending }
    }

    /// Switch the default PHP version
    func switchVersion(to version: String, via session: TerminalViewModel) async -> Bool {
        // Check if update-alternatives is available (Debian/Ubuntu)
        let checkResult = await baseService.execute("which update-alternatives 2>/dev/null", via: session, timeout: 5)

        if !checkResult.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
            // Use update-alternatives for Debian/Ubuntu
            let result = await baseService.execute("""
                sudo update-alternatives --set php /usr/bin/php\(version) 2>&1 && echo 'SWITCHED'
            """, via: session, timeout: 15)

            if result.output.contains("SWITCHED") {
                // Also switch php-fpm if available
                _ = await baseService.execute("sudo update-alternatives --set php-fpm /usr/sbin/php-fpm\(version) 2>/dev/null || true", via: session, timeout: 10)
                return true
            }
        }

        // Manual symlink approach as fallback
        let symlinkResult = await baseService.execute("""
            sudo ln -sf /usr/bin/php\(version) /usr/bin/php && echo 'LINKED'
        """, via: session, timeout: 10)

        return symlinkResult.output.contains("LINKED")
    }

    /// Get PHP configuration file path for a specific version
    func getConfigPath(version: String, via session: TerminalViewModel) async -> String? {
        // Check FPM config first
        let fpmPath = "/etc/php/\(version)/fpm/php.ini"
        let fpmResult = await baseService.execute("test -f '\(fpmPath)' && echo 'EXISTS'", via: session, timeout: 5)
        if fpmResult.output.contains("EXISTS") {
            return fpmPath
        }

        // Check CLI config
        let cliPath = "/etc/php/\(version)/cli/php.ini"
        let cliResult = await baseService.execute("test -f '\(cliPath)' && echo 'EXISTS'", via: session, timeout: 5)
        if cliResult.output.contains("EXISTS") {
            return cliPath
        }

        return nil
    }

    /// Parse version number from php -v output
    private func parseVersion(from output: String) -> String? {
        let cleaned = output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        // Extract major.minor version (e.g., 8.2 from 8.2.10)
        if let regex = try? NSRegularExpression(pattern: "([0-9]+\\.[0-9]+)", options: []),
           let match = regex.firstMatch(in: cleaned, options: [], range: NSRange(cleaned.startIndex..., in: cleaned)),
           let range = Range(match.range(at: 1), in: cleaned) {
            return String(cleaned[range])
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
