//
//  StatusSectionProvider.swift
//  Velo
//
//  Provider for loading service status and metrics.
//

import Foundation

/// Provides status and metrics data for the Status section
struct StatusSectionProvider: SectionProvider {
    static var providerType: SectionProviderType { .status }

    func loadData(
        for app: ApplicationDefinition,
        state: ApplicationState,
        session: TerminalViewModel
    ) async throws {
        let baseService = ServerAdminService.shared

        switch app.id.lowercased() {
        case "nginx":
            try await loadNginxStatus(state: state, session: session, baseService: baseService)
        case "mysql", "mariadb":
            try await loadMySQLStatus(state: state, session: session, baseService: baseService)
        case "postgresql", "postgres":
            try await loadPostgresStatus(state: state, session: session, baseService: baseService)
        case "redis":
            try await loadRedisStatus(state: state, session: session, baseService: baseService)
        case "php":
            try await loadPHPFPMStatus(state: state, session: session, baseService: baseService)
        default:
            // Generic systemd status
            try await loadGenericStatus(for: app, state: state, session: session, baseService: baseService)
        }
    }

    // MARK: - Nginx Status

    private func loadNginxStatus(state: ApplicationState, session: TerminalViewModel, baseService: ServerAdminService) async throws {
        // Try nginx stub_status
        let result = await baseService.execute(
            "curl -s http://127.0.0.1/nginx_status 2>/dev/null || curl -s http://localhost/nginx_status 2>/dev/null",
            via: session,
            timeout: 5
        )

        if result.output.contains("Active connections") {
            let statusInfo = parseNginxStubStatus(result.output)
            await MainActor.run {
                state.nginxStatus = statusInfo
            }
        } else {
            // Fallback to basic systemd status
            let systemdResult = await baseService.execute(
                "systemctl show nginx --property=ActiveState,SubState,MainPID --no-pager",
                via: session
            )

            // Parse systemd output for basic info
            var statusInfo = NginxStatusInfo(
                activeConnections: 0,
                accepts: 0,
                handled: 0,
                requests: 0,
                reading: 0,
                writing: 0,
                waiting: 0
            )

            await MainActor.run {
                state.nginxStatus = statusInfo
            }
        }
    }

