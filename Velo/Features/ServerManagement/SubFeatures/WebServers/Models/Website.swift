import Foundation

public struct Website: Identifiable, Codable {
    public var id = UUID()
    public var domain: String
    public var path: String
    public var status: WebsiteStatus
    public var port: Int
    public var framework: String // e.g., "Node.js", "PHP", "Static"
    
    public init(id: UUID = UUID(), domain: String, path: String, status: WebsiteStatus, port: Int, framework: String) {
        self.id = id
        self.domain = domain
        self.path = path
        self.status = status
        self.port = port
        self.framework = framework
    }
}
