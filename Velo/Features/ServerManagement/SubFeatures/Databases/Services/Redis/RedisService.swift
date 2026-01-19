//
//  RedisService.swift
//  Velo
//
//  Public facade for all Redis operations.
//

import Foundation
import Combine

@MainActor
final class RedisService: ObservableObject, DatabaseServerService {
    static let shared = RedisService()

    let baseService = SSHBaseService.shared
    let databaseType: DatabaseType = .redis
    
    // Sub-components
    private let detector = RedisDetector()
    private let versionResolver = RedisVersionResolver()

    private init() {}

    // MARK: - ServerModuleService

    func isInstalled(via session: TerminalViewModel) async -> Bool {
        await detector.isInstalled(via: session)
    }

    func getVersion(via session: TerminalViewModel) async -> String? {
        await versionResolver.getVersion(via: session)
    }

    func isRunning(via session: TerminalViewModel) async -> Bool {
        let serviceName = await detector.getServiceName(via: session)
        return await LinuxServiceHelper.isActive(serviceName: serviceName, via: session)
    }

    func getStatus(via session: TerminalViewModel) async -> SoftwareStatus {
        guard await isInstalled(via: session) else {
            return .notInstalled
        }

        let version = await getVersion(via: session) ?? "installed"
        let running = await isRunning(via: session)

        return running ? .running(version: version) : .stopped(version: version)
    }
    
    // MARK: - ControllableService
    
    var serviceName: String { "redis-server" } // Protocol requirement, but we use dynamic detection below
    
    func restart(via session: TerminalViewModel) async -> Bool {
        let serviceName = await detector.getServiceName(via: session)
        return await LinuxServiceHelper.restartService(serviceName: serviceName, via: session)
    }
    
    func start(via session: TerminalViewModel) async -> Bool {
        let serviceName = await detector.getServiceName(via: session)
        return await LinuxServiceHelper.startService(serviceName: serviceName, via: session)
    }
    
    func stop(via session: TerminalViewModel) async -> Bool {
        let serviceName = await detector.getServiceName(via: session)
        return await LinuxServiceHelper.stopService(serviceName: serviceName, via: session)
    }
    
    func reload(via session: TerminalViewModel) async -> Bool {
        let serviceName = await detector.getServiceName(via: session)
        return await LinuxServiceHelper.reloadService(serviceName: serviceName, via: session)
    }
    
    func enable(via session: TerminalViewModel) async -> Bool {
        let serviceName = await detector.getServiceName(via: session)
        return await LinuxServiceHelper.executeAction(.enable, serviceName: serviceName, via: session)
    }
    
    func disable(via session: TerminalViewModel) async -> Bool {
        let serviceName = await detector.getServiceName(via: session)
        return await LinuxServiceHelper.executeAction(.disable, serviceName: serviceName, via: session)
    }

    // MARK: - DatabaseServerService

    func fetchDatabases(via session: TerminalViewModel) async -> [Database] {
        // Redis uses numbered databases (0-15 etc).
        // We use 'INFO KEYSPACE' to see which ones have keys.
        let result = await baseService.execute("redis-cli INFO KEYSPACE", via: session, timeout: 10)
        let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)

        var databases: [Database] = []
        
        // Always include db0 at least if running, or maybe just parse output
        // Output format:
        // # Keyspace
        // db0:keys=5,expires=0,avg_ttl=0
        // db1:keys=1,expires=0,avg_ttl=0
        
        let lines = output.components(separatedBy: CharacterSet.newlines)
        for line in lines {
            if line.hasPrefix("db") {
                // Parse "db0:keys=..."
                let parts = line.components(separatedBy: ":")
                if let dbPart = parts.first {
                    let name = dbPart // "db0"
                    
                    // Try to parse key count for "size" approximation or just 0
                    // We don't have bytes size easily without scanning.
                    databases.append(Database(
                        name: name,
                        type: .redis,
                        sizeBytes: 0, // Not easily available
                        status: .active
                    ))
                }
            }
        }
        
        // If empty but running, maybe show db0?
        let running = await isRunning(via: session)
        if databases.isEmpty && running {
             databases.append(Database(
                name: "db0",
                type: .redis,
                sizeBytes: 0,
                status: .active
            ))
        }

        return databases.sorted { $0.name < $1.name }
    }

    func createDatabase(name: String, username: String?, password: String?, via session: TerminalViewModel) async -> Bool {
        // Redis does not support creating named databases.
        return false
    }

    func deleteDatabase(name: String, via session: TerminalViewModel) async -> Bool {
        // "Delete" for Redis means flushing the DB.
        // name should be like "db0", "db1"
        guard name.hasPrefix("db"), let index = Int(name.dropFirst(2)) else { return false }
        
        let result = await baseService.execute("redis-cli -n \(index) FLUSHDB", via: session, timeout: 15)
        return result.output.contains("OK")
    }

    func backupDatabase(name: String, via session: TerminalViewModel) async -> String? {
        // SAVE or BGSAVE. But that saves ALL databases to dump.rdb
        // To backup specific DB is harder.
        // For now, let's trigger a SAVE and cp the dump file?
        // Or simpler: Not supported per DB yet.
        return nil
    }

    // MARK: - User Management
    // Redis 6+ has ACLs. For now we can implement simple ACL check/create if version supports it.
    
    func createUser(username: String, password: String, via session: TerminalViewModel) async -> Bool {
        // Only works for Redis 6+ with ACL
        // ACL SETUSER <username> on >password ~* +@all
        let result = await baseService.execute("redis-cli ACL SETUSER \(username) on >\(password) ~* +@all", via: session)
        return result.output.contains("OK")
    }

    func deleteUser(username: String, via session: TerminalViewModel) async -> Bool {
        let result = await baseService.execute("redis-cli ACL DELUSER \(username)", via: session)
        return result.output.contains("1") // Returns number of users deleted
    }

    func listUsers(via session: TerminalViewModel) async -> [String] {
        let result = await baseService.execute("redis-cli ACL LIST", via: session)
        // Output: user default on ...
        // We need to parse usernames
        let lines = result.output.components(separatedBy: "\n")
        var users: [String] = []
        for line in lines {
            let parts = line.components(separatedBy: " ")
            if parts.count > 1 && parts[0] == "user" {
                users.append(parts[1])
            }
        }
        return users
    }
}
