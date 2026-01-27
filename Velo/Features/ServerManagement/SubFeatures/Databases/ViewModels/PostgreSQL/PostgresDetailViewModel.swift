//
//  PostgresDetailViewModel.swift
//  Velo
//
//  ViewModel for detailed PostgreSQL management.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class PostgresDetailViewModel: ObservableObject {
    
    // MARK: - Dependencies
    weak var session: TerminalViewModel?
    public let service = PostgreSQLService.shared
    public let baseService = ServerAdminService.shared
    var adminExecutor: ServerAdminExecutor?
    
    // MARK: - Published State
    
    // General Info
    @Published var version: String = "..."
    @Published var isRunning: Bool = false
    @Published var configPath: String = "/etc/postgresql/13/main/postgresql.conf" // Default fallback
    @Published var uptime: String = "0"
    
    // Sections
    @Published var selectedSection: MySQLDetailSection = .service // reusing same enum if possible, or create PostgresDetailSection? 
    // Wait, MySQLDetailSection might be specific. Let's check imports.
    // If it's a shared enum, good. If not, I might need to make one.
    // Assuming for now it's shared or I should make a generic one.
    // But to match "copy", I will assume there is a generic one or I use Int/String?
    // User said "same system". 
    // If MySQLDetailSection is "Service, Configuration, Users, Status, Logs", I can reuse it or create equivalent.
    
    // Configuration Values
    @Published var configValues: [SharedConfigValue] = [] // Reuse or rename to DatabaseConfigValue?
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
    @Published var statusInfo: MySQLStatusInfo = MySQLStatusInfo() // Reuse or rename to DatabaseStatusInfo?
    @Published var isLoadingStatus: Bool = false
    
    // Versions (Local & API)
    @Published var installedVersions: [String] = [] 
    @Published var availableVersionsFromAPI: [CapabilityVersion] = []
    @Published var isInstallingVersion: Bool = false
    @Published var installingVersionName: String = ""
    @Published var installStatus: String = ""
    @Published var capabilityIcon: String? = nil
    
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
        
        if version != "Not Installed" && version != "..." {
            self.installedVersions = [version]
        } else {
            self.installedVersions = []
        }
        
        await loadConfigPath()
        await loadAPIData()
        await loadSectionData()
        
        isLoading = false
    }
    
    func loadSectionData() async {
        guard session != nil else { return }
        
        switch selectedSection {
        case .service:
            break
        case .configuration:
            // await loadConfigValues() // TODO: Implement in +Config
            break
        case .users:
            await loadUsers()
        case .status:
            // await loadStatusInfo() // TODO: Implement in +Status
            break
        case .logs:
            await loadLogs()
        case .databases:
            break
        }
    }
    
    // MARK: - Helper Actions
    
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
