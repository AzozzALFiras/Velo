//
//  NginxDetector.swift
//  Velo
//
//  Handles Nginx installation detection and availability checks.
//

import Foundation

struct NginxDetector {
    private let baseService = SSHBaseService.shared

    /// Check if Nginx is installed on the server
    func isInstalled(via session: TerminalViewModel) async -> Bool {
        // 1. Check which
        let result = await baseService.execute("which nginx 2>/dev/null", via: session, timeout: 5)
        let path = result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if !path.isEmpty && path.hasPrefix("/") { return true }
        
        // 2. Check service status
        let serviceResult = await baseService.execute("systemctl is-active nginx 2>/dev/null || systemctl is-enabled nginx 2>/dev/null", via: session, timeout: 5)
        let sOut = serviceResult.output.lowercased()
        if sOut.contains("active") || sOut.contains("enabled") || sOut.contains("started") { return true }
        
        // 3. Check common installation paths
        let pathCheck = await baseService.execute("ls /usr/sbin/nginx /usr/local/bin/nginx /usr/bin/nginx 2>/dev/null", via: session, timeout: 5)
        if !pathCheck.output.isEmpty && pathCheck.output.contains("nginx") { return true }
        
        // 4. Check package manager
        return await isPackageInstalled(via: session)
    }

    /// Check if Nginx binary exists at a specific path
    func binaryExists(at path: String, via session: TerminalViewModel) async -> Bool {
        let result = await baseService.execute("test -x '\(path)' && echo 'EXISTS'", via: session, timeout: 5)
        return result.output.contains("EXISTS")
    }

    /// Get the path to the Nginx binary
    func getBinaryPath(via session: TerminalViewModel) async -> String? {
        let result = await baseService.execute("which nginx 2>/dev/null", via: session, timeout: 10)
        let path = result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return path.isEmpty || !path.hasPrefix("/") ? nil : path
    }

    /// Check if Nginx was installed via package manager
    func isPackageInstalled(via session: TerminalViewModel) async -> Bool {
        // Check Debian/Ubuntu
        let dpkgResult = await baseService.execute("dpkg -l nginx 2>/dev/null | grep -E '^ii' | wc -l", via: session, timeout: 10)
        if let count = Int(dpkgResult.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)), count > 0 {
            return true
        }

        // Check RHEL/CentOS
        let rpmResult = await baseService.execute("rpm -q nginx 2>/dev/null | grep -v 'not installed' | wc -l", via: session, timeout: 10)
        if let count = Int(rpmResult.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)), count > 0 {
            return true
        }

        return false
    }
}
