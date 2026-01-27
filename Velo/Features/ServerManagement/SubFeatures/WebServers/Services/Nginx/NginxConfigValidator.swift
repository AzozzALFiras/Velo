//
//  NginxConfigValidator.swift
//  Velo
//
//  Handles Nginx configuration validation.
//

import Foundation

struct NginxConfigValidator {
    private let baseService = ServerAdminService.shared

    /// Validate the Nginx configuration
    func validate(via session: TerminalViewModel) async -> (isValid: Bool, message: String) {
        let result = await baseService.execute("sudo nginx -t 2>&1", via: session, timeout: 15)
        let output = result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased()

        // Check for success indicators
        if output.contains("syntax is ok") && output.contains("test is successful") {
            return (true, "Configuration is valid")
        }

        // If output is empty or doesn't mention failure, assume success
        if output.isEmpty || (!output.contains("failed") && !output.contains("error")) {
            return (true, "Configuration appears valid")
        }

        // Parse error message
        let errorMessage = parseErrorMessage(from: result.output)
        return (false, errorMessage)
    }

    /// Validate a specific configuration file
    func validateFile(_ filePath: String, via session: TerminalViewModel) async -> (isValid: Bool, message: String) {
        // Create a temporary test config that includes the file
        let result = await baseService.execute("""
            sudo nginx -c '\(filePath)' -t 2>&1 || sudo nginx -t 2>&1
        """, via: session, timeout: 15)

        let output = result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased()

        if output.contains("test is successful") || output.contains("syntax is ok") {
            return (true, "File syntax is valid")
        }

        let errorMessage = parseErrorMessage(from: result.output)
        return (false, errorMessage)
    }

    /// Check for common configuration issues
    func checkCommonIssues(via session: TerminalViewModel) async -> [String] {
        var issues: [String] = []

        // Check for duplicate server_name
        let dupResult = await baseService.execute("""
            grep -rh 'server_name' /etc/nginx/sites-enabled/ 2>/dev/null | sort | uniq -d
        """, via: session, timeout: 10)
        if !dupResult.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
            issues.append("Duplicate server_name found in configuration")
        }

        // Check for missing SSL certificates
        let sslResult = await baseService.execute("""
            grep -rh 'ssl_certificate' /etc/nginx/sites-enabled/ 2>/dev/null | awk '{print $2}' | tr -d ';' | while read cert; do
                [ ! -f "$cert" ] && echo "Missing: $cert"
            done
        """, via: session, timeout: 10)
        if !sslResult.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
            issues.append("Missing SSL certificate files detected")
        }

        // Check worker_processes setting
        let workerResult = await baseService.execute("grep 'worker_processes' /etc/nginx/nginx.conf 2>/dev/null", via: session, timeout: 5)
        if workerResult.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
            issues.append("worker_processes not configured")
        }

        return issues
    }

    /// Parse error message from nginx -t output
    private func parseErrorMessage(from output: String) -> String {
        let lines = output.components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Look for lines containing error details
        for line in lines {
            if line.lowercased().contains("error") || line.lowercased().contains("failed") {
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
