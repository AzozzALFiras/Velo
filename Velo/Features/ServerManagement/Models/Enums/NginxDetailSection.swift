import Foundation

public enum NginxDetailSection: String, CaseIterable, Identifiable {
    case service = "Service"
    case configuration = "Configuration"
    case configFile = "Config File"
    case logs = "Logs"
    case modules = "Modules"
    case security = "Security"
    case status = "Status"
    
    public var id: String { rawValue }
    
    public var icon: String {
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
