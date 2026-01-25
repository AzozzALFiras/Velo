
import Foundation

struct WafSectionProvider: SectionProvider {
    static var providerType: SectionProviderType { .wafStats }

    func loadData(
        for app: ApplicationDefinition,
        state: ApplicationState,
        session: TerminalViewModel
    ) async throws {
        let baseService = SSHBaseService.shared
        
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
        
        // 2. Determine log path based on selection
        var logPath = "/var/log/nginx/access.log" // Default global
        
        if state.currentWafSite != "All" {
            // Try to find access_log directive for this site
            // This is "best effort" grep
            let siteConf = "/etc/nginx/sites-enabled/\(state.currentWafSite)"
            let grep = await baseService.execute("grep 'access_log' \(siteConf) | head -1", via: session)
            let output = grep.output.trimmingCharacters(in: .whitespaces)
            
            // Format: access_log /path/to/log combined;
            if let pathRange = output.range(of: "\\s/[^;\\s]+", options: .regularExpression) {
                logPath = String(output[pathRange]).trimmingCharacters(in: .whitespaces)
            }
        }
        
        // 3. Read Logs (Tail 100)
        let logCmd = "tail -n 100 \(logPath)"
        let logResult = await baseService.execute(logCmd, via: session)
        
        let logs = parseAccessLog(logResult.output)
        
        await MainActor.run {
            state.wafLogs = logs.reversed() // Newest first
        }
    }
    
    private func parseAccessLog(_ content: String) -> [WafLogEntry] {
        var entries: [WafLogEntry] = []
        let lines = content.components(separatedBy: .newlines)
        
        // Nginx Default Log Format:
        // $remote_addr - $remote_user [$time_local] "$request" $status $body_bytes_sent "$http_referer" "$http_user_agent"
        // Regex is safer
        
        // Simple manual split for speed, assuming default format
        for line in lines {
            if line.isEmpty { continue }
            
            // We can try to use a regex for standard combined format
            // IP - - [Date] "REQ" Status Bytes "Ref" "UA"
            
            let pattern = "^(\\S+) \\S+ \\S+ \\[(.+?)\\] \"(.*?)\" (\\d{3}) (\\d+) \"(.*?)\" \"(.*?)\""
            
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let nsString = line as NSString
                if let match = regex.firstMatch(in: line, range: NSRange(location: 0, length: nsString.length)) {
                    let ip = nsString.substring(with: match.range(at: 1))
                    let time = nsString.substring(with: match.range(at: 2))
                    let request = nsString.substring(with: match.range(at: 3))
                    let status = nsString.substring(with: match.range(at: 4))
                    let bytes = nsString.substring(with: match.range(at: 5))
                    let referrer = nsString.substring(with: match.range(at: 6))
                    let ua = nsString.substring(with: match.range(at: 7))
                    
                    entries.append(WafLogEntry(
                        ip: ip,
                        time: time,
                        request: request,
                        status: status,
                        bytes: bytes,
                        referrer: referrer,
                        userAgent: ua,
                        country: "Unknown" // GeoIP requires database or API
                    ))
                }
            }
        }
        return entries
    }
}
