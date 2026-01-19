import Foundation

extension PHPDetailViewModel {
    
    // MARK: - Configuration
    
    func loadConfigValues() async {
        guard let session = session else { return }
        
        isLoadingConfig = true
        
        // Key configuration values to fetch
        let configKeys: [(key: String, display: String, desc: String, type: ConfigValueType)] = [
            ("upload_max_filesize", "Max Upload Size", "Maximum size of an uploaded file", .size),
            ("post_max_size", "Max POST Size", "Maximum size of POST data", .size),
            ("memory_limit", "Memory Limit", "Maximum memory a script can consume", .size),
            ("max_execution_time", "Max Execution Time", "Maximum time a script can run (seconds)", .time),
            ("max_input_time", "Max Input Time", "Maximum time to parse input data (seconds)", .time),
            ("max_input_vars", "Max Input Vars", "Maximum number of input variables", .number),
            ("max_file_uploads", "Max File Uploads", "Maximum number of files to upload simultaneously", .number),
            ("display_errors", "Display Errors", "Show PHP errors on screen", .boolean),
            ("error_reporting", "Error Reporting", "Error reporting level", .string),
            ("date.timezone", "Timezone", "Default timezone", .string),
        ]
        
        var values: [SharedConfigValue] = []
        
        for config in configKeys {
            if let value = await PHPService.shared.getConfigValue(config.key, via: session) {
                values.append(SharedConfigValue(
                    key: config.key,
                    value: value,
                    displayName: config.display,
                    description: config.desc,
                    type: config.type,
                    section: "General"
                ))
            }
        }
        
        configValues = values
        isLoadingConfig = false
    }
    
    // MARK: - Config File
    
    /// Load ONLY active configuration lines (no comments) - much faster!
    /// This reduces ~1800 lines to ~80 lines
    func loadConfigFile() async {
        guard let session = session else { return }
        
        isLoadingConfigFile = true
        
        // Use grep to extract only non-empty, non-comment lines
        // This is MUCH faster and won't freeze the UI
        let command = "grep -v '^[[:space:]]*;' '\(configPath)' 2>/dev/null | grep -v '^[[:space:]]*$' | grep -v '^\\['"
        let result = await SSHBaseService.shared.execute(command, via: session, timeout: 10)
        configFileContent = result.output
        
        isLoadingConfigFile = false
    }
    
    /// Load full config file (use with caution - large file!)
    func loadFullConfigFile() async {
        guard let session = session else { return }
        
        isLoadingConfigFile = true
        
        // Increase timeout for large file
        let result = await SSHBaseService.shared.execute("cat '\(configPath)' 2>/dev/null", via: session, timeout: 30)
        configFileContent = result.output
        
        isLoadingConfigFile = false
    }
    
    /// Save a specific configuration value using sed (fast and reliable)
    func saveConfigValue(_ key: String, _ value: String) async -> Bool {
        guard let session = session else { return false }
        
        isSavingConfigFile = true
        errorMessage = nil
        successMessage = nil
        
        // Use sed to update just this one value in the config file
        // This is MUCH faster than rewriting the entire file
        let escapedValue = value.replacingOccurrences(of: "/", with: "\\/")
        let command = "sed -i 's/^\\s*\(key)\\s*=.*/\(key) = \(escapedValue)/' '\(configPath)'"
        
        let result = await SSHBaseService.shared.execute(command, via: session, timeout: 10)
        
        if result.exitCode == 0 {
            successMessage = "Updated \(key) successfully"
            // Reload PHP-FPM to apply changes
            _ = await PHPService.shared.reload(via: session)
            isSavingConfigFile = false
            return true
        } else {
            errorMessage = "Failed to update \(key)"
            isSavingConfigFile = false
            return false
        }
    }
    
