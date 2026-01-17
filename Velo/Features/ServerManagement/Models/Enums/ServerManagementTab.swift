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
        case .home: return "Home"
        case .websites: return "Websites"
        case .databases: return "Databases"
        case .files: return "Files"
        case .applications: return "Applications"
        case .logs: return "Activity Logs"
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
        case .logs: return "list.bullet.rectangle.fill"
        case .settings: return "gearshape"
        }
    }
}
