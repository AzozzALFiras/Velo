import Foundation

enum NginxDetailSection: String, CaseIterable, Identifiable {
    case service = "Service"
    case configuration = "Configuration"
    case configFile = "Config File"
    case logs = "Logs"
    case modules = "Modules"
    case security = "Security"
    case status = "Status"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .service: return "gear.circle"
        case .configuration: return "slider.horizontal.3"
        case .configFile: return "doc.text"
        case .logs: return "list.bullet.rectangle"
        case .modules: return "cpu"
        case .security: return "shield.lefthalf.filled"
        case .status: return "chart.bar.xaxis"
        }
    }
}

struct NginxConfigValue: Identifiable {
    let id = UUID()
    let key: String
    let value: String
    let description: String
    let displayName: String
    
    // Helper to help identifying section in config file if needed
    let section: String?
}

struct NginxStatusInfo {
    let activeConnections: Int
    let accepts: Int
    let handled: Int
    let requests: Int
    let reading: Int
    let writing: Int
    let waiting: Int
}
