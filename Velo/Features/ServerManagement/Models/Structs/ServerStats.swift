import Foundation

public struct ServerStats: Identifiable {
    public let id = UUID()
    public var cpuUsage: Double // 0.0 to 1.0
    public var ramUsage: Double // 0.0 to 1.0
    public var diskUsage: Double // 0.0 to 1.0
    public var uptime: TimeInterval
    public var isOnline: Bool
    public var osName: String
    public var ipAddress: String
    
    public init(cpuUsage: Double, ramUsage: Double, diskUsage: Double, uptime: TimeInterval, isOnline: Bool, osName: String, ipAddress: String) {
        self.cpuUsage = cpuUsage
        self.ramUsage = ramUsage
        self.diskUsage = diskUsage
        self.uptime = uptime
        self.isOnline = isOnline
        self.osName = osName
        self.ipAddress = ipAddress
    }
    
    public var uptimeString: String {
        let days = Int(uptime) / 86400
        let hours = (Int(uptime) % 86400) / 3600
        return "\(days)d \(hours)h"
    }
}
