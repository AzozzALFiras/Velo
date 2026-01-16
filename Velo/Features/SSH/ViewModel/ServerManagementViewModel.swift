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
        guard let session = session else { return }
        log("🔄 Refreshing server status...")
        isLoadingServerStatus = true
        serverStatus = await sshService.fetchServerStatus(via: session)
        isLoadingServerStatus = false
        updateInstalledSoftwareFromStatus()
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
        
        let packages = await sshService.fetchInstalledPackages(via: session)
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
    
    // MARK: - Server Management Actions
    
    func changeRootPassword(newPass: String) {
        // Mock SSH command: "echo 'root:newPass' | chpasswd"
        print("Changing root password to \(newPass)...")
    }
    
    func changeDBPassword(newPass: String) {
        // Mock SQL command: "ALTER USER 'root'@'localhost' IDENTIFIED BY 'newPass';"
        print("Changing DB password to \(newPass)...")
    }
    
    func restartService(_ serviceName: String) {
        // Mock SSH command: "systemctl restart \(serviceName)"
        print("Restarting \(serviceName)...")
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
                    }
                    
                } catch {
                    await appendLog("❌ Failed to install \(slug): \(error.localizedDescription)")
                }
            }
            
            // Complete the stack installation
            await MainActor.run {
                self.installProgress = 1.0
                self.installLog += "\n> Stack Installation Completed! ✅"
            }
            
            await completion(success: true)
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
            
            await completion(success: true)
            
            // 5. Refresh installed packages from server
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
    private func completion(success: Bool) {
        self.isInstalling = false
        if success {
            self.installLog += "\n> Installation Completed Successfully! ✅"
            self.installProgress = 1.0
            log("✅ Installation completed successfully")
            
            // Refresh server status to detect newly installed software
            log("🔄 Refreshing server status after installation...")
            Task {
                // Short delay to ensure installation is fully complete
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                // Refresh server status to update UI
                if let session = self.session {
                    let newStatus = await self.sshService.fetchServerStatus(via: session)
                    await MainActor.run {
                        self.serverStatus = newStatus
                        log("📌 Updated server status - nginx: \(newStatus.nginx != .notInstalled), apache: \(newStatus.apache != .notInstalled)")
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
    
    func deleteFile(_ file: ServerFileItem) {
        securelyPerformAction(reason: "Confirm deletion of \(file.name)") {
            withAnimation {
                self.files.removeAll(where: { $0.id == file.id })
            }
        }
    }
    
    func renameFile(_ file: ServerFileItem, to newName: String) {
        if let index = files.firstIndex(where: { $0.id == file.id }) {
            files[index].name = newName
        }
    }
    
    func downloadFile(_ file: ServerFileItem) {
        // In a real app, this would trigger an SCP/SFTP pull
        // For now, we simulate the action which will be confirmed by a Toast UI
        print("Downloading \(file.name)...")
    }
    
    func updatePermissions(_ file: ServerFileItem, to newPerms: String) {
        if let index = files.firstIndex(where: { $0.id == file.id }) {
            withAnimation {
                files[index].permissions = newPerms
            }
        }
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
    
    // MARK: - Website Management
    
    func addWebsite(_ website: Website) {
        if !websites.contains(where: { $0.id == website.id }) {
            websites.insert(website, at: 0)
            print("Website \(website.domain) added.")
        }
    }
    
    /// Create a real website on the server (Directory + Index)
    func createRealWebsite(domain: String, path: String, framework: String, port: Int) async throws {
        guard let session = session else {
            throw NSError(domain: "ServerMgmt", code: 1, userInfo: [NSLocalizedDescriptionKey: "No SSH session"])
        }
        
        let safePath = path.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Create Directory
        log("Creating website directory: \(safePath)")
        _ = await sshService.executeCommand("mkdir -p \(safePath)", via: session)
        
        // 2. Set ownership (try www-data)
        _ = await sshService.executeCommand("chown -R www-data:www-data \(safePath) 2>/dev/null || true", via: session)
        _ = await sshService.executeCommand("chmod -R 755 \(safePath)", via: session)
        
        // 3. Create Default index.html (using base64 to avoid escaping issues)
        log("Creating default index.html...")
        let htmlContent = """
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
        
        if let data = htmlContent.data(using: .utf8) {
            let base64 = data.base64EncodedString()
            _ = await sshService.executeCommand("echo '\(base64)' | base64 --decode > \(safePath)/index.html", via: session)
        }
        
        // 4. Update local state
        let newSite = Website(
            id: UUID(),
            domain: domain,
            path: safePath,
            status: .running,
            port: port,
            framework: framework
        )
        
        await MainActor.run {
            self.addWebsite(newSite)
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
            print("Website \(website.domain) updated.")
        }
    }
    
    func toggleWebsiteStatus(_ website: Website) {
        if let index = websites.firstIndex(where: { $0.id == website.id }) {
            websites[index].status = websites[index].status == .running ? .stopped : .running
        }
    }
    
    func deleteWebsite(_ website: Website) {
        websites.removeAll { $0.id == website.id }
        print("Website \(website.domain) deleted.")
    }
    
    // MARK: - Secure Actions
    
    func securelyPerformAction(reason: String, action: @escaping () -> Void) {
        SecurityManager.shared.securelyPerformAction(reason: reason, action: action) { error in
            self.errorMessage = error
        }
    }
    
    // MARK: - Database Management
    
    func addDatabase(_ database: Database) {
        databases.insert(database, at: 0)
        print("Database \(database.name) added.")
    }
    
    func updateDatabase(_ database: Database) {
        if let index = databases.firstIndex(where: { $0.id == database.id }) {
            databases[index] = database
            print("Database \(database.name) updated.")
        }
    }
    
    func deleteDatabase(_ database: Database) {
        databases.removeAll { $0.id == database.id }
        print("Database \(database.name) deleted.")
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
    
    /// Start periodic stats refresh (real SSH)
    func startLiveUpdates() {
        log("Starting periodic stats refresh...")
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let _ = self.session else { return }
                
                // Only refresh stats (lightweight)
                await self.fetchRealServerStats()
            }
        }
    }
}
