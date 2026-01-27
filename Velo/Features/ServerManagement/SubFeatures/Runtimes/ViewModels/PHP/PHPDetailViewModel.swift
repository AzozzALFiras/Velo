//
//  PHPDetailViewModel.swift
//  Velo
//
//  ViewModel for detailed PHP management.
//  Logic is split into extensions in ViewModels/PHP/ directory.
//

import Foundation
import Combine
import SwiftUI

// MARK: - PHPDetailViewModel

@MainActor
final class PHPDetailViewModel: ObservableObject {
    
    // MARK: - Dependencies
    
    weak var session: TerminalViewModel?
    public let phpService = PHPService.shared
    public let baseService = ServerAdminService.shared
    var adminExecutor: ServerAdminExecutor?
    
    // MARK: - Published State
    
    // General Info
    @Published var activeVersion: String = "..."
    @Published var installedVersions: [String] = []
    @Published var isRunning: Bool = false
    @Published var configPath: String = "..."
    @Published var binaryPath: String = "..."
    
    // Sections
    @Published var selectedSection: PHPDetailSection = .service
    
    // Extensions
    @Published var extensions: [PHPExtension] = []
    @Published var availableExtensions: [String] = []
    @Published var isLoadingExtensions: Bool = false
    @Published var isInstallingExtension: Bool = false
    
    // Disabled Functions
    @Published var disabledFunctions: [String] = []
    @Published var isLoadingDisabledFunctions: Bool = false
    
    // Configuration Values
    @Published var configValues: [SharedConfigValue] = []
    @Published var isLoadingConfig: Bool = false
    
    // Config File Content
    @Published var configFileContent: String = ""
    @Published var isLoadingConfigFile: Bool = false
    @Published var isSavingConfigFile: Bool = false
    
    // Logs
    @Published var logContent: String = ""
    @Published var isLoadingLogs: Bool = false
    
    // PHP Info
    @Published var phpInfoHTML: String = ""
    @Published var phpInfoData: [String: String] = [:]
    @Published var isLoadingPHPInfo: Bool = false
    
    // FPM Status
    @Published var fpmStatus: [String: Bool] = [:]
    @Published var isLoadingFPM: Bool = false
    
    // Loading & Error
    @Published var isLoading: Bool = false
    @Published var isPerformingAction: Bool = false
    @Published var errorMessage: String? = nil
    @Published var successMessage: String? = nil
    
    // API Data
    @Published var availableVersionsFromAPI: [CapabilityVersion] = []
    @Published var capabilityIcon: String? = nil
    @Published var isInstallingVersion: Bool = false
    @Published var installingVersionName: String = ""
    @Published var installStatus: String = ""
    
    // MARK: - Init
    
    init(session: TerminalViewModel? = nil) {
        self.session = session
    }
    
    // MARK: - Data Loading
    
    /// Load all PHP data
    func loadData() async {
        guard session != nil else { return }
        
        isLoading = true
        errorMessage = nil
        
        // Serialize calls to ensure SSH session stability
        await loadVersionInfo()
        await loadServiceStatus()
        await loadPaths()
        await loadAPIData()
        
        // Load section-specific data
        await loadSectionData()
        
        isLoading = false
    }
    
    /// Load data for the current section
    func loadSectionData() async {
        // Skip reloading if a version is being installed (session is busy)
        guard !isInstallingVersion else { return }
        
        switch selectedSection {
        case .service:
            await loadFPMStatus()
        case .extensions:
            await loadExtensions()
        case .disabledFunctions:
            await loadDisabledFunctions()
        case .configuration, .uploadLimits, .timeouts:
            await loadConfigValues()
        case .configFile:
            await loadConfigFile()
        case .fpmProfile:
            await loadFPMStatus()
        case .logs:
            await loadLogs()
        case .phpinfo:
            await loadPHPInfo()
        }
    }
    // MARK: - Helper Actions
    
    /// Generic helper to perform async actions with loading state and error handling
    /// - Parameters:
    ///   - actionName: Name of action for logging (optional)
    ///   - action: Async closure that returns success bool and optional error message
    func performAsyncAction(
        _ actionName: String? = nil,
        action: () async -> (success: Bool, message: String?)
    ) async {
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
