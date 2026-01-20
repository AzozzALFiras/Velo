import Foundation

extension NginxDetailViewModel {
    
    func loadServiceStatus() async {
        guard let session = session else { return }
        
        let status = await service.getStatus(via: session)
        
        switch status {
        case .running(let ver):
            isRunning = true
            version = ver
        case .stopped(let ver):
            isRunning = false
            version = ver
        default:
            isRunning = false
            version = "Not Installed"
        }
        
        // Also get paths
        // Typically nginx binary is at /usr/sbin/nginx, config at /etc/nginx/nginx.conf
        // We can verify this with `which nginx` and `nginx -t`
        
        let whichResult = await SSHBaseService.shared.execute("which nginx", via: session)
        if !whichResult.output.isEmpty {
            binaryPath = whichResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
    
    func startService() async {
        guard let session = session else { return }
        
        await performAsyncAction("Start Nginx") {
            let result = await SSHBaseService.shared.execute("sudo systemctl start nginx", via: session, timeout: 10)
            
            if result.exitCode == 0 {
                await loadServiceStatus()
                return (true, "nginx.msg.started".localized)
            } else {
                // Fetch status to understand why it failed
                let status = await SSHBaseService.shared.execute("sudo systemctl status nginx --no-pager -l -n 10", via: session)
                let cleanOutput = stripANSICodes(status.output)
                return (false, "Failed to start Nginx: \(cleanOutput)")
            }
        }
    }
    
    func stopService() async {
        guard let session = session else { return }
        
        await performAsyncAction("Stop Nginx") {
            let result = await SSHBaseService.shared.execute("sudo systemctl stop nginx", via: session, timeout: 10)
            let success = result.exitCode == 0
            
            if success {
                isRunning = false
            }
            
            return (success, success ? "nginx.msg.stopped".localized : "nginx.err.stop".localized)
        }
    }
    
    func restartService() async {
        guard let session = session else { return }
        
        await performAsyncAction("Restart Nginx") {
            let result = await SSHBaseService.shared.execute("sudo systemctl restart nginx", via: session, timeout: 15)
            
            if result.exitCode == 0 {
                await loadServiceStatus()
                return (true, "nginx.msg.restarted".localized)
            } else {
                // Fetch status to understand why it failed
                let status = await SSHBaseService.shared.execute("sudo systemctl status nginx --no-pager -l -n 10", via: session)
                let cleanOutput = stripANSICodes(status.output)
                return (false, "Failed to restart Nginx: \(cleanOutput)")
            }
        }
    }
    
    func reloadService() async {
        guard let session = session else { return }
        
        await performAsyncAction("Reload Nginx") {
            // Test config first
            let testResult = await SSHBaseService.shared.execute("sudo nginx -t", via: session)
            guard testResult.exitCode == 0 else {
                return (false, "Config check failed: \(testResult.output)")
            }
            
            let result = await SSHBaseService.shared.execute("sudo systemctl reload nginx", via: session, timeout: 10)
            let success = result.exitCode == 0
            
            return (success, success ? "nginx.msg.reloaded".localized : "nginx.err.reload".localized)
        }
    }
    
    private func stripANSICodes(_ input: String) -> String {
        let pattern = "\\x1B\\[[0-9;]*[mGKHF]|\\[\\d*(;\\d+)*m"
        return input.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }
}
