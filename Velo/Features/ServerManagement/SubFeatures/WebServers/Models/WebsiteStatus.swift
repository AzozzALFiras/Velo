import Foundation
import SwiftUI

public enum WebsiteStatus: String, CaseIterable, Codable {
    case running
    case stopped
    case error
    
    public var title: String { rawValue.capitalized }
    
    public var color: Color {
        switch self {
        case .running: return .green
        case .stopped: return .gray
        case .error: return .red
        }
    }
    
    public var icon: String {
        switch self {
        case .running: return "play.circle.fill"
        case .stopped: return "stop.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        }
    }
}
