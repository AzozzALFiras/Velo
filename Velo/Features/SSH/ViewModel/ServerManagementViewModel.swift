//
//  ServerManagementViewModel.swift
//  Velo
//
//  ViewModel for the Server Management UI
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class ServerManagementViewModel: ObservableObject {
    
    // MARK: - Dependencies
    weak var session: TerminalViewModel?
    private let sshService = SSHServerCommandService.shared
    
    // MARK: - Published State
    @Published var stats: ServerStats
    @Published var websites: [Website]
    @Published var databases: [Database]
    @Published var installedSoftware: [InstalledSoftware]
    @Published var trafficHistory: [TrafficPoint]
    @Published var overviewCounts: OverviewCounts
    @Published var files: [ServerFileItem] = []
    @Published var currentPath: String = "/"
    @Published var pathStack: [String] = ["/"]
    @Published var activeUploads: [FileUploadTask] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    // MARK: - Loading States
    @Published var isLoadingStats = false
    @Published var isLoadingPackages = false
    @Published var isLoadingWebsites = false
    @Published var isLoadingDatabases = false
    @Published var isLoadingServerStatus = false
    @Published var dataLoadedOnce = false
    
    // MARK: - Server Software Status
    @Published var serverStatus = ServerStatus()
    
    // MARK: - Capabilities & Installation State
    @Published var availableCapabilities: [Capability] = []
    @Published var searchQuery: String = ""
    @Published var isInstalling: Bool = false
    @Published var installLog: String = ""
    @Published var installProgress: Double = 0.0
    @Published var showInstallOverlay: Bool = false
    @Published var currentInstallingCapability: String?
    
    var filteredCapabilities: [Capability] {
        if searchQuery.isEmpty {
            return availableCapabilities
        }
        return availableCapabilities.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
    }
    
    // MARK: - Server Info for Settings
    @Published var serverHostname = "Loading..."
    @Published var serverIP = "..."
    @Published var serverOS = "..." 
    @Published var serverUptime = "..."
    @Published var cpuUsage = 0
    @Published var ramUsage = 0
    @Published var diskUsage = 0
    @Published var isLiveUpdating = false
    
    // Task management
    private var refreshTask: Task<Void, Never>?
    private var lastManualRefresh: Date?
    private let refreshCooldown: TimeInterval = 3.0
    
    // Legacy Chart History
    @Published var cpuHistory: [ServerManagementViewModel.HistoryPoint] = []
    @Published var ramHistory: [ServerManagementViewModel.HistoryPoint] = []
    
    // Chart History
    struct HistoryPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }
    
    // MARK: - Logging
    private func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        print("[\(timestamp)] [ServerMgmt] \(message)")
    }
    
    // MARK: - Init
    init(session: TerminalViewModel? = nil) {
        self.session = session
        
        // Initialize with empty/placeholder data
        self.stats = ServerStats(
            cpuUsage: 0, ramUsage: 0, diskUsage: 0,
            uptime: 0, isOnline: true,
            osName: "Loading...", ipAddress: "..."
        )
        self.websites = []
        self.databases = []
        self.installedSoftware = []
        self.trafficHistory = []
        self.overviewCounts = OverviewCounts(sites: 0, ftp: 0, databases: 0, security: 0)
        self.files = []
        
        log("ViewModel initialized with session: \(session != nil ? "YES" : "NO")")
        
        // Fetch Capabilities from API
        Task {
            await fetchCapabilities()
        }
    }
    
    // MARK: - Load All Real Data
    func loadAllData() async {
        guard let session = session else {
            log("❌ No SSH session available")
            return
        }
        
        guard !dataLoadedOnce else {
            log("Data already loaded, skipping...")
            return
        }
        
        log("🚀 Loading all server data...")
        isLoading = true
        
        // STEP 1: Load server status FIRST (sequential, no parallel execution)
        log("📌 Step 1: Checking server software status...")
        isLoadingServerStatus = true
        serverStatus = await sshService.fetchServerStatus(via: session)
        isLoadingServerStatus = false
        
        // STEP 2: Load other data based on what's installed
        log("📌 Step 2: Loading server data...")
        
        // Fetch stats (always)
        await fetchRealServerStats()
        
        // Fetch websites ONLY if web server is installed
        if serverStatus.hasWebServer {
            await fetchRealWebsites()
        } else {
            log("⚠️ No web server installed, skipping websites fetch")
            websites = []
        }
        
        // Fetch databases ONLY if DB is installed
        if serverStatus.hasDatabase {
            await fetchRealDatabases()
        } else {
            log("⚠️ No database installed, skipping databases fetch")
            databases = []
        }
        
        // Fetch files (always)
        await fetchRealFiles(at: currentPath)
        
        // Update installed software from server status
        updateInstalledSoftwareFromStatus()
        
        dataLoadedOnce = true
        isLoading = false
        log("✅ All data loaded successfully")
        
        // Start periodic refresh
        startLiveUpdates()
    }
    
    // MARK: - Refresh Actions
    
    func refreshServerStatus() async {
        guard let session = session else { 
            log("❌ No session available for server status refresh")
            return 
        }
        
        // Skip if installation is in progress
        guard !isInstalling else {
            log("⏸️ Skipping refresh - installation in progress")
            return
        }
        
        log("🔄 Refreshing server status (optimized)...")
        isLoadingServerStatus = true
        serverStatus = await sshService.fetchServerStatusOptimized(via: session)
        isLoadingServerStatus = false
        updateInstalledSoftwareFromStatus()
        
        // Debug: Print full server status
        printServerStatus()
    }
    
    /// Debug helper: Print current server status to console
    func printServerStatus() {
        print("📊 ========== SERVER STATUS ==========")
        print("📊 Web Servers:")
        print("📊   Nginx: \(serverStatus.nginx) - isInstalled: \(serverStatus.nginx.isInstalled)")
        print("📊   Apache: \(serverStatus.apache) - isInstalled: \(serverStatus.apache.isInstalled)")
        print("📊   LiteSpeed: \(serverStatus.litespeed) - isInstalled: \(serverStatus.litespeed.isInstalled)")
        print("📊 Databases:")
        print("📊   MySQL: \(serverStatus.mysql) - isInstalled: \(serverStatus.mysql.isInstalled)")
        print("📊   MariaDB: \(serverStatus.mariadb) - isInstalled: \(serverStatus.mariadb.isInstalled)")
        print("📊   PostgreSQL: \(serverStatus.postgresql) - isInstalled: \(serverStatus.postgresql.isInstalled)")
        print("📊 Runtimes:")
        print("📊   PHP: \(serverStatus.php) - isInstalled: \(serverStatus.php.isInstalled)")
        print("📊   Node.js: \(serverStatus.nodejs) - isInstalled: \(serverStatus.nodejs.isInstalled)")
        print("📊   Python: \(serverStatus.python) - isInstalled: \(serverStatus.python.isInstalled)")
        print("📊 Computed:")
        print("📊   hasWebServer: \(serverStatus.hasWebServer)")
        print("📊   hasDatabase: \(serverStatus.hasDatabase)")
        print("📊   hasRuntime: \(serverStatus.hasRuntime)")
        print("📊 ======================================")
    }
    
    /// Update installedSoftware array from serverStatus
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
        log("📦 Updated installedSoftware: \(software.count) items")
    }
    
    // MARK: - Fetch Real Server Stats
    func fetchRealServerStats() async {
        guard let session = session else { return }
        
        log("Fetching real server stats...")
        isLoadingStats = true
        
        let parsedStats = await sshService.fetchServerStats(via: session)
        
        // Update published properties
        self.stats = ServerStats(
            cpuUsage: parsedStats.cpuUsage,
            ramUsage: parsedStats.ramUsage,
            diskUsage: parsedStats.diskUsage,
            uptime: 0, // We'll use uptime string instead
            isOnline: true,
            osName: parsedStats.osName,
            ipAddress: parsedStats.ipAddress
        )
        
        self.serverHostname = parsedStats.hostname
        self.serverIP = parsedStats.ipAddress
        self.serverOS = parsedStats.osName
        self.serverUptime = parsedStats.uptime
        self.cpuUsage = Int(parsedStats.cpuUsage * 100)
        self.ramUsage = Int(parsedStats.ramUsage * 100)
        self.diskUsage = Int(parsedStats.diskUsage * 100)
        
        // Add to history
        let now = Date()
        cpuHistory.append(HistoryPoint(date: now, value: parsedStats.cpuUsage))
        ramHistory.append(HistoryPoint(date: now, value: parsedStats.ramUsage))
        if cpuHistory.count > 20 { cpuHistory.removeFirst() }
        if ramHistory.count > 20 { ramHistory.removeFirst() }
        
        isLoadingStats = false
        log("Stats updated: CPU \(cpuUsage)%, RAM \(ramUsage)%, Disk \(diskUsage)%")
    }
    
    // MARK: - Fetch Real Installed Packages
    func fetchRealInstalledPackages() async {
        guard let session = session else { return }
        
        log("Fetching real installed packages...")
        isLoadingPackages = true
        
        let packages = await sshService.fetchInstalledSoftware(via: session)
        self.installedSoftware = packages
        
        // Update overview count
        self.overviewCounts.security = packages.count
        
        isLoadingPackages = false
        log("Found \(packages.count) installed packages")
    }
    
    // MARK: - Fetch Real Websites
    func fetchRealWebsites() async {
        guard let session = session else { return }
        
        log("Fetching real websites...")
        isLoadingWebsites = true
        
        var allSites: [Website] = []
        
        // Fetch from Nginx if installed
        if serverStatus.nginx.isInstalled {
            let nginxSites = await sshService.fetchNginxSites(via: session)
            allSites.append(contentsOf: nginxSites)
        }
        
        // Fetch from Apache if installed
        if serverStatus.apache.isInstalled {
            let apacheSites = await sshService.fetchApacheSites(via: session)
            allSites.append(contentsOf: apacheSites)
        }
        
        self.websites = allSites
        self.overviewCounts.sites = allSites.count
        
        isLoadingWebsites = false
        log("Found \(allSites.count) websites (nginx: \(serverStatus.nginx.isInstalled), apache: \(serverStatus.apache.isInstalled))")
    }
    
    // MARK: - Fetch Real Databases
    func fetchRealDatabases() async {
        guard let session = session else { return }
        
        log("Fetching real databases...")
        isLoadingDatabases = true
        
        var allDatabases: [Database] = []
        
        // Fetch from MySQL/MariaDB if installed
        if serverStatus.mysql.isInstalled || serverStatus.mariadb.isInstalled {
            let mysqlDbs = await sshService.fetchMySQLDatabases(via: session)
            allDatabases.append(contentsOf: mysqlDbs)
        }
        
        // Fetch from PostgreSQL if installed
        if serverStatus.postgresql.isInstalled {
            let pgDbs = await sshService.fetchPostgreSQLDatabases(via: session)
            allDatabases.append(contentsOf: pgDbs)
        }
        
        self.databases = allDatabases
        self.overviewCounts.databases = allDatabases.count
        
        isLoadingDatabases = false
        log("Found \(allDatabases.count) databases (mysql: \(serverStatus.mysql.isInstalled), pgsql: \(serverStatus.postgresql.isInstalled))")
    }
    
    // MARK: - Server Management Actions (Real SSH)

    func changeRootPassword(newPass: String) async -> Bool {
        guard let session = session else { return false }
        log("Changing root password...")
        return await sshService.changeRootPassword(newPassword: newPass, via: session)
    }

    func changeDBPassword(newPass: String) async -> Bool {
        guard let session = session else { return false }
        log("Changing MySQL root password...")
        return await sshService.changeMySQLRootPassword(newPassword: newPass, via: session)
    }

    func restartService(_ serviceName: String) async -> Bool {
        guard let session = session else { return false }
        log("Restarting \(serviceName)...")
        let success = await sshService.restartService(serviceName, via: session)
        if success {
            // Refresh server status to update UI
            await refreshServerStatus()
        }
        return success
    }

    func stopService(_ serviceName: String) async -> Bool {
        guard let session = session else { return false }
        log("Stopping \(serviceName)...")
        return await sshService.stopService(serviceName, via: session)
    }

    func startService(_ serviceName: String) async -> Bool {
        guard let session = session else { return false }
        log("Starting \(serviceName)...")
        return await sshService.startService(serviceName, via: session)
    }
    
    // MARK: - Capability Management
    
    func fetchCapabilities() async {
        do {
            let caps = try await ApiService.shared.fetchCapabilities()
            await MainActor.run {
                self.availableCapabilities = caps
            }
        } catch {
            print("Failed to fetch capabilities: \(error)")
        }
    }
    
    /// Install a capability by its slug (fetches details and uses default version)
    func installCapabilityBySlug(_ slug: String) {
        Task {
            await MainActor.run {
                self.showInstallOverlay = true
                self.isInstalling = true
                self.currentInstallingCapability = slug.capitalized
                self.installProgress = 0.0
                self.installLog = "> Fetching \(slug.capitalized) details...\n"
            }
            
            do {
                // Fetch capability details
                let capability = try await ApiService.shared.fetchCapabilityDetails(slug: slug)
                
                // Get default version or first available version
                guard let version = capability.defaultVersion?.version ?? capability.versions?.first?.version else {
                    await appendLog("❌ No versions available for \(slug)")
                    await MainActor.run {
                        self.isInstalling = false
                    }
                    return
                }
                
                await appendLog("> Installing \(capability.name) v\(version)...")
                await installCapability(capability, version: version)
            } catch {
                await appendLog("❌ Error: \(error.localizedDescription)")
                await MainActor.run {
                    self.isInstalling = false
                    self.showInstallOverlay = false
                }
            }
        }
    }
    
    /// Install a stack of capabilities sequentially (e.g., LEMP, LAMP)
    func installStack(_ slugs: [String]) {
        Task {
            await MainActor.run {
                self.showInstallOverlay = true
                self.isInstalling = true
                self.currentInstallingCapability = "Stack"
                self.installProgress = 0.0
                self.installLog = "> Installing stack: \(slugs.joined(separator: " + "))...\n"
            }

            let totalSteps = Double(slugs.count)

            for (index, slug) in slugs.enumerated() {
                let progress = Double(index) / totalSteps
                await MainActor.run {
                    self.installProgress = progress
                    self.currentInstallingCapability = slug.capitalized
                }

                await appendLog("\n> [\(index + 1)/\(slugs.count)] Installing \(slug.capitalized)...")

                do {
                    // Fetch capability details
                    let capability = try await ApiService.shared.fetchCapabilityDetails(slug: slug)

                    // Get default version or first available version
                    guard let version = capability.defaultVersion?.version ?? capability.versions?.first?.version else {
                        await appendLog("⚠️ No versions available for \(slug), skipping...")
                        continue
                    }

                    // Get version details for installation command
                    let versionDetails = try await ApiService.shared.fetchCapabilityVersion(slug: slug, version: version)

                    // Detect OS for installation command
                    let osType = await detectServerOS()

                    guard let installCommand = getInstallCommand(from: versionDetails, os: osType) else {
                        await appendLog("⚠️ No \(osType) installation for \(slug).")
                        continue
                    }

                    await appendLog("> Executing: \(installCommand)")
                    log("Executing real SSH installation: \(installCommand)")

                    // Execute installation
                    if let session = session {
                        _ = await sshService.installPackage(installCommand, via: session) { output in
                            Task { @MainActor in
                                self.installLog += output + "\n"
                            }
                        }
                        await appendLog("✅ \(capability.name) installed successfully")

                        // Enable and start the service immediately after installation
                        await appendLog("> Enabling and starting \(slug) service...")
                        await self.enableAndStartService(slug: slug, via: session)
                    }

                } catch {
                    await appendLog("❌ Failed to install \(slug): \(error.localizedDescription)")
                }
            }

            // Complete the stack installation - pass last slug for final refresh
            await MainActor.run {
                self.installProgress = 1.0
                self.installLog += "\n> Stack Installation Completed! ✅"
            }

            // Final completion triggers status refresh
            await completionForStack(success: true)
        }
    }

    /// Completion handler specifically for stack installation (refreshes status without enabling single service)
    @MainActor
    private func completionForStack(success: Bool) {
        self.isInstalling = false
        if success {
            log("✅ Stack installation completed successfully")
            print("📦 [StackInstall] Stack installation completed, refreshing status...")

            // Refresh server status to detect all newly installed software
            Task {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

                print("📦 [StackInstall] Waiting 1s before refreshing status...")
                log("🔄 Refreshing server status after stack installation...")
                
                if let session = self.session {
                    print("📦 [StackInstall] Fetching server status...")
                    let newStatus = await self.sshService.fetchServerStatusOptimized(via: session)
                    
                    print("📦 [StackInstall] New status received:")
                    print("📦 [StackInstall]   nginx: \(newStatus.nginx)")
                    print("📦 [StackInstall]   mysql: \(newStatus.mysql)")
                    print("📦 [StackInstall]   php: \(newStatus.php)")
                    print("📦 [StackInstall]   hasWebServer: \(newStatus.hasWebServer)")
                    
                    await MainActor.run {
                        self.serverStatus = newStatus
                        self.updateInstalledSoftwareFromStatus()
                        log("📌 Updated server status after stack install")
                        print("📦 [StackInstall] ✅ Server status updated!")
                        self.printServerStatus()
                    }
                } else {
                    print("📦 [StackInstall] ❌ No session available!")
                }

                await MainActor.run {
                    self.showInstallOverlay = false
                }
            }
        } else {
            self.installLog += "\n> Stack Installation Failed! ❌"
            log("❌ Stack installation failed")
        }
    }
    
    func installCapability(_ capability: Capability, version: String) async {
        await MainActor.run {
            self.showInstallOverlay = true
            self.isInstalling = true
            self.currentInstallingCapability = capability.name
            self.installProgress = 0.0
            self.installLog = "> Initializing installation for \(capability.name) v\(version)...\n"
        }

        do {
            // 1. Fetch Version Details
            await appendLog("> Fetching installation details from Velo API...")
            let versionDetail = try await ApiService.shared.fetchCapabilityVersion(slug: capability.slug, version: version)

            // 2. Detect OS
            await appendLog("> Detecting server OS...")
            let osType = detectServerOS()
            await appendLog("> Detected OS: \(osType)")

            // 3. Select Command
            guard let installCmd = getInstallCommand(from: versionDetail, os: osType) else {
                await appendLog("> Error: No installation instruction found for \(osType).")
                await completion(success: false)
                return
            }

            await appendLog("> Installation command prepared.")
            await appendLog("> Executing: \(installCmd)")

            // 4. Execute Command via real SSH
            try await executeRealInstallation(command: installCmd)

            // 5. Complete with slug so service can be enabled
            await completion(success: true, installedSlug: capability.slug)

            // 6. Refresh installed packages from server
            await fetchRealInstalledPackages()

        } catch {
            await appendLog("> Error: \(error.localizedDescription)")
            await completion(success: false)
        }
    }
    
    /// Execute real installation via SSH
    private func executeRealInstallation(command: String) async throws {
        guard let session = session else {
            throw NSError(domain: "ServerMgmt", code: 1, userInfo: [NSLocalizedDescriptionKey: "No SSH session"])
        }
        
        log("Executing real SSH installation: \(command)")
        
        // Use the SSH service to install with streaming output
        _ = await sshService.installPackage(command, via: session) { [weak self] output in
            Task { @MainActor in
                self?.installLog += output + "\n"
                // Update progress based on output patterns
                if output.contains("Unpacking") || output.contains("Setting up") {
                    self?.installProgress = min((self?.installProgress ?? 0) + 0.1, 0.9)
                }
            }
        }
    }
    
    private func detectServerOS() -> String {
        // Use real OS from fetched stats
        if serverOS.localizedCaseInsensitiveContains("ubuntu") { return "ubuntu" }
        if serverOS.localizedCaseInsensitiveContains("debian") { return "debian" }
        if serverOS.localizedCaseInsensitiveContains("centos") { return "centos" }
        if serverOS.localizedCaseInsensitiveContains("rhel") { return "rhel" }
        return "ubuntu" // Default
    }
    
    @MainActor
    private func appendLog(_ text: String) {
        self.installLog += "\(text)\n"
        log(text)
    }
    
    @MainActor
    private func completion(success: Bool, installedSlug: String? = nil) {
        self.isInstalling = false
        if success {
            self.installLog += "\n> Installation Completed Successfully! ✅"
            self.installProgress = 1.0
            log("✅ Installation completed successfully")

            // Enable and start services, then refresh status
            Task {
                // Short delay to ensure installation is fully complete
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

                // Enable and start the installed service
                if let slug = installedSlug, let session = self.session {
                    await MainActor.run {
                        self.installLog += "\n> Enabling and starting \(slug) service...\n"
                    }
                    await self.enableAndStartService(slug: slug, via: session)
                }

                // Refresh server status to detect newly installed software
                log("🔄 Refreshing server status after installation...")
                if let session = self.session {
                    let newStatus = await self.sshService.fetchServerStatusOptimized(via: session)
                    await MainActor.run {
                        self.serverStatus = newStatus
                        self.updateInstalledSoftwareFromStatus()
                        log("📌 Updated server status - nginx: \(newStatus.nginx), mysql: \(newStatus.mysql), php: \(newStatus.php)")
                    }
                }

                // Hide overlay after refresh
                await MainActor.run {
                    self.showInstallOverlay = false
                }
            }
        } else {
            self.installLog += "\n> Installation Failed! ❌"
            log("❌ Installation failed")
        }
    }

    /// Enable and start a service after installation
    private func enableAndStartService(slug: String, via session: TerminalViewModel) async {
        // Special handling for PHP since it has version-specific service names
        if slug.lowercased() == "php" || slug.lowercased() == "php-fpm" {
            await enablePHPFPMService(via: session)
            return
        }

        let serviceName = getServiceName(for: slug)

        guard !serviceName.isEmpty else {
            log("⚠️ No service to enable for \(slug) (tools like git, node, python don't need service activation)")
            await MainActor.run {
                self.installLog += "> ℹ️ \(slug) doesn't require a system service\n"
            }
            return
        }

        log("🔧 Enabling and starting service: \(serviceName)")

        // Enable the service to start on boot
        let enableResult = await sshService.executeCommand("sudo systemctl enable \(serviceName) 2>&1", via: session, timeout: 30)
        let enableOutput = enableResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
        await MainActor.run {
            self.installLog += "> systemctl enable \(serviceName): \(enableOutput.isEmpty ? "OK" : enableOutput)\n"
        }

        // Start the service
        let startResult = await sshService.executeCommand("sudo systemctl start \(serviceName) 2>&1", via: session, timeout: 30)
        let startOutput = startResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
        await MainActor.run {
            self.installLog += "> systemctl start \(serviceName): \(startOutput.isEmpty ? "OK" : startOutput)\n"
        }

        // Verify service is running
        let statusResult = await sshService.executeCommand("systemctl is-active \(serviceName) 2>/dev/null", via: session, timeout: 10)
        let isActive = statusResult.output.trimmingCharacters(in: .whitespacesAndNewlines) == "active"

        await MainActor.run {
            if isActive {
                self.installLog += "> ✅ \(serviceName) is now running\n"
            } else {
                self.installLog += "> ⚠️ \(serviceName) may not be running (status: \(statusResult.output.trimmingCharacters(in: .whitespacesAndNewlines)))\n"
            }
        }

        log(isActive ? "✅ Service \(serviceName) enabled and started" : "⚠️ Service \(serviceName) may have issues")
    }

    /// Map capability slug to systemd service name
    private func getServiceName(for slug: String) -> String {
        switch slug.lowercased() {
        case "nginx":
            return "nginx"
        case "apache", "apache2":
            return "apache2"
        case "mysql":
            return "mysql"
        case "mariadb":
            return "mariadb"
        case "postgresql", "postgres":
            return "postgresql"
        case "redis":
            return "redis-server"
        case "php", "php-fpm":
            // PHP-FPM service name varies by version - will be handled specially
            return "php-fpm"
        case "mongodb", "mongo":
            return "mongod"
        case "memcached":
            return "memcached"
        case "nodejs", "node":
            // Node.js doesn't have a system service
            return ""
        case "python", "python3":
            // Python doesn't have a system service
            return ""
        case "git":
            // Git doesn't have a system service
            return ""
        case "composer":
            // Composer doesn't have a system service
            return ""
        case "npm":
            // NPM doesn't have a system service
            return ""
        default:
            // For other services, try the slug as-is
            return slug
        }
    }

    /// Special handling for PHP-FPM service which has version-specific names
    private func enablePHPFPMService(via session: TerminalViewModel) async {
        log("🔧 Detecting and enabling PHP-FPM service...")

        // Try to find PHP-FPM service - check common version patterns
        let detectCmd = "systemctl list-units --type=service --all | grep -E 'php.*fpm' | head -1 | awk '{print $1}'"
        let result = await sshService.executeCommand(detectCmd, via: session, timeout: 15)
        let serviceName = result.output.trimmingCharacters(in: .whitespacesAndNewlines)

        if !serviceName.isEmpty && serviceName.contains("php") {
            log("Found PHP-FPM service: \(serviceName)")

            // Enable and start
            _ = await sshService.executeCommand("sudo systemctl enable \(serviceName) 2>&1", via: session, timeout: 30)
            _ = await sshService.executeCommand("sudo systemctl start \(serviceName) 2>&1", via: session, timeout: 30)

            let statusResult = await sshService.executeCommand("systemctl is-active \(serviceName) 2>/dev/null", via: session, timeout: 10)
            let isActive = statusResult.output.trimmingCharacters(in: .whitespacesAndNewlines) == "active"

            await MainActor.run {
                self.installLog += "> \(isActive ? "✅" : "⚠️") PHP-FPM (\(serviceName)): \(isActive ? "running" : "not running")\n"
            }
        } else {
            // Try common PHP-FPM service names
            let commonNames = ["php8.3-fpm", "php8.2-fpm", "php8.1-fpm", "php8.0-fpm", "php7.4-fpm", "php-fpm"]
            for name in commonNames {
                let checkResult = await sshService.executeCommand("systemctl list-units --type=service --all | grep '\(name)'", via: session, timeout: 10)
                if !checkResult.output.isEmpty {
                    _ = await sshService.executeCommand("sudo systemctl enable \(name) && sudo systemctl start \(name)", via: session, timeout: 30)
                    log("Enabled PHP-FPM service: \(name)")
                    await MainActor.run {
                        self.installLog += "> Enabled PHP-FPM: \(name)\n"
                    }
                    break
                }
            }
        }
    }
    
    // MARK: - Actions
    
    func refreshData() {
        log("🔄 Refreshing all data...")
        dataLoadedOnce = false // Allow reload
        Task {
            await loadAllData()
        }
    }
    
    // MARK: - File Operations
    
    func navigateTo(folder: ServerFileItem) {
        guard folder.isDirectory else { return }
        isLoading = true
        
        // In a real app, this would be an SSH command: cd folder.name && ls -la
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let newPath = self.currentPath == "/" ? "/\(folder.name)" : "\(self.currentPath)/\(folder.name)"
            self.currentPath = newPath
            self.pathStack.append(newPath)
            
            // Trigger real file fetch
            Task {
                await self.fetchRealFiles(at: newPath)
            }
        }
    }
    
    func navigateBack() {
        guard pathStack.count > 1 else { return }
        pathStack.removeLast()
        jumpToPath(pathStack.last ?? "/")
    }
    
    func jumpToPath(_ path: String) {
        // Update the current path and stack
        currentPath = path
        if let index = pathStack.firstIndex(of: path) {
            pathStack = Array(pathStack.prefix(through: index))
        } else {
            pathStack.append(path)
        }
        
        // Fetch files via SSH
        Task {
            await fetchRealFiles(at: path)
        }
    }
    
    // MARK: - Fetch Real Files
    func fetchRealFiles(at path: String) async {
        guard let session = session else {
            log("❌ No SSH session for file fetch")
            return
        }
        
        log("Fetching files at: \(path)")
        isLoading = true
        
        let fetchedFiles = await sshService.fetchFiles(at: path, via: session)
        self.files = fetchedFiles
        
        isLoading = false
        log("Loaded \(fetchedFiles.count) files")
    }
    
    /// Delete file with real SSH execution
    func deleteFile(_ file: ServerFileItem) async -> Bool {
        guard let session = session else { return false }

        log("Deleting file: \(file.name) at \(currentPath)")

        let success = await sshService.deleteFile(at: currentPath, name: file.name, isDirectory: file.isDirectory, via: session)

        if success {
            withAnimation {
                files.removeAll(where: { $0.id == file.id })
            }
            log("File \(file.name) deleted successfully")
        } else {
            log("Failed to delete file \(file.name)")
        }

        return success
    }

    /// Rename file with real SSH execution
    func renameFile(_ file: ServerFileItem, to newName: String) async -> Bool {
        guard let session = session else { return false }

        log("Renaming file: \(file.name) to \(newName)")

        let success = await sshService.renameFile(at: currentPath, from: file.name, to: newName, via: session)

        if success {
            if let index = files.firstIndex(where: { $0.id == file.id }) {
                files[index].name = newName
            }
            log("File renamed successfully")
        } else {
            log("Failed to rename file")
        }

        return success
    }

    func downloadFile(_ file: ServerFileItem) {
        // TODO: Implement SFTP download when SFTP support is added
        // For now, we log the action
        log("Download requested for: \(file.name)")
        print("Downloading \(file.name)...")
    }

    /// Update file permissions with real SSH execution
    func updatePermissions(_ file: ServerFileItem, to newPerms: String) async -> Bool {
        guard let session = session else { return false }

        log("Updating permissions for \(file.name) to \(newPerms)")

        let success = await sshService.changePermissions(at: currentPath, name: file.name, permissions: newPerms, via: session)

        if success {
            if let index = files.firstIndex(where: { $0.id == file.id }) {
                withAnimation {
                    files[index].permissions = newPerms
                }
            }
            log("Permissions updated successfully")
        } else {
            log("Failed to update permissions")
        }

        return success
    }

    /// Update file owner with real SSH execution
    func updateOwner(_ file: ServerFileItem, to newOwner: String) async -> Bool {
        guard let session = session else { return false }

        log("Updating owner for \(file.name) to \(newOwner)")

        let success = await sshService.changeOwner(at: currentPath, name: file.name, owner: newOwner, via: session)

        if success {
            if let index = files.firstIndex(where: { $0.id == file.id }) {
                withAnimation {
                    files[index].owner = newOwner
                }
            }
            log("Owner updated successfully")
        } else {
            log("Failed to update owner")
        }

        return success
    }

    /// Create new directory with real SSH execution
    func createDirectory(named name: String) async -> Bool {
        guard let session = session else { return false }

        log("Creating directory: \(name) at \(currentPath)")

        let success = await sshService.createDirectory(at: currentPath, name: name, via: session)

        if success {
            // Refresh file list
            await fetchRealFiles(at: currentPath)
            log("Directory created successfully")
        } else {
            log("Failed to create directory")
        }

        return success
    }
    
    func startMockUpload(fileName: String) {
        var task = FileUploadTask(fileName: fileName, progress: 0.0)
        activeUploads.append(task)
        let taskId = task.id
        
        // Simulate progress
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            guard let index = self.activeUploads.firstIndex(where: { $0.id == taskId }) else {
                timer.invalidate()
                return
            }
            
            if self.activeUploads[index].progress < 1.0 {
                self.activeUploads[index].progress = min(1.0, self.activeUploads[index].progress + Double.random(in: 0.05...0.15))
            } else {
                self.activeUploads[index].isCompleted = true
                timer.invalidate()
                
                // Add the uploaded file to the list after 1s
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.files.insert(ServerFileItem(name: fileName, isDirectory: false, sizeBytes: 15420, permissions: "-rw-r--r--", modificationDate: Date(), owner: "root"), at: 0)
                    // Clear the task after 2s
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.activeUploads.removeAll(where: { $0.id == taskId })
                    }
                }
            }
        }
    }
    
    // MARK: - Website Management (Real SSH)

    func addWebsite(_ website: Website) {
        if !websites.contains(where: { $0.id == website.id }) {
            websites.insert(website, at: 0)
            overviewCounts.sites = websites.count
            log("Website \(website.domain) added to UI.")
        }
    }

    /// Create a real website on the server with full web server configuration
    func createRealWebsite(domain: String, path: String, framework: String, port: Int) async throws {
        guard let session = session else {
            throw NSError(domain: "ServerMgmt", code: 1, userInfo: [NSLocalizedDescriptionKey: "No SSH session"])
        }

        print("🌐 [CreateWebsite] Starting website creation...")
        print("🌐 [CreateWebsite] Input: domain=\(domain), path=\(path), framework=\(framework), port=\(port)")
        
        // Validate and sanitize inputs
        let safeDomain = domain.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var safePath = path.trimmingCharacters(in: .whitespacesAndNewlines)

        // Auto-generate path if empty or invalid
        if safePath.isEmpty || safePath == "/var/www" {
            safePath = "/var/www/\(safeDomain.replacingOccurrences(of: ".", with: "_"))"
        }

        // Ensure path starts with /
        if !safePath.hasPrefix("/") {
            safePath = "/\(safePath)"
        }

        print("🌐 [CreateWebsite] Sanitized: domain=\(safeDomain), path=\(safePath)")
        log("Creating website: domain=\(safeDomain), path=\(safePath), framework=\(framework)")

        // Detect if we are root
        let whoami = await SSHBaseService.shared.execute("whoami", via: session)
        let isRoot = whoami.output.trimmingCharacters(in: .whitespacesAndNewlines) == "root"
        let sudoPrefix = isRoot ? "" : "sudo "
        print("🌐 [CreateWebsite] Acting as root: \(isRoot)")
        
        // Use the new high-speed website service
        isLoading = true
        let success = await SSHWebsiteService.shared.createWebsite(
            domain: safeDomain, 
            path: safePath, 
            framework: framework, 
            port: port, 
            phpVersion: nil, 
            via: session
        )

        // The new website service already handled directory creation, chown, chmod and index file
        // We can jump straight to web server configuration
        if !success {
            log("⚠️ Specialized website creation script failed, attempting fallback configuration...")
        }
        
        // 3. Create web server configuration
        var webServerUsed = "Static"

        // Determine PHP version if needed
        var phpVersion: String? = nil
        if framework.lowercased().contains("php") {
            print("🌐 [CreateWebsite] Step 3a: Detecting PHP-FPM versions...")
            // Get installed PHP versions and use the first one
            let phpVersions = await sshService.fetchInstalledPHPVersions(via: session)
            print("🌐 [CreateWebsite] Found PHP versions: \(phpVersions)")
            phpVersion = phpVersions.first ?? serverStatus.php.version
            print("🌐 [CreateWebsite] Using PHP version: \(phpVersion ?? "none")")
        }

        // Create Nginx or Apache config based on what's installed
        print("🌐 [CreateWebsite] Step 3b: Creating web server config...")
        print("🌐 [CreateWebsite] nginx.isInstalled=\(serverStatus.nginx.isInstalled), apache.isInstalled=\(serverStatus.apache.isInstalled)")
        
        if serverStatus.nginx.isInstalled {
            print("🌐 [CreateWebsite] Creating Nginx site config...")
            let success = await sshService.createNginxSite(domain: safeDomain, path: safePath, port: port, phpVersion: phpVersion, via: session)
            if success {
                webServerUsed = "Nginx"
                print("🌐 [CreateWebsite] ✅ Nginx site created successfully")
                log("✅ Nginx site created")
                
                // Verify Nginx config
                let verifyConfig = await sshService.executeCommand("ls -la /etc/nginx/sites-available/\(safeDomain) /etc/nginx/sites-enabled/\(safeDomain) 2>&1", via: session)
                print("🌐 [CreateWebsite] Nginx config files: \(verifyConfig.output)")
            } else {
                print("🌐 [CreateWebsite] ❌ Nginx config failed!")
                log("⚠️ Nginx config failed, site may not work properly")
            }
        } else if serverStatus.apache.isInstalled {
            print("🌐 [CreateWebsite] Creating Apache site config...")
            let success = await sshService.createApacheSite(domain: safeDomain, path: safePath, port: port, via: session)
            if success {
                webServerUsed = "Apache"
                print("🌐 [CreateWebsite] ✅ Apache site created successfully")
                log("✅ Apache site created")
            } else {
                print("🌐 [CreateWebsite] ❌ Apache config failed!")
                log("⚠️ Apache config failed, site may not work properly")
            }
        } else {
            print("🌐 [CreateWebsite] ⚠️ No web server installed!")
        }

        // 4. Update local state
        let newSite = Website(
            id: UUID(),
            domain: safeDomain,
            path: safePath,
            status: .running,
            port: port,
            framework: "\(framework) (\(webServerUsed))"
        )

        await MainActor.run {
            self.addWebsite(newSite)
        }

        // 5. Refresh websites list to verify
        print("🌐 [CreateWebsite] Step 4: Refreshing websites list...")
        await fetchRealWebsites()

        print("🌐 [CreateWebsite] ✅ Website \(safeDomain) creation completed!")
        log("✅ Website \(safeDomain) created successfully")
    }

    /// Create default index file based on framework
    private func createDefaultIndexFile(at path: String, domain: String, framework: String) async {
        guard let session = session else { return }

        let fileName: String
        let content: String

        if framework.lowercased().contains("php") {
            fileName = "index.php"
            content = """
            <?php
            // Created by Velo Server Management
            ?>
            <!DOCTYPE html>
            <html lang="en">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>Welcome to \(domain)</title>
                <style>
                    body { margin: 0; padding: 0; font-family: system-ui, -apple-system, sans-serif; background: #0f172a; color: #fff; display: flex; align-items: center; justify-content: center; height: 100vh; }
                    .container { text-align: center; padding: 40px; background: #1e293b; border-radius: 16px; box-shadow: 0 10px 25px rgba(0,0,0,0.5); border: 1px solid #334155; max-width: 400px; }
                    h1 { margin: 0 0 10px; font-size: 24px; font-weight: 700; }
                    p { color: #94a3b8; margin-bottom: 24px; }
                    .badge { display: inline-block; padding: 6px 12px; background: linear-gradient(135deg, #6366f1, #8b5cf6); color: white; border-radius: 20px; font-size: 12px; font-weight: 600; text-transform: uppercase; }
                    .info { background: #334155; padding: 12px; border-radius: 8px; margin-top: 20px; font-size: 12px; }
                </style>
            </head>
            <body>
                <div class="container">
                    <div class="badge">Created By Velo</div>
                    <h1 style="margin-top: 20px;">\(domain)</h1>
                    <p>PHP <?php echo phpversion(); ?> is running</p>
                    <div class="info">Server: <?php echo $_SERVER['SERVER_SOFTWARE'] ?? 'N/A'; ?></div>
                </div>
            </body>
            </html>
            """
        } else {
            fileName = "index.html"
            content = """
            <!DOCTYPE html>
            <html lang="en">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>Welcome to \(domain)</title>
                <style>
                    body { margin: 0; padding: 0; font-family: system-ui, -apple-system, sans-serif; background: #0f172a; color: #fff; display: flex; align-items: center; justify-content: center; height: 100vh; }
                    .container { text-align: center; padding: 40px; background: #1e293b; border-radius: 16px; box-shadow: 0 10px 25px rgba(0,0,0,0.5); border: 1px solid #334155; max-width: 400px; }
                    h1 { margin: 0 0 10px; font-size: 24px; font-weight: 700; }
                    p { color: #94a3b8; margin-bottom: 24px; }
                    .badge { display: inline-block; padding: 6px 12px; background: linear-gradient(135deg, #6366f1, #8b5cf6); color: white; border-radius: 20px; font-size: 12px; font-weight: 600; text-transform: uppercase; }
                </style>
            </head>
            <body>
                <div class="container">
                    <div class="badge">Created By Velo</div>
                    <h1 style="margin-top: 20px;">\(domain)</h1>
                    <p>Ready for content</p>
                    <div style="font-size: 12px; color: #64748b;">Coming Soon</div>
                </div>
            </body>
            </html>
            """
        }

        if let data = content.data(using: .utf8) {
            let base64 = data.base64EncodedString()
            _ = await sshService.executeCommand("echo '\(base64)' | base64 --decode | sudo tee '\(path)/\(fileName)' > /dev/null", via: session)
        }
    }

    /// Helper for file picker
    func fetchFilesForPicker(path: String) async -> [ServerFileItem] {
        guard let session = session else { return [] }
        return await sshService.fetchFiles(at: path, via: session)
    }

    func updateWebsite(_ website: Website) {
        if let index = websites.firstIndex(where: { $0.id == website.id }) {
            websites[index] = website
            log("Website \(website.domain) updated.")
        }
    }

    /// Toggle website status (start/stop the associated web server service for this site)
    func toggleWebsiteStatus(_ website: Website) async {
        guard let session = session else { return }

        let newStatus: Website.WebsiteStatus = website.status == .running ? .stopped : .running

        // Determine web server from framework
        let webServer = website.framework.lowercased().contains("nginx") ? "nginx" :
                        website.framework.lowercased().contains("apache") ? "apache2" : nil

        if let service = webServer {
            if newStatus == .stopped {
                // For individual site control, we disable the site config instead of stopping the whole server
                if service == "nginx" {
                    _ = await sshService.executeCommand("sudo rm -f /etc/nginx/sites-enabled/\(website.domain) && sudo systemctl reload nginx", via: session)
                } else {
                    _ = await sshService.executeCommand("sudo a2dissite \(website.domain).conf && sudo systemctl reload apache2", via: session)
                }
            } else {
                // Re-enable the site
                if service == "nginx" {
                    _ = await sshService.executeCommand("sudo ln -sf /etc/nginx/sites-available/\(website.domain) /etc/nginx/sites-enabled/ && sudo systemctl reload nginx", via: session)
                } else {
                    _ = await sshService.executeCommand("sudo a2ensite \(website.domain).conf && sudo systemctl reload apache2", via: session)
                }
            }
        }

        // Update local state
        if let index = websites.firstIndex(where: { $0.id == website.id }) {
            websites[index].status = newStatus
            log("Website \(website.domain) status changed to \(newStatus)")
        }
    }

    /// Restart website (reload web server config)
    func restartWebsite(_ website: Website) async {
        guard let session = session else { return }

        let webServer = website.framework.lowercased().contains("nginx") ? "nginx" :
                        website.framework.lowercased().contains("apache") ? "apache2" : nil

        if let service = webServer {
            _ = await sshService.restartService(service, via: session)
            log("Website \(website.domain) restarted via \(service)")
        }
    }

    /// Delete website with real SSH execution
    func deleteWebsite(_ website: Website, deleteFiles: Bool = false) async {
        guard let session = session else { return }

        let webServer = website.framework.lowercased().contains("nginx") ? "nginx" :
                        website.framework.lowercased().contains("apache") ? "apache" : "nginx" // Default to nginx

        // Delete via SSH
        let success = await sshService.deleteWebsite(
            domain: website.domain,
            path: website.path,
            deleteFiles: deleteFiles,
            webServer: webServer,
            via: session
        )

        if success {
            // Update local state
            websites.removeAll { $0.id == website.id }
            overviewCounts.sites = websites.count
            log("Website \(website.domain) deleted successfully")
        } else {
            log("Failed to delete website \(website.domain)")
        }
    }

    /// Get list of installed PHP versions for website configuration
    func fetchInstalledPHPVersions() async -> [String] {
        guard let session = session else { return [] }
        return await sshService.fetchInstalledPHPVersions(via: session)
    }

    /// Switch PHP version for a website
    func switchPHPVersion(forWebsite website: Website, toVersion version: String) async -> Bool {
        guard let session = session else { return false }
        return await sshService.switchPHPVersion(forDomain: website.domain, toVersion: version, via: session)
    }
    
    // MARK: - Secure Actions
    
    func securelyPerformAction(reason: String, action: @escaping () -> Void) {
        SecurityManager.shared.securelyPerformAction(reason: reason, action: action) { error in
            self.errorMessage = error
        }
    }
    
    // MARK: - Database Management (Real SSH)

    func addDatabase(_ database: Database) {
        databases.insert(database, at: 0)
        overviewCounts.databases = databases.count
        log("Database \(database.name) added to UI.")
    }

    /// Create a real database on the server
    func createRealDatabase(name: String, type: Database.DatabaseType, username: String?, password: String?) async -> Bool {
        guard let session = session else { return false }

        log("Creating \(type.rawValue) database: \(name)")

        var success = false

        switch type {
        case .mysql:
            success = await sshService.createMySQLDatabase(name: name, username: username, password: password, via: session)
        case .postgres:
            success = await sshService.createPostgreSQLDatabase(name: name, username: username, password: password, via: session)
        case .redis, .mongo:
            // Redis and MongoDB don't have traditional "create database" semantics
            log("⚠️ \(type.rawValue) databases are created on first use")
            success = true
        }

        if success {
            let newDb = Database(
                name: name,
                type: type,
                username: username,
                password: password,
                sizeBytes: 0,
                status: .active
            )
            await MainActor.run {
                self.addDatabase(newDb)
            }

            // Refresh database list
            await fetchRealDatabases()
        }

        return success
    }

    func updateDatabase(_ database: Database) {
        if let index = databases.firstIndex(where: { $0.id == database.id }) {
            databases[index] = database
            log("Database \(database.name) updated.")
        }
    }

    /// Delete a database with real SSH execution
    func deleteDatabase(_ database: Database) async {
        guard let session = session else { return }

        log("Deleting database: \(database.name)")

        let success = await sshService.deleteDatabase(name: database.name, type: database.type.rawValue, via: session)

        if success {
            databases.removeAll { $0.id == database.id }
            overviewCounts.databases = databases.count
            log("Database \(database.name) deleted successfully")
        } else {
            log("Failed to delete database \(database.name)")
        }
    }

    /// Backup a database
    func backupDatabase(_ database: Database) async -> String? {
        guard let session = session else { return nil }

        if database.type == .mysql {
            return await sshService.backupMySQLDatabase(name: database.name, via: session)
        }

        log("⚠️ Backup not implemented for \(database.type.rawValue)")
        return nil
    }
    
    // MARK: - Private
    
    /// Helper to get the correct installation command with fallbacks
    private func getInstallCommand(from version: CapabilityVersion, os: String) -> String? {
        guard let commands = version.installCommands else { return nil }
        
        let osKey = os.lowercased()
        
        // 1. Try exact OS match (try both "default" and "install" keys)
        if let osCommands = commands[osKey], let cmd = osCommands["default"] ?? osCommands["install"] {
            return cmd
        }
        
        // 2. Fallback: Ubuntu (since most Velo services cover Ubuntu)
        if osKey != "ubuntu", let ubuntuCommands = commands["ubuntu"], let cmd = ubuntuCommands["default"] ?? ubuntuCommands["install"] {
            log("⚠️ Falling back to Ubuntu command for \(os)")
            return cmd
        }
        
        // 3. Fallback: Debian
        if osKey != "debian", let debianCommands = commands["debian"], let cmd = debianCommands["default"] ?? debianCommands["install"] {
            log("⚠️ Falling back to Debian command for \(os)")
            return cmd
        }
        
        // 4. Fallback: Linux (generic)
        if let linuxCommands = commands["linux"], let cmd = linuxCommands["default"] ?? linuxCommands["install"] {
            log("⚠️ Falling back to Linux command for \(os)")
            return cmd
        }
        
        return nil
    }
    
    /// Start periodic stats refresh (real SSH - optimized)
    func startLiveUpdates() {
        guard !isLiveUpdating else { return }
        isLiveUpdating = true
        
        log("Starting periodic stats refresh loop (optimized)...")
        
        Task { @MainActor in
            while !Task.isCancelled && isLiveUpdating {
                guard let session = self.session else { break }
                
                // Skip while installing
                if !isInstalling {
                    // Use optimized batch command for stats
                    let parsedStats = await self.sshService.fetchAllStatsOptimized(via: session)
                    
                    guard !Task.isCancelled else { break }
                    
                    // Update published properties
                    self.stats = ServerStats(
                        cpuUsage: parsedStats.cpuUsage,
                        ramUsage: parsedStats.ramUsage,
                        diskUsage: parsedStats.diskUsage,
                        uptime: 0,
                        isOnline: true,
                        osName: parsedStats.osName,
                        ipAddress: parsedStats.ipAddress
                    )

                    self.serverHostname = parsedStats.hostname
                    self.serverIP = parsedStats.ipAddress
                    self.serverOS = parsedStats.osName
                    self.serverUptime = parsedStats.uptime
                    self.cpuUsage = Int(parsedStats.cpuUsage * 100)
                    self.ramUsage = Int(parsedStats.ramUsage * 100)
                    self.diskUsage = Int(parsedStats.diskUsage * 100)

                    // Update history
                    let now = Date()
                    self.cpuHistory.append(HistoryPoint(date: now, value: parsedStats.cpuUsage))
                    self.ramHistory.append(HistoryPoint(date: now, value: parsedStats.ramUsage))
                    if self.cpuHistory.count > 20 { self.cpuHistory.removeFirst() }
                    if self.ramHistory.count > 20 { self.ramHistory.removeFirst() }
                    
                    // Update traffic history
                    await self.fetchTrafficStats()
                }
                
                // Wait 15 seconds before next refresh
                try? await Task.sleep(nanoseconds: 15_000_000_000)
            }
            isLiveUpdating = false
            log("Periodic stats refresh loop stopped.")
        }
    }

    // MARK: - Domain Management (Real SSH)

    /// Published property for configured domains
    @Published var configuredDomains: [String] = []

    /// Fetch all configured domains from web servers
    func fetchConfiguredDomains() async {
        guard let session = session else { return }
        log("Fetching configured domains...")
        configuredDomains = await sshService.fetchConfiguredDomains(via: session)
    }

    /// Add a domain alias to an existing website
    func addDomainAlias(toWebsite website: Website, aliasDomain: String) async -> Bool {
        guard let session = session else { return false }

        let webServer = website.framework.lowercased().contains("nginx") ? "nginx" :
                        website.framework.lowercased().contains("apache") ? "apache" : "nginx"

        let success = await sshService.addDomainAlias(
            mainDomain: website.domain,
            aliasDomain: aliasDomain,
            webServer: webServer,
            via: session
        )

        if success {
            // Refresh domains list
            await fetchConfiguredDomains()
        }

        return success
    }

    // MARK: - Network Traffic Stats

    /// Fetch network traffic and add to history
    func fetchTrafficStats() async {
        guard let session = session else { return }

        let (rx, tx) = await sshService.fetchNetworkStats(via: session)

        // Convert bytes to KB
        let rxKB = Double(rx) / 1024.0
        let txKB = Double(tx) / 1024.0

        // Only add if we have meaningful data
        if rx > 0 || tx > 0 {
            let point = TrafficPoint(
                timestamp: Date(),
                upstreamKB: txKB / 1000, // Convert to reasonable scale
                downstreamKB: rxKB / 1000
            )

            await MainActor.run {
                self.trafficHistory.append(point)
                // Keep last 30 points
                if self.trafficHistory.count > 30 {
                    self.trafficHistory.removeFirst()
                }
            }
        }
    }

    // MARK: - Optimized Data Loading

    /// Load all data using optimized batch commands (faster, less server load)
    func loadAllDataOptimized() async {
        guard let session = session else {
            log("❌ No SSH session available")
            return
        }

        // Cancel any ongoing refresh
        refreshTask?.cancel()
        
        // Cooldown check for manual refreshes
        if let last = lastManualRefresh, Date().timeIntervalSince(last) < refreshCooldown && dataLoadedOnce {
            log("Refreshed too recently, skipping...")
            return
        }
        lastManualRefresh = Date()

        log("🚀 Starting new optimized load task...")
        
        refreshTask = Task {
            guard !Task.isCancelled else { return }
            
            isLoading = true
            
            log("📌 Step 1: Checking server software status...")
            isLoadingServerStatus = true
            let newStatus = await SSHStatsService.shared.fetchServerStatus(via: session)
            
            await MainActor.run {
                if newStatus.hasWebServer || newStatus.hasDatabase || newStatus.hasRuntime {
                    self.serverStatus = newStatus
                } else if self.serverStatus.hasWebServer {
                    log("⚠️ Status refresh failed, preserving old status")
                }
            }
            
            // STEP 2: Load stats using optimized batch command
            log("📌 Step 2: Loading server stats...")
            let s = await SSHStatsService.shared.fetchSystemStats(via: session)
            
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                self.stats = ServerStats(
                    cpuUsage: s.cpu,
                    ramUsage: s.ram,
                    diskUsage: s.disk,
                    uptime: 0,
                    isOnline: true,
                    osName: s.os,
                    ipAddress: s.ip
                )
                
                self.serverHostname = s.hostname
                self.serverIP = s.ip
                self.serverOS = s.os
                self.serverUptime = s.uptime
                self.cpuUsage = Int(s.cpu * 100)
                self.ramUsage = Int(s.ram * 100)
                self.diskUsage = Int(s.disk * 100)
            }
            
            // Update installed software from status
            let packages = await sshService.fetchInstalledSoftware(via: session)
            
            await MainActor.run {
                self.installedSoftware = packages
                
                // CRITICAL: Synchronize back to serverStatus if software was found via dpkg 
                // but missed by binary detection.
                var updatedStatus = self.serverStatus
                print("🔧 [ServerMgmt] Syncing \(packages.count) packages to server status...")
                
                for pkg in packages {
                    let name = pkg.name.lowercased()
                    let version = pkg.version
                    let status: SoftwareStatus = pkg.isRunning ? .running(version: version) : .stopped(version: version)
                    
                    if name.contains("nginx") { 
                        updatedStatus.nginx = status 
                        print("🔧 [ServerMgmt] ✅ Synced Nginx: \(status.displayText)")
                    } else if name.contains("apache") { 
                        updatedStatus.apache = status 
                    } else if name.contains("mysql") || name.contains("mariadb") { 
                        updatedStatus.mysql = status 
                    } else if name.contains("php") { 
                        updatedStatus.php = status 
                    } else if name.contains("postgresql") || name.contains("psql") { 
                        updatedStatus.postgresql = status 
                    } else if name.contains("git") { 
                        updatedStatus.git = status 
                    } else if name.contains("node") { 
                        updatedStatus.nodejs = status 
                    }
                }
                
                if updatedStatus.hasWebServer || updatedStatus.hasDatabase || updatedStatus.hasRuntime {
                     print("🔧 [ServerMgmt] 🌐 hasWebServer: \(updatedStatus.hasWebServer), hasDatabase: \(updatedStatus.hasDatabase)")
                     self.serverStatus = updatedStatus
                } else {
                     print("🔧 [ServerMgmt] ⚠️ No web server or database detected in sync.")
                }
            }
            
            // 3. Loading websites and databases
            print("[ServerMgmt] 📌 Step 3: Loading websites and databases...")
            
            // Sites
            print("[ServerMgmt] Fetching real websites...")
            let sites = await SSHWebsiteService.shared.fetchWebsites(via: session)
            print("[ServerMgmt] Found \(sites.count) websites")
            
            // Databases
            print("[ServerMgmt] Fetching real databases...")
            let mysqlDBs = await SSHDatabaseService.shared.fetchDatabases(type: .mysql, via: session)
            let pgsqlDBs = await SSHDatabaseService.shared.fetchDatabases(type: .postgres, via: session)
            let allDBs = mysqlDBs + pgsqlDBs
            print("[ServerMgmt] Found \(allDBs.count) databases")
            
            // STEP 4: Files
            guard !Task.isCancelled else { return }
            await fetchRealFiles(at: currentPath)
            
            // Update UI
            await MainActor.run {
                self.websites = sites.map { Website(domain: $0, path: "/var/www/\($0)", status: .running, port: 80, framework: "PHP") }
                self.databases = allDBs
                self.dataLoadedOnce = true
                self.isLoading = false
                print("[ServerMgmt] ✅ Optimized load task completed successfully")
            }
            // Start periodic updates if not already running
            startLiveUpdates()
        }
    }
}
