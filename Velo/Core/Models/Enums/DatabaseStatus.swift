import Foundation
import SwiftUI

public enum DatabaseStatus: String, Codable {
    case active
    case maintenance
    
    public var color: Color {
        switch self {
        case .active: return .green
        case .maintenance: return .orange
        }
    }
}
