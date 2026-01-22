import Foundation

extension NginxDetailViewModel {
    
    func loadLogs() async {
        guard let session = session else { return }
        isLoadingLogs = true
        
        // Default error log path
        let logPath = "/var/log/nginx/error.log"
        
        let result = await SSHBaseService.shared.execute("tail -n 100 \(logPath)", via: session)
        if result.exitCode == 0 {
            logContent = result.output
        } else {
            // Try access log if error log is empty/inaccessible or just to show something
            // Or maybe permission denied.
            if result.output.contains("denied") {
                logContent = "Access denied reading \(logPath). Try running as root."
            } else {
                logContent = "No logs found or empty.\nError: \(result.output)"
            }
        }
        
        isLoadingLogs = false
    }
}
