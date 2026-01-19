//
//  MongoDetailViewModel+Status.swift
//  Velo
//
//  Status metrics for MongoDB.
//

import Foundation

extension MongoDetailViewModel {
    
    func loadStatusInfo() async {
        guard let session = session else { return }
        isLoadingStatus = true
        
        var info = MySQLStatusInfo()
        
        // db.serverStatus()
        let cmd = "mongosh --quiet --eval 'JSON.stringify(db.serverStatus())'"
        let result = await baseService.execute(cmd, via: session)
        
        if let data = result.output.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            
            if let uptimeVal = json["uptime"] as? Double {
                info.uptime = "\(Int(uptimeVal))"
            }
            
            if let connections = json["connections"] as? [String: Any],
               let current = connections["current"] as? Int {
                info.activeConnections = current
                info.threads = current
            }
            
            if let opcounters = json["opcounters"] as? [String: Any],
               let query = opcounters["query"] as? Int {
                info.userQueries = "\(query)"
            }
        }
        
        await MainActor.run {
            self.statusInfo = info
            self.uptime = info.uptime
            self.isLoadingStatus = false
        }
    }
}
