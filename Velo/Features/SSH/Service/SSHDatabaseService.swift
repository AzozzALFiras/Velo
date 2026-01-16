//
//  SSHDatabaseService.swift
//  Velo
//
//  Created by Velo Assistant
//  Specialized service for database operations (MySQL, PostgreSQL, MariaDB)
//

import Foundation
import Combine

@MainActor
class SSHDatabaseService: ObservableObject {
    static let shared = SSHDatabaseService()
    
    private let base = SSHBaseService.shared
    
    private init() {}
    
    /// List all databases of a specific type
    func fetchDatabases(type: Database.DatabaseType, via session: TerminalViewModel) async -> [Database] {
        let command: String
        switch type {
        case .mysql:
            command = "mysql -e 'SHOW DATABASES' 2>/dev/null || mysql -u root -e 'SHOW DATABASES' 2>/dev/null"
        case .postgres:
            command = "sudo -u postgres psql -t -c 'SELECT datname FROM pg_database WHERE datistemplate = false;' 2>/dev/null"
        default:
            return []
        }
        
        let result = await base.execute(command, via: session)
        let lines = result.output.components(separatedBy: .newlines)
        
        var databases: [Database] = []
        for line in lines {
            let name = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard isValidDatabaseName(name, type: type) else { continue }
            
            databases.append(Database(
                name: name,
                type: type,
                sizeBytes: 0,
                status: .active
            ))
        }
        
        return databases
    }
    
    /// Create a new database
    func createDatabase(name: String, type: Database.DatabaseType, via session: TerminalViewModel) async -> Bool {
        let command: String
        let safeName = name.replacingOccurrences(of: "'", with: "")
        
        switch type {
        case .mysql:
            command = "mysql -e \"CREATE DATABASE \\`\(safeName)\\`\" 2>/dev/null || sudo mysql -e \"CREATE DATABASE \\`\(safeName)\\`\" 2>/dev/null"
        case .postgres:
            command = "sudo -u postgres psql -c \"CREATE DATABASE \(safeName)\""
        default:
            return false
        }
        
        let result = await base.execute(command, via: session)
        return result.exitCode == 0
    }
    
    private func isValidDatabaseName(_ name: String, type: Database.DatabaseType) -> Bool {
        guard !name.isEmpty, name.count > 1, name.count < 64 else { return false }
        
        // System databases to ignore
        let systemDBs: Set<String>
        if type == .mysql {
            systemDBs = ["information_schema", "performance_schema", "mysql", "sys", "Database"]
        } else {
            systemDBs = ["postgres", "template0", "template1", "datname"]
        }
        
        if systemDBs.contains(name) { return false }
        
        // Basic character check
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        return name.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}
