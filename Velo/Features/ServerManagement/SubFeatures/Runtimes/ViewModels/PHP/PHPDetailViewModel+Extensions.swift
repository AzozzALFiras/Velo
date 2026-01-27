import Foundation

extension PHPDetailViewModel {
    
    // MARK: - Extensions
    
    func loadExtensions() async {
        guard let session = session else { return }
        
        isLoadingExtensions = true
        
        let loadedExtensions = await PHPService.shared.getLoadedExtensions(via: session)
        
        // Core extensions that are typically built-in
        let coreExtensions = ["Core", "date", "libxml", "pcre", "reflection", "spl", "standard", "filter", "hash", "json"]
        
        extensions = loadedExtensions.map { ext in
            PHPExtension(
                name: ext,
                isLoaded: true,
                isCore: coreExtensions.contains { $0.lowercased() == ext.lowercased() }
            )
        }.sorted { $0.name.lowercased() < $1.name.lowercased() }
        
        isLoadingExtensions = false
    }
    
    func loadAvailableExtensions() async {
        // Implementation for loading available extensions via apt-cache
        // For now we might leave it empty or implement basic check
        // This was missing from original read, so implementing simplified version if needed
        // Or if the view uses a static list, we might not need much here.
        // But the view calls it.
        guard let session = session else { return }
        // TODO: Implement proper fetching if needed.
    }
    
    func installExtension(_ name: String) async -> Bool {
        guard let session = session else { return false }

        isInstallingExtension = true
        errorMessage = nil

        // Detect OS and package manager
        let osInfo = await SystemStatsService.shared.getOSInfo(via: session)
        let pm = PackageManagerCommandBuilder.detect(from: osInfo.id)

        let packageName = "php\(activeVersion)-\(name)"
        let cmd = PackageManagerCommandBuilder.installCommand(packages: [packageName], packageManager: pm)

        // Use centralized admin service
        let result = await ServerAdminService.shared.execute(cmd, via: session, timeout: 300)

        if result.exitCode == 0 {
            successMessage = "Extension \(name) installed successfully"
            await loadExtensions()
            _ = await PHPService.shared.reload(via: session)
            isInstallingExtension = false
            return true
        } else {
            // Try generic name if versioned failed (e.g. php-redis)
            let genericCmd = PackageManagerCommandBuilder.installCommand(packages: ["php-\(name)"], packageManager: pm)
            let resultGeneric = await ServerAdminService.shared.execute(genericCmd, via: session, timeout: 300)
            if resultGeneric.exitCode == 0 {
                successMessage = "Extension \(name) installed successfully"
                await loadExtensions()
                _ = await PHPService.shared.reload(via: session)
                isInstallingExtension = false
                return true
            }

            errorMessage = "Failed to install \(name)"
            isInstallingExtension = false
            return false
        }
    }

    // MARK: - Admin Service access is now handled via ServerAdminService.shared
}
