import Foundation

extension MySQLDetailViewModel {
    
    func loadConfigValues() async {
        guard let session = session else { return }
        isLoadingConfig = true
        
        // Ensure config path is known
        if configPath == "..." {
            await loadConfigPath()
        }
        
        let directives = [
            ("port", "Port", "The port on which MySQL listens (3306)"),
            ("bind-address", "Bind Address", "IP address to listen on (0.0.0.0 or 127.0.0.1)"),
            ("max_connections", "Max Connections", "Maximum number of simultaneous client connections"),
            ("innodb_buffer_pool_size", "InnoDB Buffer Size", "Memory allocated for caching data and indexes"),
            ("slow_query_log", "Slow Query Log", "Enable (1) or disable (0) the slow query log"),
            ("long_query_time", "Long Query Time", "threshold for slow query log (in seconds)")
        ]
        
        // Read file using sudo
        let result = await baseService.execute("sudo cat '\(configPath)'", via: session)
        let content = result.output
        
        var newValues: [MySQLConfigValue] = []
        
        for (key, name, desc) in directives {
            // Regex to match "key = value" or "key=value"
            let pattern = "^\\s*\(key)\\s*=\\s*([^\\n#;]+)"
            if let range = content.range(of: pattern, options: [.regularExpression, .anchored, .caseInsensitive]) {
                let match = content[range]
                if let equalIndex = match.firstIndex(of: "=") {
                    let value = String(match[content.index(after: equalIndex)...]).trimmingCharacters(in: .whitespaces)
                    newValues.append(MySQLConfigValue(key: key, value: value, description: desc, displayName: name, section: nil))
                }
            } else if content.contains("\(key)") {
                // Secondary check for simple grep if regex misses due to multiline or strange format
                let grepResult = await baseService.execute("grep -i '^\(key)' '\(configPath)' | head -1 | awk -F= '{print $2}'", via: session)
                let val = grepResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
                if !val.isEmpty {
                    newValues.append(MySQLConfigValue(key: key, value: val, description: desc, displayName: name, section: nil))
                }
            }
        }
        
        await MainActor.run {
            self.configValues = newValues
            self.isLoadingConfig = false
        }
    }
    
    func loadConfigFile() async {
        guard let session = session else { return }
        isLoadingConfigFile = true
        
        let result = await baseService.execute("sudo cat '\(configPath)'", via: session)
        await MainActor.run {
            self.configFileContent = result.output
            self.isLoadingConfigFile = false
        }
    }
    
    func saveConfigFile() async -> Bool {
        guard let session = session else { return false }
        isSavingConfigFile = true
        
        let success = await baseService.writeFile(at: configPath, content: configFileContent, useSudo: true, via: session)
        
        if success {
            // Test & Reload (Nginx style)
            // MySQL doesn't have a direct "test" as clean as nginx, but we can check service syntax if possible
            successMessage = "Configuration saved. Please restart service to apply changes."
        } else {
            errorMessage = "Failed to save configuration file."
        }
        
        isSavingConfigFile = false
        return success
    }
}
