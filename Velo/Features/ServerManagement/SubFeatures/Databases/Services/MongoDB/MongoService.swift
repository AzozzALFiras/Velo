//
//  MongoService.swift
//  Velo
//
//  Public facade for all MongoDB operations.
//

import Foundation
import Combine

@MainActor
final class MongoService: ObservableObject, DatabaseServerService {
    static let shared = MongoService()

    let baseService = SSHBaseService.shared
    let databaseType: DatabaseType = .mongo
    
    // Sub-components
    private let detector = MongoDetector()
    private let versionResolver = MongoVersionResolver()

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
    
    var serviceName: String { "mongod" } // Protocol requirement, but we use dynamic detection below
    
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
        // mongosh eval 'db.adminCommand("listDatabases")'
        let result = await baseService.execute("mongosh --quiet --eval 'JSON.stringify(db.adminCommand(\"listDatabases\"))'", via: session, timeout: 15)
        
        // Output should be JSON
        let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !output.isEmpty, output.starts(with: "{") else { return [] }
        
        var databases: [Database] = []
        
        // Simple JSON parsing using string manipulation/regex or data if complex
        // Expected format: { "databases" : [ { "name" : "admin", "sizeOnDisk" : 102400, "empty" : false }, ... ], ... }
        
        if let data = output.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let dbs = json["databases"] as? [[String: Any]] {
            
            for db in dbs {
                if let name = db["name"] as? String {
                    let size = (db["sizeOnDisk"] as? Int64) ?? 0
                    
                    databases.append(Database(
                        name: name,
                        type: .mongo,
                        sizeBytes: size,
                        status: .active
                    ))
                }
            }
        }

        return databases.sorted { $0.name < $1.name }
    }

    func createDatabase(name: String, username: String?, password: String?, via session: TerminalViewModel) async -> Bool {
        // MongoDB creates DB on insert. We can switch and create a dummy collection.
        // db.createCollection('init')
        let safeName = name.replacingOccurrences(of: "'", with: "")
        let cmd = "mongosh \(safeName) --eval 'db.createCollection(\"init\")'"
        
        let result = await baseService.execute(cmd, via: session)
        if !result.output.contains("1") && !result.output.contains("ok") {
            return false
        }
        
        // Add User if needed
        if let user = username, !user.isEmpty, let pass = password, !pass.isEmpty {
            return await createUser(database: safeName, username: user, password: pass, via: session)
        }
        
        return true
    }

    func deleteDatabase(name: String, via session: TerminalViewModel) async -> Bool {
        let safeName = name.replacingOccurrences(of: "'", with: "")
        let cmd = "mongosh \(safeName) --eval 'db.dropDatabase()'"
        let result = await baseService.execute(cmd, via: session)
        return result.output.contains("ok")
    }

    func backupDatabase(name: String, via session: TerminalViewModel) async -> String? {
        let safeName = name.replacingOccurrences(of: "'", with: "")
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backupPath = "/tmp/\(safeName)_\(timestamp).gz" // mongodump can gzip
        
        // mongodump --db <db> --archive=<path> --gzip
        let result = await baseService.execute(
            "mongodump --db \(safeName) --archive='\(backupPath)' --gzip && echo 'SUCCESS'",
            via: session, timeout: 300
        )
        
        return result.output.contains("SUCCESS") ? backupPath : nil
    }

    // MARK: - User Management
    
    func createUser(database: String = "admin", username: String, password: String, via session: TerminalViewModel) async -> Bool {
        let safeDb = database.replacingOccurrences(of: "'", with: "")
        let safeUser = username.replacingOccurrences(of: "'", with: "")
        // db.createUser({ user: "name", pwd: "pwd", roles: [{ role: "readWrite", db: "db" }] })
        let cmd = """
        mongosh \(safeDb) --eval 'db.createUser({ user: "\(safeUser)", pwd: "\(password)", roles: [{ role: "readWrite", db: "\(safeDb)" }] })'
        """
        let result = await baseService.execute(cmd, via: session)
        return result.output.contains("ok") || result.output.contains("already exists")
    }

    func deleteUser(database: String = "admin", username: String, via session: TerminalViewModel) async -> Bool {
        let safeDb = database.replacingOccurrences(of: "'", with: "")
        let safeUser = username.replacingOccurrences(of: "'", with: "")
        let cmd = "mongosh \(safeDb) --eval 'db.dropUser(\"\(safeUser)\")'"
        let result = await baseService.execute(cmd, via: session)
        return result.output.contains("true")
    }

    func listUsers(database: String = "admin", via session: TerminalViewModel) async -> [String] {
        // db.getUsers()
        let cmd = "mongosh \(database) --quiet --eval 'JSON.stringify(db.getUsers())'"
        let result = await baseService.execute(cmd, via: session)
        
        var users: [String] = []
        if let data = result.output.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            for u in json {
                if let name = u["user"] as? String {
                    users.append(name)
                }
            }
        }
        return users
    }
}
