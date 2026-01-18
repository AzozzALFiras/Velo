import Foundation

public enum ServerManagementTab: String, CaseIterable, Identifiable {
    case home
    case websites
    case databases
    case files
    case applications
    case logs
    case settings
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .home: return "server.tab.home".localized
        case .websites: return "server.tab.websites".localized
        case .databases: return "server.tab.databases".localized
        case .files: return "server.tab.files".localized
        case .applications: return "server.tab.applications".localized
        case .logs: return "server.tab.logs".localized
        case .settings: return "server.tab.settings".localized
        }
    }
    
    public var icon: String {
        switch self {
        case .home: return "house"
        case .websites: return "globe"
        case .databases: return "cylinder.split.1x2"
        case .files: return "folder"
        case .applications: return "square.grid.2x2"
        case .logs: return "list.bullet.rectangle.fill"
        case .settings: return "gearshape"
        }
    }
}
