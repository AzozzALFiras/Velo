import Foundation
import Combine

@MainActor
class NginxDetailViewModel: ObservableObject {
    
    // Dependencies
    let session: TerminalViewModel?
    let service = NginxService.shared
    
    // State
    @Published var selectedSection: NginxDetailSection = .service
    @Published var isLoading = false
    @Published var isPerformingAction = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    // Installation / Versions
    @Published var availableVersions: [CapabilityVersion] = []
    @Published var isInstallingVersion = false
    @Published var installingVersionName = ""
    @Published var installStatus = ""
    @Published var isRunning = false
    @Published var version = ""
    @Published var binaryPath = "/usr/sbin/nginx"
    @Published var configPath = "/etc/nginx/nginx.conf"
    
    // Config
    @Published var configValues: [NginxConfigValue] = []
    @Published var configFileContent = ""
    @Published var isLoadingConfig = false
    @Published var isLoadingConfigFile = false
    @Published var isSavingConfig = false
    
    // Security / WAF
    @Published var securityRulesStatus: [String: Bool] = [:]
    @Published var securityStats: (total: String, last24h: String) = ("0", "0")
    
    // Logs
    @Published var logContent = ""
    @Published var isLoadingLogs = false
    
    // Modules/Info
    @Published var modules: [String] = []
    @Published var configureArguments: [String] = []
    @Published var isLoadingInfo = false
    
    // Status
    @Published var statusInfo: NginxStatusInfo?
    @Published var isLoadingStatus = false
    
    init(session: TerminalViewModel?) {
        self.session = session
    }
    
    func loadData() async {
        guard let session = session else { return }
        
        isLoading = true
        errorMessage = nil
        
        await loadServiceStatus()
        await loadSectionData()
        await loadAvailableVersions() // Load versions
        
        isLoading = false
    }
    
    func loadSectionData() async {
        switch selectedSection {
        case .service:
            await loadServiceStatus()
        case .configuration:
            await loadConfigurationValues()
        case .configFile:
            await loadConfigFile()
        case .logs:
            await loadLogs()
        case .modules:
            await loadModules()
        case .status:
            await loadStatusMetrics()
        case .security:
            // Placeholder: Load security status if needed, or it might be managed by view state
            break 
        }
    }
    
    // MARK: - Helper
    
    func performAsyncAction(_ actionName: String? = nil, action: () async -> (success: Bool, message: String?)) async {
        isPerformingAction = true
        errorMessage = nil
        successMessage = nil
        
        let result = await action()
        
        if result.success {
            if let msg = result.message {
                successMessage = msg
            }
        } else {
            errorMessage = result.message ?? "An error occurred"
        }
        
        isPerformingAction = false
    }
}
