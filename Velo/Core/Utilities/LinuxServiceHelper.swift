//
//  LinuxServiceHelper.swift
//  Velo
//
//  Utility for managing systemd services on remote Linux servers.
//

import Foundation

@MainActor
final class LinuxServiceHelper {
    
    /// Execute a standard systemctl command
    static func executeAction(_ action: ServiceAction, serviceName: String, via session: TerminalViewModel) async -> Bool {
        let cmd = "sudo systemctl \(action.rawValue) \(serviceName)"
        let result = await ServerAdminService.shared.execute(cmd, via: session, timeout: 30)
        
        // Some actions like start/stop don't return output on success, 
        // so we check the exit code.
        return result.exitCode == 0
    }
    
    /// Check if a service is active
    static func isActive(serviceName: String, via session: TerminalViewModel) async -> Bool {
        let cmd = "systemctl is-active \(serviceName) 2>/dev/null"
        let result = await ServerAdminService.shared.execute(cmd, via: session, timeout: 10)
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines) == "active"
    }
    
    /// Get detailed status message
    static func getStatusMessage(serviceName: String, via session: TerminalViewModel) async -> String {
        let cmd = "systemctl status \(serviceName) --no-pager 2>/dev/null"
        let result = await ServerAdminService.shared.execute(cmd, via: session, timeout: 10)
        return result.output
    }
    
    // MARK: - Service Checks
    
    /// Check if a service exists (is loaded or enabled)
    static func serviceExists(serviceName: String, via session: TerminalViewModel) async -> Bool {
        // Check loaded state
        let loadedCheck = await ServerAdminService.shared.execute("systemctl list-units --full -all | grep -F \"\(serviceName).service\"", via: session, timeout: 5)
        if !loadedCheck.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        
        // Check unit file
        let fileCheck = await ServerAdminService.shared.execute("systemctl list-unit-files | grep -F \"\(serviceName).service\"", via: session, timeout: 5)
        return !fileCheck.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Convenience Wrappers
    
    static func startService(serviceName: String, via session: TerminalViewModel) async -> Bool {
        return await executeAction(.start, serviceName: serviceName, via: session)
    }
    
    static func stopService(serviceName: String, via session: TerminalViewModel) async -> Bool {
        return await executeAction(.stop, serviceName: serviceName, via: session)
    }
    
    static func restartService(serviceName: String, via session: TerminalViewModel) async -> Bool {
        return await executeAction(.restart, serviceName: serviceName, via: session)
    }
    
    static func reloadService(serviceName: String, via session: TerminalViewModel) async -> Bool {
        return await executeAction(.reload, serviceName: serviceName, via: session)
    }
}
