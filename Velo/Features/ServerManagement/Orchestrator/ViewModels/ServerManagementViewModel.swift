//
//  ServerManagementViewModel.swift
//  Velo
//
//  ViewModel for the Server Management UI.
//  Acts as a lightweight container/coordinator for specialized modular ViewModels.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class ServerManagementViewModel: ObservableObject {
    
    // MARK: - Child ViewModels (Modular)
    @Published var overviewVM: ServerOverviewViewModel
    @Published var websitesVM: WebsitesViewModel
    @Published var databasesVM: DatabasesViewModel
    @Published var servicesVM: ServiceManagementViewModel
    @Published var installerVM: ServerInstallerViewModel
    @Published var filesVM: FilesViewModel
    
    // Health Check
    let healthCheckService = ServerHealthCheckService.shared
    @Published var showHealthIssuesSheet = false
    
    // MARK: - Dependencies
    weak var session: TerminalViewModel? {
        didSet {
            // Propagate session to children
            overviewVM.session = session
            websitesVM.session = session
            databasesVM.session = session
            servicesVM.session = session
            installerVM.session = session
            filesVM.session = session
        }
    }
    
    // MARK: - Published State (Compatibility Wrappers)
    
    // Overview / Stats
    var stats: ServerStats {
        overviewVM.currentStats
    }
    
    var overviewCounts: OverviewCounts {
        OverviewCounts(
            sites: websitesVM.websites.count,
            ftp: 0,
            databases: databasesVM.totalDatabaseCount,
            security: overviewVM.installedSoftware.count
        )
    }
    
    var serverStatus: ServerStatus { overviewVM.serverStatus }
    var websites: [Website] { websitesVM.websites }
    var databases: [Database] { databasesVM.databases }
    var installedSoftware: [InstalledSoftware] { overviewVM.installedSoftware }
    
    // Server Info Wrappers
    var serverHostname: String { overviewVM.hostname }
    var serverIP: String { overviewVM.ipAddress }
    var serverOS: String { overviewVM.osName }
    var serverUptime: String { overviewVM.uptime }
    var cpuUsage: Int { overviewVM.cpuUsage }
    var ramUsage: Int { overviewVM.ramUsage }
    var trafficHistory: [TrafficPoint] { overviewVM.trafficHistory }
    
    // Applications / Installer
    @Published var searchQuery: String = ""
    var filteredCapabilities: [Capability] {
        if searchQuery.isEmpty {
            return installerVM.availableCapabilities
        }
        return installerVM.availableCapabilities.filter {
            $0.name.localizedCaseInsensitiveContains(searchQuery) ||
            $0.description.localizedCaseInsensitiveContains(searchQuery) ||
            $0.slug.localizedCaseInsensitiveContains(searchQuery)
        }
    }
    
    // Loading State
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    // Files (Delegated to FilesViewModel)
    var files: [ServerFileItem] { filesVM.files }
    var currentPath: String { filesVM.currentPath }
    var pathStack: [String] { filesVM.pathStack }
    var activeUploads: [FileUploadTask] { filesVM.activeUploads }
    
    // Capabilities / Installation Wrappers
    var availableCapabilities: [Capability] { installerVM.availableCapabilities }
    var isInstalling: Bool { installerVM.isInstalling }
    var installLog: String { installerVM.installLog }
    var installProgress: Double { installerVM.installProgress }
    var showInstallOverlay: Bool {
        get { installerVM.showInstallOverlay }
        set { installerVM.showInstallOverlay = newValue }
    }
    var currentInstallingCapability: String? { installerVM.currentInstallingCapability }
    
    private var subscribers: Set<AnyCancellable> = []
    private var dataLoadedOnce = false
    
    // MARK: - Init
    
    init(session: TerminalViewModel? = nil) {
        self.session = session
        
        // Initialize Children
        self.overviewVM = ServerOverviewViewModel(session: session)
        self.websitesVM = WebsitesViewModel(session: session)
        self.databasesVM = DatabasesViewModel(session: session)
        self.servicesVM = ServiceManagementViewModel(session: session)
        self.installerVM = ServerInstallerViewModel(session: session)
        self.filesVM = FilesViewModel(session: session)
        
        setupBindings()
    }
    
    private func setupBindings() {
        // Forward changes from children to self
        overviewVM.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &subscribers)
        websitesVM.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &subscribers)
        databasesVM.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &subscribers)
        servicesVM.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &subscribers)
        installerVM.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &subscribers)
        filesVM.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &subscribers)
        
        // Handle post-install refresh
        installerVM.onInstallationComplete = { [weak self] success in
            if success {
                Task { await self?.refreshServerStatus() }
            }
        }
    }
    
    // MARK: - Data Loading
    
    func loadAllData(force: Bool = false) async {
        guard !dataLoadedOnce || force else { return }
        isLoading = true
        
        AppLogger.shared.log("Starting full server analysis...", level: .info)
        
        // Parallel load
        async let overview: () = overviewVM.loadData()
        async let sites: () = websitesVM.loadWebsites()
        async let dbs: () = databasesVM.loadDatabases()
        async let services: () = servicesVM.loadServices()
        async let caps: () = installerVM.fetchCapabilities()
        
        await overview
        await sites
        await dbs
        await services
        await caps
        
        AppLogger.shared.log("Full server analysis completed correctly ✅", level: .result)
        
        // Start live updates
        overviewVM.startLiveUpdates()
        
        // Health checks disabled temporarily - slowing down UI
        // TODO: Make health checks opt-in via settings
        // if let session = session {
        //     await healthCheckService.runAllChecks(via: session)
        //     let hasImportantIssues = healthCheckService.detectedIssues.contains { 
        //         $0.severity == .critical || $0.severity == .warning 
        //     }
        //     if hasImportantIssues {
        //         showHealthIssuesSheet = true
        //     }
        // }
        
        dataLoadedOnce = true
        isLoading = false
    }
    
    func loadAllDataOptimized() async {
        await loadAllData(force: true)
    }
    
    func refreshServerStatus() async {
        await overviewVM.fetchServerStatus()
        await websitesVM.loadWebsites()
        await databasesVM.loadDatabases()
        await servicesVM.loadServices()
        // Also refresh installer capabilities to update 'installed' status in marketplace
        await installerVM.fetchCapabilities()
    }
    
    func refreshData() {
        Task {
            await loadAllData(force: true)
        }
    }
    
    // MARK: - Delegated Actions
    
    // Websites
    func createRealWebsite(
        domain: String,
        path: String,
        framework: String,
        port: Int,
        shouldGenerateSSL: Bool = false,
        sslEmail: String? = nil
    ) async throws {
        _ = await websitesVM.createWebsite(
            domain: domain,
            path: path,
            framework: framework,
            port: port,
            shouldGenerateSSL: shouldGenerateSSL,
            sslEmail: sslEmail
        )
    }
    
    func deleteWebsite(_ website: Website, deleteFiles: Bool = false) async {
        _ = await websitesVM.deleteWebsite(website, deleteFiles: deleteFiles)
    }
    
    func fetchInstalledPHPVersions() async -> [String] {
        await websitesVM.availablePHPVersions
    }
    
    func switchPHPVersion(forWebsite website: Website, toVersion version: String) async -> Bool {
        await websitesVM.switchPHPVersion(forWebsite: website, toVersion: version)
    }
    
    func toggleWebsiteStatus(_ website: Website) async {
        _ = await websitesVM.toggleWebsiteStatus(website)
    }
    
    func restartWebsite(_ website: Website) async {
        _ = await websitesVM.restartWebsite(website)
    }
    
    // Databases
    func createRealDatabase(name: String, type: DatabaseType, username: String?, password: String?) async -> Bool {
        await databasesVM.createDatabase(name: name, type: type, username: username, password: password)
    }
    
    func deleteDatabase(_ database: Database) async {
        _ = await databasesVM.deleteDatabase(database)
    }
    
    func backupDatabase(_ database: Database) async -> String? {
        await databasesVM.backupDatabase(database)
    }
    
    func updateDatabase(_ database: Database) {
        databasesVM.updateDatabase(database)
    }
    
    func updateWebsite(_ website: Website) {
        websitesVM.updateWebsite(website)
    }
    
    // Services
    func restartService(_ serviceName: String) async -> Bool {
        let temp = ServiceInfo(name: serviceName, serviceName: serviceName, type: .other, status: .unknown, canReload: true)
        return await servicesVM.restartService(temp)
    }
    
    func stopService(_ serviceName: String) async -> Bool {
         let temp = ServiceInfo(name: serviceName, serviceName: serviceName, type: .other, status: .unknown, canReload: true)
        return await servicesVM.stopService(temp)
    }
    
    func startService(_ serviceName: String) async -> Bool {
         let temp = ServiceInfo(name: serviceName, serviceName: serviceName, type: .other, status: .unknown, canReload: true)
        return await servicesVM.startService(temp)
    }
    
    // Install
    func installCapabilityBySlug(_ slug: String) {
        installerVM.installCapabilityBySlug(slug)
    }
    
    func installCapability(_ capability: Capability, version: String) async {
        // In a real scenario, we might pass the version. 
        // For now, our installerVM handles the latest stable by slug.
        installerVM.installCapabilityBySlug(capability.slug)
    }
    
    func installStack(_ slugs: [String]) {
        let os = overviewVM.osName.isEmpty ? "ubuntu" : overviewVM.osName
        installerVM.installStack(slugs, osType: os)
    }
    
    // Settings / Security
    func changeRootPassword(newPass: String) async -> Bool {
        // Implementation placeholder
        return true
    }
    
    func changeDBPassword(newPass: String) async -> Bool {
        // Implementation placeholder
        return true
    }
    
    // Secure Actions
    func securelyPerformAction(reason: String, action: @escaping () -> Void) {
        SecurityManager.shared.securelyPerformAction(reason: reason, action: action) { [weak self] error in
            self?.errorMessage = error
        }
    }
    
    // MARK: - Files (Delegated)
    func fetchFilesForPicker(path: String) async -> [ServerFileItem] {
        await filesVM.loadFiles() // Simplified: uses internal state
        return filesVM.files
    }
    
    func navigateBack() {
        filesVM.navigateBack()
    }
    
    func jumpToPath(_ path: String) {
        filesVM.jumpToPath(path)
    }
    
    func navigateTo(folder: ServerFileItem) {
        filesVM.navigateTo(folder: folder)
    }
    
    func loadFiles() async {
        await filesVM.loadFiles()
    }
    
    func deleteFile(_ file: ServerFileItem) async -> Bool {
        await filesVM.deleteFile(file)
    }
    
    func renameFile(_ file: ServerFileItem, to: String) async -> Bool {
        await filesVM.renameFile(file, to: to)
    }
    
    func updatePermissions(_ file: ServerFileItem, to: String) async -> Bool {
        // Still a placeholder but could be in filesVM
        return true
    }
    
    func updateOwner(_ file: ServerFileItem, to: String) async -> Bool {
        return true
    }
    
    func downloadFile(_ file: ServerFileItem) {
        // Implementation placeholder
    }
    
    func startMockUpload(fileName: String) {
        filesVM.startMockUpload(fileName: fileName)
    }
}
