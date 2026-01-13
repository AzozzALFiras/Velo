//
//  SSHConnection.swift
//  Velo
//
//  SSH Connection Models
//

import Foundation
import SwiftUI

// MARK: - SSH Auth Method
enum SSHAuthMethod: String, Codable, CaseIterable, Identifiable {
    case password = "password"
    case privateKey = "privateKey"
    case sshAgent = "sshAgent"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .password: return "Password"
        case .privateKey: return "Private Key"
        case .sshAgent: return "SSH Agent"
        }
    }
    
    var icon: String {
        switch self {
        case .password: return "key.fill"
        case .privateKey: return "doc.text.fill"
        case .sshAgent: return "person.badge.key.fill"
        }
    }
}

// MARK: - SSH Connection
struct SSHConnection: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var host: String
    var port: Int
    var username: String
    var authMethod: SSHAuthMethod
    var privateKeyPath: String?
    var groupId: UUID?
    var colorHex: String
    var icon: String
    var lastConnected: Date?
    var notes: String
    
    init(
        id: UUID = UUID(),
        name: String = "",
        host: String = "",
        port: Int = 22,
        username: String = "",
        authMethod: SSHAuthMethod = .password,
        privateKeyPath: String? = nil,
        groupId: UUID? = nil,
        colorHex: String = "00F5FF",
        icon: String = "server.rack",
        lastConnected: Date? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.authMethod = authMethod
        self.privateKeyPath = privateKeyPath
        self.groupId = groupId
        self.colorHex = colorHex
        self.icon = icon
        self.lastConnected = lastConnected
        self.notes = notes
    }
    
    var displayName: String {
        name.isEmpty ? "\(username)@\(host)" : name
    }
    
    var connectionString: String {
        if port == 22 {
            return "\(username)@\(host)"
        }
        return "\(username)@\(host):\(port)"
    }
    
    var sshCommand: String {
        var cmd = "ssh"
        if port != 22 {
            cmd += " -p \(port)"
        }
        if authMethod == .privateKey, let keyPath = privateKeyPath {
            cmd += " -i \(keyPath)"
        }
        cmd += " \(username)@\(host)"
        return cmd
    }
    
    var color: Color {
        Color(hex: colorHex)
    }
}

// MARK: - SSH Connection Group
struct SSHConnectionGroup: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var colorHex: String
    var icon: String
    var isExpanded: Bool
    
    init(
        id: UUID = UUID(),
        name: String = "Default",
        colorHex: String = "A0A0B0",
        icon: String = "folder.fill",
        isExpanded: Bool = true
    ) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.icon = icon
        self.isExpanded = isExpanded
    }
    
    var color: Color {
        Color(hex: colorHex)
    }
}

// MARK: - SSH Config Parser
struct SSHConfigParser {
    static func parseConfig(at path: String = "~/.ssh/config") -> [SSHConnection] {
        let expandedPath = NSString(string: path).expandingTildeInPath
        guard let content = try? String(contentsOfFile: expandedPath, encoding: .utf8) else {
            return []
        }
        
        var connections: [SSHConnection] = []
        var currentHost: String?
        var currentHostname: String?
        var currentUser: String?
        var currentPort: Int = 22
        var currentIdentityFile: String?
        
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }
            
            let parts = trimmed.split(separator: " ", maxSplits: 1).map(String.init)
            guard parts.count >= 2 else { continue }
            
            let key = parts[0].lowercased()
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            
            switch key {
            case "host":
                // Save previous host if exists
                if let host = currentHost, let hostname = currentHostname {
                    let connection = SSHConnection(
                        name: host,
                        host: hostname,
                        port: currentPort,
                        username: currentUser ?? NSUserName(),
                        authMethod: currentIdentityFile != nil ? .privateKey : .sshAgent,
                        privateKeyPath: currentIdentityFile
                    )
                    connections.append(connection)
                }
                // Start new host
                currentHost = value
                currentHostname = nil
                currentUser = nil
                currentPort = 22
                currentIdentityFile = nil
                
            case "hostname":
                currentHostname = value
                
            case "user":
                currentUser = value
                
            case "port":
                currentPort = Int(value) ?? 22
                
            case "identityfile":
                currentIdentityFile = NSString(string: value).expandingTildeInPath
                
            default:
                break
            }
        }
        
        // Save last host
        if let host = currentHost, let hostname = currentHostname {
            let connection = SSHConnection(
                name: host,
                host: hostname,
                port: currentPort,
                username: currentUser ?? NSUserName(),
                authMethod: currentIdentityFile != nil ? .privateKey : .sshAgent,
                privateKeyPath: currentIdentityFile
            )
            connections.append(connection)
        }
        
        return connections
    }
}
