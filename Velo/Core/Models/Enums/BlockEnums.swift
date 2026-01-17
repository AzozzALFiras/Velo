//
//  BlockEnums.swift
//  Velo
//
//  Enums for Command Block status and actions.
//

import SwiftUI

public enum BlockStatus: String, Codable, Sendable {
    case idle
    case running
    case success
    case error
    
    public var icon: String {
        switch self {
        case .idle: return "circle"
        case .running: return "circle.dotted"
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        }
    }
    
    public var color: Color {
        switch self {
        case .idle: return ColorTokens.textTertiary
        case .running: return ColorTokens.warning
        case .success: return ColorTokens.success
        case .error: return ColorTokens.error
        }
    }
}

public enum BlockAction: String, CaseIterable, Sendable {
    case retry = "Retry"
    case copy = "Copy"
    case copyOutput = "Copy Output"
    case explain = "Explain"
    case fix = "Fix"
    case delete = "Delete"
    case pin = "Pin"
    
    public var icon: String {
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
    
    public var isDestructive: Bool {
        self == .delete
    }
    
    public static func actions(for status: BlockStatus) -> [BlockAction] {
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
