//
//  IntelligenceModels.swift
//  Velo
//
//  Intelligence Feature - Data Models
//  Models for AI messages, errors, suggestions, and scripts.
//

import Foundation

// MARK: - Intelligence Tab

/// Tabs in the intelligence panel
enum IntelligenceTab: String, CaseIterable, Identifiable {
    case chat = "Chat"
    case history = "History"
    case files = "Files"
    case errors = "Errors"
    case suggestions = "Suggestions"
    case scripts = "Scripts"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right"
        case .history: return "clock.arrow.circlepath"
        case .files: return "folder"
        case .errors: return "exclamationmark.triangle"
        case .suggestions: return "lightbulb"
        case .scripts: return "scroll"
        }
    }
}

// MARK: - AI Message

struct AIMessage: Identifiable {
    let id: UUID = UUID()
    let content: String
    let isUser: Bool
    let codeBlocks: [String]
    let timestamp: Date = Date()

    init(content: String, isUser: Bool, codeBlocks: [String] = []) {
        self.content = content
        self.isUser = isUser
        self.codeBlocks = codeBlocks
    }
}

// MARK: - Error Item

struct ErrorItem: Identifiable {
    let id: UUID = UUID()
    let message: String
    let command: String
    let timestamp: Date
}

// MARK: - Suggestion Item

struct SuggestionItem: Identifiable {
    let id: UUID = UUID()
    let command: String
    let reason: String
}

// MARK: - Auto Script

struct AutoScript: Identifiable {
    let id: UUID = UUID()
    let name: String
    let commands: [String]
}
