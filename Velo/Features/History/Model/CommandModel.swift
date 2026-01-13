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
