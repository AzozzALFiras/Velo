//
//  PostgresDetailViewModel+Config.swift
//  Velo
//
//  Configuration management for PostgreSQL.
//

import Foundation

extension PostgresDetailViewModel {
    
    // Postgres config values are often complex in postgresql.conf
    // For now we might implement a simple reader or leave empty until needed.
    
    func loadConfigValues() async {
        guard let session = session else { return }
        isLoadingConfig = true
        
        // We can read common settings via SQL
        // SHOW max_connections; SHOW shared_buffers; etc.
        let settings = ["max_connections", "shared_buffers", "work_mem", "maintenance_work_mem", "port"]
        
        var newValues: [MySQLConfigValue] = []
        
        for setting in settings {
            let cmd = "sudo -u postgres psql -t -c 'SHOW \(setting);' 2>/dev/null"
            let result = await baseService.execute(cmd, via: session)
            let val = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !val.isEmpty {
                newValues.append(MySQLConfigValue(
                    key: setting,
                    value: val,
                    description: "PostgreSQL Setting", // Could map descriptions
                    displayName: setting,
                    section: "General"
                ))
            }
        }
        
        await MainActor.run {
            self.configValues = newValues
            self.isLoadingConfig = false
        }
    }
}
