import Foundation

// MySQLDetailSection moved to Enums/MySQLDetailSection.swift

struct DatabaseUser: Identifiable, Equatable {
    let id: String // usually "user@host"
    let username: String
    let host: String
    let privileges: String
}

// MySQLConfigValue replaced by SharedConfigValue in Models/Shared/SharedConfigValue.swift

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
