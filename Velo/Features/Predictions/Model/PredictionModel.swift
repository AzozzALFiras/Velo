//
//  PredictionModel.swift
//  Velo
//
//  AI-Powered Terminal - Prediction Data Model
//

import Foundation

// MARK: - Prediction Model
/// Represents an AI-generated command prediction/suggestion
struct PredictionModel: Identifiable, Hashable {
    let id: UUID
    let suggestedCommand: String
    let confidence: Double
    let reason: String
    let source: PredictionSource
    let timestamp: Date
    
    init(
        id: UUID = UUID(),
        suggestedCommand: String,
        confidence: Double,
        reason: String,
        source: PredictionSource,
        timestamp: Date = Date()
    ) {
        self.id = id
        self.suggestedCommand = suggestedCommand
        self.confidence = min(1.0, max(0.0, confidence))
        self.reason = reason
        self.source = source
        self.timestamp = timestamp
    }
    
    var confidencePercentage: Int {
        Int(confidence * 100)
    }
    
    var confidenceLevel: ConfidenceLevel {
        switch confidence {
        case 0.8...1.0: return .high
        case 0.5..<0.8: return .medium
        default: return .low
        }
    }
}

// MARK: - Prediction Source
/// Where the prediction originated from
enum PredictionSource: String, Codable, CaseIterable {
    case recent = "Recent"
    case frequent = "Frequent"
    case contextual = "Contextual"
    case sequential = "Sequential"
    case ai = "AI"
    
    var icon: String {
        switch self {
        case .recent: return "clock"
        case .frequent: return "flame"
        case .contextual: return "scope"
        case .sequential: return "arrow.right.circle"
        case .ai: return "brain"
        }
    }
    
    var description: String {
        switch self {
        case .recent: return "Recently used"
        case .frequent: return "Frequently used"
        case .contextual: return "Based on context"
        case .sequential: return "Common follow-up"
        case .ai: return "AI suggestion"
        }
    }
}

// MARK: - Confidence Level
enum ConfidenceLevel {
    case high, medium, low
    
    var color: String {
        switch self {
        case .high: return "#00FF88"
        case .medium: return "#FFD60A"
        case .low: return "#FF6B6B"
        }
    }
}

// MARK: - Command Suggestion
/// Lightweight suggestion for autocomplete dropdown
struct CommandSuggestion: Identifiable, Hashable {
    let id: UUID
    let command: String
    let description: String
    let matchRange: Range<String.Index>?
    let source: PredictionSource
    let priority: Int
    
    init(
        id: UUID = UUID(),
        command: String,
        description: String = "",
        matchRange: Range<String.Index>? = nil,
        source: PredictionSource = .recent,
        priority: Int = 0
    ) {
        self.id = id
        self.command = command
        self.description = description
        self.matchRange = matchRange
        self.source = source
        self.priority = priority
    }
}

// MARK: - Command Explanation
/// AI-generated explanation for a command
struct CommandExplanation: Identifiable {
    let id: UUID
    let command: String
    let summary: String
    let breakdown: [ExplanationPart]
    let relatedCommands: [String]
    let warnings: [String]
    let tips: [String]
    
    init(
        id: UUID = UUID(),
        command: String,
        summary: String,
        breakdown: [ExplanationPart] = [],
        relatedCommands: [String] = [],
        warnings: [String] = [],
        tips: [String] = []
    ) {
        self.id = id
        self.command = command
        self.summary = summary
        self.breakdown = breakdown
        self.relatedCommands = relatedCommands
        self.warnings = warnings
        self.tips = tips
    }
}

// MARK: - Explanation Part
/// Part of a command breakdown
struct ExplanationPart: Identifiable {
    let id: UUID
    let token: String
    let explanation: String
    let type: TokenType
    
    init(id: UUID = UUID(), token: String, explanation: String, type: TokenType) {
        self.id = id
        self.token = token
        self.explanation = explanation
        self.type = type
    }
}

// MARK: - Token Type
enum TokenType: String {
    case command = "command"
    case flag = "flag"
    case argument = "argument"
    case path = "path"
    case option = "option"
    case pipe = "pipe"
    case redirect = "redirect"
    
    var color: String {
        switch self {
        case .command: return "#00F5FF"
        case .flag: return "#BF40BF"
        case .argument: return "#FFD60A"
        case .path: return "#00FF88"
        case .option: return "#FF6B6B"
        case .pipe, .redirect: return "#888888"
        }
    }
}
