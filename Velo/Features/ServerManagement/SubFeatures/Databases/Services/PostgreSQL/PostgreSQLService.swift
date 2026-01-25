//
//  PostgreSQLService.swift
//  Velo
//
//  Public facade for all PostgreSQL operations.
//  Handles database management, user management, and service control.
//

import Foundation
import Combine

@MainActor
final class PostgreSQLService: ObservableObject, DatabaseServerService {
    static let shared = PostgreSQLService()

    let baseService = SSHBaseService.shared
    let databaseType: DatabaseType = .postgres
    let serviceName = "postgresql"

    // Sub-components
    private let detector = PostgreSQLDetector()
    private let versionResolver = PostgreSQLVersionResolver()

    private init() {}

    // MARK: - ServerModuleService

    func isInstalled(via session: TerminalViewModel) async -> Bool {
        await detector.isInstalled(via: session)
    }

    func getVersion(via session: TerminalViewModel) async -> String? {
        await versionResolver.getVersion(via: session)
    }

    func isRunning(via session: TerminalViewModel) async -> Bool {
        await LinuxServiceHelper.isActive(serviceName: serviceName, via: session)
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
        let result = await baseService.execute(
            "sudo -u postgres psql -t -c \"SELECT datname FROM pg_database WHERE datistemplate = false;\" 2>/dev/null",
            via: session, timeout: 15
        )
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
                sudo -u postgres psql -t -c "SELECT pg_database_size('\(dbName)');" 2>/dev/null
            """, via: session, timeout: 10)
            let sizeBytes = Int64(sizeResult.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)) ?? 0

            databases.append(Database(
                name: dbName,
                type: .postgres,
                sizeBytes: sizeBytes,
                status: .active
            ))
        }

        return databases
    }

    func createDatabase(name: String, username: String?, password: String?, via session: TerminalViewModel) async -> Bool {
        let safeName = name.replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "\"", with: "")

        // Create database
        let createResult = await baseService.execute(
            "sudo -u postgres createdb \(safeName) 2>&1 && echo 'CREATED'",
            via: session, timeout: 15
        )

        guard createResult.output.contains("CREATED") || createResult.output.contains("already exists") else {
            return false
        }

        // Create user if credentials provided
        if let user = username, !user.isEmpty, let pass = password, !pass.isEmpty {
            let safeUser = user.replacingOccurrences(of: "'", with: "")

            // Create user
            _ = await baseService.execute(
                "sudo -u postgres psql -c \"CREATE USER \(safeUser) WITH PASSWORD '\(pass)';\" 2>/dev/null || true",
                via: session, timeout: 15
            )

            // Grant privileges
            _ = await baseService.execute(
                "sudo -u postgres psql -c \"GRANT ALL PRIVILEGES ON DATABASE \(safeName) TO \(safeUser);\"",
                via: session, timeout: 15
            )
        }

        return true
    }

    func deleteDatabase(name: String, via session: TerminalViewModel) async -> Bool {
        let safeName = name.replacingOccurrences(of: "'", with: "")

        // Terminate active connections first
        _ = await baseService.execute("""
            sudo -u postgres psql -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '\(safeName)' AND pid <> pg_backend_pid();" 2>/dev/null
        """, via: session, timeout: 15)

        // Drop database
        let result = await baseService.execute(
            "sudo -u postgres dropdb \(safeName) 2>&1 && echo 'DROPPED'",
            via: session, timeout: 15
        )
        return result.output.contains("DROPPED")
    }

    func backupDatabase(name: String, via session: TerminalViewModel) async -> String? {
        let safeName = name.replacingOccurrences(of: "'", with: "")
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backupPath = "/tmp/\(safeName)_\(timestamp).sql"

        let result = await baseService.execute(
            "sudo -u postgres pg_dump \(safeName) > '\(backupPath)' 2>/dev/null && echo 'SUCCESS'",
            via: session, timeout: 120
        )

        return result.output.contains("SUCCESS") ? backupPath : nil
    }

    // MARK: - User Management

    /// Create a PostgreSQL user
    func createUser(username: String, password: String, via session: TerminalViewModel) async -> Bool {
        let safeUser = username.replacingOccurrences(of: "'", with: "")
        let result = await baseService.execute(
            "sudo -u postgres psql -c \"CREATE USER \(safeUser) WITH PASSWORD '\(password)';\" && echo 'CREATED'",
            via: session, timeout: 15
        )
        return result.output.contains("CREATED") || result.output.contains("already exists")
    }

    /// Delete a PostgreSQL user
    func deleteUser(username: String, via session: TerminalViewModel) async -> Bool {
        let safeUser = username.replacingOccurrences(of: "'", with: "")
        let result = await baseService.execute(
            "sudo -u postgres psql -c \"DROP USER IF EXISTS \(safeUser);\" && echo 'DROPPED'",
            via: session, timeout: 15
        )
        return result.output.contains("DROPPED")
    }

    /// Grant privileges to a user on a database
    func grantPrivileges(database: String, username: String, via session: TerminalViewModel) async -> Bool {
        let safeDb = database.replacingOccurrences(of: "'", with: "")
        let safeUser = username.replacingOccurrences(of: "'", with: "")

        let result = await baseService.execute(
            "sudo -u postgres psql -c \"GRANT ALL PRIVILEGES ON DATABASE \(safeDb) TO \(safeUser);\" && echo 'GRANTED'",
            via: session, timeout: 15
        )
        return result.output.contains("GRANTED")
    }

    /// List all PostgreSQL users
    func listUsers(via session: TerminalViewModel) async -> [String] {
        let result = await baseService.execute(
            "sudo -u postgres psql -t -c \"SELECT usename FROM pg_user;\" 2>/dev/null",
            via: session, timeout: 15
        )

        return result.output.components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Password Management

    /// Change PostgreSQL user password
    func changeUserPassword(username: String, newPassword: String, via session: TerminalViewModel) async -> Bool {
        let safeUser = username.replacingOccurrences(of: "'", with: "")
        let result = await baseService.execute(
            "sudo -u postgres psql -c \"ALTER USER \(safeUser) WITH PASSWORD '\(newPassword)';\" && echo 'CHANGED'",
            via: session, timeout: 15
        )
        return result.output.contains("CHANGED")
    }

    // MARK: - Private Helpers

    private func isValidDatabaseName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.count > 1, trimmed.count < 64 else { return false }

        // Skip system databases
        let systemDbs = ["postgres", "template0", "template1", "datname"]
        if systemDbs.contains(trimmed) { return false }

        // Skip exact invalid names (not substrings)
        let invalidNames = ["root", "test"]
        if invalidNames.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) { return false }

        // Skip invalid characters, but allow alphanumeric, underscore, hyphen
        let allowedChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        return trimmed.unicodeScalars.allSatisfy { allowedChars.contains($0) }
    }
}

// MARK: - MultiVersionCapable Extension

extension PostgreSQLService: MultiVersionCapable {
    var versionDetectionStrategy: VersionDetectionStrategy {
        .directoryBased(path: "/etc/postgresql", pattern: "[0-9]+")
    }

    var versionSwitchStrategy: VersionSwitchStrategy {
        .updateAlternatives(binary: "psql", path: "/usr/bin")
    }

    func listAvailableVersions(via session: TerminalViewModel) async -> [String] {
        do {
            let capabilities = try await ApiService.shared.fetchCapabilities()
            if let pgCap = capabilities.first(where: { $0.slug.lowercased() == "postgresql" }) {
                return pgCap.versions?.map { $0.version } ?? []
            }
        } catch {}
        return []
    }

    func listInstalledVersions(via session: TerminalViewModel) async -> [String] {
        await VersionManagementService.detectVersions(
            using: versionDetectionStrategy,
            via: session
        )
    }

    func getActiveVersion(via session: TerminalViewModel) async -> String? {
        await getVersion(via: session)
    }

    func switchActiveVersion(to version: String, via session: TerminalViewModel) async throws -> Bool {
        // PostgreSQL supports multiple versions via port configuration
        // For now, use update-alternatives for CLI tools
        return try await VersionManagementService.switchVersion(
            to: version,
            using: versionSwitchStrategy,
            via: session
        )
    }
}
