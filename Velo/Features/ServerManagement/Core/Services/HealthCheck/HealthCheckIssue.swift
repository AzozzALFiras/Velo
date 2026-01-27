//
//  HealthCheckIssue.swift
//  Velo
//
//  Model representing a detected server health issue.
//

import Foundation

/// Represents a detected health issue on the server
struct HealthCheckIssue: Identifiable, Equatable {
    let id: String
    let severity: Severity
    let title: String
    let description: String
    let affectedOS: [String]
    let canAutoFix: Bool
    let fixDescription: String?
    
    enum Severity: String, CaseIterable {
        case critical
        case warning
        case info
        
        var icon: String {
            switch self {
            case .critical: return "xmark.octagon.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            }
        }
        
        var colorName: String {
            switch self {
            case .critical: return "red"
            case .warning: return "yellow"
            case .info: return "blue"
            }
        }
    }
    
    static func == (lhs: HealthCheckIssue, rhs: HealthCheckIssue) -> Bool {
        lhs.id == rhs.id
    }
}

/// Definition of a health check to run
struct HealthCheck {
    let id: String
    let osTypes: [String]  // ["ubuntu", "debian", "centos", "rocky", "almalinux", "all"]
    let checkCommand: String
    let expectedOutput: String  // Simple comparison, or "<90" for numeric
    let issue: HealthCheckIssue
    let fixCommands: [String]
    
    /// Check if this health check applies to the given OS
    func appliesTo(os: String) -> Bool {
        if osTypes.contains("all") { return true }
        let osLower = os.lowercased()
        return osTypes.contains { osLower.contains($0.lowercased()) }
    }
    
    /// Evaluate if the check output indicates a problem
    func hasProblem(output: String) -> Bool {
        // Strip ANSI escape codes and clean the output
        let ansiPattern = "\\x1B\\[[0-9;]*[a-zA-Z]"
        let bracketPattern = "\\[\\?[0-9]+[a-zA-Z]"
        
        var cleaned = output
        if let regex = try? NSRegularExpression(pattern: ansiPattern) {
            cleaned = regex.stringByReplacingMatches(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: "")
        }
        if let regex = try? NSRegularExpression(pattern: bracketPattern) {
            cleaned = regex.stringByReplacingMatches(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned), withTemplate: "")
        }
        cleaned = cleaned.replacingOccurrences(of: "\u{001B}", with: "")
        
        // Get first non-empty line as the result
        let lines = cleaned.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }
        let trimmed = lines.first(where: { !$0.isEmpty }) ?? ""
        
        // Numeric comparison (e.g., "<90")
        if expectedOutput.hasPrefix("<"), let threshold = Int(expectedOutput.dropFirst()) {
            if let value = Int(trimmed) {
                return value >= threshold
            }
            return true // Can't parse = assume problem
        }
        
        // Numeric comparison (e.g., ">0")
        if expectedOutput.hasPrefix(">"), let threshold = Int(expectedOutput.dropFirst()) {
            if let value = Int(trimmed) {
                return value <= threshold
            }
            return true // Can't parse = assume problem
        }
        
        // Exact match expected
        return trimmed != expectedOutput
    }
}
