//
//  PHPDetector.swift
//  Velo
//
//  Handles PHP installation detection and availability checks.
//

import Foundation

struct PHPDetector {
    private let baseService = ServerAdminService.shared

    /// Check if PHP is installed on the server
    func isInstalled(via session: TerminalViewModel) async -> Bool {
        // 1. Check which
        let result = await baseService.execute("which php 2>/dev/null", via: session, timeout: 5)
        let path = result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if !path.isEmpty && path.hasPrefix("/") { return true }
        
        // 2. Check service (php-fpm)
        let fpmCheck = await baseService.execute("systemctl list-units --type=service --all | grep -E 'php.*fpm' | grep -v 'not-found' | wc -l", via: session, timeout: 5)
        let cleanedFpm = fpmCheck.output.filter { "0123456789".contains($0) }
        if let count = Int(cleanedFpm), count > 0 {
            return true
        }
        
        // 3. Check common binary paths
        let pathCheck = await baseService.execute("ls /usr/bin/php /usr/local/bin/php 2>/dev/null", via: session, timeout: 5)
        if !pathCheck.output.isEmpty && pathCheck.output.contains("php") { return true }
        
        // 4. Check package manager
        return await isPackageInstalled(via: session)
    }

    /// Get the path to the PHP binary
    func getBinaryPath(via session: TerminalViewModel) async -> String? {
        let result = await baseService.execute("which php 2>/dev/null", via: session, timeout: 5)
        let path = result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return path.isEmpty || !path.hasPrefix("/") ? nil : path
    }

    /// Check if PHP-FPM is installed
    func isFPMInstalled(via session: TerminalViewModel) async -> Bool {
        // Check for any php-fpm service
        let result = await baseService.execute("systemctl list-units --type=service --all | grep -E 'php.*fpm' | wc -l", via: session, timeout: 10)
        let cleaned = result.output.filter { "0123456789".contains($0) }
        if let count = Int(cleaned), count > 0 {
            return true
        }

        // Check for php-fpm binary
        let binaryResult = await baseService.execute("which php-fpm 2>/dev/null || find /usr/sbin -name 'php-fpm*' 2>/dev/null | head -1", via: session, timeout: 10)
        return !binaryResult.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty
    }

    /// Check if PHP was installed via package manager
    func isPackageInstalled(via session: TerminalViewModel) async -> Bool {
        // Check Debian/Ubuntu
        let dpkgResult = await baseService.execute("dpkg -l | grep -E '^ii\\s+php[0-9]' | wc -l", via: session, timeout: 10)
        let cleanedDpkg = dpkgResult.output.filter { "0123456789".contains($0) }
        if let count = Int(cleanedDpkg), count > 0 {
            return true
        }

        // Check RHEL/CentOS
        let rpmResult = await baseService.execute("rpm -qa | grep -E '^php[0-9]' | wc -l", via: session, timeout: 10)
        let cleanedRpm = rpmResult.output.filter { "0123456789".contains($0) }
        if let count = Int(cleanedRpm), count > 0 {
            return true
        }

        return false
    }

    /// Get list of available PHP packages that can be installed
    func getAvailablePackages(via session: TerminalViewModel) async -> [String] {
        // Check apt cache for available PHP packages
        let result = await baseService.execute("apt-cache search '^php[0-9]\\.[0-9]-' 2>/dev/null | awk '{print $1}' | sort -u | head -50", via: session, timeout: 15)
        return result.output.components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
