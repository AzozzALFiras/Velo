//
//  DatabasesViewModel.swift
//  Velo
//
//  ViewModel for database management including creation, listing, and operations.
//  Supports MySQL/MariaDB and PostgreSQL.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class DatabasesViewModel: ObservableObject {

    // MARK: - Dependencies
    weak var session: TerminalViewModel?
    private let mysqlService = MySQLService.shared
    private let postgresService = PostgreSQLService.shared
    private let redisService = RedisService.shared
    private let mongoService = MongoService.shared

    // MARK: - Published State

    @Published var databases: [Database] = []
    @Published var isLoading = false
    @Published var isCreating = false
    @Published var errorMessage: String?

    // Server capabilities
    @Published var hasMySQL = false
    @Published var hasPostgreSQL = false
    @Published var hasRedis = false
    @Published var hasMongoDB = false
    @Published var isMariaDB = false

    // MARK: - Init

    init(session: TerminalViewModel? = nil) {
        self.session = session
    }

    // MARK: - Data Loading

    /// Load all databases from installed database servers
    func loadDatabases() async {
        guard let session = session else { return }

        isLoading = true
        errorMessage = nil

        // Check what's installed
        async let mysqlCheck = mysqlService.isInstalled(via: session)
        async let pgCheck = postgresService.isInstalled(via: session)
        async let redisCheck = redisService.isInstalled(via: session)
        async let mongoCheck = mongoService.isInstalled(via: session)

        hasMySQL = await mysqlCheck
        hasPostgreSQL = await pgCheck
        hasRedis = await redisCheck
        hasMongoDB = await mongoCheck

        // Fetch databases from installed servers
        var allDatabases: [Database] = []

        if hasMySQL {
            let mysqlDbs = await mysqlService.fetchDatabases(via: session)
            allDatabases.append(contentsOf: mysqlDbs)
        }

        if hasPostgreSQL {
            let pgDbs = await postgresService.fetchDatabases(via: session)
            allDatabases.append(contentsOf: pgDbs)
        }
        
        if hasRedis {
            let redisDbs = await redisService.fetchDatabases(via: session)
            allDatabases.append(contentsOf: redisDbs)
        }
        
        if hasMongoDB {
            let mongoDbs = await mongoService.fetchDatabases(via: session)
            allDatabases.append(contentsOf: mongoDbs)
        }

        databases = allDatabases
        isLoading = false
    }

    /// Refresh databases list
    func refresh() async {
        await loadDatabases()
    }

    // MARK: - Database CRUD Operations

    /// Create a new database
    func createDatabase(name: String, type: DatabaseType, username: String? = nil, password: String? = nil) async -> Bool {
        guard let session = session else { return false }

        isCreating = true
        errorMessage = nil

        var success = false

        switch type {
        case .mysql:
            if hasMySQL {
                success = await mysqlService.createDatabase(name: name, username: username, password: password, via: session)
            } else {
                errorMessage = "MySQL is not installed"
            }
        case .postgres:
            if hasPostgreSQL {
                success = await postgresService.createDatabase(name: name, username: username, password: password, via: session)
            } else {
                errorMessage = "PostgreSQL is not installed"
            }
        case .redis, .mongo:
            errorMessage = "\(type.rawValue) databases are created on first use"
            success = true
        }

        if success {
            // Add to local state
            let newDb = Database(
                name: name,
                type: type,
                username: username,
                password: password,
                sizeBytes: 0,
                status: .active
            )
            databases.insert(newDb, at: 0)
        } else if errorMessage == nil {
            errorMessage = "Failed to create database"
        }

        isCreating = false
        return success
    }

    /// Delete a database
    func deleteDatabase(_ database: Database) async -> Bool {
        guard let session = session else { return false }

        var success = false

        switch database.type {
        case .mysql:
            success = await mysqlService.deleteDatabase(name: database.name, via: session)
        case .postgres:
            success = await postgresService.deleteDatabase(name: database.name, via: session)
        case .redis, .mongo:
            errorMessage = "Deletion not supported for \(database.type.rawValue)"
            return false
        }

        if success {
            databases.removeAll { $0.id == database.id }
        }

        return success
    }

    /// Locally update a database's state
    func updateDatabase(_ database: Database) {
        if let index = databases.firstIndex(where: { $0.id == database.id }) {
            databases[index] = database
        }
    }

    /// Backup a database
    func backupDatabase(_ database: Database) async -> String? {
        guard let session = session else { return nil }

        switch database.type {
        case .mysql:
            return await mysqlService.backupDatabase(name: database.name, via: session)
        case .postgres:
            return await postgresService.backupDatabase(name: database.name, via: session)
        case .redis, .mongo:
            errorMessage = "Backup not supported for \(database.type.rawValue)"
            return nil
        }
    }

    // MARK: - User Management

    /// Create a database user (MySQL)
    func createMySQLUser(username: String, password: String, host: String = "localhost") async -> Bool {
        guard let session = session, hasMySQL else { return false }
        return await mysqlService.createUser(username: username, password: password, host: host, via: session)
    }

    /// Create a database user (PostgreSQL)
    func createPostgreSQLUser(username: String, password: String) async -> Bool {
        guard let session = session, hasPostgreSQL else { return false }
        return await postgresService.createUser(username: username, password: password, via: session)
    }

    /// Grant privileges to a user
    func grantPrivileges(database: Database, username: String) async -> Bool {
        guard let session = session else { return false }

        switch database.type {
        case .mysql:
            return await mysqlService.grantPrivileges(database: database.name, username: username, via: session)
        case .postgres:
            return await postgresService.grantPrivileges(database: database.name, username: username, via: session)
        default:
            return false
        }
    }

    // MARK: - Password Management

    /// Change MySQL root password
    func changeMySQLRootPassword(newPassword: String) async -> Bool {
        guard let session = session, hasMySQL else { return false }
        return await mysqlService.changeRootPassword(newPassword: newPassword, via: session)
    }

    /// Change PostgreSQL user password
    func changePostgreSQLPassword(username: String, newPassword: String) async -> Bool {
        guard let session = session, hasPostgreSQL else { return false }
        return await postgresService.changeUserPassword(username: username, newPassword: newPassword, via: session)
    }

    // MARK: - Computed Properties

    var mysqlDatabases: [Database] {
        databases.filter { $0.type == .mysql }
    }

    var postgresDatabases: [Database] {
        databases.filter { $0.type == .postgres }
    }

    var totalDatabaseCount: Int {
        databases.count
    }
}
