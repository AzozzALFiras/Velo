//
//  PostgresDetailViewModel+Users.swift
//  Velo
//
//  User management for PostgreSQL.
//

import Foundation

extension PostgresDetailViewModel {
    
    func loadUsers() async {
        guard let session = session else { return }
        isLoadingUsers = true
        
        // Use service to list users
        let userNames = await service.listUsers(via: session)
        
        var newUsers: [DatabaseUser] = []
        for name in userNames {
            // Postgres users are cluster-wide, host is usually logical or localhost
            // We don't easily get 'host' like MySQL user@host, so we imply localhost or %
            newUsers.append(DatabaseUser(id: name, username: name, host: "localhost", privileges: "Unknown"))
        }
        
        await MainActor.run {
            self.users = newUsers
            self.isLoadingUsers = false
        }
    }
    
    func loadLogs() async {
        guard let session = session else { return }
        isLoadingLogs = true
        
        // PostgreSQL logs are usually in /var/log/postgresql/postgresql-VER-main.log
        // or just /var/log/postgresql/
        
        let logPaths = [
            "/var/log/postgresql/postgresql-*.log",
            "/var/lib/pgsql/data/log/*.log"
        ]
        
        var logOutput = ""
        for path in logPaths {
             // Find latest log file in directory
             let findLatest = "ls -t \(path) 2>/dev/null | head -1"
             let result = await baseService.execute(findLatest, via: session)
             let latest = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
             
             if !latest.isEmpty && latest.hasPrefix("/") {
                 let check = await baseService.execute("sudo tail -n 100 \(latest) 2>/dev/null", via: session)
                 if !check.output.isEmpty {
                     logOutput = check.output
                     break
                 }
             }
        }
        
        await MainActor.run {
            self.logContent = logOutput
            self.isLoadingLogs = false
        }
    }
}
