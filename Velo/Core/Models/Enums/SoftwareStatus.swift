import Foundation
import SwiftUI

/// Status of a software package on the server
public enum SoftwareStatus: Equatable, Codable {
    case notInstalled
    case installed(version: String)
    case running(version: String)
    case stopped(version: String)
    case error(message: String)
    case unknown
    
    // Custom coding to handle associated values
    private enum CodingKeys: String, CodingKey {
        case type, version, message
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "notInstalled":
            self = .notInstalled
        case "installed":
            let version = try container.decode(String.self, forKey: .version)
            self = .installed(version: version)
        case "running":
            let version = try container.decode(String.self, forKey: .version)
            self = .running(version: version)
        case "stopped":
            let version = try container.decode(String.self, forKey: .version)
            self = .stopped(version: version)
        case "error":
            let message = try container.decode(String.self, forKey: .message)
            self = .error(message: message)
        case "unknown":
            self = .unknown
        default:
            self = .unknown
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .notInstalled:
            try container.encode("notInstalled", forKey: .type)
        case .installed(let version):
            try container.encode("installed", forKey: .type)
            try container.encode(version, forKey: .version)
        case .running(let version):
            try container.encode("running", forKey: .type)
            try container.encode(version, forKey: .version)
        case .stopped(let version):
            try container.encode("stopped", forKey: .type)
            try container.encode(version, forKey: .version)
        case .error(let message):
            try container.encode("error", forKey: .type)
            try container.encode(message, forKey: .message)
        case .unknown:
            try container.encode("unknown", forKey: .type)
        }
    }
    
    public var isInstalled: Bool {
        switch self {
        case .notInstalled: return false
        default: return true
        }
    }
    
    public var isRunning: Bool {
        if case .running = self { return true }
        return false
    }
    
    public var version: String? {
        switch self {
        case .installed(let v), .running(let v), .stopped(let v): return v
        default: return nil
        }
    }
    
    public var displayText: String {
        switch self {
        case .notInstalled: return "Not Installed"
        case .installed(let v): return "v\(v)"
        case .running(let v): return "v\(v) • Running"
        case .stopped(let v): return "v\(v) • Stopped"
        case .error(let msg): return "Error: \(msg)"
        case .unknown: return "Unknown"
        }
    }
    
    public var statusColor: Color {
        switch self {
        case .notInstalled: return .gray
        case .installed: return .blue
        case .running: return .green
        case .stopped: return .orange
        case .error, .unknown: return .red
        }
    }
}
