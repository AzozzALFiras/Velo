import Foundation

public struct Capability: Identifiable, Codable {
    public let id: Int
    public let name: String
    public let slug: String
    public let icon: String // URL string
    public let color: String? // Hex string (Optional)
    public let category: String
    public let isEnabled: Bool
    public let description: String
    public let defaultVersion: String? // Changed to String as List API returns string version
    public let versions: [CapabilityVersion]?
}

public struct CapabilityVersion: Identifiable, Codable {
    public let versionId: Int?  // API may not always provide id
    public let version: String
    public let stability: String
    public let releaseDate: String?
    public let eolDate: String?
    public let recommendedUsage: String?
    public let isDefault: Bool
    public let installCommands: [String: [String]]? // OS -> Commands (Array of strings)
    public let features: [CapabilityFeature]?
    
    // Computed id for Identifiable conformance
    public var id: String { version }
    
    // Custom decoding to handle missing id
    public enum CodingKeys: String, CodingKey {
        case versionId = "id"
        case version, stability, releaseDate, eolDate, recommendedUsage, isDefault, installCommands, features
    }
}

public struct CapabilityFeature: Identifiable, Codable {
    public let featureId: Int?  // API may not always provide id
    public let name: String
    public let slug: String
    public let icon: String?
    public let description: String?
    public let isOptional: Bool?
    public let status: String?
    
    public var id: String { slug }
    
    public enum CodingKeys: String, CodingKey {
        case featureId = "id"
        case name, slug, icon, description, isOptional, status
    }
}
