//
//  RedisDetailViewModel+Status.swift
//  Velo
//
//  Status metrics for Redis.
//

import Foundation

extension RedisDetailViewModel {
    
    func loadStatusInfo() async {
        guard let session = session else { return }
        isLoadingStatus = true
        
        var info = MySQLStatusInfo()
        
        // redis-cli INFO
        let result = await baseService.execute("redis-cli INFO", via: session)
        let output = result.output
        
        // Parse basic info
        // uptime_in_seconds:123
        // connected_clients:1
        // instantaneous_ops_per_sec:0
        
        if let uptimeRange = output.range(of: "uptime_in_seconds:[0-9]+", options: .regularExpression) {
            let val = String(output[uptimeRange]).components(separatedBy: ":").last ?? "0"
            info.uptime = val
        }
        
        if let clientsRange = output.range(of: "connected_clients:[0-9]+", options: .regularExpression) {
            let val = String(output[clientsRange]).components(separatedBy: ":").last ?? "0"
            info.activeConnections = Int(val) ?? 0
            info.threads = Int(val) ?? 0
        }
        
        if let opsRange = output.range(of: "instantaneous_ops_per_sec:[0-9]+", options: .regularExpression) {
            let val = String(output[opsRange]).components(separatedBy: ":").last ?? "0"
            info.userQueries = val
        }
        
        await MainActor.run {
            self.statusInfo = info
            self.uptime = info.uptime
            self.isLoadingStatus = false
        }
    }
}
