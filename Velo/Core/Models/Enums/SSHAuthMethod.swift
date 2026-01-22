//
//  SSHAuthMethod.swift
//  Velo
//
//  Authentication methods for SSH connections.
//

import SwiftUI

public enum SSHAuthMethod: String, Codable, CaseIterable, Identifiable, Sendable {
    case password = "password"
    case privateKey = "privateKey"
    case sshAgent = "sshAgent"
    
    public var id: String { rawValue }
    
    public var displayName: String {
        switch self {
        case .password: return "Password"
        case .privateKey: return "Private Key"
        case .sshAgent: return "SSH Agent"
        }
    }
    
    public var icon: String {
        switch self {
        case .password: return "key.fill"
        case .privateKey: return "doc.text.fill"
        case .sshAgent: return "person.badge.key.fill"
        }
    }
}
