import Foundation
import Combine
import SwiftUI

/// ViewModel for detailed MySQL management.
/// Logic is split into extensions in ViewModels/MySQL/ directory.
@MainActor
final class MySQLDetailViewModel: ObservableObject {
    
    // MARK: - Dependencies
    weak var session: TerminalViewModel?
    public let service = MySQLService.shared
    public let baseService = SSHBaseService.shared
    
    // MARK: - Published State
    
    // General Info
    @Published var version: String = "..."
    @Published var isRunning: Bool = false
    @Published var configPath: String = "/etc/mysql/my.cnf"
    @Published var uptime: String = "0"
    
    // Sections
    @Published var selectedSection: MySQLDetailSection = .service
    
    // Configuration Values
    @Published var configValues: [MySQLConfigValue] = []
    @Published var isLoadingConfig: Bool = false
    
    // Config File Content
    @Published var configFileContent: String = ""
    @Published var isLoadingConfigFile: Bool = false
    @Published var isSavingConfigFile: Bool = false
    
    // Users
    @Published var users: [DatabaseUser] = []
    @Published var isLoadingUsers: Bool = false
    
    // Logs
    @Published var logContent: String = ""
    @Published var isLoadingLogs: Bool = false
    
    // Status Metrics
    @Published var statusInfo: MySQLStatusInfo = MySQLStatusInfo()
    @Published var isLoadingStatus: Bool = false
    
    // Loading & Error
    @Published var isLoading: Bool = false
    @Published var isPerformingAction: Bool = false
    @Published var errorMessage: String? = nil
    @Published var successMessage: String? = nil
    
    // MARK: - Init
    init(session: TerminalViewModel? = nil) {
        self.session = session
    }
    
    // MARK: - Data Loading
    
    func loadData() async {
        guard let session = session else { return }
        
        isLoading = true
        errorMessage = nil
        
        // Basic info
        let status = await service.getStatus(via: session)
        switch status {
        case .running(let ver):
            self.isRunning = true
            self.version = ver
        case .stopped(let ver):
            self.isRunning = false
            self.version = ver
        default:
            self.isRunning = false
            self.version = "Not Installed"
        }
        
        // Find config path
        await loadConfigPath()
        
        // Load section-specific data
        await loadSectionData()
        
        isLoading = false
    }
    
    func loadSectionData() async {
        guard session != nil else { return }
        
        switch selectedSection {
        case .service:
            // Service status already loaded in loadData or can be refreshed
            break
        case .configuration:
            await loadConfigValues()
        case .users:
            await loadUsers()
        case .status:
            await loadStatusInfo()
        case .logs:
            await loadLogs()
        case .databases:
            // This section might be handled by existing DatabasesViewModel 
            // but we can add a simple list here if needed.
            break
        }
    }
}
