import Foundation

extension PHPDetailViewModel {
    
    // MARK: - Service Status
    
    func loadServiceStatus() async {
        guard let session = session else { return }
        isRunning = await PHPService.shared.isRunning(via: session)
    }
    
    // MARK: - FPM Status
    
    func loadFPMStatus() async {
        guard let session = session else { return }
        
        isLoadingFPM = true
        fpmStatus = await PHPService.shared.getAllFPMStatus(via: session)
        isLoadingFPM = false
    }
    
    // MARK: - Service Actions
    
    func startService() async {
        guard let session = session else { return }
        
        isPerformingAction = true
        errorMessage = nil
        
        let success = await PHPService.shared.start(via: session)
        
        if success {
            isRunning = true
            successMessage = "PHP-FPM started successfully"
        } else {
            errorMessage = "Failed to start PHP-FPM"
        }
        
        isPerformingAction = false
    }
    
    func stopService() async {
        guard let session = session else { return }
        
        isPerformingAction = true
        errorMessage = nil
        
        let success = await PHPService.shared.stop(via: session)
        
        if success {
            isRunning = false
            successMessage = "PHP-FPM stopped successfully"
        } else {
            errorMessage = "Failed to stop PHP-FPM"
        }
        
        isPerformingAction = false
    }
    
    func restartService() async {
        guard let session = session else { return }
        
        isPerformingAction = true
        errorMessage = nil
        
        let success = await PHPService.shared.restart(via: session)
        
        if success {
            isRunning = true
            successMessage = "PHP-FPM restarted successfully"
        } else {
            errorMessage = "Failed to restart PHP-FPM"
        }
        
        isPerformingAction = false
    }
    
    func reloadService() async {
        guard let session = session else { return }
        
        isPerformingAction = true
        errorMessage = nil
        
        let success = await PHPService.shared.reload(via: session)
        
        if success {
            successMessage = "PHP-FPM configuration reloaded"
        } else {
            errorMessage = "Failed to reload PHP-FPM"
        }
        
        isPerformingAction = false
    }
    
    // MARK: - FPM Version-Specific Actions
    
    func startFPM(version: String) async {
        guard let session = session else { return }
        
        isPerformingAction = true
        _ = await PHPService.shared.startFPM(version: version, via: session)
        await loadFPMStatus()
        isPerformingAction = false
    }
    
    func stopFPM(version: String) async {
        guard let session = session else { return }
        
        isPerformingAction = true
        _ = await PHPService.shared.stopFPM(version: version, via: session)
        await loadFPMStatus()
        isPerformingAction = false
    }
}
