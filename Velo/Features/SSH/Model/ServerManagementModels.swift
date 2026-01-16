//
//  ServerManagementModels.swift
//  Velo
//
//  Models for the Server Management UI (SSH Feature)
//  Includes ServerStats, Website, Database and mock data generators.
//

import Foundation
import SwiftUI

// MARK: - Server Stats

struct ServerStats: Identifiable {
    let id = UUID()
    var cpuUsage: Double // 0.0 to 1.0
    var ramUsage: Double // 0.0 to 1.0
    var diskUsage: Double // 0.0 to 1.0
    var uptime: TimeInterval
    var isOnline: Bool
    var osName: String
    var ipAddress: String
    
    var uptimeString: String {
        let days = Int(uptime) / 86400
        let hours = (Int(uptime) % 86400) / 3600
        return "\(days)d \(hours)h"
    }
}

// MARK: - Website Model

struct Website: Identifiable {
    let id = UUID()
    var domain: String
    var path: String
    var status: WebsiteStatus
    var port: Int
    var framework: String // e.g., "Node.js", "PHP", "Static"
    
    enum WebsiteStatus: String, CaseIterable {
        case running
        case stopped
        case error
        
        var title: String { rawValue.capitalized }
        
        var color: Color {
            switch self {
            case .running: return .green
            case .stopped: return .gray
            case .error: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .running: return "play.circle.fill"
            case .stopped: return "stop.circle.fill"
            case .error: return "exclamationmark.triangle.fill"
            }
        }
    }
}

// MARK: - Database Model

struct Database: Identifiable {
    let id = UUID()
    var name: String
    var type: DatabaseType
    var sizeBytes: Int64
    var status: DatabaseStatus
    
    var sizeString: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
    
    enum DatabaseType: String, CaseIterable {
        case mysql = "MySQL"
        case postgres = "PostgreSQL"
        case redis = "Redis"
        case mongo = "MongoDB"
        
        var icon: String {
            switch self {
            case .mysql, .postgres: return "cylinder.split.1x2"
            case .redis: return "bolt.horizontal.circle"
            case .mongo: return "leaf"
            }
        }
    }
    
    enum DatabaseStatus: String {
        case active
        case maintenance
        
        var color: Color {
            switch self {
            case .active: return .green
            case .maintenance: return .orange
            }
        }
    }
}

// MARK: - Mock Data Generator

// MARK: - New Dashboard Models

struct InstalledSoftware: Identifiable {
    let id = UUID()
    let name: String
    let version: String
    let iconName: String // Custom asset or SF Symbol
    let isRunning: Bool
}

struct TrafficPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let upstreamKB: Double
    let downstreamKB: Double
}

struct OverviewCounts {
    var sites: Int
    var ftp: Int
    var databases: Int
    var security: Int
}

// MARK: - File Model

public struct ServerFileItem: Identifiable, Hashable {
    public let id = UUID()
    public var name: String
    public var isDirectory: Bool
    public var sizeBytes: Int64
    public var permissions: String // e.g., "755"
    public var modificationDate: Date
    public var owner: String
    
    public var numericPermissions: Int {
        Int(permissions) ?? 644
    }
    
    // Symbolic representation helper (e.g., rwxr-xr-x)
    public var symbolicPermissions: String {
        let p = numericPermissions
        let owner = formatTrip(p / 100)
        let group = formatTrip((p / 10) % 10)
        let world = formatTrip(p % 10)
        return (isDirectory ? "d" : "-") + owner + group + world
    }
    
    private func formatTrip(_ n: Int) -> String {
        let r = (n & 4) != 0 ? "r" : "-"
        let w = (n & 2) != 0 ? "w" : "-"
        let x = (n & 1) != 0 ? "x" : "-"
        return r + w + x
    }
    
    public var sizeString: String {
        if isDirectory { return "--" }
        return ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
    
    public var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: modificationDate)
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: ServerFileItem, rhs: ServerFileItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Upload Task Model

public struct FileUploadTask: Identifiable {
    public let id = UUID()
    public let fileName: String
    public var progress: Double // 0.0 to 1.0
    public var isCompleted: Bool = false
    public var isFailed: Bool = false
    
    public var progressPercentage: Int {
        Int(progress * 100)
    }
}

// MARK: - Mock Data Generator

struct ServerManagementMockData {
    
    static func generateStats() -> ServerStats {
        return ServerStats(
            cpuUsage: Double.random(in: 0.1...0.3), // Lower mock values for realism
            ramUsage: Double.random(in: 0.2...0.4),
            diskUsage: Double.random(in: 0.2...0.6),
            uptime: TimeInterval(Int.random(in: 86400...5000000)),
            isOnline: true,
            osName: "Ubuntu 22.04 LTS",
            ipAddress: "192.168.1.\(Int.random(in: 2...254))"
        )
    }
    
