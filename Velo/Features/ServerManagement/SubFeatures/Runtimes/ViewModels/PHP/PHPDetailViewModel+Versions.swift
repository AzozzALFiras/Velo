import Foundation

extension PHPDetailViewModel {
    
    // MARK: - Version Switching
    
    func switchVersion(to version: String) async {
        guard let session = session else { return }
        
        isPerformingAction = true
        errorMessage = nil
        
        let success = await PHPService.shared.switchVersion(to: version, via: session)
        
        if success {
            activeVersion = version
            successMessage = "Switched to PHP \(version)"
            // Reload data for the new version
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s delay
            await loadData()
        } else {
            errorMessage = "Failed to switch PHP version"
        }
        
        isPerformingAction = false
    }
    
    /// Install a new PHP version from API
    func installVersion(_ version: CapabilityVersion) async {
        guard let session = session else { return }
        
        isInstallingVersion = true
        installingVersionName = version.version
        installStatus = "Detecting OS..."
        errorMessage = nil
        
        // Get OS name (ubuntu/debian)
        let osResult = await SSHBaseService.shared.execute("cat /etc/os-release | grep -E '^ID=' | cut -d= -f2", via: session, timeout: 5)
        let osName = osResult.output
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\"", with: "")
        
        print("[PHPDetailVM] Detected OS: '\(osName)', installCommands: \(version.installCommands ?? [:])")
        
        installStatus = "Preparing installation..."
        
        // Get install commands from API - API uses "default" key, not "install"
        guard let installCommands = version.installCommands,
              let osCommands = installCommands[osName] ?? installCommands["ubuntu"] ?? installCommands["debian"],
              let installCommand = osCommands["default"] ?? osCommands["install"] else {
            errorMessage = "No install commands available for \(osName)"
            isInstallingVersion = false
            installStatus = ""
            return
        }
        
        print("[PHPDetailVM] Executing install command: \(installCommand.prefix(100))...")
        
        installStatus = "Installing PHP \(version.version)..."
        
        // Execute install command (with longer timeout for package installation)
        let result = await SSHBaseService.shared.execute(installCommand, via: session, timeout: 600)
        
        if result.exitCode == 0 || result.output.contains("is already") || result.output.contains("newest version") {
            installStatus = "Verifying installation..."
            successMessage = "PHP \(version.version) installed successfully"
            // Reload installed versions
            await loadVersionInfo()
        } else {
            errorMessage = "Failed to install PHP \(version.version)"
            print("[PHPDetailVM] Install error: \(result.output.suffix(200))")
        }
        
        isInstallingVersion = false
        installingVersionName = ""
        installStatus = ""
    }
    
    /// Set a PHP version as the default (update-alternatives)
    func setAsDefaultVersion(_ version: String) async {
        guard let session = session else { return }
        
        isPerformingAction = true
        errorMessage = nil
        
        // Use update-alternatives to set default PHP
        let command = "update-alternatives --set php /usr/bin/php\(version)"
        let result = await SSHBaseService.shared.execute(command, via: session, timeout: 10)
        
        if result.exitCode == 0 || result.output.isEmpty {
            activeVersion = version
            successMessage = "PHP \(version) is now the default version"
            // Reload to update active version
            await loadVersionInfo()
        } else {
            errorMessage = "Failed to set PHP \(version) as default"
        }
        
        isPerformingAction = false
    }
}
