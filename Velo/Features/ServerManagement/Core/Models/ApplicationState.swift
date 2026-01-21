//
//  ApplicationState.swift
//  Velo
//
//  Runtime state for an application in the unified detail view.
//

import Foundation

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

    // MySQL specific
    @Published var mysqlStatus: MySQLStatusInfo?

    // Nginx specific
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

// MARK: - Supporting Types

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

/// Database information
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

/// Database user information
struct DatabaseUser: Identifiable, Hashable {
    let id: String
    let username: String
    let host: String
    let privileges: [String]

    init(username: String, host: String = "localhost", privileges: [String] = []) {
        self.id = "\(username)@\(host)"
        self.username = username
        self.host = host
        self.privileges = privileges
    }
}

/// MySQL status info - placeholder if not already defined
struct MySQLStatusInfo: Hashable {
    let uptime: String
    let threads: Int
    let questions: Int
    let slowQueries: Int
    let opens: Int
    let flushTables: Int
    let openTables: Int
    let queriesPerSecond: Double
}

/// Nginx status info - placeholder if not already defined
struct NginxStatusInfo: Hashable {
    let activeConnections: Int
    let accepts: Int
    let handled: Int
    let requests: Int
    let reading: Int
    let writing: Int
    let waiting: Int
}
