//
//  ServerServiceAggregator.swift
//  Velo
//
//  Unified interface to all modular server services.
//  Provides backward compatibility for existing code while using the new modular architecture.
//

import Foundation
import Combine

@MainActor
final class ServerServiceAggregator: ObservableObject {
    static let shared = ServerServiceAggregator()

    // MARK: - Services

    let nginx = NginxService.shared
    let apache = ApacheService.shared
    let php = PHPService.shared
    let mysql = MySQLService.shared
    let postgresql = PostgreSQLService.shared
    let systemStats = SystemStatsService.shared
    
    // Runtimes & Tools
    let node = NodeService.shared
    let python = PythonService.shared
    let git = GitService.shared

    private init() {}

    // MARK: - Server Status (All Software)

    /// Fetch complete server status using an optimized batch command
    func fetchServerStatus(via session: TerminalViewModel) async -> ServerStatus {
        let services = ["nginx", "apache2", "httpd", "mysql", "postgresql", "php", "redis"]
        var checkCmd = ""
        for svc in services {
            checkCmd += "echo \"SVC_\(svc.uppercased())\" && systemctl is-active \(svc) 2>/dev/null || echo \"inactive\"\n"
            checkCmd += "echo \"VER_\(svc.uppercased())\" && \(svc) --version 2>/dev/null | head -n 1 || echo \"not installed\"\n"
        }
        
        let result = await SSHBaseService.shared.execute(checkCmd, via: session, timeout: 20)
        return parseBatchStatus(result.output)
    }
    
    private func parseBatchStatus(_ output: String) -> ServerStatus {
        var status = ServerStatus()
        let lines = output.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
        
        var statuses: [String: String] = [:]
        var versions: [String: String] = [:]
        
        var i = 0
        while i < lines.count {
            let line = lines[i]
            if line.hasPrefix("SVC_") {
                let svcKey = line.replacingOccurrences(of: "SVC_", with: "").lowercased()
                if i + 1 < lines.count {
                    statuses[svcKey] = lines[i+1]
                }
            } else if line.hasPrefix("VER_") {
                let svcKey = line.replacingOccurrences(of: "VER_", with: "").lowercased()
                if i + 1 < lines.count {
                    versions[svcKey] = lines[i+1]
                }
            }
            i += 1
        }
        
        func mapToStatus(svc: String) -> SoftwareStatus {
            let v = versions[svc] ?? ""
            let s = statuses[svc] ?? ""
            
            if v.contains("not installed") || v.isEmpty {
                return .notInstalled
            }
            
            // Extract a cleaner version number (e.g., from "nginx version: nginx/1.18.0")
            let versionParts = v.split(separator: " ")
            let cleanV = versionParts.first { $0.contains("/") || $0.contains(".") }?.description ?? "installed"
            
            if s == "active" {
                return .running(version: cleanV)
            } else {
                return .stopped(version: cleanV)
            }
        }
        
        status.nginx = mapToStatus(svc: "nginx")
        status.apache = mapToStatus(svc: "apache2")
        if status.apache == .notInstalled { status.apache = mapToStatus(svc: "httpd") }
        status.mysql = mapToStatus(svc: "mysql")
        status.postgresql = mapToStatus(svc: "postgresql")
        status.php = mapToStatus(svc: "php")
        status.redis = mapToStatus(svc: "redis")
        
        return status
    }

    // MARK: - System Stats

    /// Fetch all system stats
    func fetchSystemStats(via session: TerminalViewModel) async -> ServerStats {
        await systemStats.fetchAllStats(via: session)
    }

    /// Fetch quick stats for live updates
    func fetchQuickStats(via session: TerminalViewModel) async -> (cpu: Double, ram: Double, disk: Double) {
        await systemStats.fetchQuickStats(via: session)
    }

    /// Fetch all websites from configured web servers
    func fetchWebsites(via session: TerminalViewModel) async -> [Website] {
        var allSites: [Website] = []

        if await nginx.isInstalled(via: session) {
            let sites = await nginx.fetchSites(via: session)
            allSites.append(contentsOf: sites)
        }

        if await apache.isInstalled(via: session) {
            let sites = await apache.fetchSites(via: session)
            allSites.append(contentsOf: sites)
        }

        return allSites
    }

    /// Create a website using the appropriate web server
    func createWebsite(domain: String, path: String, port: Int, phpVersion: String?, via session: TerminalViewModel) async -> Bool {
        // Prefer Nginx if installed, otherwise Apache
        if await nginx.isInstalled(via: session) {
            return (try? await nginx.createSite(domain: domain, path: path, port: port, phpVersion: phpVersion, via: session)) ?? false
        } else if await apache.isInstalled(via: session) {
            return (try? await apache.createSite(domain: domain, path: path, port: port, phpVersion: phpVersion, via: session)) ?? false
        }
        return false
    }

