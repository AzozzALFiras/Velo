//
//  SecuritySectionProvider.swift
//  Velo
//
//  Provider for loading web server security/WAF data.
//

import Foundation

/// Provides security and WAF data for web servers
struct SecuritySectionProvider: SectionProvider {
    static var providerType: SectionProviderType { .security }

    func loadData(
        for app: ApplicationDefinition,
        state: ApplicationState,
        session: TerminalViewModel
    ) async throws {
        let baseService = SSHBaseService.shared

        switch app.id.lowercased() {
        case "nginx":
            try await loadNginxSecurity(state: state, session: session, baseService: baseService)
        case "apache", "apache2":
            try await loadApacheSecurity(state: state, session: session, baseService: baseService)
        default:
            break
        }
    }

    private func loadNginxSecurity(state: ApplicationState, session: TerminalViewModel, baseService: SSHBaseService) async throws {
        // Use the dedicated NginxSecurityService for consistent status and stats
        let service = NginxSecurityService.shared
        
        // Fetch Rules Status
        let rulesStatus = await service.getRulesStatus(via: session)
        
        // Fetch WAF Stats
        let stats = await service.getStats(via: session)
        
        await MainActor.run {
            state.securityRulesStatus = rulesStatus
            state.securityStats = (total: stats.total, last24h: stats.last24h)
        }
    }

    private func loadApacheSecurity(state: ApplicationState, session: TerminalViewModel, baseService: SSHBaseService) async throws {
        var securityRulesStatus: [String: Bool] = [:]

        // Check Apache security modules and configurations
        let securityChecks = [
            ("ModSecurity", "apache2ctl -M 2>/dev/null | grep security"),
            ("ModEvasive", "apache2ctl -M 2>/dev/null | grep evasive"),
            ("SSL/TLS", "apache2ctl -M 2>/dev/null | grep ssl"),
            ("Headers", "apache2ctl -M 2>/dev/null | grep headers")
        ]

        for (name, command) in securityChecks {
            let result = await baseService.execute(command, via: session)
            securityRulesStatus[name] = result.exitCode == 0 && !result.output.isEmpty
        }

        await MainActor.run {
            state.securityRulesStatus = securityRulesStatus
            state.securityStats = ("0", "0")
        }
    }
}
