//
//  ServiceType.swift
//  Velo
//
//  Classification of server services.
//

import Foundation

public enum ServiceType: String, CaseIterable, Codable, Sendable {
    case webServer
    case database
    case runtime
    case cache
    case other

    public var displayName: String {
        switch self {
        case .webServer: return "Web Server"
        case .database: return "Database"
        case .runtime: return "Runtime"
        case .cache: return "Cache"
        case .other: return "Other"
        }
    }

    public var iconName: String {
        switch self {
        case .webServer: return "network"
        case .database: return "cylinder.split.1x2"
        case .runtime: return "terminal"
        case .cache: return "bolt.horizontal"
        case .other: return "cube.box"
        }
    }
}
