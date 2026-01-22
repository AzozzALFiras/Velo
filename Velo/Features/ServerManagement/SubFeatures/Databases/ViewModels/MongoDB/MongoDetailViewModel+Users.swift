//
//  MongoDetailViewModel+Users.swift
//  Velo
//
//  User management for MongoDB.
//

import Foundation

extension MongoDetailViewModel {
    
    func loadUsers() async {
        guard let session = session else { return }
        isLoadingUsers = true
        
        let userNames = await service.listUsers(via: session)
        
        var newUsers: [DatabaseUser] = []
        for name in userNames {
            newUsers.append(DatabaseUser(id: name, username: name, host: "admin", privileges: "readWrite"))
        }
        
        await MainActor.run {
            self.users = newUsers
            self.isLoadingUsers = false
        }
    }
    
    func loadLogs() async {
        guard let session = session else { return }
        isLoadingLogs = true
        
        // Mongo logs /var/log/mongodb/mongod.log
        let paths = ["/var/log/mongodb/mongod.log", "/var/log/mongodb.log"]
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
