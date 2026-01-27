//
//  SSHManager.swift
//  Velo
//
//  SSH Connection Management Service
//

import Foundation
import Security
import SwiftUI
import Combine

// MARK: - SSH Manager
@MainActor
final class SSHManager: ObservableObject {
    
    // MARK: - Published State
    @Published private(set) var connections: [SSHConnection] = []
    @Published private(set) var groups: [SSHConnectionGroup] = []
    @Published private(set) var recentConnections: [SSHConnection] = []
    
    // MARK: - Storage
    private let storageURL: URL
    private let groupsURL: URL
    private let maxRecentConnections = 5
    
    // MARK: - Keychain
    private let keychainService = "dev.3zozz.velo.ssh"
    
    // MARK: - Init
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let veloDir = appSupport.appendingPathComponent("Velo", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: veloDir, withIntermediateDirectories: true)
        
        self.storageURL = veloDir.appendingPathComponent("ssh_connections.json")
        self.groupsURL = veloDir.appendingPathComponent("ssh_groups.json")
        
        loadConnections()
        loadGroups()
        updateRecentConnections()
    }
    
    // MARK: - Connection CRUD
    
    func addConnection(_ connection: SSHConnection) {
        connections.append(connection)
        saveConnections()
    }
    
    func updateConnection(_ connection: SSHConnection) {
        if let index = connections.firstIndex(where: { $0.id == connection.id }) {
            connections[index] = connection
            saveConnections()
            updateRecentConnections()
        }
    }
    
    func deleteConnection(_ connection: SSHConnection) {
        connections.removeAll { $0.id == connection.id }
        deletePassword(for: connection)
        saveConnections()
        updateRecentConnections()
    }
    
    func deleteConnections(at offsets: IndexSet) {
        let toDelete = offsets.map { connections[$0] }
        toDelete.forEach { deletePassword(for: $0) }
        connections.remove(atOffsets: offsets)
        saveConnections()
        updateRecentConnections()
    }
    
    // MARK: - Group CRUD
    
    func addGroup(_ group: SSHConnectionGroup) {
        groups.append(group)
        saveGroups()
    }
    
    func updateGroup(_ group: SSHConnectionGroup) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index] = group
            saveGroups()
        }
    }
    
    func deleteGroup(_ group: SSHConnectionGroup) {
        // Move connections to ungrouped
        for i in connections.indices {
            if connections[i].groupId == group.id {
                connections[i].groupId = nil
            }
        }
        groups.removeAll { $0.id == group.id }
        saveConnections()
        saveGroups()
    }
    
    func connections(in group: SSHConnectionGroup?) -> [SSHConnection] {
        connections.filter { $0.groupId == group?.id }
    }
    
    func ungroupedConnections() -> [SSHConnection] {
        connections.filter { $0.groupId == nil }
    }
    
    // MARK: - Connection Actions
    
    func markAsConnected(_ connection: SSHConnection) {
        var updated = connection
        updated.lastConnected = Date()
        updateConnection(updated)
    }
    
    // MARK: - Import
    
    func importFromSSHConfig() -> Int {
        let imported = SSHConfigParser.parseConfig()
        var count = 0
        
        for conn in imported {
            // Skip if duplicate host exists
            if !connections.contains(where: { $0.host == conn.host && $0.username == conn.username }) {
                addConnection(conn)
                count += 1
            }
        }
        
        return count
    }
    
    // MARK: - Keychain - Password Storage
    
    func savePassword(_ password: String, for connection: SSHConnection) {
        let key = keychainKey(for: connection)
        let data = password.data(using: .utf8)!
        
        // Delete existing
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Add new
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]
        SecItemAdd(addQuery as CFDictionary, nil)
    }
    
    func getPassword(for connection: SSHConnection) -> String? {
        let key = keychainKey(for: connection)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let password = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return password
    }
    
    func deletePassword(for connection: SSHConnection) {
        let key = keychainKey(for: connection)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    private func keychainKey(for connection: SSHConnection) -> String {
        "\(connection.username)@\(connection.host):\(connection.port)"
    }
    
    // MARK: - Persistence
    
    private func saveConnections() {
        do {
            let data = try JSONEncoder().encode(connections)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            print("Failed to save SSH connections: \(error)")
        }
    }
    
    private func loadConnections() {
        guard FileManager.default.fileExists(atPath: storageURL.path),
              let data = try? Data(contentsOf: storageURL),
              let loaded = try? JSONDecoder().decode([SSHConnection].self, from: data) else {
            return
        }
        connections = loaded
    }
    
    private func saveGroups() {
        do {
            let data = try JSONEncoder().encode(groups)
            try data.write(to: groupsURL, options: .atomic)
        } catch {
            print("Failed to save SSH groups: \(error)")
        }
    }
    
    private func loadGroups() {
        guard FileManager.default.fileExists(atPath: groupsURL.path),
              let data = try? Data(contentsOf: groupsURL),
              let loaded = try? JSONDecoder().decode([SSHConnectionGroup].self, from: data) else {
            return
        }
        groups = loaded
    }
    
    private func updateRecentConnections() {
        recentConnections = connections
            .filter { $0.lastConnected != nil }
            .sorted { ($0.lastConnected ?? .distantPast) > ($1.lastConnected ?? .distantPast) }
            .prefix(maxRecentConnections)
            .map { $0 }
    }
}

// MARK: - Connection Lookup

extension SSHManager {
    /// Find the SSHConnection matching an active terminal session.
    /// Parses the session's `activeSSHConnectionString` ("user@host" or "user@host:port")
    /// and matches it against saved connections.
    func findConnection(for session: TerminalViewModel) -> SSHConnection? {
        guard let connStr = session.activeSSHConnectionString else { return nil }
        let parts = connStr.components(separatedBy: "@")
        guard parts.count == 2 else { return nil }

        let username = parts[0]
        let hostAndPort = parts[1]
        let host = hostAndPort.components(separatedBy: ":").first ?? hostAndPort

        return connections.first {
            $0.host.lowercased() == host.lowercased() &&
            $0.username.lowercased() == username.lowercased()
        }
    }
}

// MARK: - Environment Key
struct SSHManagerKey: EnvironmentKey {
    @MainActor
    static let defaultValue = SSHManager()
}

extension EnvironmentValues {
    var sshManager: SSHManager {
        get { self[SSHManagerKey.self] }
        set { self[SSHManagerKey.self] = newValue }
    }
}
