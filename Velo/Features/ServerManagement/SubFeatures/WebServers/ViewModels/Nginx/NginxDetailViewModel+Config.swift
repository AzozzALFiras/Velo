import Foundation

extension NginxDetailViewModel {
    
    // MARK: - Config Values
    
    func loadConfigurationValues() async {
        guard let session = session else { return }
        isLoadingConfig = true
        
        // Ensure config path is known, default to /etc/nginx/nginx.conf
        // We will grep specific known directives
        // Directives to look for:
        // - worker_processes
        // - worker_connections
        // - keepalive_timeout
        // - client_max_body_size
        // - server_tokens
        // - gzip
        
        configValues = []
        
        let directives = [
            ("worker_processes", "Worker Processes", "Number of worker processes (auto or number)"),
            ("worker_connections", "Worker Connections", "Max connections per worker"),
            ("keepalive_timeout", "Keepalive Timeout", "Timeout for keep-alive connections"),
            ("client_max_body_size", "Max Body Size", "Maximum allowed size of the client request body"),
            ("server_tokens", "Server Tokens", "Show/Hide nginx version (on/off)"),
            ("gzip", "Gzip Compression", "Enable/Disable gzip compression (on/off)")
        ]
        
        let fileContentResult = await SSHBaseService.shared.execute("cat \(configPath)", via: session)
        let content = fileContentResult.output
        
        for (key, name, desc) in directives {
            // Regex to find "key value;"
            // Matches "key value;" or "key value ;"
            if let range = content.range(of: "\(key)\\s+([^;]+);", options: .regularExpression) {
                let match = content[range]
                // Extract value
                var value = String(match).replacingOccurrences(of: key, with: "")
                    .replacingOccurrences(of: ";", with: "")
                    .trimmingCharacters(in: .whitespaces)
                
                configValues.append(NginxConfigValue(
                    key: key,
                    value: value,
                    description: desc,
                    displayName: name,
                    section: nil
                ))
            } else {
                // If not found in main config, might be default?
                // Add with empty or default? Let's skip or show "Unknown"
            }
        }
        
        isLoadingConfig = false
    }
    
    func updateConfigValue(_ key: String, to newValue: String) async -> Bool {
        guard let session = session else { return false }
        isPerformingAction = true
        
        // 1. Read file
        let readResult = await SSHBaseService.shared.execute("cat \(configPath)", via: session)
        var content = readResult.output
        
        // 2. Replace using regex
        // We need to be careful not to break the file.
        // Regex: (key\s+)([^;]+)(;)
        let pattern = "(\(key)\\s+)([^;]+)(;)"
        
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(content.startIndex..., in: content)
            let newContent = regex.stringByReplacingMatches(
                in: content,
                options: [],
                range: range,
                withTemplate: "$1\(newValue)$3"
            )
            
            if newContent != content {
                // 3. Save
                let saveResult = await SSHBaseService.shared.writeFile(at: configPath, content: newContent, useSudo: true, via: session)
                if saveResult {
                    // 4. Test & Reload
                    let testResult = await SSHBaseService.shared.execute("sudo nginx -t", via: session)
                    if testResult.exitCode == 0 {
                        _ = await service.reload(via: session)
                        successMessage = "Value updated to '\(newValue)'"
                        await loadConfigurationValues()
                        isPerformingAction = false
                        return true
                    } else {
                        // Revert? simpler to just warn for now, or redundant safe-keeping?
                        errorMessage = "Invalid config: \(testResult.output)"
                    }
                } else {
                    errorMessage = "Failed to write config file"
                }
            }
        }
        
        isPerformingAction = false
        return false
    }
    
    // MARK: - Config File
    
    func loadConfigFile() async {
        guard let session = session else { return }
        isLoadingConfigFile = true
        
        // Try global config first
        let primaryPath = configPath.isEmpty ? "/etc/nginx/nginx.conf" : configPath
        
        // 1. Try reading with sudo (cat)
        var result = await SSHBaseService.shared.execute("sudo cat '\(primaryPath)'", via: session)
        
        // 2. Fallback to common aaPanel/other paths if empty or error
        if result.output.isEmpty || result.output.contains("No such file") {
             let fallbacks = [
                "/www/server/nginx/conf/nginx.conf", // aaPanel common
                "/usr/local/nginx/conf/nginx.conf",
                "/etc/nginx/nginx.conf"
             ]
             
             for path in fallbacks {
                 if path == primaryPath { continue }
                 let fallbackResult = await SSHBaseService.shared.execute("sudo cat '\(path)'", via: session)
                 if !fallbackResult.output.isEmpty && !fallbackResult.output.contains("No such file") {
                     result = fallbackResult
                     // Update configPath to the one found so we save back to correct place
                     await MainActor.run {
                         self.configPath = path
                     }
                     break
                 }
             }
        }
        
        configFileContent = result.output
        
        if configFileContent.isEmpty {
            errorMessage = "Could not load nginx.conf. Please check permissions or path."
        }
        
        isLoadingConfigFile = false
    }
    
    func saveConfigFile() async -> Bool {
        guard let session = session else { return false }
        isSavingConfig = true
        
        // Save
        let saveResult = await SSHBaseService.shared.writeFile(at: configPath, content: configFileContent, useSudo: true, via: session)
        
        if saveResult {
            // Test
            let testResult = await SSHBaseService.shared.execute("sudo nginx -t", via: session)
            if testResult.exitCode == 0 {
                _ = await service.reload(via: session)
                successMessage = "Configuration saved and reloaded"
                isSavingConfig = false
                return true
            } else {
                errorMessage = "Config test failed: \(testResult.output)"
            }
        } else {
            errorMessage = "Failed to save file"
        }
        
        isSavingConfig = false
        return false
    }
}
