//
//  DatabasesSectionProvider.swift
//  Velo
//
//  Provider for loading database lists.
//

import Foundation

/// Provides database list data
struct DatabasesSectionProvider: SectionProvider {
    static var providerType: SectionProviderType { .databases }

    func loadData(
        for app: ApplicationDefinition,
        state: ApplicationState,
        session: TerminalViewModel
    ) async throws {
        let baseService = SSHBaseService.shared

        switch app.id.lowercased() {
        case "mysql", "mariadb":
            try await loadMySQLDatabases(state: state, session: session, baseService: baseService)
        case "postgresql", "postgres":
            try await loadPostgresDatabases(state: state, session: session, baseService: baseService)
        case "mongodb", "mongo":
            try await loadMongoDatabases(state: state, session: session, baseService: baseService)
        case "redis":
            try await loadRedisDatabases(state: state, session: session, baseService: baseService)
        default:
            break
        }
    }

    private func loadMySQLDatabases(state: ApplicationState, session: TerminalViewModel, baseService: SSHBaseService) async throws {
        // Get list of databases with sizes
        let result = await baseService.execute(
            """
            mysql -e "SELECT table_schema AS 'Database',
                      ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)',
                      COUNT(*) AS 'Tables'
                      FROM information_schema.tables
                      GROUP BY table_schema;" 2>/dev/null
            """,
            via: session
        )

        var databases: [DatabaseInfo] = []

        if result.exitCode == 0 {
            let lines = result.output.components(separatedBy: .newlines)
            for (index, line) in lines.enumerated() {
                // Skip header line
                if index == 0 { continue }

                let parts = line.split(separator: "\t").map { String($0).trimmingCharacters(in: .whitespaces) }
                if parts.count >= 3 {
                    let name = parts[0]
                    let size = parts[1] + " MB"
                    let tableCount = Int(parts[2]) ?? 0

                    // Skip system databases from display (but still loaded)
                    databases.append(DatabaseInfo(
                        name: name,
                        size: size,
                        tableCount: tableCount
                    ))
                }
            }
        }

        await MainActor.run {
            state.databases = databases
        }
    }

    private func loadPostgresDatabases(state: ApplicationState, session: TerminalViewModel, baseService: SSHBaseService) async throws {
        let result = await baseService.execute(
            """
            sudo -u postgres psql -c "SELECT datname, pg_size_pretty(pg_database_size(datname)) as size
            FROM pg_database WHERE datistemplate = false;" -t 2>/dev/null
            """,
            via: session
        )

        var databases: [DatabaseInfo] = []

        if result.exitCode == 0 {
            let lines = result.output.components(separatedBy: .newlines)
            for line in lines {
                let parts = line.split(separator: "|").map { String($0).trimmingCharacters(in: .whitespaces) }
                if parts.count >= 2 && !parts[0].isEmpty {
                    databases.append(DatabaseInfo(
                        name: parts[0],
                        size: parts[1],
                        tableCount: 0
                    ))
                }
            }
        }

        await MainActor.run {
            state.databases = databases
        }
    }

    private func loadMongoDatabases(state: ApplicationState, session: TerminalViewModel, baseService: SSHBaseService) async throws {
        let result = await baseService.execute(
            "mongosh --quiet --eval 'db.adminCommand(\"listDatabases\").databases.forEach(d => print(d.name + \"\\t\" + d.sizeOnDisk))' 2>/dev/null",
            via: session
        )

        var databases: [DatabaseInfo] = []

        if result.exitCode == 0 {
            let lines = result.output.components(separatedBy: .newlines)
            for line in lines {
                let parts = line.split(separator: "\t").map { String($0).trimmingCharacters(in: .whitespaces) }
                if parts.count >= 2 {
                    let size = formatBytes(Int64(parts[1]) ?? 0)
                    databases.append(DatabaseInfo(
                        name: parts[0],
                        size: size,
                        tableCount: 0
                    ))
                }
            }
        }

        await MainActor.run {
            state.databases = databases
        }
    }

    private func loadRedisDatabases(state: ApplicationState, session: TerminalViewModel, baseService: SSHBaseService) async throws {
        // Redis uses numbered databases (0-15 by default)
        let result = await baseService.execute(
            "redis-cli INFO keyspace 2>/dev/null",
            via: session
        )

        var databases: [DatabaseInfo] = []

        if result.exitCode == 0 {
            let lines = result.output.components(separatedBy: .newlines)
            for line in lines {
                // Parse lines like "db0:keys=123,expires=0,avg_ttl=0"
                if line.hasPrefix("db") {
                    let parts = line.split(separator: ":").map { String($0) }
                    if parts.count >= 2 {
                        let dbName = parts[0]
                        let keyInfo = parts[1]

                        // Extract key count
                        var keyCount = 0
                        if let keysMatch = keyInfo.range(of: "keys=(\\d+)", options: .regularExpression) {
                            let keysStr = String(keyInfo[keysMatch])
                                .replacingOccurrences(of: "keys=", with: "")
                            keyCount = Int(keysStr) ?? 0
                        }

                        databases.append(DatabaseInfo(
                            name: dbName,
                            size: "\(keyCount) keys",
                            tableCount: keyCount
                        ))
                    }
                }
            }
        }

        await MainActor.run {
            state.databases = databases
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