    /// Delete a website
    func deleteWebsite(domain: String, webServer: String, deleteFiles: Bool, via session: TerminalViewModel) async -> Bool {
        if webServer.lowercased() == "nginx" {
            return await nginx.deleteSite(domain: domain, deleteFiles: deleteFiles, via: session)
        } else {
            return await apache.deleteSite(domain: domain, deleteFiles: deleteFiles, via: session)
        }
    }

    // MARK: - Databases

    /// Fetch all databases
    func fetchDatabases(via session: TerminalViewModel) async -> [Database] {
        var allDatabases: [Database] = []

        if await mysql.isInstalled(via: session) {
            let dbs = await mysql.fetchDatabases(via: session)
            allDatabases.append(contentsOf: dbs)
        }

        if await postgresql.isInstalled(via: session) {
            let dbs = await postgresql.fetchDatabases(via: session)
            allDatabases.append(contentsOf: dbs)
        }

        return allDatabases
    }

    /// Create a database
    func createDatabase(name: String, type: DatabaseType, username: String?, password: String?, via session: TerminalViewModel) async -> Bool {
        switch type {
        case .mysql:
            return await mysql.createDatabase(name: name, username: username, password: password, via: session)
        case .postgres:
            return await postgresql.createDatabase(name: name, username: username, password: password, via: session)
        default:
            return false
        }
    }

    /// Delete a database
    func deleteDatabase(name: String, type: DatabaseType, via session: TerminalViewModel) async -> Bool {
        switch type {
        case .mysql:
            return await mysql.deleteDatabase(name: name, via: session)
        case .postgres:
            return await postgresql.deleteDatabase(name: name, via: session)
        default:
            return false
        }
    }

    /// Backup a database
    func backupDatabase(name: String, type: DatabaseType, via session: TerminalViewModel) async -> String? {
        switch type {
        case .mysql:
            return await mysql.backupDatabase(name: name, via: session)
        case .postgres:
            return await postgresql.backupDatabase(name: name, via: session)
        default:
            return nil
        }
    }

    // MARK: - Service Control

    /// Restart a service by name
    func restartService(_ serviceName: String, via session: TerminalViewModel) async -> Bool {
        switch serviceName.lowercased() {
        case "nginx":
            return await nginx.restart(via: session)
        case "apache2", "httpd":
            return await apache.restart(via: session)
        case "php-fpm":
            return await php.restart(via: session)
        case "mysql", "mariadb", "mysqld":
            return await mysql.restart(via: session)
        case "postgresql":
            return await postgresql.restart(via: session)
        default:
            let base = SSHBaseService.shared
            let result = await base.execute("sudo systemctl restart \(serviceName)", via: session, timeout: 30)
            return result.exitCode == 0
        }
    }

    /// Stop a service
    func stopService(_ serviceName: String, via session: TerminalViewModel) async -> Bool {
        switch serviceName.lowercased() {
        case "nginx":
            return await nginx.stop(via: session)
        case "apache2", "httpd":
            return await apache.stop(via: session)
        case "php-fpm":
            return await php.stop(via: session)
        case "mysql", "mariadb", "mysqld":
            return await mysql.stop(via: session)
        case "postgresql":
            return await postgresql.stop(via: session)
        default:
            let base = SSHBaseService.shared
            let result = await base.execute("sudo systemctl stop \(serviceName)", via: session, timeout: 30)
            return result.exitCode == 0
        }
    }

    /// Start a service
    func startService(_ serviceName: String, via session: TerminalViewModel) async -> Bool {
        switch serviceName.lowercased() {
        case "nginx":
            return await nginx.start(via: session)
        case "apache2", "httpd":
            return await apache.start(via: session)
        case "php-fpm":
            return await php.start(via: session)
        case "mysql", "mariadb", "mysqld":
            return await mysql.start(via: session)
        case "postgresql":
            return await postgresql.start(via: session)
        default:
            let base = SSHBaseService.shared
            let result = await base.execute("sudo systemctl start \(serviceName)", via: session, timeout: 30)
            return result.exitCode == 0
        }
    }

    // MARK: - PHP Version Management

    /// Get installed PHP versions
    func getInstalledPHPVersions(via session: TerminalViewModel) async -> [String] {
        await php.getInstalledVersions(via: session)
    }

    /// Switch PHP version for a site
    func switchPHPVersion(forDomain domain: String, toVersion version: String, via session: TerminalViewModel) async -> Bool {
        let base = SSHBaseService.shared
        let configPath = "/etc/nginx/sites-available/\(domain)"
        _ = await base.execute("sudo sed -i 's/php[0-9.]*-fpm.sock/php\(version)-fpm.sock/g' '\(configPath)'", via: session, timeout: 15)

        let validation = await nginx.validateConfig(via: session)
        if validation.isValid {
            return await nginx.reload(via: session)
        }
        return false
    }

    // MARK: - Password Management

    /// Change MySQL root password
    func changeMySQLRootPassword(newPassword: String, via session: TerminalViewModel) async -> Bool {
        await mysql.changeRootPassword(newPassword: newPassword, via: session)
    }
}
