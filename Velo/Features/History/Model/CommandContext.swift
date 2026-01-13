//
//  CommandContext.swift
//  Velo
//
//  Created by Velo AI
//

import Foundation

// MARK: - Command Context
/// Detected context/category for a command
enum CommandContext: String, Codable, CaseIterable {
    case git = "git"
    case docker = "docker"
    case npm = "npm"
    case yarn = "yarn"
    case python = "python"
    case ruby = "ruby"
    case swift = "swift"
    case xcode = "xcode"
    case filesystem = "fs"
    case network = "network"
    case system = "system"
    case general = "general"
    
    var icon: String {
        switch self {
        case .git: return "arrow.triangle.branch"
        case .docker: return "shippingbox"
        case .npm, .yarn: return "cube.box"
        case .python: return "chevron.left.forwardslash.chevron.right"
        case .ruby: return "diamond"
        case .swift, .xcode: return "swift"
        case .filesystem: return "folder"
        case .network: return "network"
        case .system: return "gearshape"
        case .general: return "terminal"
        }
    }
    
    var color: String {
        switch self {
        case .git: return "#F05032"
        case .docker: return "#2496ED"
        case .npm: return "#CB3837"
        case .yarn: return "#2C8EBB"
        case .python: return "#3776AB"
        case .ruby: return "#CC342D"
        case .swift, .xcode: return "#F05138"
        case .filesystem: return "#FFD60A"
        case .network: return "#00F5FF"
        case .system: return "#BF40BF"
        case .general: return "#FFFFFF"
        }
    }
    
    /// Detect context from command string
    static func detect(from command: String) -> CommandContext {
        let lowercased = command.lowercased().trimmingCharacters(in: .whitespaces)
        
        if lowercased.hasPrefix("git ") || lowercased == "git" {
            return .git
        } else if lowercased.hasPrefix("docker ") || lowercased.hasPrefix("docker-compose") {
            return .docker
        } else if lowercased.hasPrefix("npm ") || lowercased.hasPrefix("npx ") {
            return .npm
        } else if lowercased.hasPrefix("yarn ") {
            return .yarn
        } else if lowercased.hasPrefix("python") || lowercased.hasPrefix("pip ") || lowercased.hasPrefix("pip3 ") {
            return .python
        } else if lowercased.hasPrefix("ruby ") || lowercased.hasPrefix("gem ") || lowercased.hasPrefix("bundle ") {
            return .ruby
        } else if lowercased.hasPrefix("swift ") || lowercased.hasPrefix("xcodebuild") || lowercased.hasPrefix("xcrun") {
            return .swift
        } else if ["ls", "cd", "mkdir", "rm", "cp", "mv", "cat", "touch", "find", "chmod", "chown"].contains(where: { lowercased.hasPrefix($0) }) {
            return .filesystem
        } else if ["curl", "wget", "ping", "ssh", "scp", "netstat", "ifconfig"].contains(where: { lowercased.hasPrefix($0) }) {
            return .network
        } else if ["sudo", "brew", "apt", "yum", "systemctl", "launchctl", "ps", "kill", "top"].contains(where: { lowercased.hasPrefix($0) }) {
            return .system
        }
        
        return .general
    }
}
