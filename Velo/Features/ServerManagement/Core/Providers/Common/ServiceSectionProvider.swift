//
//  ServiceSectionProvider.swift
//  Velo
//
//  Provider for loading service status and control data.
//

import Foundation

/// Provides service status data for the Service section
struct ServiceSectionProvider: SectionProvider {
    static var providerType: SectionProviderType { .service }

    func loadData(
        for app: ApplicationDefinition,
        state: ApplicationState,
        session: TerminalViewModel
    ) async throws {
        let resolver = ServiceResolver.shared
        let baseService = ServerAdminService.shared

        guard let service = resolver.resolve(for: app.id) else {
            throw SectionProviderError.serviceNotFound(app.id)
        }

        // Get basic status
        let status = await service.getStatus(via: session)

        switch status {
        case .running(let ver):
            await MainActor.run {
                state.isRunning = true
                state.version = ver
            }
        case .stopped(let ver):
            await MainActor.run {
                state.isRunning = false
                state.version = ver
            }
        default:
            await MainActor.run {
                state.isRunning = false
                state.version = "Not Installed"
            }
        }

        // Get binary path
        let binaryCommand: String
        switch app.id.lowercased() {
        case "nginx":
            binaryCommand = "which nginx"
        case "apache", "apache2":
            binaryCommand = "which apache2 || which httpd"
        case "php":
            binaryCommand = "which php"
        case "mysql", "mariadb":
            binaryCommand = "which mysql"
        case "postgresql", "postgres":
            binaryCommand = "which psql"
        case "redis":
            binaryCommand = "which redis-server"
        case "mongodb", "mongo":
            binaryCommand = "which mongod"
        case "python":
            binaryCommand = "which python3 || which python"
        case "node", "nodejs":
            binaryCommand = "which node"
        default:
            binaryCommand = "which \(app.id)"
        }

        let whichResult = await ServerAdminService.shared.execute(binaryCommand, via: session)
        if !whichResult.output.isEmpty && whichResult.exitCode == 0 {
            await MainActor.run {
                state.binaryPath = whichResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // Set config path from service config
        await MainActor.run {
            state.configPath = app.serviceConfig.configPath
        }

        // Load app-specific status
        await loadAppSpecificStatus(for: app, state: state, session: session)
    }

    private func loadAppSpecificStatus(
        for app: ApplicationDefinition,
        state: ApplicationState,
        session: TerminalViewModel
    ) async {
        let baseService = ServerAdminService.shared

        switch app.id.lowercased() {
        case "nginx":
            await loadNginxStatus(state: state, session: session)
        case "mysql", "mariadb":
            await loadMySQLStatus(state: state, session: session)
        case "php":
            await loadPHPFPMStatus(state: state, session: session)
        default:
            break
        }
    }

    private func loadNginxStatus(state: ApplicationState, session: TerminalViewModel) async {
        // Check nginx stub_status if available
        let statusResult = await ServerAdminService.shared.execute(
            "curl -s http://127.0.0.1/nginx_status 2>/dev/null || echo 'not_available'",
            via: session
        )

        if statusResult.output.contains("Active connections") {
            let statusInfo = parseNginxStatus(statusResult.output)
            await MainActor.run {
                state.nginxStatus = statusInfo
            }
        }
    }

    private func parseNginxStatus(_ output: String) -> NginxStatusInfo {
        // Parse nginx stub_status output
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
                // Try to parse "accepts handled requests" line
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

    private func loadMySQLStatus(state: ApplicationState, session: TerminalViewModel) async {
        // StatusSectionProvider handles the detailed metrics.
        // We don't need to load anything extra here.
    }

    private func loadPHPFPMStatus(state: ApplicationState, session: TerminalViewModel) async {
        // Get active PHP version
        let versionResult = await ServerAdminService.shared.execute(
            "php -r 'echo PHP_MAJOR_VERSION.\".\".PHP_MINOR_VERSION;'",
            via: session
        )

        let activeVersion = versionResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if !activeVersion.isEmpty {
            await MainActor.run {
                state.activeVersion = activeVersion
            }
        }

        // Get installed versions
        let versionsResult = await ServerAdminService.shared.execute(
            "ls -1 /etc/php/ 2>/dev/null | sort -V",
            via: session
        )

        if versionsResult.exitCode == 0 {
            let versions = versionsResult.output
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            await MainActor.run {
                state.installedVersions = versions
            }
        }
    }
}
