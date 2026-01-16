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
    var id = UUID()
    var domain: String
    var path: String
    var status: WebsiteStatus
    var port: Int
    var framework: String // e.g., "Node.js", "PHP", "Static"
    
    init(id: UUID = UUID(), domain: String, path: String, status: WebsiteStatus, port: Int, framework: String) {
        self.id = id
        self.domain = domain
        self.path = path
        self.status = status
        self.port = port
        self.framework = framework
    }
    
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
    var id = UUID()
    var name: String
    var type: DatabaseType
    var username: String?
    var password: String?
    var sizeBytes: Int64
    var status: DatabaseStatus
    
    init(id: UUID = UUID(), name: String, type: DatabaseType, username: String? = nil, password: String? = nil, sizeBytes: Int64, status: DatabaseStatus) {
        self.id = id
        self.name = name
        self.type = type
        self.username = username
        self.password = password
        self.sizeBytes = sizeBytes
        self.status = status
    }
    
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

// MARK: - Software Status

/// Status of a software package on the server
enum SoftwareStatus: Equatable {
    case notInstalled
    case installed(version: String)
    case running(version: String)
    case stopped(version: String)
    case error(message: String)
    
    var isInstalled: Bool {
        switch self {
        case .notInstalled: return false
        default: return true
        }
    }
    
    var isRunning: Bool {
        if case .running = self { return true }
        return false
    }
    
    var version: String? {
        switch self {
        case .installed(let v), .running(let v), .stopped(let v): return v
        default: return nil
        }
    }
    
    var displayText: String {
        switch self {
        case .notInstalled: return "Not Installed"
        case .installed(let v): return "v\(v)"
        case .running(let v): return "v\(v) • Running"
        case .stopped(let v): return "v\(v) • Stopped"
        case .error(let msg): return "Error: \(msg)"
        }
    }
    
    var statusColor: Color {
        switch self {
        case .notInstalled: return .gray
        case .installed: return .blue
        case .running: return .green
        case .stopped: return .orange
        case .error: return .red
        }
    }
}

// MARK: - Server Status

/// Complete status of all detectable software on the server
struct ServerStatus {
    // Web Servers
    var nginx: SoftwareStatus = .notInstalled
    var apache: SoftwareStatus = .notInstalled
    var litespeed: SoftwareStatus = .notInstalled
    
    // Databases
    var mysql: SoftwareStatus = .notInstalled
    var mariadb: SoftwareStatus = .notInstalled
    var postgresql: SoftwareStatus = .notInstalled
    var redis: SoftwareStatus = .notInstalled
    var mongodb: SoftwareStatus = .notInstalled
    
    // Runtimes
    var php: SoftwareStatus = .notInstalled
    var python: SoftwareStatus = .notInstalled
    var nodejs: SoftwareStatus = .notInstalled
    
    // Tools
    var composer: SoftwareStatus = .notInstalled
    var npm: SoftwareStatus = .notInstalled
    var git: SoftwareStatus = .notInstalled
    
    // Computed properties
    var hasWebServer: Bool {
        nginx.isInstalled || apache.isInstalled || litespeed.isInstalled
    }
    
    var hasDatabase: Bool {
        mysql.isInstalled || mariadb.isInstalled || postgresql.isInstalled
    }
    
    var hasRuntime: Bool {
        php.isInstalled || python.isInstalled || nodejs.isInstalled
    }
    
    var activeWebServer: String? {
        if nginx.isRunning { return "Nginx" }
        if apache.isRunning { return "Apache" }
        if litespeed.isRunning { return "LiteSpeed" }
        if nginx.isInstalled { return "Nginx" }
        if apache.isInstalled { return "Apache" }
        if litespeed.isInstalled { return "LiteSpeed" }
        return nil
    }
    
    var installedDatabases: [String] {
        var dbs: [String] = []
        if mysql.isInstalled { dbs.append("MySQL") }
        if mariadb.isInstalled { dbs.append("MariaDB") }
        if postgresql.isInstalled { dbs.append("PostgreSQL") }
        if redis.isInstalled { dbs.append("Redis") }
        if mongodb.isInstalled { dbs.append("MongoDB") }
        return dbs
    }
    
    var installedRuntimes: [String] {
        var runtimes: [String] = []
        if php.isInstalled { runtimes.append("PHP") }
        if python.isInstalled { runtimes.append("Python") }
        if nodejs.isInstalled { runtimes.append("Node.js") }
        return runtimes
    }
}

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

// MARK: - Capability Models

struct Capability: Identifiable, Codable {
    let id: Int
    let name: String
    let slug: String
    let icon: String // URL string
    let color: String // Hex string
    let category: String
    let isEnabled: Bool
    let description: String
    let defaultVersion: CapabilityVersion?
    let versions: [CapabilityVersion]?
}

struct CapabilityVersion: Identifiable, Codable {
    let versionId: Int?  // API may not always provide id
    let version: String
    let stability: String
    let releaseDate: String?
    let eolDate: String?
    let recommendedUsage: String?
    let isDefault: Bool
    let installCommands: [String: [String: String]]? // OS -> Type -> Command
    let features: [CapabilityFeature]?
    
    // Computed id for Identifiable conformance
    var id: String { version }
    
    // Custom decoding to handle missing id
    enum CodingKeys: String, CodingKey {
        case versionId = "id"
        case version, stability, releaseDate, eolDate, recommendedUsage, isDefault, installCommands, features
    }
}

struct CapabilityFeature: Identifiable, Codable {
    let featureId: Int?  // API may not always provide id
    let name: String
    let slug: String
    let icon: String?
    let description: String?
    let isOptional: Bool?
    let status: String?
    
    var id: String { slug }
    
    enum CodingKeys: String, CodingKey {
        case featureId = "id"
        case name, slug, icon, description, isOptional, status
    }
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
    case applications
    case settings
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .home: return "Home"
        case .websites: return "Websites"
        case .databases: return "Databases"
        case .files: return "Files"
        case .applications: return "Applications"
        case .settings: return "Settings"
        }
    }
    
    public var icon: String {
        switch self {
        case .home: return "house"
        case .websites: return "globe"
        case .databases: return "cylinder.split.1x2"
        case .files: return "folder"
        case .applications: return "square.grid.2x2"
        case .settings: return "gearshape"
        }
    }
}
