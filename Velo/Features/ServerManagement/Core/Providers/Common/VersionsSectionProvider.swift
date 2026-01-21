//
//  VersionsSectionProvider.swift
//  Velo
//
//  Provider for loading installed and available versions.
//

import Foundation

/// Provides version information for the Versions section
struct VersionsSectionProvider: SectionProvider {
    static var providerType: SectionProviderType { .versions }

    func loadData(
        for app: ApplicationDefinition,
        state: ApplicationState,
        session: TerminalViewModel
    ) async throws {
        let baseService = SSHBaseService.shared

        // Load installed versions based on app type
        switch app.id.lowercased() {
        case "php":
            await loadPHPVersions(state: state, session: session, baseService: baseService)
        case "python":
            await loadPythonVersions(state: state, session: session, baseService: baseService)
        case "node", "nodejs":
            await loadNodeVersions(state: state, session: session, baseService: baseService)
        case "mysql", "mariadb":
            await loadMySQLVersion(state: state, session: session, baseService: baseService)
        case "postgresql", "postgres":
            await loadPostgresVersion(state: state, session: session, baseService: baseService)
        default:
            // For single-version apps, just get the current version
            await loadSingleVersion(for: app, state: state, session: session, baseService: baseService)
        }

        // Load available versions from API if app has capability
        if app.capabilities.contains(.multiVersion) {
            await loadAvailableVersionsFromAPI(for: app, state: state)
        }
    }

    private func loadPHPVersions(state: ApplicationState, session: TerminalViewModel, baseService: SSHBaseService) async {
        // Get active version
        let activeResult = await baseService.execute(
            "php -r 'echo PHP_MAJOR_VERSION.\".\".PHP_MINOR_VERSION;'",
            via: session
        )
        let activeVersion = activeResult.output.trimmingCharacters(in: .whitespacesAndNewlines)

        // Get installed versions
        let versionsResult = await baseService.execute(
            "ls -1 /etc/php/ 2>/dev/null | sort -V",
            via: session
        )

        var installedVersions: [String] = []
        if versionsResult.exitCode == 0 {
            installedVersions = versionsResult.output
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }

        await MainActor.run {
            state.activeVersion = activeVersion
            state.installedVersions = installedVersions
        }
    }

    private func loadPythonVersions(state: ApplicationState, session: TerminalViewModel, baseService: SSHBaseService) async {
        // Get python3 version
        let result = await baseService.execute("python3 --version 2>/dev/null || python --version 2>/dev/null", via: session)
        let version = result.output
            .replacingOccurrences(of: "Python ", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        await MainActor.run {
            state.activeVersion = version
            state.installedVersions = [version]
        }
    }

    private func loadNodeVersions(state: ApplicationState, session: TerminalViewModel, baseService: SSHBaseService) async {
        // Get node version
        let nodeResult = await baseService.execute("node --version 2>/dev/null", via: session)
        let nodeVersion = nodeResult.output
            .replacingOccurrences(of: "v", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if nvm is available for multiple versions
        let nvmResult = await baseService.execute("source ~/.nvm/nvm.sh 2>/dev/null && nvm list 2>/dev/null", via: session)
        var installedVersions = [nodeVersion]

        if nvmResult.exitCode == 0 && !nvmResult.output.isEmpty {
            // Parse nvm list output
            let lines = nvmResult.output.components(separatedBy: .newlines)
            installedVersions = lines.compactMap { line -> String? in
                let cleaned = line
                    .replacingOccurrences(of: "->", with: "")
                    .replacingOccurrences(of: "*", with: "")
                    .replacingOccurrences(of: "v", with: "")
                    .trimmingCharacters(in: .whitespaces)
                return cleaned.isEmpty ? nil : cleaned.components(separatedBy: .whitespaces).first
            }
        }

        await MainActor.run {
            state.activeVersion = nodeVersion
            state.installedVersions = installedVersions
        }
    }

    private func loadMySQLVersion(state: ApplicationState, session: TerminalViewModel, baseService: SSHBaseService) async {
        let result = await baseService.execute("mysql --version 2>/dev/null", via: session)
        var version = ""

        // Parse version from output like "mysql  Ver 8.0.35-0ubuntu0.22.04.1 for Linux..."
        if let range = result.output.range(of: "Ver\\s+([\\d.]+)", options: .regularExpression) {
            let match = String(result.output[range])
            version = match.replacingOccurrences(of: "Ver ", with: "").trimmingCharacters(in: .whitespaces)
        }

        await MainActor.run {
            state.activeVersion = version
            state.installedVersions = [version]
        }
    }

    private func loadPostgresVersion(state: ApplicationState, session: TerminalViewModel, baseService: SSHBaseService) async {
        let result = await baseService.execute("psql --version 2>/dev/null", via: session)
        var version = ""

        // Parse version from output like "psql (PostgreSQL) 15.4 (Ubuntu 15.4-1.pgdg22.04+1)"
        if let range = result.output.range(of: "\\d+\\.\\d+", options: .regularExpression) {
            version = String(result.output[range])
        }

        // Check for multiple installed versions
        let clustersResult = await baseService.execute("pg_lsclusters 2>/dev/null | tail -n +2", via: session)
        var installedVersions = [version]

        if clustersResult.exitCode == 0 && !clustersResult.output.isEmpty {
            let lines = clustersResult.output.components(separatedBy: .newlines)
            installedVersions = lines.compactMap { line -> String? in
                let parts = line.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                return parts.first
            }.filter { !$0.isEmpty }
        }

        await MainActor.run {
            state.activeVersion = version
            state.installedVersions = Array(Set(installedVersions)).sorted()
        }
    }

    private func loadSingleVersion(for app: ApplicationDefinition, state: ApplicationState, session: TerminalViewModel, baseService: SSHBaseService) async {
        let resolver = ServiceResolver.shared

        guard let service = resolver.resolve(for: app.id) else { return }

        if let version = await service.getVersion(via: session) {
            await MainActor.run {
                state.activeVersion = version
                state.installedVersions = [version]
            }
        }
    }

    private func loadAvailableVersionsFromAPI(for app: ApplicationDefinition, state: ApplicationState) async {
        // Fetch available versions from the Velo API
        do {
            let capabilities = try await ApiService.shared.fetchCapabilities()
            if let capability = capabilities.first(where: { $0.slug.lowercased() == app.slug.lowercased() }) {
                await MainActor.run {
                    state.availableVersions = capability.versions ?? []
                }
            }
        } catch {
            // API fetch failed, continue without available versions
        }
    }
}
