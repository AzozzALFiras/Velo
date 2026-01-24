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
    public let installCommands: [String: InstallInstruction]? // Handles both formats
    public let features: [CapabilityFeature]?
    
    // Computed id for Identifiable conformance
    public var id: String { version }
    
    // Custom decoding to handle missing id
    public enum CodingKeys: String, CodingKey {
        case versionId = "id"
        case version, stability, releaseDate, eolDate, recommendedUsage, isDefault, installCommands, features
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        versionId = try container.decodeIfPresent(Int.self, forKey: .versionId)
        version = try container.decode(String.self, forKey: .version)
        stability = try container.decode(String.self, forKey: .stability)
        releaseDate = try container.decodeIfPresent(String.self, forKey: .releaseDate)
        eolDate = try container.decodeIfPresent(String.self, forKey: .eolDate)
        recommendedUsage = try container.decodeIfPresent(String.self, forKey: .recommendedUsage)
        isDefault = try container.decode(Bool.self, forKey: .isDefault)
        features = try container.decodeIfPresent([CapabilityFeature].self, forKey: .features)
        
        // Use InstallInstruction for polymorphic decoding
        installCommands = try container.decodeIfPresent([String: InstallInstruction].self, forKey: .installCommands)
    }
}

public enum InstallInstruction: Codable {
    case list([String])
    case keyed([String: String])
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let list = try? container.decode([String].self) {
            self = .list(list)
            return
        }
        
        if let keyed = try? container.decode([String: String].self) {
            self = .keyed(keyed)
            return
        }
        
        // Handle empty array as empty list (sometimes API sends [])
        // This relies on the fact that an empty array is valid JSON for [String] check above,
        // but if it failed for some reason, we can check specifically.
        // Actually [String] decode handles [], so we are good.
        
        throw DecodingError.typeMismatch(InstallInstruction.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected [String] or [String: String]"))
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .list(let list):
            try container.encode(list)
        case .keyed(let keyed):
            try container.encode(keyed)
        }
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
