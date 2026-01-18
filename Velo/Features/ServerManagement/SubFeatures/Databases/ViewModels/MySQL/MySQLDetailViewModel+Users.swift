import Foundation

extension MySQLDetailViewModel {
    
    func loadUsers() async {
        guard let session = session else { return }
        isLoadingUsers = true
        
        let result = await baseService.execute(
            "sudo mysql -e \"SELECT User, Host FROM mysql.user;\" 2>/dev/null | tail -n +2",
            via: session
        )
        
        var newUsers: [DatabaseUser] = []
        let lines = result.output.components(separatedBy: CharacterSet.newlines)
        
        for line in lines {
            let parts = line.split(separator: "\t").map { String($0).trimmingCharacters(in: .whitespaces) }
            if parts.count >= 2 {
                newUsers.append(DatabaseUser(id: "\(parts[0])@\(parts[1])", username: parts[0], host: parts[1], privileges: "Unknown"))
            }
        }
        
        await MainActor.run {
            self.users = newUsers
            self.isLoadingUsers = false
        }
    }
    
    func loadLogs() async {
        guard let session = session else { return }
        isLoadingLogs = true
        
        let logPaths = [
            "/var/log/mysql/error.log",
            "/var/log/mysqld.log",
            "/var/log/mariadb/mariadb.log",
            "/www/server/data/*.err" // aaPanel
        ]
        
        var logOutput = ""
        for path in logPaths {
            let check = await baseService.execute("sudo tail -n 100 \(path) 2>/dev/null", via: session)
            if !check.output.isEmpty && !check.output.contains("No such file") {
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
