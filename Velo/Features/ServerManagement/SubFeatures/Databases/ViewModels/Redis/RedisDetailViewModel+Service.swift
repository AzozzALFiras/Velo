//
//  RedisDetailViewModel+Service.swift
//  Velo
//
//  Service management for Redis.
//

import Foundation

extension RedisDetailViewModel {
    
    func loadConfigPath() async {
        guard let session = session else { return }
        
        // Redis config is usually /etc/redis/redis.conf
        // Or check via CONFIG GET dir + dbfilename? No, CONFIG GET *
        
        let paths = ["/etc/redis/redis.conf", "/usr/local/etc/redis.conf"]
        for p in paths {
            let check = await baseService.execute("test -f \(p) && echo 'YES'", via: session)
            if check.output.contains("YES") {
                self.configPath = p
                return
            }
        }
        
        // Fallback: try to ask redis-cli
        let cmd = "redis-cli CONFIG GET dir" // This just gets data dir, not config file
        // INFO SERVER has config_file
        let info = await baseService.execute("redis-cli INFO SERVER | grep config_file", via: session)
        let output = info.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if output.contains("config_file:"), let path = output.components(separatedBy: ":").last {
            let cleanPath = path.trimmingCharacters(in: .whitespacesAndNewlines)
            if !cleanPath.isEmpty {
                self.configPath = cleanPath
            }
        }
    }
    
    func startService() async {
        guard let session = session else { return }
        isPerformingAction = true
        _ = await baseService.execute("sudo systemctl start redis-server", via: session)
        await loadData()
        isPerformingAction = false
    }
    
    func stopService() async {
        guard let session = session else { return }
        isPerformingAction = true
        _ = await baseService.execute("sudo systemctl stop redis-server", via: session)
        await loadData()
        isPerformingAction = false
    }
    
    func restartService() async {
        guard let session = session else { return }
        isPerformingAction = true
        _ = await baseService.execute("sudo systemctl restart redis-server", via: session)
        await loadData()
        isPerformingAction = false
    }
}
