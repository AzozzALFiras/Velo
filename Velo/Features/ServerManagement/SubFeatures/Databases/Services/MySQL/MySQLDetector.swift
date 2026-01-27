//
//  MySQLDetector.swift
//  Velo
//
//  Handles MySQL/MariaDB installation detection and availability checks.
//

import Foundation

struct MySQLDetector {
    private let baseService = ServerAdminService.shared

    /// Detect MySQL/MariaDB installation and return details
    func detect(via session: TerminalViewModel) async -> (installed: Bool, serviceName: String?, isMariaDB: Bool) {
        let isInstalled = await self.isInstalled(via: session)
        guard isInstalled else {
            return (false, nil, false)
        }

        // Determine if it's MariaDB
        let versionResult = await baseService.execute("mysql --version 2>&1", via: session, timeout: 5)
        let versionOutput = versionResult.output.lowercased()
        let isMariaDB = versionOutput.contains("mariadb")

        // Get the service name
        let serviceName = await getServiceName(via: session)

        return (true, serviceName, isMariaDB)
    }

    /// Check if MySQL is installed on the server
    func isInstalled(via session: TerminalViewModel) async -> Bool {
        // 1. Check which
        let result = await baseService.execute("which mysql 2>/dev/null", via: session, timeout: 5)
        if !result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty { return true }
        
        // 2. Check service status
        let serviceName = await getServiceName(via: session)
        let serviceCheck = await baseService.execute("systemctl is-active \(serviceName) 2>/dev/null || systemctl is-enabled \(serviceName) 2>/dev/null", via: session, timeout: 5)
        let sOut = serviceCheck.output.lowercased()
        if sOut.contains("active") || sOut.contains("enabled") { return true }
        
        // 3. Check common binary paths
        let pathCheck = await baseService.execute("ls /usr/bin/mysql /usr/local/bin/mysql 2>/dev/null", via: session, timeout: 5)
        if !pathCheck.output.isEmpty && pathCheck.output.contains("mysql") { return true }
        
        // 4. Check package manager
        return await isPackageInstalled(via: session)
    }

    /// Get the systemd service name
    func getServiceName(via session: TerminalViewModel) async -> String {
        // Check for mysql service
        let mysqlResult = await baseService.execute("systemctl is-active mysql 2>/dev/null || systemctl is-enabled mysql 2>/dev/null", via: session, timeout: 10)
        if !mysqlResult.output.contains("unknown") && !mysqlResult.output.isEmpty {
            return "mysql"
        }

        // Check for mariadb service
        let mariaResult = await baseService.execute("systemctl is-active mariadb 2>/dev/null || systemctl is-enabled mariadb 2>/dev/null", via: session, timeout: 10)
        if !mariaResult.output.contains("unknown") && !mariaResult.output.isEmpty {
            return "mariadb"
        }

        // Check for mysqld service (RHEL/CentOS)
        let mysqldResult = await baseService.execute("systemctl is-active mysqld 2>/dev/null || systemctl is-enabled mysqld 2>/dev/null", via: session, timeout: 10)
        if !mysqldResult.output.contains("unknown") && !mysqldResult.output.isEmpty {
            return "mysqld"
        }

        return "mysql"
    }

    /// Check if this is MariaDB rather than MySQL
    func isMariaDB(via session: TerminalViewModel) async -> Bool {
        let result = await baseService.execute("mysql --version 2>&1", via: session, timeout: 10)
        return result.output.lowercased().contains("mariadb")
    }

    /// Get the path to the MySQL binary
    func getBinaryPath(via session: TerminalViewModel) async -> String? {
        let result = await baseService.execute("which mysql 2>/dev/null", via: session, timeout: 10)
        let path = result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if !path.isEmpty { return path }
        
        // Fallback: Check common paths
        let commonPaths = ["/usr/sbin/mysql", "/usr/bin/mysql", "/usr/local/bin/mysql", "/usr/local/sbin/mysql", "/bin/mysql"]
        let checkCmd = "ls " + commonPaths.joined(separator: " ") + " 2>/dev/null | head -n 1"
        let fallbackResult = await baseService.execute(checkCmd, via: session)
        let fallbackPath = fallbackResult.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        return fallbackPath.isEmpty ? nil : fallbackPath
    }

    /// Check if MySQL was installed via package manager
    func isPackageInstalled(via session: TerminalViewModel) async -> Bool {
        // Check Debian/Ubuntu
        let dpkgResult = await baseService.execute("dpkg -l | grep -E '^ii\\s+(mysql-server|mariadb-server)' | wc -l", via: session, timeout: 10)
        if let count = Int(dpkgResult.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)), count > 0 {
            return true
        }

        // Check RHEL/CentOS
        let rpmResult = await baseService.execute("rpm -qa | grep -E '(mysql-server|mariadb-server)' | wc -l", via: session, timeout: 10)
        if let count = Int(rpmResult.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)), count > 0 {
            return true
        }

        return false
    }

    /// Check if MySQL can connect without password (initial setup)
    func canConnectWithoutPassword(via session: TerminalViewModel) async -> Bool {
        let result = await baseService.execute("mysql -e 'SELECT 1' 2>&1 | grep -v 'ERROR' | wc -l", via: session, timeout: 10)
        if let count = Int(result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)), count > 0 {
            return true
        }
        return false
    }
}
