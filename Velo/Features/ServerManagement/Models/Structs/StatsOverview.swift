import Foundation

public struct TrafficPoint: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let upstreamKB: Double
    public let downstreamKB: Double
    
    public init(timestamp: Date, upstreamKB: Double, downstreamKB: Double) {
        self.timestamp = timestamp
        self.upstreamKB = upstreamKB
        self.downstreamKB = downstreamKB
    }
}

public struct OverviewCounts {
    public var sites: Int
    public var ftp: Int
    public var databases: Int
    public var security: Int
    
    public init(sites: Int, ftp: Int, databases: Int, security: Int) {
        self.sites = sites
        self.ftp = ftp
        self.databases = databases
        self.security = security
    }
}
