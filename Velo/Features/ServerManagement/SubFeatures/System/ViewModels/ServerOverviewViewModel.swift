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
    private let redisService = RedisService.shared
    private let nodeService = NodeService.shared
    private let pythonService = PythonService.shared
    private let gitService = GitService.shared
    private let apiService = ApiService.shared

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
    
    // Capabilities for dynamic slugs
    private var capabilities: [Capability] = []

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
        
        // Fetch capabilities first for accurate slugs
        await fetchCapabilities()

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
    
    /// Fetch available capabilities for dynamic slugs
    func fetchCapabilities() async {
        do {
            capabilities = try await apiService.fetchCapabilities()
        } catch {
            print("Failed to fetch capabilities: \(error)")
        }
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
        async let redisStatus = redisService.getStatus(via: session)
        
        async let nodeStatus = nodeService.getStatus(via: session)
        async let npmStatus = nodeService.getNPMStatus(via: session)
        async let pythonStatus = pythonService.getStatus(via: session)
        async let gitStatus = gitService.getStatus(via: session)
        async let composerStatus = phpService.getComposerStatus(via: session)

        // Web & DB
        let (n, a, p, m, pg, r) = await (nginxStatus, apacheStatus, phpStatus, mysqlStatus, pgStatus, redisStatus)
        // Runtimes & Tools
        let (nd, np, py, g, c) = await (nodeStatus, npmStatus, pythonStatus, gitStatus, composerStatus)
        
        var status = ServerStatus()
        status.nginx = n
        status.apache = a
        status.php = p
        status.mysql = m
        status.postgresql = pg
        status.redis = r
        status.nodejs = nd
        status.npm = np
        status.python = py
        status.git = g
        status.composer = c

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

    private func resolveCapability(key: String) -> Capability? {
        capabilities.first { $0.slug.lowercased() == key.lowercased() || $0.name.lowercased() == key.lowercased() }
    }

    private func updateInstalledSoftwareFromStatus() {
        var software: [InstalledSoftware] = []

        // Helper to add software using API data if available
        func addSoftware(key: String, version: String?, defaultName: String, isRunning: Bool) {
            guard let version = version else { return }
            let cap = resolveCapability(key: key)
            
            software.append(InstalledSoftware(
                name: cap?.name ?? defaultName,
                slug: cap?.slug ?? key.lowercased(),
                version: version,
                iconName: cap?.icon ?? "", // Strictly use API icon or empty
                isRunning: isRunning
            ))
        }

        // Web Servers
        addSoftware(key: "nginx", version: serverStatus.nginx.version, defaultName: "Nginx", isRunning: serverStatus.nginx.isRunning)
        addSoftware(key: "apache", version: serverStatus.apache.version, defaultName: "Apache", isRunning: serverStatus.apache.isRunning)

        // Databases
        addSoftware(key: "mysql", version: serverStatus.mysql.version, defaultName: "MySQL", isRunning: serverStatus.mysql.isRunning)
        addSoftware(key: "mariadb", version: serverStatus.mariadb.version, defaultName: "MariaDB", isRunning: serverStatus.mariadb.isRunning)
        // PostgreSQL slug in API is "postgres", so we search by that key
        addSoftware(key: "postgres", version: serverStatus.postgresql.version, defaultName: "PostgreSQL", isRunning: serverStatus.postgresql.isRunning)
        addSoftware(key: "redis", version: serverStatus.redis.version, defaultName: "Redis", isRunning: serverStatus.redis.isRunning)

        // Runtimes
        addSoftware(key: "php", version: serverStatus.php.version, defaultName: "PHP", isRunning: serverStatus.php.isRunning)
        addSoftware(key: "python", version: serverStatus.python.version, defaultName: "Python", isRunning: false)
        // Node.js slug in API is "node", name is "Node.js". Searching by "node" finds it.
        addSoftware(key: "node", version: serverStatus.nodejs.version, defaultName: "Node.js", isRunning: false)

        // Tools
        addSoftware(key: "git", version: serverStatus.git.version, defaultName: "Git", isRunning: false)
        // Composer
        addSoftware(key: "composer", version: serverStatus.composer.version, defaultName: "Composer", isRunning: false)

        installedSoftware = software
    }
}
