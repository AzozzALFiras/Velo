//
//  MySQLService.swift
//  Velo
//
//  Public facade for all MySQL/MariaDB operations.
//  Handles database management, user management, and service control.
//

import Foundation
import Combine

@MainActor
final class MySQLService: ObservableObject, DatabaseServerService {
    static let shared = MySQLService()

    let baseService = SSHBaseService.shared
    let databaseType: DatabaseType = .mysql

    var serviceName: String {
        // MySQL service name varies (mysql vs mariadb)
        return detectedServiceName ?? "mysql"
    }

    private var detectedServiceName: String?
    private var isMariaDB = false

    // Sub-components
    private let detector = MySQLDetector()
    private let versionResolver = MySQLVersionResolver()

    private init() {}

    // MARK: - ServerModuleService

    func isInstalled(via session: TerminalViewModel) async -> Bool {
        let (installed, serviceName, mariaDB) = await detector.detect(via: session)
        self.detectedServiceName = serviceName
        self.isMariaDB = mariaDB
        return installed
    }

    func getVersion(via session: TerminalViewModel) async -> String? {
        await versionResolver.getVersion(via: session)
    }

    func isRunning(via session: TerminalViewModel) async -> Bool {
        let svcName: String
        if let detected = detectedServiceName {
            svcName = detected
        } else {
            svcName = await detector.getServiceName(via: session)
        }
        
        let result = await baseService.execute("systemctl is-active \(svcName) 2>/dev/null", via: session, timeout: 10)
        return result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) == "active"
    }

    func getStatus(via session: TerminalViewModel) async -> SoftwareStatus {
        guard await isInstalled(via: session) else {
            return .notInstalled
        }

        let version = await getVersion(via: session) ?? "installed"
        let running = await isRunning(via: session)

        return running ? .running(version: version) : .stopped(version: version)
    }

    // MARK: - DatabaseServerService

    func fetchDatabases(via session: TerminalViewModel) async -> [Database] {
        let result = await baseService.execute("mysql -e 'SHOW DATABASES' 2>/dev/null || sudo mysql -e 'SHOW DATABASES' 2>/dev/null", via: session, timeout: 15)
        let output = result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        guard !output.isEmpty && !output.contains("error") && !output.contains("denied") else {
            return []
        }

        var databases: [Database] = []
        let lines = output.components(separatedBy: CharacterSet.newlines)

        for line in lines {
            let dbName = line.trimmingCharacters(in: .whitespaces)
            guard isValidDatabaseName(dbName) else { continue }

            // Get database size
            let sizeResult = await baseService.execute("""
                mysql -e "SELECT ROUND(SUM(data_length + index_length), 2) AS size FROM information_schema.tables WHERE table_schema = '\(dbName)' GROUP BY table_schema;" 2>/dev/null | tail -1
            """, via: session, timeout: 10)
            let sizeBytes = Int64(sizeResult.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)) ?? 0

            databases.append(Database(
                name: dbName,
                type: .mysql,
                sizeBytes: sizeBytes,
                status: .active
            ))
        }

        return databases
    }

    func createDatabase(name: String, username: String?, password: String?, via session: TerminalViewModel) async -> Bool {
        let safeName = name.replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "`", with: "")

        // Create database
        let createResult = await baseService.execute(
            "sudo mysql -e \"CREATE DATABASE IF NOT EXISTS \\`\(safeName)\\`;\" && echo 'CREATED'",
            via: session, timeout: 15
        )

        guard createResult.output.contains("CREATED") else { return false }

        // Create user if credentials provided
        if let user = username, !user.isEmpty, let pass = password, !pass.isEmpty {
            let safeUser = user.replacingOccurrences(of: "'", with: "")

            _ = await baseService.execute(
                "sudo mysql -e \"CREATE USER IF NOT EXISTS '\(safeUser)'@'localhost' IDENTIFIED BY '\(pass)';\"",
                via: session, timeout: 15
            )

            _ = await baseService.execute(
                "sudo mysql -e \"GRANT ALL PRIVILEGES ON \\`\(safeName)\\`.* TO '\(safeUser)'@'localhost';\"",
                via: session, timeout: 15
            )

            _ = await baseService.execute("sudo mysql -e \"FLUSH PRIVILEGES;\"", via: session, timeout: 10)
        }

        return true
    }

    func deleteDatabase(name: String, via session: TerminalViewModel) async -> Bool {
        let safeName = name.replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "`", with: "")
        let result = await baseService.execute(
            "sudo mysql -e \"DROP DATABASE IF EXISTS \\`\(safeName)\\`;\" && echo 'DROPPED'",
            via: session, timeout: 15
        )
        return result.output.contains("DROPPED")
    }

    func backupDatabase(name: String, via session: TerminalViewModel) async -> String? {
        let safeName = name.replacingOccurrences(of: "'", with: "")
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backupPath = "/tmp/\(safeName)_\(timestamp).sql"

        let result = await baseService.execute(
            "sudo mysqldump \(safeName) > '\(backupPath)' 2>/dev/null && echo 'SUCCESS'",
            via: session, timeout: 120
        )

        return result.output.contains("SUCCESS") ? backupPath : nil
    }

    // MARK: - User Management

    /// Create a MySQL user
    func createUser(username: String, password: String, host: String = "localhost", via session: TerminalViewModel) async -> Bool {
        let safeUser = username.replacingOccurrences(of: "'", with: "")
        let result = await baseService.execute(
            "sudo mysql -e \"CREATE USER IF NOT EXISTS '\(safeUser)'@'\(host)' IDENTIFIED BY '\(password)';\" && echo 'CREATED'",
            via: session, timeout: 15
        )
        return result.output.contains("CREATED")
    }

    /// Delete a MySQL user
    func deleteUser(username: String, host: String = "localhost", via session: TerminalViewModel) async -> Bool {
        let safeUser = username.replacingOccurrences(of: "'", with: "")
        let result = await baseService.execute(
            "sudo mysql -e \"DROP USER IF EXISTS '\(safeUser)'@'\(host)';\" && echo 'DROPPED'",
            via: session, timeout: 15
        )
        return result.output.contains("DROPPED")
    }

    /// Grant privileges to a user
    func grantPrivileges(database: String, username: String, privileges: [String] = ["ALL PRIVILEGES"], host: String = "localhost", via session: TerminalViewModel) async -> Bool {
        let safeDb = database.replacingOccurrences(of: "`", with: "")
        let safeUser = username.replacingOccurrences(of: "'", with: "")
        let privString = privileges.joined(separator: ", ")

        let result = await baseService.execute(
            "sudo mysql -e \"GRANT \(privString) ON \\`\(safeDb)\\`.* TO '\(safeUser)'@'\(host)'; FLUSH PRIVILEGES;\" && echo 'GRANTED'",
            via: session, timeout: 15
        )
        return result.output.contains("GRANTED")
    }

    /// List all MySQL users
    func listUsers(via session: TerminalViewModel) async -> [(user: String, host: String)] {
        let result = await baseService.execute(
            "sudo mysql -e \"SELECT User, Host FROM mysql.user;\" 2>/dev/null | tail -n +2",
            via: session, timeout: 15
        )

        var users: [(user: String, host: String)] = []
        let lines = result.output.components(separatedBy: CharacterSet.newlines)

        for line in lines {
            let parts = line.split(separator: "\t").map { String($0).trimmingCharacters(in: .whitespaces) }
            if parts.count >= 2 {
                users.append((user: parts[0], host: parts[1]))
            }
        }

        return users
    }

    // MARK: - Password Management

    /// Change MySQL root password
    func changeRootPassword(newPassword: String, via session: TerminalViewModel) async -> Bool {
        let result = await baseService.execute(
            "sudo mysql -e \"ALTER USER 'root'@'localhost' IDENTIFIED BY '\(newPassword)'; FLUSH PRIVILEGES;\" && echo 'CHANGED'",
            via: session, timeout: 15
        )
        return result.output.contains("CHANGED")
    }

    // MARK: - Private Helpers

    private func isValidDatabaseName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.count > 1, trimmed.count < 64 else { return false }

        // Skip system databases
        let systemDbs = ["information_schema", "performance_schema", "mysql", "sys", "Database"]
        if systemDbs.contains(trimmed) { return false }

        // Skip invalid patterns
        let invalidPatterns = ["@", "#", "$", ":", "root", "vmi", "bash", "inactive", "grep", "echo"]
        for pattern in invalidPatterns {
            if trimmed.lowercased().contains(pattern.lowercased()) { return false }
        }

        // Must be valid identifier
        let allowedChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        return trimmed.unicodeScalars.allSatisfy { allowedChars.contains($0) }
    }
}
