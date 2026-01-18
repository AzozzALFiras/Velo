import Foundation

extension MySQLDetailViewModel {
    
    func loadStatusInfo() async {
        guard let session = session else { return }
        isLoadingStatus = true
        
        // 1. Get version and basic stats via mysqladmin
        // Note: using sudo to ensure access without password prompts if possible, 
        // or relying on root session.
        let adminResult = await baseService.execute("sudo mysqladmin status 2>/dev/null", via: session)
        let adminOutput = adminResult.output
        
        // Example output: Uptime: 1542  Threads: 1  Questions: 219  Slow queries: 0  Opens: 102  Flush tables: 1  Open tables: 95  Queries per second avg: 0.142
        
        var newInfo = MySQLStatusInfo()
        
        if !adminOutput.isEmpty {
            let parts = adminOutput.components(separatedBy: "  ")
            for part in parts {
                let kv = part.components(separatedBy: ": ")
                if kv.count == 2 {
                    let key = kv[0].trimmingCharacters(in: .whitespaces)
                    let value = kv[1].trimmingCharacters(in: .whitespaces)
                    
                    switch key.lowercased() {
                    case "uptime": newInfo.uptime = value
                    case "threads": newInfo.threadsConnected = value
                    case "questions": newInfo.questions = value
                    case "slow queries": newInfo.slowQueries = value
                    case "open tables": newInfo.openTables = value
                    case "queries per second avg": newInfo.qps = value
                    default: break
                    }
                }
            }
        }
        
        // 2. Get version explicitly if not known
        if version == "..." || version == "installed" {
            let verResult = await baseService.execute("mysql --version", via: session)
            newInfo.version = verResult.output.components(separatedBy: " ").filter { $0.contains(".") }.first ?? "Unknown"
        } else {
            newInfo.version = version
        }
        
        await MainActor.run {
            self.statusInfo = newInfo
            self.isLoadingStatus = false
        }
    }
}
