//
//  PostgresDetailViewModel+Service.swift
//  Velo
//
//  Service management for PostgreSQL.
//

import Foundation

extension PostgresDetailViewModel {
    
    func loadConfigPath() async {
        guard let session = session else { return }
        
        // Postgres config path often depends on version /etc/postgresql/<ver>/main/postgresql.conf
        // or show config_file via psql
        let findCmd = "sudo -u postgres psql -t -c 'SHOW config_file;' 2>/dev/null"
        let result = await baseService.execute(findCmd, via: session)
        let path = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !path.isEmpty && path.hasPrefix("/") {
            self.configPath = path
        } else {
            // Fallback scan
            // Assume 13/main or 14/main etc
            let versions = ["16", "15", "14", "13", "12"]
            for v in versions {
                let p = "/etc/postgresql/\(v)/main/postgresql.conf"
                let check = await baseService.execute("test -f \(p) && echo 'YES'", via: session)
                if check.output.contains("YES") {
                    self.configPath = p
                    break
                }
            }
        }
    }
    
    func startService() async {
        guard let session = session else { return }
        isPerformingAction = true
        // Service name is usually postgresql
        _ = await baseService.execute("sudo systemctl start postgresql", via: session)
        await loadData()
        isPerformingAction = false
    }
    
    func stopService() async {
        guard let session = session else { return }
        isPerformingAction = true
        _ = await baseService.execute("sudo systemctl stop postgresql", via: session)
        await loadData()
        isPerformingAction = false
    }
    
    func restartService() async {
        guard let session = session else { return }
        isPerformingAction = true
        _ = await baseService.execute("sudo systemctl restart postgresql", via: session)
        await loadData()
        isPerformingAction = false
    }
}
