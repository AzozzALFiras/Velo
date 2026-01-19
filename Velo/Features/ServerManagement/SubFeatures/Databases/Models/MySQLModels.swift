import Foundation

enum MySQLDetailSection: String, CaseIterable, Identifiable {
    case service = "Service"
    case configuration = "Configuration"
    case databases = "Databases"
    case users = "Users"
    case status = "Status"
    case logs = "Logs"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .service: return "gearshape"
        case .configuration: return "slider.horizontal.3"
        case .databases: return "server.rack"
        case .users: return "person.2"
        case .status: return "chart.bar.xaxis"
        case .logs: return "list.bullet.rectangle"
        }
    }
}

struct DatabaseUser: Identifiable, Equatable {
    let id: String // usually "user@host"
    let username: String
    let host: String
    let privileges: String
}

struct MySQLConfigValue: Identifiable, Equatable {
    let id = UUID()
    let key: String
    var value: String
    let description: String
    let displayName: String
    let section: String?
}

struct MySQLStatusInfo {
    var version: String = ""
    var uptime: String = "0"
    var threadsConnected: String = "0"
    var questions: String = "0"
    var slowQueries: String = "0"
    var openTables: String = "0"
    var qps: String = "0.0"
    
    // Compatibility wrappers
    var activeConnections: Int {
        get { Int(threadsConnected) ?? 0 }
        set { threadsConnected = "\(newValue)" }
    }
    
    var threads: Int {
        get { Int(threadsConnected) ?? 0 }
        set { threadsConnected = "\(newValue)" }
    }
    
    var userQueries: String {
        get { questions }
        set { questions = newValue }
    }
}

struct DatabaseTable: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let rows: Int
    let sizeBytes: Int64
    
    var sizeString: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}
