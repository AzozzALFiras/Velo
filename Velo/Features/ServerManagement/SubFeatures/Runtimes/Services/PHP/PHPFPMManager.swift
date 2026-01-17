//
//  PHPFPMManager.swift
//  Velo
//
//  Manages PHP-FPM service instances including multi-version support.
//

import Foundation

struct PHPFPMManager {
    private let baseService = SSHBaseService.shared

    // MARK: - Active FPM Operations

    /// Check if any PHP-FPM instance is running
    func isAnyFPMRunning(via session: TerminalViewModel) async -> Bool {
        let result = await baseService.execute("systemctl is-active php*-fpm 2>/dev/null | grep -q active && echo 'RUNNING'", via: session, timeout: 10)
        if result.output.contains("RUNNING") {
            return true
        }

        // Alternative check
        let altResult = await baseService.execute("systemctl list-units --type=service --state=running | grep -E 'php.*fpm' | wc -l", via: session, timeout: 10)
        if let count = Int(altResult.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)), count > 0 {
            return true
        }

        return false
    }

    /// Start the active/default PHP-FPM
    func startActiveFPM(via session: TerminalViewModel) async -> Bool {
        let serviceName = await detectActiveFPMService(via: session)
        let result = await baseService.execute("sudo systemctl start \(serviceName) 2>&1 && echo 'STARTED'", via: session, timeout: 30)
        return result.output.contains("STARTED")
    }

    /// Stop the active/default PHP-FPM
    func stopActiveFPM(via session: TerminalViewModel) async -> Bool {
        let serviceName = await detectActiveFPMService(via: session)
        let result = await baseService.execute("sudo systemctl stop \(serviceName) 2>&1 && echo 'STOPPED'", via: session, timeout: 30)
        return result.output.contains("STOPPED")
    }

    /// Restart the active/default PHP-FPM
    func restartActiveFPM(via session: TerminalViewModel) async -> Bool {
        let serviceName = await detectActiveFPMService(via: session)
        let result = await baseService.execute("sudo systemctl restart \(serviceName) 2>&1 && echo 'RESTARTED'", via: session, timeout: 30)
        return result.output.contains("RESTARTED")
    }

    /// Reload the active/default PHP-FPM configuration
    func reloadActiveFPM(via session: TerminalViewModel) async -> Bool {
        let serviceName = await detectActiveFPMService(via: session)
        let result = await baseService.execute("sudo systemctl reload \(serviceName) 2>&1 && echo 'RELOADED'", via: session, timeout: 30)
        return result.output.contains("RELOADED")
    }

    /// Enable the active/default PHP-FPM to start on boot
    func enableActiveFPM(via session: TerminalViewModel) async -> Bool {
        let serviceName = await detectActiveFPMService(via: session)
        let result = await baseService.execute("sudo systemctl enable \(serviceName) 2>&1 && echo 'ENABLED'", via: session, timeout: 30)
        return result.output.contains("ENABLED")
    }

    /// Disable the active/default PHP-FPM from starting on boot
    func disableActiveFPM(via session: TerminalViewModel) async -> Bool {
        let serviceName = await detectActiveFPMService(via: session)
        let result = await baseService.execute("sudo systemctl disable \(serviceName) 2>&1 && echo 'DISABLED'", via: session, timeout: 30)
        return result.output.contains("DISABLED")
    }

    // MARK: - Version-Specific FPM Operations

    /// Start FPM for a specific PHP version
    func startFPM(version: String, via session: TerminalViewModel) async -> Bool {
        let serviceName = "php\(version)-fpm"
        let result = await baseService.execute("sudo systemctl start \(serviceName) 2>&1 && echo 'STARTED'", via: session, timeout: 30)
        return result.output.contains("STARTED")
    }

    /// Stop FPM for a specific PHP version
    func stopFPM(version: String, via session: TerminalViewModel) async -> Bool {
        let serviceName = "php\(version)-fpm"
        let result = await baseService.execute("sudo systemctl stop \(serviceName) 2>&1 && echo 'STOPPED'", via: session, timeout: 30)
        return result.output.contains("STOPPED")
    }

    /// Restart FPM for a specific PHP version
    func restartFPM(version: String, via session: TerminalViewModel) async -> Bool {
        let serviceName = "php\(version)-fpm"
        let result = await baseService.execute("sudo systemctl restart \(serviceName) 2>&1 && echo 'RESTARTED'", via: session, timeout: 30)
        return result.output.contains("RESTARTED")
    }

    /// Check if FPM for a specific version is running
    func isFPMRunning(version: String, via session: TerminalViewModel) async -> Bool {
        let serviceName = "php\(version)-fpm"
        let result = await baseService.execute("systemctl is-active \(serviceName) 2>/dev/null", via: session, timeout: 10)
        return result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) == "active"
    }

    // MARK: - FPM Status

    /// Get status of all PHP-FPM instances
    func getAllFPMStatus(via session: TerminalViewModel) async -> [String: Bool] {
        let result = await baseService.execute("""
            for svc in $(systemctl list-units --type=service --all | grep -oE 'php[0-9.]+-fpm' | sort -u); do
                status=$(systemctl is-active $svc 2>/dev/null)
                echo "$svc:$status"
            done
        """, via: session, timeout: 15)

        var status: [String: Bool] = [:]
        let lines = result.output.components(separatedBy: CharacterSet.newlines)

        for line in lines {
            let parts = line.split(separator: ":")
            if parts.count == 2 {
                let serviceName = String(parts[0]).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                let isActive = String(parts[1]).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) == "active"
                status[serviceName] = isActive
            }
        }

        return status
    }

    /// Get list of all installed FPM services
    func getInstalledFPMServices(via session: TerminalViewModel) async -> [String] {
        let result = await baseService.execute("systemctl list-units --type=service --all | grep -oE 'php[0-9.]+-fpm' | sort -u", via: session, timeout: 10)
        return result.output.components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // MARK: - FPM Pool Management

    /// Get FPM pool configuration path for a version
    func getPoolConfigPath(version: String, via session: TerminalViewModel) async -> String {
        return "/etc/php/\(version)/fpm/pool.d/www.conf"
    }

    /// Get FPM socket path for a version
    func getSocketPath(version: String, via session: TerminalViewModel) async -> String? {
        let possiblePaths = [
            "/var/run/php/php\(version)-fpm.sock",
            "/run/php/php\(version)-fpm.sock",
            "/var/run/php-fpm/php\(version)-fpm.sock"
        ]

        for path in possiblePaths {
            let result = await baseService.execute("test -S '\(path)' && echo 'EXISTS'", via: session, timeout: 5)
            if result.output.contains("EXISTS") {
                return path
            }
        }

        return nil
    }

    // MARK: - Private Helpers

    /// Detect the active PHP-FPM service name
    private func detectActiveFPMService(via session: TerminalViewModel) async -> String {
        // First try to find a running FPM service
        let runningResult = await baseService.execute("systemctl list-units --type=service --state=running | grep -oE 'php[0-9.]+-fpm' | head -1", via: session, timeout: 10)
        let runningService = runningResult.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        if !runningService.isEmpty {
            return runningService
        }

        // Find any installed FPM service
        let installedResult = await baseService.execute("systemctl list-units --type=service --all | grep -oE 'php[0-9.]+-fpm' | head -1", via: session, timeout: 10)
        let installedService = installedResult.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        if !installedService.isEmpty {
            return installedService
        }

        // Fallback to generic php-fpm
        return "php-fpm"
    }
}
