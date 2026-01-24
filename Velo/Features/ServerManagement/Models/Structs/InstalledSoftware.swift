import Foundation

public struct InstalledSoftware: Identifiable, Codable {
    public let id = UUID()
    public let name: String
    public let slug: String
    public let version: String
    public let iconName: String // Custom asset or SF Symbol
    public let isRunning: Bool
    
    public init(name: String, slug: String, version: String, iconName: String, isRunning: Bool) {
        self.name = name
        self.slug = slug
        self.version = version
        self.iconName = iconName
        self.isRunning = isRunning
    }
}
