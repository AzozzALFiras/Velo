import Foundation

/// Service to handle Nginx Security / WAF operations
/// This service manages a dedicated security configuration file included in nginx.conf
actor NginxSecurityService {
    static let shared = NginxSecurityService()
    private let baseService = SSHBaseService.shared
    
    // The path where we will store our security rules
    private let securityConfigPath = "/etc/nginx/conf.d/security_rules.conf"
    
    // Enum mapping internal rule keys to Nginx directives
    enum SecurityRule: String, CaseIterable {
        case ccDefense = "CC_DEFENSE"
        case sqlInjection = "SQL_INJECTION"
        case xss = "XSS_PROTECTION"
        case scanner = "ANTI_SCANNER"
        case userAgent = "UA_FILTER"
        
        var description: String {
            switch self {
            case .ccDefense: return "CC Defense"
            case .sqlInjection: return "SQL Injection"
            case .xss: return "XSS Protection"
            case .scanner: return "Anti-Scanner"
            case .userAgent: return "UA Filter"
            }
        }
    }
    
    /// Ensures the security config file exists and is included
    func ensureSecurityConfig(via session: TerminalViewModel) async {
        // 1. Check if file exists
        let check = await baseService.execute("test -f \(securityConfigPath)", via: session)
        if check.exitCode != 0 {
            // Create empty file
            _ = await baseService.execute("sudo touch \(securityConfigPath)", via: session)
        }
        
        // 2. Ideally we check if it is included in nginx.conf, but that is risky to automate blindly.
        // For now we assume user's setup allows conf.d/*.conf includes (standard in Ubuntu/Debian/CentOS/aaPanel).
    }
    
    /// Reads the current status of all rules
    func getRulesStatus(via session: TerminalViewModel) async -> [String: Bool] {
        await ensureSecurityConfig(via: session)
        
        let result = await baseService.execute("cat \(securityConfigPath)", via: session)
        let content = result.output
        
        var statuses: [String: Bool] = [:]
        
        for rule in SecurityRule.allCases {
            // If the rule block exists and is NOT commented out, it's enabled.
            // Our convention: 
            // # BEGIN RULE_KEY
            // ... directives ...
            // # END RULE_KEY
            
            // If we find `# DISABLED RULE_KEY`, it is disabled.
            // If we find `# ENABLED RULE_KEY`, it is enabled.
            
            if content.contains("# ENABLED \(rule.rawValue)") {
                statuses[rule.rawValue] = true
            } else {
                statuses[rule.rawValue] = false
            }
        }
        
        return statuses
    }
    
    /// Toggles a specific rule
    func toggleRule(_ rule: SecurityRule, enabled: Bool, via session: TerminalViewModel) async -> Bool {
        // Generate the Nginx directive content for the rule
        let ruleContent = generateRuleContent(for: rule)
        
        // Marker tags
        let enabledMarker = "# ENABLED \(rule.rawValue)"
        let disabledMarker = "# DISABLED \(rule.rawValue)"
        let startMarker = "# BEGIN \(rule.rawValue)"
        let endMarker = "# END \(rule.rawValue)"
        
        // Read current file
        let read = await baseService.execute("cat \(securityConfigPath)", via: session)
        var content = read.output
        
        // Remove existing block for this rule if any
        content = removeBlock(from: content, start: startMarker, end: endMarker)
        
        // Append new block
        let newBlock = """
        \(startMarker)
        \(enabled ? enabledMarker : disabledMarker)
        \(enabled ? ruleContent : "# Rule is disabled")
        \(endMarker)
        
        """
        
        content += "\n" + newBlock
        
        // Save
        let written = await baseService.writeFile(at: securityConfigPath, content: content, useSudo: true, via: session)
        
        if written {
            // Test config
            let test = await baseService.execute("sudo nginx -t", via: session)
            if test.exitCode == 0 {
                // Reload
                _ = await NginxService.shared.reload(via: session)
                return true
            } else {
                return false
            }
        }
        return false
    }
    
    // MARK: - Helper: Rule Content Generation
    private func generateRuleContent(for rule: SecurityRule) -> String {
        switch rule {
        case .ccDefense:
            return """
            # Limit requests zone must be defined in http block usually.
            # Assuming zone 'one' exists or using local implementation.
            # Using generic return 444 for simple flood.
            limit_req_status 444;
            # limit_conn addr 100;
            """
        case .sqlInjection:
            return """
            if ($query_string ~ "union.*select.*\\(") { return 403; }
            if ($query_string ~ "union.*all.*select") { return 403; }
            if ($query_string ~ "concat.*\\(") { return 403; }
            """
        case .xss:
            return """
            if ($query_string ~ "(<|%3C).*script.*(>|%3E)") { return 403; }
            if ($query_string ~ "base64_(en|de)code") { return 403; }
            """
        case .scanner:
            return """
            if ($http_user_agent ~* (netcraw|npbot|malicious|scanner)) { return 444; }
            """
        case .userAgent:
            return """
            if ($http_user_agent ~* (curl|wget|python)) { return 403; }
            """
        }
    }
    
    private func removeBlock(from content: String, start: String, end: String) -> String {
        var lines = content.components(separatedBy: "\n")
        var newLines: [String] = []
        var skipping = false
        
        for line in lines {
            if line.contains(start) {
                skipping = true
            }
            
            if !skipping {
                newLines.append(line)
            }
            
            if line.contains(end) {
                skipping = false
            }
        }
        return newLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Get attack stats (mock logic replaced with real log parsing)
    func getStats(via session: TerminalViewModel) async -> (total: String, last24h: String) {
        // Grep error log or access log for 403/444
        // Example: grep -c " 444 " /var/log/nginx/access.log
        
        let path = "/var/log/nginx/access.log"
        // Total 403/444
        let totalCmd = "grep -E ' (403|444) ' \(path) | wc -l"
        let total = await baseService.execute(totalCmd, via: session).output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Last 24h (approximate by grep date, complex via simple grep, simplified for speed)
        // Just return simple count for now or try standard date format grep if known.
        // Let's rely on total for now, or fetch last 1000 lines and count.
        
        let recentCmd = "tail -n 5000 \(path) | grep -E ' (403|444) ' | wc -l"
        let recent = await baseService.execute(recentCmd, via: session).output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        return (total.isEmpty ? "0" : total, recent.isEmpty ? "0" : recent)
    }
}
