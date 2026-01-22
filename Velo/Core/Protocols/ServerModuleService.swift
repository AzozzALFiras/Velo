//
//  ServerModuleService.swift
//  Velo
//
//  Base protocol for all server management service modules.
//  Each module (Nginx, Apache, PHP, MySQL, etc.) conforms to this protocol.
//

import Foundation
import Combine

/// Errors thrown during validation or creation of server resources
enum ValidationError: Error, LocalizedError {
    case fileWriteFailed
    case symlinkFailed
    case nginxValidationFailed(message: String)
    case apacheValidationFailed(message: String)
    case unknown(message: String)

    var errorDescription: String? {
        switch self {
        case .fileWriteFailed:
            return "Failed to write configuration file to server."
        case .symlinkFailed:
            return "Failed to enable site (symlink creation failed)."
        case .nginxValidationFailed(let message):
            return "Nginx configuration invalid: \(message)"
        case .apacheValidationFailed(let message):
            return "Apache configuration invalid: \(message)"
        case .unknown(let message):
            return "Unknown error: \(message)"
        }
    }
}

/// Base protocol that all server module services must conform to
protocol ServerModuleService {
    /// The SSH base service used for command execution
    var baseService: SSHBaseService { get }

    /// Check if this software is installed on the server
    func isInstalled(via session: TerminalViewModel) async -> Bool

    /// Get the installed version of the software
    func getVersion(via session: TerminalViewModel) async -> String?

    /// Check if the service is currently running
    func isRunning(via session: TerminalViewModel) async -> Bool

    /// Get comprehensive status (installed + running + version)
    func getStatus(via session: TerminalViewModel) async -> SoftwareStatus
}

/// Protocol for services that can be controlled (start/stop/restart)
protocol ControllableService: ServerModuleService {
    /// The systemd service name
    var serviceName: String { get }

    /// Start the service
    func start(via session: TerminalViewModel) async -> Bool

    /// Stop the service
    func stop(via session: TerminalViewModel) async -> Bool

    /// Restart the service
    func restart(via session: TerminalViewModel) async -> Bool

    /// Reload configuration without full restart
    func reload(via session: TerminalViewModel) async -> Bool

    /// Enable service to start on boot
    func enable(via session: TerminalViewModel) async -> Bool

    /// Disable service from starting on boot
    func disable(via session: TerminalViewModel) async -> Bool
}

/// Protocol for web servers (Nginx, Apache, LiteSpeed)
protocol WebServerService: ControllableService {
    /// Fetch all configured sites
    func fetchSites(via session: TerminalViewModel) async -> [Website]

    /// Create a new site configuration
    /// Create a new site configuration
    func createSite(domain: String, path: String, port: Int, phpVersion: String?, runtimeVersion: String?, framework: String, via session: TerminalViewModel) async throws -> Bool

    /// Delete a site configuration
    func deleteSite(domain: String, deleteFiles: Bool, via session: TerminalViewModel) async -> Bool

    /// Enable an existing site
    func enableSite(domain: String, via session: TerminalViewModel) async -> Bool

    /// Disable a site without deleting it
    func disableSite(domain: String, via session: TerminalViewModel) async -> Bool

    /// Validate the server configuration
    func validateConfig(via session: TerminalViewModel) async -> (isValid: Bool, message: String)

    /// Get the dynamic default document root for new websites
    func getDefaultDocumentRoot(via session: TerminalViewModel) async -> String
}

/// Protocol for database servers (MySQL, PostgreSQL, Redis)
protocol DatabaseServerService: ControllableService {
    /// The database type
    var databaseType: DatabaseType { get }

    /// Fetch all databases
    func fetchDatabases(via session: TerminalViewModel) async -> [Database]

    /// Create a new database
    func createDatabase(name: String, username: String?, password: String?, via session: TerminalViewModel) async -> Bool

    /// Delete a database
    func deleteDatabase(name: String, via session: TerminalViewModel) async -> Bool

    /// Backup a database
    func backupDatabase(name: String, via session: TerminalViewModel) async -> String?
}

/// Protocol for runtime services (PHP-FPM)
protocol RuntimeService: ControllableService {
    /// Get available versions installed on the system
    func getInstalledVersions(via session: TerminalViewModel) async -> [String]

    /// Get the currently active version
    func getActiveVersion(via session: TerminalViewModel) async -> String?
}

// MARK: - Default Implementations

extension ControllableService {
    func start(via session: TerminalViewModel) async -> Bool {
        let result = await baseService.execute("sudo systemctl start \(serviceName)", via: session, timeout: 30)
        return await isRunning(via: session)
    }

    func stop(via session: TerminalViewModel) async -> Bool {
        let result = await baseService.execute("sudo systemctl stop \(serviceName)", via: session, timeout: 30)
        let running = await isRunning(via: session)
        return !running
    }

    func restart(via session: TerminalViewModel) async -> Bool {
        let result = await baseService.execute("sudo systemctl restart \(serviceName)", via: session, timeout: 30)
        return await isRunning(via: session)
    }

    func reload(via session: TerminalViewModel) async -> Bool {
        let result = await baseService.execute("sudo systemctl reload \(serviceName)", via: session, timeout: 30)
        return result.exitCode == 0
    }

    func enable(via session: TerminalViewModel) async -> Bool {
        let result = await baseService.execute("sudo systemctl enable \(serviceName)", via: session, timeout: 30)
        return result.exitCode == 0
    }

    func disable(via session: TerminalViewModel) async -> Bool {
        let result = await baseService.execute("sudo systemctl disable \(serviceName)", via: session, timeout: 30)
        return result.exitCode == 0
    }
}
