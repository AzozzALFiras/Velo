//
//  ServerStats.swift
//  Velo
//
//  Unified model for system statistics gathered from the server.
//

import Foundation

public struct ServerStats: Identifiable, Codable {
    public let id = UUID()
    
    // System Identification
    public var hostname: String = ""
    public var ipAddress: String = ""
    public var osName: String = ""
    public var uptime: String = ""
    public var isOnline: Bool = false
    
    // Resource Usage (0.0 to 1.0)
    public var cpuUsage: Double = 0
    public var ramUsage: Double = 0
    public var diskUsage: Double = 0
    public var loadAverage: Double = 0
    
    // Detailed Stats
    public var ramTotalMB: Int = 0
    public var ramUsedMB: Int = 0
    public var diskTotal: String = ""
    public var diskUsed: String = ""
    public var diskAvailable: String = ""
    
    public init() {}
}

public struct MemoryStats: Codable {
    public let totalMB: Int
    public let usedMB: Int
    public let freeMB: Int
    public let availableMB: Int
    public let usagePercent: Double
}

public struct DiskStats: Codable {
    public let totalFormatted: String
    public let usedFormatted: String
    public let availableFormatted: String
    public let usagePercent: Double
}

public struct OSInfo: Codable {
    public var prettyName: String = ""
    public var id: String = ""
    public var versionId: String = ""
    public var kernelVersion: String = ""
    
    public init() {}
}

public struct NetworkStats: Codable {
    public let rxBytes: Int64
    public let rxPackets: Int64
    public let txBytes: Int64
    public let txPackets: Int64

    public var rxKB: Double { Double(rxBytes) / 1024.0 }
    public var txKB: Double { Double(txBytes) / 1024.0 }
    public var rxMB: Double { Double(rxBytes) / (1024.0 * 1024.0) }
    public var txMB: Double { Double(txBytes) / (1024.0 * 1024.0) }
}

public struct ServerProcessItem: Identifiable, Codable {
    public let id = UUID()
    public let user: String
    public let pid: Int
    public let cpuPercent: Double
    public let memPercent: Double
    public let command: String
}
