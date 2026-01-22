import Foundation

/// A unified structure for configuration values across different services (MySQL, PHP, etc.)
public struct SharedConfigValue: Identifiable, Equatable {
    public let id = UUID()
    public let key: String
    public var value: String
    public let displayName: String
    public let description: String
    public let type: ConfigValueType?
    public let section: String?

    public init(
        key: String,
        value: String,
        displayName: String,
        description: String,
        type: ConfigValueType? = nil,
        section: String? = nil
    ) {
        self.key = key
        self.value = value
        self.displayName = displayName
        self.description = description
        self.type = type
        self.section = section
    }
}
