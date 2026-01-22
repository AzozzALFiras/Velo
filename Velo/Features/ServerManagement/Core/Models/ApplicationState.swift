//
//  ApplicationState.swift
//  Velo
//
//  Runtime state for an application in the unified detail view.
//

import Foundation
import Combine

/// Holds the runtime state of an application
@MainActor
final class ApplicationState: ObservableObject {
    // Service State
    @Published var isRunning: Bool = false
    @Published var version: String = ""
    @Published var binaryPath: String = ""
    @Published var configPath: String = ""
    @Published var activeVersion: String = ""
    @Published var installedVersions: [String] = []

    // Configuration State
    @Published var configValues: [SharedConfigValue] = []
    @Published var configFileContent: String = ""

    // Logs State
    @Published var logContent: String = ""
    @Published var availableLogFiles: [String] = []
    @Published var selectedLogFile: String = ""

    // Module/Extension State
    @Published var modules: [String] = []
    @Published var configureArguments: [String] = []

    // Extension State (PHP)
    @Published var extensions: [PHPExtensionInfo] = []
    @Published var availableExtensions: [String] = []
    @Published var disabledFunctions: [String] = []

    // FPM State (PHP)
    @Published var fpmStatus: PHPFPMStatus?
    @Published var fpmProfileContent: String = ""

    // PHP Info State
    @Published var phpInfoHTML: String = ""
    @Published var phpInfoData: [String: String] = [:]

    // Database State
    @Published var databases: [DatabaseInfo] = []
    @Published var users: [DatabaseUser] = []

    // MySQL specific (uses existing MySQLStatusInfo)
    @Published var mysqlStatus: MySQLStatusInfo?

    // Nginx specific (uses existing NginxStatusInfo)
    @Published var nginxStatus: NginxStatusInfo?
    @Published var securityRulesStatus: [String: Bool] = [:]
    @Published var securityStats: (total: String, last24h: String) = ("0", "0")

    // Version Installation
    @Published var availableVersions: [CapabilityVersion] = []
    @Published var isInstallingVersion: Bool = false
    @Published var installingVersionName: String = ""
    @Published var installStatus: String = ""

    // Reset all state
    func reset() {
        isRunning = false
        version = ""
        binaryPath = ""
        configPath = ""
        activeVersion = ""
        installedVersions = []
        configValues = []
        configFileContent = ""
        logContent = ""
        availableLogFiles = []
        selectedLogFile = ""
        modules = []
        configureArguments = []
        extensions = []
        availableExtensions = []
        disabledFunctions = []
        fpmStatus = nil
        fpmProfileContent = ""
        phpInfoHTML = ""
        phpInfoData = [:]
        databases = []
        users = []
        mysqlStatus = nil
        nginxStatus = nil
        securityRulesStatus = [:]
        securityStats = ("0", "0")
        availableVersions = []
        isInstallingVersion = false
        installingVersionName = ""
        installStatus = ""
    }
}

// MARK: - Supporting Types (only types not defined elsewhere)

/// Information about a PHP extension
struct PHPExtensionInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let version: String?
    let isLoaded: Bool

    init(name: String, version: String? = nil, isLoaded: Bool = true) {
        self.id = name
        self.name = name
        self.version = version
        self.isLoaded = isLoaded
    }
}

/// PHP FPM status information
struct PHPFPMStatus: Hashable {
    let pool: String
    let processManager: String
    let startTime: String
    let activeProcesses: Int
    let idleProcesses: Int
    let totalProcesses: Int
    let maxActiveProcesses: Int
    let acceptedConnections: Int
}

/// Database information (for unified database list)
struct DatabaseInfo: Identifiable, Hashable {
    let id: String
    let name: String
    let size: String
    let tableCount: Int

    init(name: String, size: String = "", tableCount: Int = 0) {
        self.id = name
        self.name = name
        self.size = size
        self.tableCount = tableCount
    }
}
