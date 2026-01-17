//
//  PHPModels.swift
//  Velo
//
//  Models and Enums for PHP management.
//

import Foundation

// MARK: - PHPConfigValue

/// Represents a PHP configuration value with metadata
struct PHPConfigValue: Identifiable, Equatable {
    let id = UUID()
    let key: String
    let value: String
    let displayName: String
    let description: String
    let type: ConfigValueType
    
    enum ConfigValueType {
        case size       // e.g., upload_max_filesize
        case time       // e.g., max_execution_time
        case number     // e.g., max_input_vars
        case boolean    // e.g., display_errors
        case string     // e.g., date.timezone
    }
}

// MARK: - PHPExtension

/// Represents a PHP extension with its status
struct PHPExtension: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let isLoaded: Bool
    let isCore: Bool
}

// MARK: - PHPDetailSection

/// Represents a section in the PHP detail sidebar
enum PHPDetailSection: String, CaseIterable, Identifiable {
    case service = "Service"
    case extensions = "Extensions"
    case disabledFunctions = "Disabled Functions"
    case configuration = "Configuration"
    case uploadLimits = "Upload Limits"
    case timeouts = "Timeouts"
    case configFile = "Config File"
    case fpmProfile = "FPM Profile"
    case logs = "Logs"
    case phpinfo = "PHP Info"
    
    var id: String { rawValue }

    
    var icon: String {
        switch self {
        case .service: return "power"
        case .extensions: return "puzzlepiece.extension"
        case .disabledFunctions: return "xmark.circle"
        case .configuration: return "gearshape"
        case .uploadLimits: return "arrow.up.doc"
        case .timeouts: return "clock"
        case .configFile: return "doc.text"
        case .fpmProfile: return "cpu"
        case .logs: return "doc.plaintext"
        case .phpinfo: return "info.circle"
        }
    }
}
