
import Foundation

extension MySQLDetailViewModel {
    
    // MARK: - API Data
    
    func loadAPIData() async {
        do {
            let capability = try await ApiService.shared.fetchCapabilityDetails(slug: "mysql")
            capabilityIcon = capability.icon
            availableVersionsFromAPI = capability.versions ?? []
        } catch {
            print("[MySQLDetailViewModel] Failed to load API data: \(error)")
        }
    }
    
    // MARK: - Version Installation
    
    /// Install a new MySQL version from API
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
        
        print("[MySQLDetailVM] Detected OS: '\(osName)', installCommands: \(version.installCommands ?? [:])")
        
        installStatus = "Preparing installation..."
        
        // Get install commands from API
        // Get install commands from API
        guard let installCommands = version.installCommands,
              let commandsList = installCommands[osName] ?? installCommands["ubuntu"] ?? installCommands["debian"],
              !commandsList.isEmpty else {
            errorMessage = "No install commands available for \(osName)"
            isInstallingVersion = false
            installStatus = ""
            return
        }
        
        let installCommand = commandsList.joined(separator: " && ")
        
        print("[MySQLDetailVM] Executing install command: \(installCommand.prefix(100))...")
        
        installStatus = "Installing MySQL \(version.version)..."
        
        // Execute install command (with longer timeout for database installation)
        // 1200 seconds = 20 minutes (compilation can be slow if source, or large binary download)
        let result = await SSHBaseService.shared.execute(installCommand, via: session, timeout: 1200)
        
        if result.exitCode == 0 || result.output.contains("is already") || result.output.contains("newest version") {
            installStatus = "Verifying installation..."
            successMessage = "MySQL \(version.version) installed successfully"
            
            // Reload everything to catch the new version and status
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s wait for service to stabilize
            await loadData()
        } else {
            errorMessage = "Failed to install MySQL \(version.version)"
            print("[MySQLDetailVM] Install error: \(result.output.suffix(200))")
        }
        
        isInstallingVersion = false
        installingVersionName = ""
        installStatus = ""
    }
}
