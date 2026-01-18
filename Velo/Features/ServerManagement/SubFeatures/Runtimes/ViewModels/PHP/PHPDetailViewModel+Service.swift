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
        
        await performAsyncAction("Start PHP-FPM") {
            let success = await PHPService.shared.start(via: session)
            if success { isRunning = true }
            return (success, success ? "php.msg.started".localized : "php.err.start".localized)
        }
    }
    
    func stopService() async {
        guard let session = session else { return }
        
        await performAsyncAction("Stop PHP-FPM") {
            let success = await PHPService.shared.stop(via: session)
            if success { isRunning = false }
            return (success, success ? "php.msg.stopped".localized : "php.err.stop".localized)
        }
    }
    
    func restartService() async {
        guard let session = session else { return }
        
        await performAsyncAction("Restart PHP-FPM") {
            let success = await PHPService.shared.restart(via: session)
            if success { isRunning = true }
            return (success, success ? "php.msg.restarted".localized : "php.err.restart".localized)
        }
    }
    
    func reloadService() async {
        guard let session = session else { return }
        
        await performAsyncAction("Reload PHP-FPM") {
            let success = await PHPService.shared.reload(via: session)
            return (success, success ? "php.msg.reloaded".localized : "php.err.reload".localized)
        }
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
