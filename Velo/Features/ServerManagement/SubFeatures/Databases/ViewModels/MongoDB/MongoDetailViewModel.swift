//
//  MongoDetailViewModel.swift
//  Velo
//
//  ViewModel for detailed MongoDB management.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class MongoDetailViewModel: ObservableObject {
    
    // MARK: - Dependencies
    weak var session: TerminalViewModel?
    public let service = MongoService.shared
    public let baseService = SSHBaseService.shared
    
    // MARK: - Published State
    
    @Published var version: String = "..."
    @Published var isRunning: Bool = false
    @Published var configPath: String = "/etc/mongod.conf"
    @Published var uptime: String = "0"
    
    @Published var selectedSection: MySQLDetailSection = .service
    
    @Published var configValues: [SharedConfigValue] = []
    @Published var isLoadingConfig: Bool = false
    
    @Published var configFileContent: String = ""
    @Published var isLoadingConfigFile: Bool = false
    @Published var isSavingConfigFile: Bool = false
    
    @Published var users: [DatabaseUser] = []
    @Published var isLoadingUsers: Bool = false
    
    @Published var logContent: String = ""
    @Published var isLoadingLogs: Bool = false
    
    @Published var statusInfo: MySQLStatusInfo = MySQLStatusInfo()
    @Published var isLoadingStatus: Bool = false
    
    @Published var installedVersions: [String] = []
    @Published var availableVersionsFromAPI: [CapabilityVersion] = []
    @Published var isInstallingVersion: Bool = false
    @Published var installingVersionName: String = ""
    @Published var installStatus: String = ""
    @Published var capabilityIcon: String? = nil
    
    @Published var isLoading: Bool = false
    @Published var isPerformingAction: Bool = false
    @Published var errorMessage: String? = nil
    @Published var successMessage: String? = nil
    
    init(session: TerminalViewModel? = nil) {
        self.session = session
    }
    
    func loadData() async {
        guard let session = session else { return }
        isLoading = true
        errorMessage = nil
        
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
        case .service: break
        case .configuration: await loadConfigValues()
        case .users: await loadUsers()
        case .status: await loadStatusInfo()
        case .logs: await loadLogs()
        case .databases: break
        }
    }
    
    func performAsyncAction(_ actionName: String? = nil, action: () async -> (success: Bool, message: String?)) async {
        isPerformingAction = true
        errorMessage = nil
        successMessage = nil
        
        let result = await action()
        
        if result.success {
            if let msg = result.message { successMessage = msg }
        } else {
            errorMessage = result.message ?? "An error occurred"
        }
        
        isPerformingAction = false
    }
}
