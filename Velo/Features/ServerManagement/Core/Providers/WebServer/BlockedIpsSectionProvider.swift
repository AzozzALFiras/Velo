
import Foundation

struct BlockedIpsSectionProvider: SectionProvider {
    static var providerType: SectionProviderType { .wafBlockedIps }

    func loadData(
        for app: ApplicationDefinition,
        state: ApplicationState,
        session: TerminalViewModel
    ) async throws {
        let baseService = ServerAdminService.shared
        let configPath = "/etc/nginx/conf.d/security_rules.conf"
        
        let result = await baseService.execute("cat \(configPath)", via: session)
        
        if result.exitCode == 0 {
            let lines = result.output.components(separatedBy: .newlines)
            var ips: [String] = []
            
            // Format: deny 1.2.3.4;
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("deny") {
                    let parts = trimmed.components(separatedBy: .whitespaces)
                    if parts.count >= 2 {
                        var ip = parts[1].replacingOccurrences(of: ";", with: "")
                        // Handle comments "deny 1.2.3.4; # comment"
                        if let commentIndex = ip.firstIndex(of: "#") {
                            ip = String(ip[..<commentIndex])
                        }
                        ip = ip.trimmingCharacters(in: .whitespaces)
                        if !ip.isEmpty {
                            ips.append(ip)
                        }
                    }
                }
            }
            
            await MainActor.run {
                state.blockedIps = ips
            }
        }
    }
}
