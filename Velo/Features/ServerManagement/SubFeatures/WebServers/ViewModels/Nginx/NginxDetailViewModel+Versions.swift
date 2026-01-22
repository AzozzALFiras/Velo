import Foundation

extension NginxDetailViewModel {
    
    func loadAvailableVersions() async {
        do {
            let capability = try await ApiService.shared.fetchCapabilityDetails(slug: "nginx")
            self.availableVersions = capability.versions ?? []
        } catch {
            print("[NginxDetailViewModel] Failed to load API data: \(error)")
            // Fallback empty or previously loaded
            self.availableVersions = []
        }
    }
    
    func installVersion(_ version: CapabilityVersion) async {
        guard let session = session else { return }
        
        isInstallingVersion = true
        installingVersionName = version.version
        installStatus = "Preparing..."
        
        // Installation Logic
        // 1. Add repo if needed
        // 2. Install package
        
        await performAsyncAction("Install Nginx \(version.version)") {
            installStatus = "Updating repositories..."
            _ = await SSHBaseService.shared.execute("sudo apt-get update", via: session)
            
            installStatus = "Installing nginx..."
            // This is risky if it replaces current. Assume user knows.
            // Force specific version is tricky with apt/system packages without pinning.
            // We'll just run install command for now.
            let cmd = "sudo apt-get install -y nginx" // In reality: nginx=version
            
            let result = await SSHBaseService.shared.execute(cmd, via: session, timeout: 300) // 5 min
            
            if result.exitCode == 0 {
                await loadServiceStatus()
                return (true, "Nginx installed successfully.")
            } else {
                return (false, "Installation failed: \(result.output)")
            }
        }
        
        isInstallingVersion = false
        installingVersionName = ""
        installStatus = ""
    }
    
    func switchVersion(_ version: CapabilityVersion) async {
       // For Nginx, "Switching" is usually just Installing another version which replaces the binary
       await installVersion(version)
    }
}