    func saveConfigFile() async -> Bool {
        guard let session = session else { return false }
        
        isSavingConfigFile = true
        errorMessage = nil
        successMessage = nil
        
        // Use heredoc approach - much faster and more reliable
        // This writes directly without encoding
        let tempPath = "/tmp/php_config_\(UUID().uuidString.prefix(8)).ini"
        
        // Escape single quotes in content
        let escapedContent = configFileContent.replacingOccurrences(of: "'", with: "'\\''")
        
        // Write using echo with single quotes (preserves all content)
        // Split into smaller chunks if needed
        let lines = configFileContent.components(separatedBy: "\n")
        
        var success = false
        
        if lines.count <= 50 {
            // Small file - write directly using cat with heredoc
            let writeCommand = "cat > '\(tempPath)' << 'ENDOFCONFIG'\n\(configFileContent)\nENDOFCONFIG"
            let result = await SSHBaseService.shared.execute(writeCommand, via: session, timeout: 15)
            
            if result.exitCode == 0 || result.output.isEmpty {
                // Move to final location
                let moveResult = await SSHBaseService.shared.execute("mv '\(tempPath)' '\(configPath)'", via: session, timeout: 5)
                success = moveResult.exitCode == 0 || !moveResult.output.contains("error")
            }
        } else {
            // Larger file - write line by line
            // First clear/create the temp file
            _ = await SSHBaseService.shared.execute("> '\(tempPath)'", via: session, timeout: 5)
            
            // Write in chunks of 20 lines
            let chunkSize = 20
            var currentIndex = 0
            success = true
            
            while currentIndex < lines.count && success {
                let endIndex = min(currentIndex + chunkSize, lines.count)
                let chunk = lines[currentIndex..<endIndex].joined(separator: "\n")
                let escapedChunk = chunk.replacingOccurrences(of: "'", with: "'\\''")
                
                let appendCommand = "echo '\(escapedChunk)' >> '\(tempPath)'"
                let result = await SSHBaseService.shared.execute(appendCommand, via: session, timeout: 10)
                
                if result.exitCode != 0 && result.output.contains("error") {
                    success = false
                }
                
                currentIndex = endIndex
            }
            
            if success {
                // Move to final location
                let moveResult = await SSHBaseService.shared.execute("mv '\(tempPath)' '\(configPath)'", via: session, timeout: 5)
                success = moveResult.exitCode == 0 || !moveResult.output.contains("error")
            }
        }
        
        if success {
            successMessage = "Configuration saved successfully"
            // Reload PHP-FPM to apply changes
            _ = await PHPService.shared.reload(via: session)
        } else {
            errorMessage = "Failed to save configuration"
            // Cleanup temp file
            _ = await SSHBaseService.shared.execute("rm -f '\(tempPath)'", via: session, timeout: 5)
        }
        
        isSavingConfigFile = false
        return success
    }
    
    // MARK: - Config Value Modification
    
    func updateConfigValue(_ key: String, to newValue: String) async -> Bool {
        guard let session = session else { return false }
        
        isPerformingAction = true
        errorMessage = nil
        
        // Use sed to update the value in php.ini
        let escapedValue = newValue.replacingOccurrences(of: "/", with: "\\/")
        let command = "sudo sed -i 's/^\\(;\\?\\s*\\)\\(\(key)\\s*=\\s*\\).*/\\2\(escapedValue)/' '\(configPath)'"
        
        let result = await SSHBaseService.shared.execute(command, via: session, timeout: 10)
        
        let success = result.exitCode == 0
        
        if success {
            // Reload config values
            await loadConfigValues()
            // Reload PHP-FPM
            _ = await PHPService.shared.reload(via: session)
            successMessage = "\(key) updated to \(newValue)"
        } else {
            errorMessage = "Failed to update \(key)"
        }
        
        isPerformingAction = false
        return success
    }
    
    // MARK: - Disabled Functions
    
    func loadDisabledFunctions() async {
        guard let session = session else { return }
        
        isLoadingDisabledFunctions = true
        
        let result = await SSHBaseService.shared.execute("php -r \"echo ini_get('disable_functions');\" 2>/dev/null", via: session, timeout: 10)
        let functions = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !functions.isEmpty && functions != "no value" {
            disabledFunctions = functions.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .sorted()
        } else {
            disabledFunctions = []
        }
        
        isLoadingDisabledFunctions = false
    }
    
    /// Remove a function from the disabled functions list
    func removeDisabledFunction(_ function: String) async -> Bool {
        guard let session = session else { return false }
        
        isPerformingAction = true
        errorMessage = nil
        
        // Remove the function from the list
        var newList = disabledFunctions.filter { $0 != function }
        let newValue = newList.joined(separator: ",")
        
        // Update php.ini
        // Escape characters for sed
        let escapedNewValue = newValue.replacingOccurrences(of: "/", with: "\\/")
        let command = "sudo sed -i 's/^\\(disable_functions\\s*=\\s*\\).*/\\1\(escapedNewValue)/' '\(configPath)'"
        let result = await SSHBaseService.shared.execute(command, via: session, timeout: 10)
        
        if result.exitCode == 0 {
            disabledFunctions = newList
            _ = await PHPService.shared.reload(via: session)
            successMessage = "Function \(function) enabled"
            isPerformingAction = false
            return true
        } else {
            errorMessage = "Failed to enable function"
            isPerformingAction = false
            return false
        }
    }
    
    /// Add a function to the disabled functions list
    func addDisabledFunction(_ function: String) async -> Bool {
        guard let session = session else { return false }
        
        isPerformingAction = true
        errorMessage = nil
        
        var newList = disabledFunctions
        if !newList.contains(function) {
            newList.append(function)
            let newValue = newList.joined(separator: ",")
            
            // Update php.ini
            let escapedNewValue = newValue.replacingOccurrences(of: "/", with: "\\/")
            let command = "sudo sed -i 's/^\\(disable_functions\\s*=\\s*\\).*/\\1\(escapedNewValue)/' '\(configPath)'"
            let result = await SSHBaseService.shared.execute(command, via: session, timeout: 10)
            
            if result.exitCode == 0 {
                disabledFunctions = newList.sorted()
                _ = await PHPService.shared.reload(via: session)
                successMessage = "Function \(function) disabled"
                isPerformingAction = false
                return true
            } else {
                errorMessage = "Failed to disable function"
                isPerformingAction = false
                return false
            }
        }
        
        isPerformingAction = false
        return true
    }
}
