import Foundation

extension PHPDetailViewModel {
    
    // MARK: - Version Info
    
    func loadVersionInfo() async {
        guard let session = session else { return }
        
        if let version = await PHPService.shared.getVersion(via: session) {
            activeVersion = version
        }
        
        installedVersions = await PHPService.shared.getInstalledVersions(via: session)
    }
    
    // MARK: - Paths
    
    func loadPaths() async {
        guard let session = session else { return }
        
        if let path = await PHPService.shared.getConfigFilePath(via: session) {
            configPath = path
        }
        
        // Get binary path
        let result = await baseService.execute("which php 2>/dev/null", via: session, timeout: 5)
        let path = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if !path.isEmpty {
            binaryPath = path
        }
    }
    
    // MARK: - API Data
    
    func loadAPIData() async {
        do {
            let capability = try await ApiService.shared.fetchCapabilityDetails(slug: "php")
            capabilityIcon = capability.icon
            availableVersionsFromAPI = capability.versions ?? []
        } catch {
            print("[PHPDetailViewModel] Failed to load API data: \(error)")
        }
    }
    
    // MARK: - Logs
    
    func loadLogs() async {
        guard let session = session else { return }
        
        isLoadingLogs = true
        
        // Try common PHP log locations
        let logPaths = [
            "/var/log/php\(activeVersion)-fpm.log",
            "/var/log/php-fpm/error.log",
            "/var/log/php/error.log",
            "/var/log/php_errors.log"
        ]
        
        for path in logPaths {
            let result = await baseService.execute("tail -100 '\(path)' 2>/dev/null", via: session, timeout: 10)
            if !result.output.isEmpty && !result.output.contains("No such file") {
                logContent = result.output
                break
            }
        }
        
        if logContent.isEmpty {
            logContent = "No PHP logs found in common locations."
        }
        
        isLoadingLogs = false
    }
    
    // MARK: - PHP Info
    
    func loadPHPInfo() async {
        guard let session = session else { return }
        
        isLoadingPHPInfo = true
        phpInfoData = [:]
        
        // Get key PHP info values
        let result = await baseService.execute("php -i 2>/dev/null | head -200", via: session, timeout: 15)
        phpInfoHTML = result.output
        
        // Parse the output into key-value pairs
        var data: [String: String] = [:]
        let lines = result.output.components(separatedBy: "\n")
        
        for line in lines {
            // Parse lines like "key => value" or "key = value"
            if line.contains(" => ") {
                let parts = line.components(separatedBy: " => ")
                if parts.count >= 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespaces)
                    let value = parts.dropFirst().joined(separator: " => ").trimmingCharacters(in: .whitespaces)
                    if !key.isEmpty && !value.isEmpty {
                        data[key] = value
                    }
                }
            }
        }
        
        phpInfoData = data
        isLoadingPHPInfo = false
    }
}
