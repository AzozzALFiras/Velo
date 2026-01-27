
import Foundation

struct ErrorPagesSectionProvider: SectionProvider {
    static var providerType: SectionProviderType { .errorPages }

    func loadData(
        for app: ApplicationDefinition,
        state: ApplicationState,
        session: TerminalViewModel
    ) async throws {
        // Only Nginx supported for now
        guard app.id == "nginx" else { return }

        let configPath = "/etc/nginx/conf.d/error_pages.conf"
        let baseService = ServerAdminService.shared

        // Ensure file exists
        let check = await baseService.execute("test -f \(configPath)", via: session)
        if check.exitCode != 0 {
            _ = await baseService.execute("sudo touch \(configPath)", via: session)
        }

        // Read content
        let result = await baseService.execute("cat \(configPath)", via: session)
        let content = result.output

        // Parse "error_page CODE /path;"
        var pages: [String: String] = [:]
        
        let lines = content.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            
            // Format: error_page 404 /404.html;
            let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            if parts.count >= 3 && parts[0] == "error_page" {
                let code = parts[1]
                var path = parts[2]
                if path.hasSuffix(";") { path.removeLast() }
                pages[code] = path
            }
        }

        await MainActor.run {
            state.errorPages = pages
        }
    }
}
