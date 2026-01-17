//
//  ApacheConfigValidator.swift
//  Velo
//
//  Handles Apache configuration validation.
//

import Foundation

struct ApacheConfigValidator {
    private let baseService = SSHBaseService.shared

    /// Validate the Apache configuration
    func validate(via session: TerminalViewModel) async -> (isValid: Bool, message: String) {
        // Try apache2ctl first (Debian), then apachectl (RHEL)
        let result = await baseService.execute("apache2ctl configtest 2>&1 || apachectl configtest 2>&1", via: session, timeout: 15)
        let output = result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        // Check for success indicator
        if output.lowercased().contains("syntax ok") {
            return (true, "Configuration is valid")
        }

        // If output is empty, assume success
        if output.isEmpty {
            return (true, "Configuration appears valid")
        }

        // Parse error message
        let errorMessage = parseErrorMessage(from: output)
        return (false, errorMessage)
    }

    /// Validate a specific configuration file
    func validateFile(_ filePath: String, via session: TerminalViewModel) async -> (isValid: Bool, message: String) {
        // Use -t flag with specific config
        let result = await baseService.execute("apache2 -t -f '\(filePath)' 2>&1 || httpd -t -f '\(filePath)' 2>&1", via: session, timeout: 15)
        let output = result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        if output.lowercased().contains("syntax ok") {
            return (true, "File syntax is valid")
        }

        let errorMessage = parseErrorMessage(from: output)
        return (false, errorMessage)
    }

    /// Check for common configuration issues
    func checkCommonIssues(via session: TerminalViewModel) async -> [String] {
        var issues: [String] = []

        // Check for duplicate ServerName
        let dupResult = await baseService.execute("""
            grep -rh 'ServerName' /etc/apache2/sites-enabled/ /etc/httpd/conf.d/ 2>/dev/null | awk '{print $2}' | sort | uniq -d
        """, via: session, timeout: 10)
        if !dupResult.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
            issues.append("Duplicate ServerName found in configuration")
        }

        // Check for missing SSL certificates
        let sslResult = await baseService.execute("""
            grep -rh 'SSLCertificateFile' /etc/apache2/sites-enabled/ /etc/httpd/conf.d/ 2>/dev/null | awk '{print $2}' | while read cert; do
                [ ! -f "$cert" ] && echo "Missing: $cert"
            done
        """, via: session, timeout: 10)
        if !sslResult.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
            issues.append("Missing SSL certificate files detected")
        }

        // Check if mod_rewrite is enabled
        let rewriteResult = await baseService.execute("apache2ctl -M 2>/dev/null | grep rewrite || apachectl -M 2>/dev/null | grep rewrite", via: session, timeout: 10)
        if rewriteResult.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
            issues.append("mod_rewrite is not enabled")
        }

        return issues
    }

    /// Enable an Apache module (Debian only)
    func enableModule(_ moduleName: String, via session: TerminalViewModel) async -> Bool {
        let result = await baseService.execute("sudo a2enmod \(moduleName) 2>&1 && echo 'ENABLED'", via: session, timeout: 15)
        return result.output.contains("ENABLED") || result.output.contains("already enabled")
    }

    /// Disable an Apache module (Debian only)
    func disableModule(_ moduleName: String, via session: TerminalViewModel) async -> Bool {
        let result = await baseService.execute("sudo a2dismod \(moduleName) 2>&1", via: session, timeout: 15)
        return true
    }

    /// Parse error message from apachectl configtest output
    private func parseErrorMessage(from output: String) -> String {
        let lines = output.components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Look for lines containing error details
        for line in lines {
            if line.lowercased().contains("error") || line.lowercased().contains("failed") || line.lowercased().contains("invalid") {
                return line
            }
        }

        // Return first meaningful line
        if let firstLine = lines.first {
            return firstLine
        }

        return "Configuration validation failed"
    }
}
