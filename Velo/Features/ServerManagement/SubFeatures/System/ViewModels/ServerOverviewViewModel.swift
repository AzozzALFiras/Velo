//
//  ServerOverviewViewModel.swift
//  Velo
//
//  ViewModel for server overview/dashboard displaying system stats, uptime, and basic status.
//  Handles live updates for CPU, RAM, and disk usage.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class ServerOverviewViewModel: ObservableObject {

    // MARK: - Dependencies
    weak var session: TerminalViewModel?
    private let statsService = SystemStatsService.shared
    private let nginxService = NginxService.shared
    private let apacheService = ApacheService.shared
    private let phpService = PHPService.shared
    private let mysqlService = MySQLService.shared
    private let postgresService = PostgreSQLService.shared
    private let nodeService = NodeService.shared
    private let pythonService = PythonService.shared
    private let gitService = GitService.shared

    // MARK: - Published State

    // System Info
    @Published var hostname: String = "Loading..."
    @Published var ipAddress: String = "..."
    @Published var osName: String = "..."
    @Published var uptime: String = "..."

    // Resource Usage (0-100 percent)
    @Published var cpuUsage: Int = 0
    @Published var ramUsage: Int = 0
    @Published var diskUsage: Int = 0

    // Resource Details
    @Published var ramTotalMB: Int = 0
    @Published var ramUsedMB: Int = 0
    @Published var diskTotal: String = "0"
    @Published var diskUsed: String = "0"
    @Published var diskAvailable: String = "0"

    // Resource / Hardware Stats
    @Published var currentStats = ServerStats()
    
    // Software Status
    @Published var serverStatus = ServerStatus()
    @Published var installedSoftware: [InstalledSoftware] = []

    // Loading States
    @Published var isLoading = false
    @Published var isLoadingStats = false
    @Published var isLoadingStatus = false
    @Published var isLiveUpdating = false
    @Published var dataLoadedOnce = false

    // History for charts
    @Published var cpuHistory: [HistoryPoint] = []
    @Published var ramHistory: [HistoryPoint] = []
    @Published var trafficHistory: [TrafficPoint] = []

    struct HistoryPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    // Task management
    private var liveUpdateTask: Task<Void, Never>?
    private let maxHistoryPoints = 20

    // MARK: - Init

    init(session: TerminalViewModel? = nil) {
        self.session = session
    }

    // MARK: - Data Loading

    /// Load all overview data
    func loadData() async {
        guard let session = session else { return }

        isLoading = true

        // Load stats and status in parallel
        async let statsTask: () = fetchStats()
        async let statusTask: () = fetchServerStatus()

        await statsTask
        await statusTask

        dataLoadedOnce = true
        isLoading = false
    }

    /// Fetch system statistics
    func fetchStats() async {
        guard let session = session else { return }

        isLoadingStats = true

        let stats = await statsService.fetchAllStats(via: session)
        currentStats = stats

        hostname = stats.hostname.isEmpty ? "Unknown" : stats.hostname
        ipAddress = stats.ipAddress.isEmpty ? "Unknown" : stats.ipAddress
        osName = stats.osName.isEmpty ? "Unknown" : stats.osName
        uptime = stats.uptime.isEmpty ? "Unknown" : stats.uptime

        cpuUsage = Int(stats.cpuUsage * 100)
        ramUsage = Int(stats.ramUsage * 100)
        diskUsage = Int(stats.diskUsage * 100)

        ramTotalMB = stats.ramTotalMB
        ramUsedMB = stats.ramUsedMB
        diskTotal = stats.diskTotal
        diskUsed = stats.diskUsed
        diskAvailable = stats.diskAvailable

        // Add to history
        addHistoryPoint(cpu: stats.cpuUsage, ram: stats.ramUsage)

        isLoadingStats = false
    }

    /// Fetch server software status
    func fetchServerStatus() async {
        guard let session = session else { return }
        
        AppLogger.shared.log("Analyzing server software status...", level: .info)
        isLoadingStatus = true

        // Fetch status from individual services in parallel
        async let nginxStatus = nginxService.getStatus(via: session)
        async let apacheStatus = apacheService.getStatus(via: session)
        async let phpStatus = phpService.getStatus(via: session)
        async let mysqlStatus = mysqlService.getStatus(via: session)
        async let pgStatus = postgresService.getStatus(via: session)
        async let nodeStatus = nodeService.getStatus(via: session)
        async let npmStatus = nodeService.getNPMStatus(via: session)
        async let pythonStatus = pythonService.getStatus(via: session)
        async let gitStatus = gitService.getStatus(via: session)
        async let composerStatus = phpService.getComposerStatus(via: session)

        let statusResult = await (nginxStatus, apacheStatus, phpStatus, mysqlStatus, pgStatus, nodeStatus, npmStatus, pythonStatus, gitStatus, composerStatus)
        
        var status = ServerStatus()
        status.nginx = statusResult.0
        status.apache = statusResult.1
        status.php = statusResult.2
        status.mysql = statusResult.3
        status.postgresql = statusResult.4
        status.nodejs = statusResult.5
        status.npm = statusResult.6
        status.python = statusResult.7
        status.git = statusResult.8
        status.composer = statusResult.9

        serverStatus = status
        updateInstalledSoftwareFromStatus()
        
        // MARK: - FIX: Add detailed logging for debugging detection issues
        let detected = installedSoftware.map { "\($0.name) (\($0.version ?? "N/A"))" }.joined(separator: ", ")
        AppLogger.shared.log("Software analysis complete. Detected: \(detected.isEmpty ? "None" : detected)", level: .result)
        
        if !serverStatus.hasWebServer {
            AppLogger.shared.log("⚠️ No web server detected. Ensure Nginx or Apache is installed and in PATH.", level: .warning)
        }

        isLoadingStatus = false
    }

    /// Refresh stats only (for quick updates)
    func refreshStats() async {
        guard let session = session else { return }

        let (cpu, ram, disk) = await statsService.fetchQuickStats(via: session)

        cpuUsage = Int(cpu * 100)
        ramUsage = Int(ram * 100)
        diskUsage = Int(disk * 100)

        addHistoryPoint(cpu: cpu, ram: ram)
    }

    // MARK: - Live Updates

    /// Start periodic stats refresh
    func startLiveUpdates() {
        guard !isLiveUpdating else { return }
        isLiveUpdating = true

        liveUpdateTask = Task { @MainActor in
            while !Task.isCancelled && isLiveUpdating {
                guard session != nil else { break }

                await refreshStats()

                try? await Task.sleep(nanoseconds: 15_000_000_000) // 15 seconds
            }
            isLiveUpdating = false
        }
    }

    /// Stop live updates
    func stopLiveUpdates() {
        isLiveUpdating = false
        liveUpdateTask?.cancel()
        liveUpdateTask = nil
    }

    // MARK: - Computed Properties

    var hasWebServer: Bool {
        serverStatus.hasWebServer
    }

    var hasDatabase: Bool {
        serverStatus.hasDatabase
    }

    var hasRuntime: Bool {
        serverStatus.hasRuntime
    }

    var ramFormatted: String {
        "\(ramUsedMB) MB / \(ramTotalMB) MB"
    }

    var diskFormatted: String {
        "\(diskUsed) / \(diskTotal)"
    }

    // MARK: - Private Helpers

    private func addHistoryPoint(cpu: Double, ram: Double) {
        let now = Date()
        cpuHistory.append(HistoryPoint(date: now, value: cpu))
        ramHistory.append(HistoryPoint(date: now, value: ram))

        if cpuHistory.count > maxHistoryPoints { cpuHistory.removeFirst() }
        if ramHistory.count > maxHistoryPoints { ramHistory.removeFirst() }
    }

    private func updateInstalledSoftwareFromStatus() {
        var software: [InstalledSoftware] = []

        // Web Servers
        if let v = serverStatus.nginx.version {
            software.append(InstalledSoftware(name: "Nginx", version: v, iconName: "nginx", isRunning: serverStatus.nginx.isRunning))
        }
        if let v = serverStatus.apache.version {
            software.append(InstalledSoftware(name: "Apache", version: v, iconName: "apache", isRunning: serverStatus.apache.isRunning))
        }

        // Databases
        if let v = serverStatus.mysql.version {
            software.append(InstalledSoftware(name: "MySQL", version: v, iconName: "mysql", isRunning: serverStatus.mysql.isRunning))
        }
        if let v = serverStatus.mariadb.version {
            software.append(InstalledSoftware(name: "MariaDB", version: v, iconName: "mariadb", isRunning: serverStatus.mariadb.isRunning))
        }
        if let v = serverStatus.postgresql.version {
            software.append(InstalledSoftware(name: "PostgreSQL", version: v, iconName: "postgresql", isRunning: serverStatus.postgresql.isRunning))
        }
        if let v = serverStatus.redis.version {
            software.append(InstalledSoftware(name: "Redis", version: v, iconName: "redis", isRunning: serverStatus.redis.isRunning))
        }

        // Runtimes
        if let v = serverStatus.php.version {
            software.append(InstalledSoftware(name: "PHP", version: v, iconName: "php", isRunning: serverStatus.php.isRunning))
        }
        if let v = serverStatus.python.version {
            software.append(InstalledSoftware(name: "Python", version: v, iconName: "python", isRunning: false))
        }
        if let v = serverStatus.nodejs.version {
            software.append(InstalledSoftware(name: "Node.js", version: v, iconName: "nodejs", isRunning: false))
        }

        // Tools
        if let v = serverStatus.git.version {
            software.append(InstalledSoftware(name: "Git", version: v, iconName: "git-scm", isRunning: false))
        }

        installedSoftware = software
    }
}
