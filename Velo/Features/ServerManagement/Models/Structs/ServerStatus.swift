import Foundation

/// Complete status of all detectable software on the server
public struct ServerStatus: Codable {
    // Web Servers
    public var nginx: SoftwareStatus = .notInstalled
    public var apache: SoftwareStatus = .notInstalled
    public var litespeed: SoftwareStatus = .notInstalled
    
    // Databases
    public var mysql: SoftwareStatus = .notInstalled
    public var mariadb: SoftwareStatus = .notInstalled
    public var postgresql: SoftwareStatus = .notInstalled
    public var redis: SoftwareStatus = .notInstalled
    public var mongodb: SoftwareStatus = .notInstalled
    
    // Runtimes
    public var php: SoftwareStatus = .notInstalled
    public var python: SoftwareStatus = .notInstalled
    public var nodejs: SoftwareStatus = .notInstalled
    
    // Tools
    public var composer: SoftwareStatus = .notInstalled
    public var npm: SoftwareStatus = .notInstalled
    public var git: SoftwareStatus = .notInstalled
    
    public init() {}
    
    // Computed properties
    public var hasWebServer: Bool {
        nginx.isInstalled || apache.isInstalled || litespeed.isInstalled
    }
    
    public var hasDatabase: Bool {
        mysql.isInstalled || mariadb.isInstalled || postgresql.isInstalled
    }
    
    public var hasRuntime: Bool {
        php.isInstalled || python.isInstalled || nodejs.isInstalled
    }
    
    public var activeWebServer: String? {
        if nginx.isRunning { return "Nginx" }
        if apache.isRunning { return "Apache" }
        if litespeed.isRunning { return "LiteSpeed" }
        if nginx.isInstalled { return "Nginx" }
        if apache.isInstalled { return "Apache" }
        if litespeed.isInstalled { return "LiteSpeed" }
        return nil
    }
    
    public var installedDatabases: [String] {
        var dbs: [String] = []
        if mysql.isInstalled { dbs.append("MySQL") }
        if mariadb.isInstalled { dbs.append("MariaDB") }
        if postgresql.isInstalled { dbs.append("PostgreSQL") }
        if redis.isInstalled { dbs.append("Redis") }
        if mongodb.isInstalled { dbs.append("MongoDB") }
        return dbs
    }
    
    public var installedRuntimes: [String] {
        var runtimes: [String] = []
        if php.isInstalled { runtimes.append("PHP") }
        if python.isInstalled { runtimes.append("Python") }
        if nodejs.isInstalled { runtimes.append("Node.js") }
        return runtimes
    }
}
