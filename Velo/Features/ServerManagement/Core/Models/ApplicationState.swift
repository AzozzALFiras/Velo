//
//  ApplicationState.swift
//  Velo
//
//  Runtime state for an application in the unified detail view.
//

import Foundation
import Combine

/// Comprehensive lifecycle state for applications
enum ApplicationLifecycleState: Equatable {
    case notInstalled
    case installing(progress: Double, phase: InstallPhase)
    case installed(version: String)
    case multipleVersionsInstalled(versions: [String], active: String?)
    case running(version: String)
    case stopped(version: String)
    case broken(reason: String)

    var isActionable: Bool {
        switch self {
        case .installing:
            return false
        default:
            return true
        }
    }

    var displayText: String {
        switch self {
        case .notInstalled:
            return "Not Installed"
        case .installing(let progress, let phase):
            return "Installing (\(Int(progress * 100))%)"
        case .installed(let version):
            return "Installed: \(version)"
        case .multipleVersionsInstalled(let versions, let active):
            return "Installed: \(versions.count) versions" + (active.map { " (Active: \($0))" } ?? "")
        case .running(let version):
            return "Running: \(version)"
        case .stopped(let version):
            return "Stopped: \(version)"
        case .broken(let reason):
            return "Error: \(reason)"
        }
    }
}

/// Holds the runtime state of an application
@MainActor
final class ApplicationState: ObservableObject {
    // Lifecycle State (New)
    @Published var lifecycleState: ApplicationLifecycleState = .notInstalled

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
    
    // Error Pages
    @Published var errorPages: [String: String] = [:]
    
    // WAF Logs
    @Published var wafLogs: [WafLogEntry] = []
    @Published var wafSites: [String] = [] // List of available sites
    @Published var currentWafSite: String = "All"

    // Version Installation
    @Published var availableVersions: [CapabilityVersion] = []
    @Published var isInstallingVersion: Bool = false
    @Published var installingVersionName: String = ""
    @Published var installStatus: String = ""

    // Reset all state
    func reset() {
        lifecycleState = .notInstalled
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
struct WafLogEntry: Identifiable, Hashable, Codable {
    let id = UUID()
    let ip: String
    let time: String
    let request: String
    let status: String
    let bytes: String
    let referrer: String
    let userAgent: String
    let country: String // Placeholder or GeoIP
}
