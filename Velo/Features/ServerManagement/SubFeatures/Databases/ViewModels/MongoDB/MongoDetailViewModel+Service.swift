//
//  MongoDetailViewModel+Service.swift
//  Velo
//
//  Service management for MongoDB.
//

import Foundation

extension MongoDetailViewModel {
    
    func loadConfigPath() async {
        guard let session = session else { return }
        
        let paths = ["/etc/mongod.conf", "/usr/local/etc/mongod.conf"]
        for p in paths {
            let check = await baseService.execute("test -f \(p) && echo 'YES'", via: session)
            if check.output.contains("YES") {
                self.configPath = p
                return
            }
        }
    }
    
    func startService() async {
        guard let session = session else { return }
        isPerformingAction = true
        _ = await baseService.execute("sudo systemctl start mongod", via: session)
        await loadData()
        isPerformingAction = false
    }
    
    func stopService() async {
        guard let session = session else { return }
        isPerformingAction = true
        _ = await baseService.execute("sudo systemctl stop mongod", via: session)
        await loadData()
        isPerformingAction = false
    }
    
    func restartService() async {
        guard let session = session else { return }
        isPerformingAction = true
        _ = await baseService.execute("sudo systemctl restart mongod", via: session)
        await loadData()
        isPerformingAction = false
    }
}