    static func generateWebsites() -> [Website] {
        return [
            Website(domain: "velo-app.com", path: "/var/www/velo", status: .running, port: 8080, framework: "Next.js"),
            Website(domain: "api.velo.io", path: "/var/www/api", status: .running, port: 3000, framework: "Node.js"),
            Website(domain: "staging.blog.com", path: "/var/www/blog_staging", status: .stopped, port: 8081, framework: "WordPress"),
            Website(domain: "docs.internal", path: "/opt/docs", status: .error, port: 4000, framework: "Docusaurus")
        ]
    }
    
    static func generateDatabases() -> [Database] {
        return [
            Database(name: "velo_production", type: .postgres, sizeBytes: 1024 * 1024 * 540, status: .active),
            Database(name: "users_redis", type: .redis, sizeBytes: 1024 * 1024 * 24, status: .active),
            Database(name: "logs_archive", type: .mongo, sizeBytes: 1024 * 1024 * 1024 * 2, status: .active),
            Database(name: "legacy_wp", type: .mysql, sizeBytes: 1024 * 1024 * 150, status: .maintenance)
        ]
    }
    
    static func generateSoftwareList() -> [InstalledSoftware] {
        return [
            InstalledSoftware(name: "Nginx", version: "1.24.0", iconName: "network", isRunning: true), // network ~ globe
            InstalledSoftware(name: "PHP 8.2", version: "8.2.11", iconName: "scroll", isRunning: true), // scroll ` script
            InstalledSoftware(name: "MySQL", version: "8.0", iconName: "cylinder.split.1x2", isRunning: true),
            InstalledSoftware(name: "Redis", version: "7.0", iconName: "bolt.horizontal", isRunning: true),
            InstalledSoftware(name: "Docker", version: "24.0", iconName: "shippingbox", isRunning: false)
        ]
    }
    
    static func generateTrafficHistory() -> [TrafficPoint] {
        let now = Date()
        var history: [TrafficPoint] = []
        for i in 0..<30 {
            let time = now.addingTimeInterval(Double(-30 + i) * 60)
            history.append(TrafficPoint(
                timestamp: time,
                upstreamKB: Double.random(in: 2...15),
                downstreamKB: Double.random(in: 10...50)
            ))
        }
        return history
    }
    
    static func generateOverviewCounts() -> OverviewCounts {
        OverviewCounts(
            sites: Int.random(in: 10...30),
            ftp: Int.random(in: 0...5),
            databases: Int.random(in: 50...80),
            security: Int.random(in: 5...20)
        )
    }
    
    static func generateFiles() -> [ServerFileItem] {
        return [
            ServerFileItem(name: "var", isDirectory: true, sizeBytes: 0, permissions: "755", modificationDate: Date().addingTimeInterval(-86400 * 5), owner: "root"),
            ServerFileItem(name: "etc", isDirectory: true, sizeBytes: 0, permissions: "755", modificationDate: Date().addingTimeInterval(-86400 * 10), owner: "root"),
            ServerFileItem(name: "home", isDirectory: true, sizeBytes: 0, permissions: "755", modificationDate: Date().addingTimeInterval(-86400 * 2), owner: "root"),
            ServerFileItem(name: "bin", isDirectory: true, sizeBytes: 0, permissions: "755", modificationDate: Date().addingTimeInterval(-86400 * 30), owner: "root"),
            ServerFileItem(name: "docker-compose.yml", isDirectory: false, sizeBytes: 2048, permissions: "644", modificationDate: Date().addingTimeInterval(-3600 * 4), owner: "www-data"),
            ServerFileItem(name: "nginx.conf", isDirectory: false, sizeBytes: 4096, permissions: "644", modificationDate: Date().addingTimeInterval(-3600 * 12), owner: "root"),
            ServerFileItem(name: ".bashrc", isDirectory: false, sizeBytes: 3500, permissions: "644", modificationDate: Date().addingTimeInterval(-86400 * 100), owner: "root"),
            ServerFileItem(name: "index.php", isDirectory: false, sizeBytes: 120, permissions: "664", modificationDate: Date().addingTimeInterval(-600), owner: "www-data")
        ]
    }
}
// MARK: - Tabs Enum

public enum ServerManagementTab: String, CaseIterable, Identifiable {
    case home
    case websites
    case databases
    case files
    case settings
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .home: return "Home"
        case .websites: return "Websites"
        case .databases: return "Databases"
        case .files: return "Files"
        case .settings: return "Settings"
        }
    }
    
    public var icon: String {
        switch self {
        case .home: return "house"
        case .websites: return "globe"
        case .databases: return "cylinder.split.1x2"
        case .files: return "folder"
        case .settings: return "gearshape"
        }
    }
}
