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
        let sshBase = SSHBaseService.shared
        let cmd = "sudo systemctl \(action.rawValue) \(serviceName)"
        let result = await sshBase.execute(cmd, via: session, timeout: 30)
        
        // Some actions like start/stop don't return output on success, 
        // so we check the exit code.
        return result.exitCode == 0
    }
    
    /// Check if a service is active
    static func isActive(serviceName: String, via session: TerminalViewModel) async -> Bool {
        let sshBase = SSHBaseService.shared
        let cmd = "systemctl is-active \(serviceName) 2>/dev/null"
        let result = await sshBase.execute(cmd, via: session, timeout: 10)
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines) == "active"
    }
    
    /// Get detailed status message
    static func getStatusMessage(serviceName: String, via session: TerminalViewModel) async -> String {
        let sshBase = SSHBaseService.shared
        let cmd = "systemctl status \(serviceName) --no-pager 2>/dev/null"
        let result = await sshBase.execute(cmd, via: session, timeout: 10)
        return result.output
    }
    
}
