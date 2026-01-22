import Foundation

/// PostgreSQL specific models.
/// Note: Configuration values now use SharedConfigValue.

struct PostgreSQLStatusInfo {
    var version: String = ""
    var uptime: String = "0"
    var activeConnections: Int = 0
    var maxConnections: Int = 0
}

struct PostgreSQLDatabase: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let owner: String
    let sizeBytes: Int64
    
    var sizeString: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}
