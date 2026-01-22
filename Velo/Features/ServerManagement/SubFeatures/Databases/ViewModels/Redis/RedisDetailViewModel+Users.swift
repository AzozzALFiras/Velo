//
//  RedisDetailViewModel+Users.swift
//  Velo
//
//  User management for Redis (ACL).
//

import Foundation

extension RedisDetailViewModel {
    
    func loadUsers() async {
        guard let session = session else { return }
        isLoadingUsers = true
        
        let userNames = await service.listUsers(via: session)
        
        var newUsers: [DatabaseUser] = []
        for name in userNames {
            newUsers.append(DatabaseUser(id: name, username: name, host: "all", privileges: "ACL"))
        }
        
        await MainActor.run {
            self.users = newUsers
            self.isLoadingUsers = false
        }
    }
    
    func loadLogs() async {
        guard let session = session else { return }
        isLoadingLogs = true
        
        // Redis logs usually at /var/log/redis/redis-server.log
        let paths = ["/var/log/redis/redis-server.log", "/var/log/redis.log"]
        var logOutput = ""
        
        for path in paths {
            let check = await baseService.execute("sudo tail -n 100 \(path) 2>/dev/null", via: session)
            if !check.output.isEmpty {
                logOutput = check.output
                break
            }
        }
        
        await MainActor.run {
            self.logContent = logOutput
            self.isLoadingLogs = false
        }
    }
}
