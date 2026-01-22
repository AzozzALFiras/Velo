import Foundation

public enum PHPDetailSection: String, CaseIterable, Identifiable {
    case service = "Service"
    case extensions = "Extensions"
    case disabledFunctions = "Disabled Functions"
    case configuration = "Configuration"
    case uploadLimits = "Upload Limits"
    case timeouts = "Timeouts"
    case configFile = "Config File"
    case fpmProfile = "FPM Profile"
    case logs = "Logs"
    case phpinfo = "PHP Info"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .service: return "power"
        case .extensions: return "puzzlepiece.extension"
        case .disabledFunctions: return "xmark.circle"
        case .configuration: return "gearshape"
        case .uploadLimits: return "arrow.up.doc"
        case .timeouts: return "clock"
        case .configFile: return "doc.text"
        case .fpmProfile: return "cpu"
        case .logs: return "doc.plaintext"
        case .phpinfo: return "info.circle"
        }
    }
}
