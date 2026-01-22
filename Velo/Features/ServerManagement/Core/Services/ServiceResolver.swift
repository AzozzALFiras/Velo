//
//  ServiceResolver.swift
//  Velo
//
//  Resolves application IDs to their corresponding service instances.
//

import Foundation

/// Resolves application IDs to their underlying service implementations
@MainActor
final class ServiceResolver {
    static let shared = ServiceResolver()

    private init() {}

    /// Resolve a ServerModuleService for the given application ID
    func resolve(for appId: String) -> (any ServerModuleService)? {
        switch appId.lowercased() {
        case "nginx":
            return NginxService.shared
        case "apache", "apache2":
            return ApacheService.shared
        case "php":
            return PHPService.shared
        case "mysql", "mariadb":
            return MySQLService.shared
        case "postgresql", "postgres":
            return PostgreSQLService.shared
        case "redis":
            return RedisService.shared
        case "mongodb", "mongo":
            return MongoService.shared
        case "python":
            return PythonService.shared
        case "node", "nodejs":
            return NodeService.shared
        default:
            return nil
        }
    }

    /// Resolve as a ControllableService (for start/stop/restart operations)
    func resolveControllable(for appId: String) -> (any ControllableService)? {
        resolve(for: appId) as? (any ControllableService)
    }

    /// Resolve as a WebServerService
    func resolveWebServer(for appId: String) -> (any WebServerService)? {
        resolve(for: appId) as? (any WebServerService)
    }

    /// Resolve as a DatabaseServerService
    func resolveDatabase(for appId: String) -> (any DatabaseServerService)? {
        resolve(for: appId) as? (any DatabaseServerService)
    }

    /// Resolve as a RuntimeService
    func resolveRuntime(for appId: String) -> (any RuntimeService)? {
        resolve(for: appId) as? (any RuntimeService)
    }

    /// Get the service name for systemctl commands
    func serviceName(for appId: String) -> String? {
        resolveControllable(for: appId)?.serviceName
    }

    // MARK: - Service-Specific Accessors

    var nginx: NginxService { NginxService.shared }
    var apache: ApacheService { ApacheService.shared }
    var php: PHPService { PHPService.shared }
    var mysql: MySQLService { MySQLService.shared }
    var postgresql: PostgreSQLService { PostgreSQLService.shared }
    var redis: RedisService { RedisService.shared }
    var mongo: MongoService { MongoService.shared }
    var python: PythonService { PythonService.shared }
    var node: NodeService { NodeService.shared }
}

// MARK: - Service Action Helpers

extension ServiceResolver {
    /// Start the service for an application
    func startService(for appId: String, via session: TerminalViewModel) async -> Bool {
        guard let service = resolveControllable(for: appId) else { return false }
        return await service.start(via: session)
    }

    /// Stop the service for an application
    func stopService(for appId: String, via session: TerminalViewModel) async -> Bool {
        guard let service = resolveControllable(for: appId) else { return false }
        return await service.stop(via: session)
    }

    /// Restart the service for an application
    func restartService(for appId: String, via session: TerminalViewModel) async -> Bool {
        guard let service = resolveControllable(for: appId) else { return false }
        return await service.restart(via: session)
    }

    /// Reload the service configuration
    func reloadService(for appId: String, via session: TerminalViewModel) async -> Bool {
        guard let service = resolveControllable(for: appId) else { return false }
        return await service.reload(via: session)
    }

    /// Check if a service is running
    func isRunning(for appId: String, via session: TerminalViewModel) async -> Bool {
        guard let service = resolve(for: appId) else { return false }
        return await service.isRunning(via: session)
    }

    /// Get the version of an installed application
    func getVersion(for appId: String, via session: TerminalViewModel) async -> String? {
        guard let service = resolve(for: appId) else { return nil }
        return await service.getVersion(via: session)
    }
}
