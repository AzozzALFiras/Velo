//
//  UsersSectionProvider.swift
//  Velo
//
//  Provider for loading database users.
//

import Foundation
import Combine

/// Provides database users data
struct UsersSectionProvider: SectionProvider {
    static var providerType: SectionProviderType { .users }

    func loadData(
        for app: ApplicationDefinition,
        state: ApplicationState,
        session: TerminalViewModel
    ) async throws {
        let baseService = SSHBaseService.shared

        switch app.id.lowercased() {
        case "mysql", "mariadb":
            try await loadMySQLUsers(state: state, session: session, baseService: baseService)
        case "postgresql", "postgres":
            try await loadPostgresUsers(state: state, session: session, baseService: baseService)
        case "mongodb", "mongo":
            try await loadMongoUsers(state: state, session: session, baseService: baseService)
        default:
            break
        }
    }

    private func loadMySQLUsers(state: ApplicationState, session: TerminalViewModel, baseService: SSHBaseService) async throws {
        let result = await baseService.execute(
            "mysql -e \"SELECT User, Host FROM mysql.user;\" 2>/dev/null",
            via: session
        )

        var users: [DatabaseUser] = []

        if result.exitCode == 0 {
            let lines = result.output.components(separatedBy: .newlines)
            for (index, line) in lines.enumerated() {
                // Skip header
                if index == 0 { continue }

                let parts = line.split(separator: "\t").map { String($0).trimmingCharacters(in: .whitespaces) }
                if parts.count >= 2 && !parts[0].isEmpty {
                    let userId = "\(parts[0])@\(parts[1])"
                    users.append(DatabaseUser(
                        id: userId,
                        username: parts[0],
                        host: parts[1],
                        privileges: "" // Would need additional query for detailed privileges
                    ))
                }
            }
        }

        await MainActor.run {
            state.users = users
        }
    }

    private func loadPostgresUsers(state: ApplicationState, session: TerminalViewModel, baseService: SSHBaseService) async throws {
        let result = await baseService.execute(
            "sudo -u postgres psql -c \"SELECT usename, usesuper, usecreatedb FROM pg_user;\" -t 2>/dev/null",
            via: session
        )

        var users: [DatabaseUser] = []

        if result.exitCode == 0 {
            let lines = result.output.components(separatedBy: .newlines)
            for line in lines {
                let parts = line.split(separator: "|").map { String($0).trimmingCharacters(in: .whitespaces) }
                if parts.count >= 3 && !parts[0].isEmpty {
                    var privilegesList: [String] = []
                    if parts[1] == "t" { privilegesList.append("SUPERUSER") }
                    if parts[2] == "t" { privilegesList.append("CREATEDB") }

                    users.append(DatabaseUser(
                        id: "\(parts[0])@local",
                        username: parts[0],
                        host: "local",
                        privileges: privilegesList.joined(separator: ", ")
                    ))
                }
            }
        }

        await MainActor.run {
            state.users = users
        }
    }

    private func loadMongoUsers(state: ApplicationState, session: TerminalViewModel, baseService: SSHBaseService) async throws {
        let result = await baseService.execute(
            "mongosh admin --quiet --eval 'db.getUsers().forEach(u => print(u.user + \"\\t\" + u.roles.map(r => r.role).join(\",\")))' 2>/dev/null",
            via: session
        )

        var users: [DatabaseUser] = []

        if result.exitCode == 0 {
            let lines = result.output.components(separatedBy: .newlines)
            for line in lines {
                let parts = line.split(separator: "\t").map { String($0).trimmingCharacters(in: .whitespaces) }
                if !parts.isEmpty && !parts[0].isEmpty {
                    let privilegesStr = parts.count > 1 ? parts[1] : ""
                    users.append(DatabaseUser(
                        id: "\(parts[0])@local",
                        username: parts[0],
                        host: "local",
                        privileges: privilegesStr
                    ))
                }
            }
        }

        await MainActor.run {
            state.users = users
        }
    }
}
