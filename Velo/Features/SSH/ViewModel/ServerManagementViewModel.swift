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
    
    // Server Info for Settings
    @Published var serverHostname = "production-sg-01"
    @Published var serverIP = "159.89.172.42"
    @Published var serverOS = "Ubuntu 22.04.3 LTS"
    @Published var serverUptime = "12 days, 4 hours"
    @Published var cpuUsage = 14
    @Published var ramUsage = 42
    @Published var diskUsage = 68
    
    // Legacy Chart History (Keep for now or deprecate if fully replacing)
    @Published var cpuHistory: [ServerManagementViewModel.HistoryPoint] = []
    @Published var ramHistory: [ServerManagementViewModel.HistoryPoint] = []
    
    // Chart History
    struct HistoryPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }
    
    // MARK: - Init
    init() {
        // Initialize with mock data
        self.stats = ServerManagementMockData.generateStats()
        self.websites = ServerManagementMockData.generateWebsites()
        self.databases = ServerManagementMockData.generateDatabases()
        self.installedSoftware = ServerManagementMockData.generateSoftwareList()
        self.trafficHistory = ServerManagementMockData.generateTrafficHistory()
        self.overviewCounts = ServerManagementMockData.generateOverviewCounts()
        self.files = ServerManagementMockData.generateFiles()
        
        // Initialize mock history (Legacy)
        let now = Date()
        for i in 0..<20 {
            let date = now.addingTimeInterval(Double(-20 + i) * 3.0)
            cpuHistory.append(HistoryPoint(date: date, value: Double.random(in: 0.1...0.6)))
            ramHistory.append(HistoryPoint(date: date, value: Double.random(in: 0.3...0.8)))
        }
        
        // Simulate live updates
        startLiveUpdates()
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
    
    // MARK: - Actions
    
    func refreshData() {
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.stats = ServerManagementMockData.generateStats()
            // Randomly update some websites status
            if var site = self.websites.randomElement(), let index = self.websites.firstIndex(where: { $0.id == site.id }) {
                site.status = site.status == .running ? .stopped : .running
                self.websites[index] = site
            }
            self.isLoading = false
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
            
            // Generate nested mock files based on the folder name for realism
            self.files = [
                ServerFileItem(name: "config.json", isDirectory: false, sizeBytes: 1024, permissions: "-rw-r--r--", modificationDate: Date(), owner: "root"),
                ServerFileItem(name: "logs", isDirectory: true, sizeBytes: 0, permissions: "drwxr-xr-x", modificationDate: Date(), owner: "root"),
                ServerFileItem(name: "README.md", isDirectory: false, sizeBytes: 500, permissions: "-rw-r--r--", modificationDate: Date(), owner: "root")
            ]
            self.isLoading = false
        }
    }
    
    func navigateBack() {
        guard pathStack.count > 1 else { return }
        pathStack.removeLast()
        jumpToPath(pathStack.last ?? "/")
    }
    
    func jumpToPath(_ path: String) {
        isLoading = true
        
        // Update the current path and stack
        currentPath = path
        if let index = pathStack.firstIndex(of: path) {
            pathStack = Array(pathStack.prefix(through: index))
        } else {
            pathStack.append(path)
        }
        
        // In a real app, this would be an SSH command: cd path && ls -la
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if path == "/" {
                self.files = ServerManagementMockData.generateFiles()
            } else {
                // Generate varied mock files for subdirectories
                self.files = [
                    ServerFileItem(name: "config.json", isDirectory: false, sizeBytes: 1024, permissions: "-rw-r--r--", modificationDate: Date(), owner: "root"),
                    ServerFileItem(name: "logs", isDirectory: true, sizeBytes: 0, permissions: "drwxr-xr-x", modificationDate: Date(), owner: "root"),
                    ServerFileItem(name: "README.md", isDirectory: false, sizeBytes: 500, permissions: "-rw-r--r--", modificationDate: Date(), owner: "root"),
                    ServerFileItem(name: "app.log", isDirectory: false, sizeBytes: 25600, permissions: "-rw-r--r--", modificationDate: Date().addingTimeInterval(-3600), owner: "www-data")
                ]
            }
            self.isLoading = false
        }
    }
    
    func deleteFile(_ file: ServerFileItem) {
        withAnimation {
            files.removeAll(where: { $0.id == file.id })
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
    
    func toggleWebsiteStatus(_ website: Website) {
        if let index = websites.firstIndex(where: { $0.id == website.id }) {
            withAnimation {
                websites[index].status = websites[index].status == .running ? .stopped : .running
            }
        }
    }
    
    func deleteDatabase(_ database: Database) {
        if let index = databases.firstIndex(where: { $0.id == database.id }) {
            withAnimation {
                databases.remove(at: index)
            }
        }
    }
    
    // MARK: - Private
    
    private func startLiveUpdates() {
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                // Slightly fluctuate stats
                var newStats = self.stats
                newStats.cpuUsage = max(0.05, min(1.0, newStats.cpuUsage + Double.random(in: -0.05...0.05)))
                newStats.ramUsage = max(0.1, min(1.0, newStats.ramUsage + Double.random(in: -0.02...0.02)))
                newStats.uptime += 3
                
                withAnimation(.easeInOut(duration: 0.5)) {
                    self.stats = newStats
                    
                    // Update Legacy history
                    let now = Date()
                    self.cpuHistory.append(HistoryPoint(date: now, value: newStats.cpuUsage))
                    self.ramHistory.append(HistoryPoint(date: now, value: newStats.ramUsage))
                    
                    if self.cpuHistory.count > 20 { self.cpuHistory.removeFirst() }
                    if self.ramHistory.count > 20 { self.ramHistory.removeFirst() }
                    
                    // Update New Traffic History
                    let newTraffic = TrafficPoint(
                        timestamp: now,
                        upstreamKB: Double.random(in: 2...15),
                        downstreamKB: Double.random(in: 10...50)
                    )
                    self.trafficHistory.append(newTraffic)
                    if self.trafficHistory.count > 50 { self.trafficHistory.removeFirst() }
                }
            }
        }
    }
}
