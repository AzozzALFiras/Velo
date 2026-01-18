import Foundation

extension NginxDetailViewModel {
    
    // MARK: - Security / WAF
    
    func loadSecurityStatus() async {
        guard let session = session else { return }
        
        // Load rules status
        let statuses = await NginxSecurityService.shared.getRulesStatus(via: session)
        
        await MainActor.run {
            self.securityRulesStatus = statuses
        }
        
        // Load stats
        let stats = await NginxSecurityService.shared.getStats(via: session)
        await MainActor.run {
            self.securityStats = stats
        }
    }
    
    func toggleSecurityRule(_ ruleKey: String, enabled: Bool) async {
        guard let session = session else { return }
        guard let rule = NginxSecurityService.SecurityRule(rawValue: ruleKey) else { return }
        
        isPerformingAction = true
        
        let success = await NginxSecurityService.shared.toggleRule(rule, enabled: enabled, via: session)
        
        if success {
            successMessage = "\(rule.description) \(enabled ? "enabled" : "disabled")"
            await loadSecurityStatus()
        } else {
            errorMessage = "Failed to toggle \(rule.description)"
            // Revert UI state if needed, or reload to sync
            await loadSecurityStatus()
        }
        
        isPerformingAction = false
    }
}
