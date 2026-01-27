//
//  ServerHealthCheckService.swift
//  Velo
//
//  Service that performs health checks on the server and provides auto-fix functionality.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class ServerHealthCheckService: ObservableObject {
    
    static let shared = ServerHealthCheckService()
    
    // MARK: - Published State
    
    @Published var detectedIssues: [HealthCheckIssue] = []
    @Published var isChecking = false
    @Published var isFixing = false
    @Published var lastCheckDate: Date?
    @Published var fixProgress: String = ""
    
    private var osType: String = ""
    
    // MARK: - Health Checks Database
    
    private lazy var healthChecks: [HealthCheck] = [
        
        // MARK: APT/DPKG Issues (Debian/Ubuntu)
        
        HealthCheck(
            id: "APT_CNF_MISSING",
            osTypes: ["ubuntu", "debian"],
            checkCommand: "test -f /usr/lib/cnf-update-db && echo 'ok' || echo 'missing'",
            expectedOutput: "ok",
            issue: HealthCheckIssue(
                id: "APT_CNF_MISSING",
                severity: .warning,
                title: "Package Manager Hook Error",
                description: "apt update fails due to missing command-not-found database. This prevents software installation.",
                affectedOS: ["ubuntu", "debian"],
                canAutoFix: true,
                fixDescription: "Reinstall command-not-found package or remove the hook"
            ),
            fixCommands: [
                "DEBIAN_FRONTEND=noninteractive apt install command-not-found --reinstall -y 2>/dev/null || rm -f /etc/apt/apt.conf.d/50command-not-found"
            ]
        ),
        
        HealthCheck(
            id: "DPKG_LOCK",
            osTypes: ["ubuntu", "debian"],
            checkCommand: "fuser /var/lib/dpkg/lock-frontend 2>/dev/null | wc -w",
            expectedOutput: "0",
            issue: HealthCheckIssue(
                id: "DPKG_LOCK",
                severity: .critical,
                title: "Package Manager Locked",
                description: "Another process is using the package manager. Software installation will fail.",
                affectedOS: ["ubuntu", "debian"],
                canAutoFix: true,
                fixDescription: "Wait for the lock to be released"
            ),
            fixCommands: [
                "while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do sleep 2; done; echo 'Lock released'"
            ]
        ),
        
        HealthCheck(
            id: "BROKEN_PACKAGES",
            osTypes: ["ubuntu", "debian"],
            checkCommand: "dpkg --audit 2>&1 | grep -v '^$' | wc -l",
            expectedOutput: "0",
            issue: HealthCheckIssue(
                id: "BROKEN_PACKAGES",
                severity: .critical,
                title: "Broken Packages Detected",
                description: "Some packages are in a broken state. This may prevent new installations.",
                affectedOS: ["ubuntu", "debian"],
                canAutoFix: true,
                fixDescription: "Configure pending packages and fix broken dependencies"
            ),
            fixCommands: [
                "DEBIAN_FRONTEND=noninteractive dpkg --configure -a",
                "DEBIAN_FRONTEND=noninteractive apt --fix-broken install -y"
            ]
        ),
        
        // APT_UPDATE_NEEDED removed - too unreliable for automatic detection
        
        // MARK: YUM/DNF Issues (CentOS/Rocky/AlmaLinux)
        
        HealthCheck(
            id: "YUM_CACHE_ISSUES",
            osTypes: ["centos", "rocky", "almalinux", "rhel"],
            checkCommand: "yum check 2>&1 | grep -iE 'error|duplicate' | wc -l",
            expectedOutput: "0",
            issue: HealthCheckIssue(
                id: "YUM_CACHE_ISSUES",
                severity: .warning,
                title: "YUM Cache Problems",
                description: "Package manager cache has errors that may affect installations.",
                affectedOS: ["centos", "rocky", "almalinux"],
                canAutoFix: true,
                fixDescription: "Clean and rebuild package cache"
            ),
            fixCommands: [
                "yum clean all",
                "yum makecache"
            ]
        ),
        
        // MARK: Disk Space
        
        HealthCheck(
            id: "LOW_DISK_SPACE",
            osTypes: ["all"],
            checkCommand: "df / | tail -1 | awk '{gsub(/%/,\"\"); print $5}'",
            expectedOutput: "<90",
            issue: HealthCheckIssue(
                id: "LOW_DISK_SPACE",
                severity: .warning,
                title: "Low Disk Space",
                description: "Root partition is almost full (>90%). This may cause installation failures.",
                affectedOS: ["all"],
                canAutoFix: true,
                fixDescription: "Clean old packages, logs, and temporary files"
            ),
            fixCommands: [
                "apt autoremove -y 2>/dev/null || yum autoremove -y 2>/dev/null || true",
                "journalctl --vacuum-time=3d 2>/dev/null || true",
                "find /var/log -name '*.gz' -delete 2>/dev/null || true",
                "find /tmp -type f -atime +7 -delete 2>/dev/null || true"
            ]
        ),
        
        HealthCheck(
            id: "LOW_DISK_SPACE_CRITICAL",
            osTypes: ["all"],
            checkCommand: "df / | tail -1 | awk '{gsub(/%/,\"\"); print $5}'",
            expectedOutput: "<95",
            issue: HealthCheckIssue(
                id: "LOW_DISK_SPACE_CRITICAL",
                severity: .critical,
                title: "Critical Disk Space",
                description: "Root partition is critically full (>95%). Server may become unresponsive.",
                affectedOS: ["all"],
                canAutoFix: true,
                fixDescription: "Aggressive cleanup of old files"
            ),
            fixCommands: [
                "apt autoremove --purge -y 2>/dev/null || yum autoremove -y 2>/dev/null || true",
                "apt clean 2>/dev/null || yum clean all 2>/dev/null || true",
                "journalctl --vacuum-size=100M 2>/dev/null || true",
                "find /var/log -name '*.log' -size +100M -exec truncate -s 0 {} \\; 2>/dev/null || true"
            ]
        ),
        
        // MARK: System Time
        
        HealthCheck(
            id: "TIME_NOT_SYNCED",
            osTypes: ["all"],
            checkCommand: "timedatectl 2>/dev/null | grep -i 'synchronized.*yes' | wc -l",
            expectedOutput: "1",
            issue: HealthCheckIssue(
                id: "TIME_NOT_SYNCED",
                severity: .info,
                title: "System Time Not Synchronized",
                description: "System clock is not synchronized. This may cause SSL certificate issues.",
                affectedOS: ["all"],
                canAutoFix: true,
                fixDescription: "Enable NTP time synchronization"
            ),
            fixCommands: [
                "timedatectl set-ntp true 2>/dev/null || systemctl enable --now chronyd 2>/dev/null || true"
            ]
        ),
        
        // MARK: Memory/Swap
        
        HealthCheck(
            id: "NO_SWAP",
            osTypes: ["all"],
            checkCommand: "free | grep -i swap | awk '{print $2}'",
            expectedOutput: ">0",
            issue: HealthCheckIssue(
                id: "NO_SWAP",
                severity: .info,
                title: "No Swap Configured",
                description: "Server has no swap space. May crash under memory pressure.",
                affectedOS: ["all"],
                canAutoFix: false,  // Creating swap is risky auto-operation
                fixDescription: nil
            ),
            fixCommands: []
        ),
        
        // MARK: Security Informational (No Auto-Fix)
        
        HealthCheck(
            id: "FIREWALL_INACTIVE",
            osTypes: ["ubuntu", "debian"],
            checkCommand: "ufw status 2>/dev/null | grep -i 'active' | wc -l",
            expectedOutput: "1",
            issue: HealthCheckIssue(
                id: "FIREWALL_INACTIVE",
                severity: .info,
                title: "Firewall Not Active",
                description: "UFW firewall is not running. Consider enabling it for security.",
                affectedOS: ["ubuntu", "debian"],
                canAutoFix: false,  // Don't auto-enable firewall - could lock user out
                fixDescription: nil
            ),
            fixCommands: []
        ),
        
        // MARK: Old Kernels (cleanup)
        
        HealthCheck(
            id: "OLD_KERNELS",
            osTypes: ["ubuntu", "debian"],
            checkCommand: "dpkg --list 'linux-image-*' 2>/dev/null | grep -c '^ii' || echo '0'",
            expectedOutput: "<4",
            issue: HealthCheckIssue(
                id: "OLD_KERNELS",
                severity: .info,
                title: "Old Kernel Versions",
                description: "Multiple old kernel versions are installed, using disk space.",
                affectedOS: ["ubuntu", "debian"],
                canAutoFix: true,
                fixDescription: "Remove old kernel versions"
            ),
            fixCommands: [
                "apt autoremove --purge -y 2>/dev/null || true"
            ]
        )
    ]
    
    // MARK: - Public Methods
    
    /// Run all applicable health checks for the connected server
    func runAllChecks(via session: TerminalViewModel) async {
        isChecking = true
        detectedIssues = []
        
        // Detect OS first
        osType = await detectOS(via: session)
        print("[HealthCheck] Detected OS: \(osType)")
        
        // Run each applicable check
        for check in healthChecks {
            guard check.appliesTo(os: osType) else { continue }
            
            // Skip if we already have a similar issue (e.g., don't show both disk space warnings)
            if check.id == "LOW_DISK_SPACE" && detectedIssues.contains(where: { $0.id == "LOW_DISK_SPACE_CRITICAL" }) {
                continue
            }
            
            if let issue = await runCheck(check, via: session) {
                // For LOW_DISK_SPACE_CRITICAL, remove the regular warning if present
                if issue.id == "LOW_DISK_SPACE_CRITICAL" {
                    detectedIssues.removeAll { $0.id == "LOW_DISK_SPACE" }
                }
                detectedIssues.append(issue)
                print("[HealthCheck] Issue detected: \(issue.title)")
            }
        }
        
        lastCheckDate = Date()
        isChecking = false
        
        print("[HealthCheck] Completed. Found \(detectedIssues.count) issues.")
    }
    
    /// Auto-fix all fixable issues
    func autoFixAll(via session: TerminalViewModel) async -> Int {
        isFixing = true
        var fixedCount = 0
        
        let fixableIssues = detectedIssues.filter { $0.canAutoFix }
        
        for (index, issue) in fixableIssues.enumerated() {
            fixProgress = "Fixing \(index + 1)/\(fixableIssues.count): \(issue.title)"
            
            if await fixIssue(issue.id, via: session) {
                fixedCount += 1
            }
        }
        
        fixProgress = ""
        isFixing = false
        
        // Re-run checks to verify fixes
        await runAllChecks(via: session)
        
        return fixedCount
    }
    
    /// Fix a specific issue by ID
    func fixIssue(_ issueId: String, via session: TerminalViewModel) async -> Bool {
        guard let check = healthChecks.first(where: { $0.id == issueId }) else {
            return false
        }
        
        guard !check.fixCommands.isEmpty else {
            return false
        }
        
        print("[HealthCheck] Fixing issue: \(issueId)")
        
        for command in check.fixCommands {
            let result = await ServerAdminService.shared.execute(command, via: session, timeout: 300)
            if result.exitCode != 0 {
                print("[HealthCheck] Fix command failed: \(command)")
                print("[HealthCheck] Output: \(result.output)")
                // Continue with other fix commands even if one fails
            }
        }
        
        return true
    }
    
    // MARK: - Private Methods
    
    private func detectOS(via session: TerminalViewModel) async -> String {
        let result = await ServerAdminService.shared.execute(
            "cat /etc/os-release 2>/dev/null | grep ^ID= | cut -d= -f2 | tr -d '\"'",
            via: session
        )
        // Strip ANSI codes and get clean OS name
        var cleaned = result.output
        if let regex = try? NSRegularExpression(pattern: "\\x1B\\[[0-9;]*[a-zA-Z]") {
            cleaned = regex.stringByReplacingMatches(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: "")
        }
        cleaned = cleaned.replacingOccurrences(of: "\u{001B}", with: "")
        let lines = cleaned.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }
        return lines.first(where: { !$0.isEmpty && $0.allSatisfy { $0.isLetter } }) ?? "unknown"
    }
    
    private func runCheck(_ check: HealthCheck, via session: TerminalViewModel) async -> HealthCheckIssue? {
        let result = await ServerAdminService.shared.execute(check.checkCommand, via: session, timeout: 30)
        
        let hasProblem = check.hasProblem(output: result.output)
        print("[HealthCheck] Check \(check.id): output='\(result.output.prefix(50))...' hasProblem=\(hasProblem)")
        
        if hasProblem {
            return check.issue
        }
        
        return nil
    }
}
