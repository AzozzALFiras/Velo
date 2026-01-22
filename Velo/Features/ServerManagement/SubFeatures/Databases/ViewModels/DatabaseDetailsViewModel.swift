//
//  DatabaseDetailsViewModel.swift
//  Velo
//
//  ViewModel for the DatabaseDetailsView.
//  Handles fetching tables, users, and operations for a specific database.
//

import Foundation
import Combine

@MainActor
final class DatabaseDetailsViewModel: ObservableObject {
    
    // Dependencies
    private let session: TerminalViewModel?
    private let mysqlService = MySQLService.shared
    private let postgresService = PostgreSQLService.shared
    
    // Target Database
    let database: Database
    
    // Published State
    @Published var tables: [DatabaseTable] = []
    @Published var users: [DatabaseUser] = []
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init(database: Database, session: TerminalViewModel?) {
        self.database = database
        self.session = session
    }
    
    func loadData() async {
        guard let session = session else { return }
        isLoading = true
        errorMessage = nil
        
        // Parallel fetch
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadTables(via: session) }
            group.addTask { await self.loadUsers(via: session) }
        }
        
        isLoading = false
    }
    
    private func loadTables(via session: TerminalViewModel) async {
        var fetchedTables: [DatabaseTable] = []
        
        switch database.type {
        case .mysql:
            fetchedTables = await mysqlService.fetchTables(database: database.name, via: session)
        // Future: Support Postgres/Redis tables/keys
        default:
            break
        }
        
        let finalTables = fetchedTables
        await MainActor.run {
            self.tables = finalTables
        }
    }
    
    private func loadUsers(via session: TerminalViewModel) async {
        var fetchedUsers: [DatabaseUser] = []
        
        switch database.type {
        case .mysql:
            fetchedUsers = await mysqlService.fetchUsers(forDatabase: database.name, via: session)
        // Future: Support Postgres users
        default:
            break
        }
        
        let finalUsers = fetchedUsers
        await MainActor.run {
            self.users = finalUsers
        }
    }
    
    func deleteDatabase() async -> Bool {
        guard let session = session else { return false }
        
        switch database.type {
        case .mysql:
            return await mysqlService.deleteDatabase(name: database.name, via: session)
        case .postgres:
            return await postgresService.deleteDatabase(name: database.name, via: session)
        default:
            return false
        }
    }
    
    // MARK: - Operations
    
    func optimizeDatabase() async -> Bool {
        guard let session = session else { return false }
        switch database.type {
        case .mysql:
            return await mysqlService.optimizeDatabase(name: database.name, via: session)
        default:
            return false
        }
    }
    
    func repairDatabase() async -> Bool {
        guard let session = session else { return false }
        switch database.type {
        case .mysql:
            return await mysqlService.repairDatabase(name: database.name, via: session)
        default:
            return false
        }
    }
    
    func exportDatabase() async -> String? {
        guard let session = session else { return nil }
        
        // 1. Create remote backup
        switch database.type {
        case .mysql:
            return await mysqlService.backupDatabase(name: database.name, via: session)
        case .postgres:
            return await postgresService.backupDatabase(name: database.name, via: session)
        default:
            return nil
        }
    }
    
    func downloadAndCleanup(remotePath: String, to localUrl: URL) async {
        guard let session = session, let connStr = session.activeSSHConnectionString else { return }
        
        let components = connStr.components(separatedBy: ":")
        let userHost = components.first ?? connStr
        
        // Construct SCP command with strict quoting for paths
        let scpCommand = "scp \(userHost):\"\(remotePath)\" \"\(localPath(from: localUrl))\""
        
        await MainActor.run {
            session.startBackgroundDownload(command: scpCommand)
        }
        
        // Listen for completion
        var observer: NSObjectProtocol?
        observer = NotificationCenter.default.addObserver(forName: TerminalViewModel.downloadFinishedNotification, object: nil, queue: .main) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let cmd = userInfo["command"] as? String,
                  let code = userInfo["code"] as? Int else { return }
            
            if cmd == scpCommand {
                if code == 0 {
                    print("✅ Download finished. Deleting remote file: \(remotePath)")
                    Task {
                        _ = await self.mysqlService.baseService.execute("rm -f '\(remotePath)'", via: session)
                    }
                }
                if let obs = observer {
                    NotificationCenter.default.removeObserver(obs)
                }
            }
        }
    }
    
    // Helper to get safe path string from URL
    private func localPath(from url: URL) -> String {
        return url.path(percentEncoded: false)
    }
    
    func deleteRemoteFile(_ path: String) async {
        guard let session = session else { return }
        _ = await mysqlService.baseService.execute("rm -f '\(path)'", via: session)
    }
}
