//
//  FPMProfileSectionProvider.swift
//  Velo
//
//  Provider for loading PHP-FPM pool configuration.
//

import Foundation

/// Provides PHP-FPM pool configuration data
struct FPMProfileSectionProvider: SectionProvider {
    static var providerType: SectionProviderType { .fpmProfile }

    func loadData(
        for app: ApplicationDefinition,
        state: ApplicationState,
        session: TerminalViewModel
    ) async throws {
        guard app.id.lowercased() == "php" else { return }

        let baseService = ServerAdminService.shared

        // Get active PHP version
        let versionResult = await baseService.execute(
            "php -r 'echo PHP_MAJOR_VERSION.\".\".PHP_MINOR_VERSION;'",
            via: session
        )
        let phpVersion = versionResult.output.trimmingCharacters(in: .whitespacesAndNewlines)

        // Try to read the www.conf pool file
        let poolPaths = [
            "/etc/php/\(phpVersion)/fpm/pool.d/www.conf",
            "/etc/php-fpm.d/www.conf",
            "/etc/php/\(phpVersion)/fpm/php-fpm.conf"
        ]

        var profileContent = ""

        for path in poolPaths {
            let result = await baseService.execute("sudo cat '\(path)' 2>/dev/null", via: session)
            if result.exitCode == 0 && !result.output.isEmpty {
                profileContent = result.output
                break
            }
        }

        // Also try to get FPM status
        let statusResult = await baseService.execute(
            "curl -s http://127.0.0.1/fpm-status 2>/dev/null",
            via: session,
            timeout: 5
        )

        var fpmStatus: PHPFPMStatus?

        if statusResult.output.contains("pool:") {
            fpmStatus = parseFPMStatus(statusResult.output)
        }

        await MainActor.run {
            state.fpmProfileContent = profileContent
            state.fpmStatus = fpmStatus
        }
    }

    private func parseFPMStatus(_ output: String) -> PHPFPMStatus {
        var pool = ""
        var processManager = ""
        var startTime = ""
        var activeProcesses = 0
        var idleProcesses = 0
        var totalProcesses = 0
        var maxActiveProcesses = 0
        var acceptedConnections = 0

        let lines = output.components(separatedBy: .newlines)
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

        return PHPFPMStatus(
            pool: pool,
            processManager: processManager,
            startTime: startTime,
            activeProcesses: activeProcesses,
            idleProcesses: idleProcesses,
            totalProcesses: totalProcesses,
            maxActiveProcesses: maxActiveProcesses,
            acceptedConnections: acceptedConnections
        )
    }
}
