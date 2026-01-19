import Foundation

public enum MySQLDetailSection: String, CaseIterable, Identifiable {
    case service = "Service"
    case configuration = "Configuration"
    case databases = "Databases"
    case users = "Users"
    case status = "Status"
    case logs = "Logs"
    
    public var id: String { rawValue }
    
    public var icon: String {
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
