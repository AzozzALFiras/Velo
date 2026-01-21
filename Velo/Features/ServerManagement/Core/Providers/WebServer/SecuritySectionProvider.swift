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
        // Check for ModSecurity or other WAF
        let modsecResult = await baseService.execute(
            "nginx -V 2>&1 | grep -i modsecurity || ls /etc/nginx/modsec/ 2>/dev/null",
            via: session
        )

        var securityRulesStatus: [String: Bool] = [:]

        // Check common security rules/configurations
        let securityChecks = [
            ("ModSecurity", "ls /etc/nginx/modsec/modsecurity.conf 2>/dev/null"),
            ("OWASP CRS", "ls /etc/nginx/modsec/crs-setup.conf 2>/dev/null || ls /usr/share/modsecurity-crs/ 2>/dev/null"),
            ("Rate Limiting", "grep -r 'limit_req_zone' /etc/nginx/ 2>/dev/null"),
            ("SSL/TLS", "grep -r 'ssl_certificate' /etc/nginx/sites-enabled/ 2>/dev/null"),
            ("Headers Security", "grep -r 'add_header.*X-Frame-Options\\|X-Content-Type-Options\\|X-XSS-Protection' /etc/nginx/ 2>/dev/null")
        ]

        for (name, command) in securityChecks {
            let result = await baseService.execute(command, via: session)
            securityRulesStatus[name] = result.exitCode == 0 && !result.output.isEmpty
        }

        // Get blocked requests stats if available
        var totalBlocked = "0"
        var last24h = "0"

        // Try to get ModSecurity audit log stats
        let auditLogResult = await baseService.execute(
            "wc -l /var/log/modsec_audit.log 2>/dev/null | awk '{print $1}'",
            via: session
        )
        if auditLogResult.exitCode == 0 && !auditLogResult.output.isEmpty {
            totalBlocked = auditLogResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Get last 24h blocks
        let recentResult = await baseService.execute(
            "find /var/log/modsec_audit.log -mtime -1 -exec wc -l {} \\; 2>/dev/null | awk '{print $1}'",
            via: session
        )
        if recentResult.exitCode == 0 && !recentResult.output.isEmpty {
            last24h = recentResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        await MainActor.run {
            state.securityRulesStatus = securityRulesStatus
            state.securityStats = (total: totalBlocked, last24h: last24h)
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
