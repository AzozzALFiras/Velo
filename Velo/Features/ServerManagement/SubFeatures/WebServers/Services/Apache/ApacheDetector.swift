//
//  ApacheDetector.swift
//  Velo
//
//  Handles Apache installation detection and availability checks.
//

import Foundation

struct ApacheDetector {
    private let baseService = ServerAdminService.shared

    /// Check if Apache is installed on the server
    func isInstalled(via session: TerminalViewModel) async -> Bool {
        // 1. Check which (apache2 or httpd)
        let result = await baseService.execute("which apache2 2>/dev/null || which httpd 2>/dev/null", via: session, timeout: 5)
        let path = result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if !path.isEmpty && path.hasPrefix("/") { return true }
        
        // 2. Check service status
        let serviceResult = await baseService.execute("systemctl is-active apache2 2>/dev/null || systemctl is-active httpd 2>/dev/null || systemctl is-enabled apache2 2>/dev/null || systemctl is-enabled httpd 2>/dev/null", via: session, timeout: 5)
        let sOut = serviceResult.output.lowercased()
        if sOut.contains("active") || sOut.contains("enabled") || sOut.contains("started") { return true }
        
        // 3. Check common installation paths
        let pathCheck = await baseService.execute("ls /usr/sbin/apache2 /usr/sbin/httpd /usr/bin/apache2 /usr/bin/httpd 2>/dev/null", via: session, timeout: 5)
        if !pathCheck.output.isEmpty && (pathCheck.output.contains("apache") || pathCheck.output.contains("httpd")) { return true }
        
        // 4. Check package manager
        return await isPackageInstalled(via: session)
    }

    /// Get the service name (varies by OS)
    func getServiceName(via session: TerminalViewModel) async -> String {
        // Check if apache2 service exists (Debian/Ubuntu)
        let apache2Result = await baseService.execute("systemctl list-units --type=service | grep -q apache2 && echo 'apache2'", via: session, timeout: 10)
        if apache2Result.output.contains("apache2") {
            return "apache2"
        }

        // Check if httpd service exists (RHEL/CentOS)
        let httpdResult = await baseService.execute("systemctl list-units --type=service | grep -q httpd && echo 'httpd'", via: session, timeout: 10)
        if httpdResult.output.contains("httpd") {
            return "httpd"
        }

        // Default to apache2
        return "apache2"
    }

    /// Get the binary name (varies by OS)
    func getBinaryName(via session: TerminalViewModel) async -> String {
        let apache2Result = await baseService.execute("which apache2 2>/dev/null", via: session, timeout: 5)
        if !apache2Result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
            return "apache2"
        }
        return "httpd"
    }

    /// Get the path to the Apache binary
    func getBinaryPath(via session: TerminalViewModel) async -> String? {
        let result = await baseService.execute("which apache2 2>/dev/null || which httpd 2>/dev/null", via: session, timeout: 10)
        let path = result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return path.isEmpty || !path.hasPrefix("/") ? nil : path
    }

    /// Check if Apache was installed via package manager
    func isPackageInstalled(via session: TerminalViewModel) async -> Bool {
        // Check Debian/Ubuntu
        let dpkgResult = await baseService.execute("dpkg -l apache2 2>/dev/null | grep -E '^ii' | wc -l", via: session, timeout: 10)
        if let count = Int(dpkgResult.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)), count > 0 {
            return true
        }

        // Check RHEL/CentOS
        let rpmResult = await baseService.execute("rpm -q httpd 2>/dev/null | grep -v 'not installed' | wc -l", via: session, timeout: 10)
        if let count = Int(rpmResult.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)), count > 0 {
            return true
        }

        return false
    }
}
