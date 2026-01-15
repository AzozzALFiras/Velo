//
//  CommandBlock.swift
//  Velo
//
//  Workspace Redesign - Command Block Model
//  Represents an executed command with its output and status
//

import SwiftUI

// MARK: - Block Status

/// Represents the execution status of a command block
enum BlockStatus: String, Codable, Sendable {
    case idle
    case running
    case success
    case error
    
    var icon: String {
        switch self {
        case .idle: return "circle"
        case .running: return "circle.dotted"
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .idle: return ColorTokens.textTertiary
        case .running: return ColorTokens.warning
        case .success: return ColorTokens.success
        case .error: return ColorTokens.error
        }
    }
}

// MARK: - Command Block Model

/// Observable model representing a single command execution block
/// Uses Swift 6 Observation framework for high-performance reactivity
@Observable
final class CommandBlock: Identifiable, @unchecked Sendable {
    
    // MARK: - Identity
    
    let id: UUID
    
    // MARK: - Command Data
    
    var command: String
    var output: [OutputLine]
    var status: BlockStatus
    var exitCode: Int32?
    var workingDirectory: String
    
    // MARK: - Timing
    
    var startTime: Date
    var endTime: Date?
    
    // MARK: - UI State
    
    var isCollapsed: Bool
    var isHovered: Bool
    
    // MARK: - Computed Properties
    
    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }
    
    var formattedDuration: String {
        let dur = duration
        if dur < 1 {
            return String(format: "%.0fms", dur * 1000)
        } else if dur < 60 {
            return String(format: "%.1fs", dur)
        } else {
            let minutes = Int(dur / 60)
            let seconds = Int(dur.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(seconds)s"
        }
    }
    
    var isSuccess: Bool {
        status == .success
    }
    
    var isError: Bool {
        status == .error
    }
    
    var isRunning: Bool {
        status == .running
    }
    
    var outputLineCount: Int {
        output.count
    }
    
    var shouldShowCollapse: Bool {
        outputLineCount > 20
    }
    
    var visibleOutput: [OutputLine] {
        if isCollapsed && shouldShowCollapse {
            return Array(output.prefix(5))
        }
        return output
    }
    
    var hasErrorLines: Bool {
        output.contains { $0.isError }
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        command: String,
        output: [OutputLine] = [],
        status: BlockStatus = .idle,
        exitCode: Int32? = nil,
        workingDirectory: String = "",
        startTime: Date = Date(),
        endTime: Date? = nil,
        isCollapsed: Bool = false
    ) {
        self.id = id
        self.command = command
        self.output = output
        self.status = status
        self.exitCode = exitCode
        self.workingDirectory = workingDirectory
        self.startTime = startTime
        self.endTime = endTime
        self.isCollapsed = isCollapsed
        self.isHovered = false
    }
    
    // MARK: - Factory Methods
    
    /// Create a block from a CommandModel (for migration/compatibility)
    static func from(_ model: CommandModel) -> CommandBlock {
        CommandBlock(
            id: model.id,
            command: model.command,
            output: model.output.components(separatedBy: "\n").map { line in
                OutputLine(text: line, isError: false)
            },
            status: model.isSuccess ? .success : .error,
            exitCode: model.exitCode,
            workingDirectory: model.workingDirectory,
            startTime: model.timestamp,
            endTime: model.timestamp.addingTimeInterval(model.duration)
        )
    }
    
    // MARK: - Actions
    
    func appendOutput(_ line: OutputLine) {
        output.append(line)
    }
    
    func appendOutput(text: String, isError: Bool = false) {
        let line = OutputLine(text: text, isError: isError)
        output.append(line)
    }
    
    func complete(exitCode: Int32) {
        self.exitCode = exitCode
        self.endTime = Date()
        self.status = exitCode == 0 ? .success : .error
    }
    
    func toggleCollapse() {
        isCollapsed.toggle()
    }
    
    func clearOutput() {
        output.removeAll()
    }
}

// MARK: - Block Action

/// Actions that can be performed on a command block
enum BlockAction: String, CaseIterable {
    case retry = "Retry"
    case copy = "Copy"
    case copyOutput = "Copy Output"
    case explain = "Explain"
    case fix = "Fix"
    case delete = "Delete"
    case pin = "Pin"
    
    var icon: String {
        switch self {
        case .retry: return "arrow.clockwise"
        case .copy: return "doc.on.doc"
        case .copyOutput: return "doc.on.clipboard"
        case .explain: return "questionmark.circle"
        case .fix: return "wrench.and.screwdriver"
        case .delete: return "trash"
        case .pin: return "pin"
        }
    }
    
    var isDestructive: Bool {
        self == .delete
    }
    
    /// Actions shown based on block status
    static func actions(for status: BlockStatus) -> [BlockAction] {
        switch status {
        case .idle, .running:
            return [.copy]
        case .success:
            return [.retry, .copy, .copyOutput, .explain]
        case .error:
            return [.retry, .fix, .explain, .copy, .copyOutput]
        }
    }
}
