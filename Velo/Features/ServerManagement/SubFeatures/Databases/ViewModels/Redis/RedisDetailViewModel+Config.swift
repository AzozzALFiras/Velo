//
//  RedisDetailViewModel+Config.swift
//  Velo
//
//  Configuration management for Redis.
//

import Foundation

extension RedisDetailViewModel {
    
    func loadConfigValues() async {
        guard let session = session else { return }
        isLoadingConfig = true
        
        // Use CONFIG GET * to list all, but that's huge.
        // Let's get meaningful ones.
        let keys = ["maxmemory", "maxmemory-policy", "port", "bind", "requirepass", "timeout"]
        var newValues: [MySQLConfigValue] = []
        
        for key in keys {
            let cmd = "redis-cli CONFIG GET \(key)"
            let result = await baseService.execute(cmd, via: session)
            // Output is key\nvalue
            let lines = result.output.components(separatedBy: .newlines).filter { !$0.isEmpty }
            if lines.count >= 2 {
                newValues.append(MySQLConfigValue(
                    key: key,
                    value: lines[1],
                    description: "Redis Configuration",
                    displayName: key,
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
