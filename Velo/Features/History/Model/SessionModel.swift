//
//  SessionModel.swift
//  Velo
//
//  AI-Powered Terminal - Session Data Model
//

import Foundation

// MARK: - Session Model
/// Represents a terminal session containing grouped commands
struct SessionModel: Identifiable, Codable {
    let id: UUID
    var startTime: Date
    var endTime: Date?
    var commands: [CommandModel]
    var contextLabel: String
    var workingDirectory: String
    var isActive: Bool
    
    init(
        id: UUID = UUID(),
        startTime: Date = Date(),
        endTime: Date? = nil,
        commands: [CommandModel] = [],
        contextLabel: String = "Session",
        workingDirectory: String = "",
        isActive: Bool = true
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.commands = commands
        self.contextLabel = contextLabel
        self.workingDirectory = workingDirectory
        self.isActive = isActive
    }
    
    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }
    
    var formattedDuration: String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "<1m"
        }
    }
    
    var commandCount: Int {
        commands.count
    }
    
    var successRate: Double {
        guard !commands.isEmpty else { return 1.0 }
        let successCount = commands.filter { $0.isSuccess }.count
        return Double(successCount) / Double(commands.count)
    }
    
    /// Auto-detect session context from commands
    mutating func detectContext() {
        var contextCounts: [CommandContext: Int] = [:]
        
        for command in commands {
            contextCounts[command.context, default: 0] += 1
        }
        
        if let dominantContext = contextCounts.max(by: { $0.value < $1.value })?.key,
           dominantContext != .general {
            contextLabel = dominantContext.rawValue.capitalized
        } else {
            // Try to detect from working directory
            if workingDirectory.contains(".git") || workingDirectory.contains("github") {
                contextLabel = "Git Project"
            } else if workingDirectory.contains("node_modules") || workingDirectory.contains("package.json") {
                contextLabel = "Node Project"
            } else {
                contextLabel = "Terminal Session"
            }
        }
    }
}

// MARK: - Session Group
/// Groups sessions by date for display
struct SessionGroup: Identifiable {
    let id: UUID
    let date: Date
    var sessions: [SessionModel]
    
    init(date: Date, sessions: [SessionModel]) {
        self.id = UUID()
        self.date = date
        self.sessions = sessions
    }
    
    var formattedDate: String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: date)
        }
    }
}
