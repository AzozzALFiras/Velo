import Foundation
import SwiftUI

public enum DatabaseType: String, CaseIterable, Codable {
    case mysql = "MySQL"
    case postgres = "PostgreSQL"
    case redis = "Redis"
    case mongo = "MongoDB"
    
    public var icon: String {
        switch self {
        case .mysql, .postgres: return "cylinder.split.1x2"
        case .redis: return "bolt.horizontal.circle"
        case .mongo: return "leaf"
        }
    }
}
