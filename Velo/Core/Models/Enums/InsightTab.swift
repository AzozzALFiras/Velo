//
//  InsightTab.swift
//  Velo
//
//  Tabs for the terminal insights panel.
//

import Foundation

public enum InsightTab: String, CaseIterable, Identifiable, Sendable {
    case suggestions = "Suggestions"
    case chat = "AI Chat"
    case history = "History"
    case errors = "Errors"
    case files = "Files"
    
    public var id: String { self.rawValue }
    
    public var iconName: String {
        switch self {
        case .suggestions: return "sparkles"
        case .chat: return "bubble.left.and.bubble.right"
        case .history: return "clock"
        case .errors: return "exclamationmark.triangle"
        case .files: return "folder"
        }
    }
}