    private func parseNginxStubStatus(_ output: String) -> NginxStatusInfo {
        var activeConnections = 0
        var accepts = 0
        var handled = 0
        var requests = 0
        var reading = 0
        var writing = 0
        var waiting = 0

        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("Active connections:") {
                let parts = line.components(separatedBy: ":")
                if parts.count > 1 {
                    activeConnections = Int(parts[1].trimmingCharacters(in: .whitespaces)) ?? 0
                }
            } else if line.contains("Reading:") {
                let pattern = #"Reading:\s*(\d+)\s*Writing:\s*(\d+)\s*Waiting:\s*(\d+)"#
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
                    reading = Int((line as NSString).substring(with: match.range(at: 1))) ?? 0
                    writing = Int((line as NSString).substring(with: match.range(at: 2))) ?? 0
                    waiting = Int((line as NSString).substring(with: match.range(at: 3))) ?? 0
                }
            } else {
                // Parse "accepts handled requests" line
                let numbers = line.split(separator: " ").compactMap { Int($0) }
                if numbers.count == 3 {
                    accepts = numbers[0]
                    handled = numbers[1]
                    requests = numbers[2]
                }
            }
        }

        return NginxStatusInfo(
            activeConnections: activeConnections,
            accepts: accepts,
            handled: handled,
            requests: requests,
            reading: reading,
            writing: writing,
            waiting: waiting
        )
    }

    // MARK: - MySQL Status

    private func loadMySQLStatus(state: ApplicationState, session: TerminalViewModel, baseService: ServerAdminService) async throws {
        let result = await baseService.execute(
            """
            mysql -e "SHOW GLOBAL STATUS WHERE Variable_name IN ('Uptime', 'Threads_connected', 'Questions', 'Slow_queries', 'Open_tables', 'Queries');" 2>/dev/null
            """,
            via: session
        )

        guard result.exitCode == 0 else { return }

        var uptime = ""
        var threadsConnected = "0"
        var questions = "0"
        var slowQueries = "0"
        var openTables = "0"

        let lines = result.output.components(separatedBy: .newlines)
        for line in lines {
            let parts = line.split(separator: "\t").map { String($0).trimmingCharacters(in: .whitespaces) }
            guard parts.count >= 2 else { continue }

            switch parts[0].lowercased() {
            case "uptime":
                let seconds = Int(parts[1]) ?? 0
                uptime = formatUptime(seconds)
            case "threads_connected":
                threadsConnected = parts[1]
            case "questions":
                questions = parts[1]
            case "slow_queries":
                slowQueries = parts[1]
            case "open_tables":
                openTables = parts[1]
            default:
                break
            }
        }

        // Get version
        let versionResult = await baseService.execute("mysql -V 2>/dev/null", via: session)
        var version = ""
        if let range = versionResult.output.range(of: "\\d+\\.\\d+\\.\\d+", options: .regularExpression) {
            version = String(versionResult.output[range])
        }

        let statusInfo = MySQLStatusInfo(
            version: version,
            uptime: uptime,
            threadsConnected: threadsConnected,
            questions: questions,
            slowQueries: slowQueries,
            openTables: openTables,
            qps: "0"
        )

        await MainActor.run {
            state.mysqlStatus = statusInfo
        }
    }

    // MARK: - PostgreSQL Status

    private func loadPostgresStatus(state: ApplicationState, session: TerminalViewModel, baseService: ServerAdminService) async throws {
        // PostgreSQL doesn't have a built-in status like MySQL
        // We could query pg_stat_activity, etc.
        let result = await baseService.execute(
            "sudo -u postgres psql -c \"SELECT count(*) as connections FROM pg_stat_activity;\" -t 2>/dev/null",
            via: session
        )

        // Basic status tracking
    }

    // MARK: - Redis Status

    private func loadRedisStatus(state: ApplicationState, session: TerminalViewModel, baseService: ServerAdminService) async throws {
        let result = await baseService.execute("redis-cli INFO 2>/dev/null", via: session)

        guard result.exitCode == 0 else { return }

        // Parse Redis INFO output
        // This would populate relevant status fields
    }

    // MARK: - PHP-FPM Status

    private func loadPHPFPMStatus(state: ApplicationState, session: TerminalViewModel, baseService: ServerAdminService) async throws {
        // Try to get FPM status from status page
        let result = await baseService.execute(
            "curl -s http://127.0.0.1/fpm-status 2>/dev/null || curl -s 'http://localhost/fpm-status?full' 2>/dev/null",
            via: session,
            timeout: 5
        )

        if result.output.contains("pool:") {
            // Parse FPM status
            var pool = ""
            var processManager = ""
            var startTime = ""
            var activeProcesses = 0
            var idleProcesses = 0
            var totalProcesses = 0
            var maxActiveProcesses = 0
            var acceptedConnections = 0

            let lines = result.output.components(separatedBy: .newlines)
            for line in lines {
                let parts = line.split(separator: ":").map { String($0).trimmingCharacters(in: .whitespaces) }
                guard parts.count >= 2 else { continue }

                switch parts[0].lowercased() {
                case "pool":
                    pool = parts[1]
                case "process manager":
                    processManager = parts[1]
                case "start time":
                    startTime = parts[1]
                case "active processes":
                    activeProcesses = Int(parts[1]) ?? 0
                case "idle processes":
                    idleProcesses = Int(parts[1]) ?? 0
                case "total processes":
                    totalProcesses = Int(parts[1]) ?? 0
                case "max active processes":
                    maxActiveProcesses = Int(parts[1]) ?? 0
                case "accepted conn":
                    acceptedConnections = Int(parts[1]) ?? 0
                default:
                    break
                }
            }

            let fpmStatus = PHPFPMStatus(
                pool: pool,
                processManager: processManager,
                startTime: startTime,
                activeProcesses: activeProcesses,
                idleProcesses: idleProcesses,
                totalProcesses: totalProcesses,
                maxActiveProcesses: maxActiveProcesses,
                acceptedConnections: acceptedConnections
            )

            await MainActor.run {
                state.fpmStatus = fpmStatus
            }
        }
    }

    // MARK: - Generic Status

    private func loadGenericStatus(for app: ApplicationDefinition, state: ApplicationState, session: TerminalViewModel, baseService: ServerAdminService) async throws {
        let serviceName = app.serviceConfig.serviceName
        guard !serviceName.isEmpty else { return }

        let result = await baseService.execute(
            "systemctl status \(serviceName) --no-pager -l -n 5 2>/dev/null",
            via: session
        )

        // Parse basic systemd status
    }

    // MARK: - Helpers

    private func formatUptime(_ seconds: Int) -> String {
        let days = seconds / 86400
        let hours = (seconds % 86400) / 3600
        let minutes = (seconds % 3600) / 60

        if days > 0 {
            return "\(days)d \(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}
