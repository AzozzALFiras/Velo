//
//  CommandModel.swift
//  Velo
//
//  AI-Powered Terminal - Command Data Model
//

import Foundation

// MARK: - Command Model
/// Represents a single terminal command with its execution context and metadata
struct CommandModel: Identifiable, Codable, Hashable {
    let id: UUID
    var command: String
    var output: String
    var exitCode: Int32
    var timestamp: Date
    var duration: TimeInterval
    var workingDirectory: String
    var sessionId: UUID
    var tags: [String]
    var context: CommandContext
    var frequency: Int
    
    init(
        id: UUID = UUID(),
        command: String,
        output: String = "",
        exitCode: Int32 = 0,
        timestamp: Date = Date(),
        duration: TimeInterval = 0,
        workingDirectory: String = "",
        sessionId: UUID = UUID(),
        tags: [String] = [],
        context: CommandContext = .general,
        frequency: Int = 1
    ) {
        self.id = id
        self.command = command
        self.output = output
        self.exitCode = exitCode
        self.timestamp = timestamp
        self.duration = duration
        self.workingDirectory = workingDirectory
        self.sessionId = sessionId
        self.tags = tags
        self.context = context
        self.frequency = frequency
    }
    
    var isSuccess: Bool {
        exitCode == 0
    }
    
    var formattedDuration: String {
        if duration < 1 {
            return String(format: "%.0fms", duration * 1000)
        } else if duration < 60 {
            return String(format: "%.1fs", duration)
        } else {
            let minutes = Int(duration / 60)
            let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(seconds)s"
        }
    }
    
    var relativeTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}

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

// MARK: - Output Line
/// Represents a single line of terminal output with ANSI formatting
struct OutputLine: Identifiable, Hashable {
    let id: UUID
    let text: String
    let attributedText: AttributedString
    let timestamp: Date
    let isError: Bool
    
    init(id: UUID = UUID(), text: String, attributedText: AttributedString? = nil, isError: Bool = false) {
        self.id = id
        self.text = text
        self.attributedText = attributedText ?? AttributedString(text)
        self.timestamp = Date()
        self.isError = isError
    }
}
