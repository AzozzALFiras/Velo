//
//  LogsSectionProvider.swift
//  Velo
//
//  Provider for loading application log files.
//

import Foundation

/// Provides log file data for the Logs section
struct LogsSectionProvider: SectionProvider {
    static var providerType: SectionProviderType { .logs }

    func loadData(
        for app: ApplicationDefinition,
        state: ApplicationState,
        session: TerminalViewModel
    ) async throws {
        let baseService = SSHBaseService.shared
        let logPaths = app.serviceConfig.logPaths

        // Populate available log files
        await MainActor.run {
            state.availableLogFiles = logPaths
            if state.selectedLogFile.isEmpty && !logPaths.isEmpty {
                state.selectedLogFile = logPaths[0]
            }
        }

        // If no log paths configured, try common paths
        let pathsToTry: [String]
        if logPaths.isEmpty {
            pathsToTry = defaultLogPaths(for: app.id)
        } else {
            pathsToTry = [state.selectedLogFile.isEmpty ? logPaths[0] : state.selectedLogFile]
        }

        var logContent = ""
        var foundLogs = false

        for logPath in pathsToTry {
            let result = await baseService.execute(
                "sudo tail -n 200 '\(logPath)' 2>/dev/null",
                via: session
            )

            if result.exitCode == 0 && !result.output.isEmpty {
                logContent = result.output
                foundLogs = true
                await MainActor.run {
                    state.selectedLogFile = logPath
                }
                break
            }
        }

        if !foundLogs {
            // Try using journalctl as fallback for systemd services
            let serviceName = app.serviceConfig.serviceName
            if !serviceName.isEmpty {
                let journalResult = await baseService.execute(
                    "sudo journalctl -u \(serviceName) -n 100 --no-pager 2>/dev/null",
                    via: session
                )
                if journalResult.exitCode == 0 && !journalResult.output.isEmpty {
                    logContent = journalResult.output
                    foundLogs = true
                }
            }
        }

        await MainActor.run {
            if foundLogs {
                state.logContent = logContent
            } else {
                state.logContent = "No logs found.\nChecked paths: \(pathsToTry.joined(separator: ", "))"
            }
        }
    }

    private func defaultLogPaths(for appId: String) -> [String] {
        switch appId.lowercased() {
        case "nginx":
            return [
                "/var/log/nginx/error.log",
                "/var/log/nginx/access.log",
                "/www/server/nginx/logs/error.log",
                "/www/server/nginx/logs/access.log"
            ]
        case "apache", "apache2":
            return [
                "/var/log/apache2/error.log",
                "/var/log/apache2/access.log",
                "/var/log/httpd/error_log",
                "/var/log/httpd/access_log"
            ]
        case "php":
            return [
                "/var/log/php-fpm.log",
                "/var/log/php8.2-fpm.log",
                "/var/log/php8.1-fpm.log",
                "/var/log/php8.0-fpm.log"
            ]
        case "mysql", "mariadb":
            return [
                "/var/log/mysql/error.log",
                "/var/log/mysql.log",
                "/var/log/mariadb/mariadb.log"
            ]
        case "postgresql", "postgres":
            return [
                "/var/log/postgresql/postgresql-main.log",
                "/var/log/postgresql/postgresql-15-main.log"
            ]
        case "redis":
            return [
                "/var/log/redis/redis-server.log",
                "/var/log/redis.log"
            ]
        case "mongodb", "mongo":
            return [
                "/var/log/mongodb/mongod.log",
                "/var/log/mongo.log"
            ]
        default:
            return []
        }
    }
}
