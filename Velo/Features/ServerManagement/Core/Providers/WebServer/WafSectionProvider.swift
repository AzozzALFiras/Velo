
import Foundation

struct WafSectionProvider: SectionProvider {
    static var providerType: SectionProviderType { .wafStats }

    func loadData(
        for app: ApplicationDefinition,
        state: ApplicationState,
        session: TerminalViewModel
    ) async throws {
        let baseService = ServerAdminService.shared
        
        // 1. Fetch available sites if empty
        if state.wafSites.isEmpty {
            // Re-use NginxService logic or simple scan
            let result = await baseService.execute("ls /etc/nginx/sites-enabled/ 2>/dev/null", via: session)
            let sites = result.output.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && !$0.hasSuffix(".conf") } // Assuming symlinks often don't have .conf, or do. 
                // Better: just list filenames
            
            // Allow user to select "All" (global access.log) or specific site
            var siteList = ["All"]
            siteList.append(contentsOf: sites)
            
            await MainActor.run {
                state.wafSites = siteList
            }
        }
        
        // 2. Load Page 1
        let service = NginxSecurityService.shared
        let (logs, total) = await service.fetchWafLogs(
            site: state.currentWafSite,
            page: 1,
            pageSize: 100, // Default page size
            via: session
        )
        
        await MainActor.run {
            state.wafLogs = logs
            state.wafLogsTotal = total
            state.wafLogsPage = 1
        }
    }
}
