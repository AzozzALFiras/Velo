import Foundation

extension MySQLDetailViewModel {
    
    func loadConfigPath() async {
        guard let session = session else { return }
        
        // Find my.cnf location
        let findCmd = "mysql --help --verbose 2>/dev/null | grep -A 1 'Default options' | tail -1 | awk '{print $1}'"
        let result = await baseService.execute(findCmd, via: session)
        let path = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !path.isEmpty && path.hasPrefix("/") {
            self.configPath = path
        } else {
            // Fallback common paths
            let fallbacks = ["/etc/mysql/my.cnf", "/etc/my.cnf", "/usr/local/etc/my.cnf"]
            for p in fallbacks {
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
        let svcName = await service.serviceName // Or detect it
        _ = await baseService.execute("sudo systemctl start \(svcName)", via: session)
        await loadData()
        isPerformingAction = false
    }
    
    func stopService() async {
        guard let session = session else { return }
        isPerformingAction = true
        let svcName = await service.serviceName
        _ = await baseService.execute("sudo systemctl stop \(svcName)", via: session)
        await loadData()
        isPerformingAction = false
    }
    
    func restartService() async {
        guard let session = session else { return }
        isPerformingAction = true
        let svcName = await service.serviceName
        _ = await baseService.execute("sudo systemctl restart \(svcName)", via: session)
        await loadData()
        isPerformingAction = false
    }
}
