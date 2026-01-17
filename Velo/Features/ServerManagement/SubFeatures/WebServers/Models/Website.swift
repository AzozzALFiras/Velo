import Foundation

public struct Website: Identifiable, Codable {
    public var id = UUID()
    public var domain: String
    public var path: String
    public var status: WebsiteStatus
    public var port: Int
    public var framework: String // e.g., "Node.js", "PHP", "Static"
    public var sslCertificate: SSLCertificate?
    
    /// Whether website has SSL configured
    public var hasSSL: Bool {
        guard let ssl = sslCertificate else { return false }
        return ssl.status == .active || ssl.status == .expiringSoon
    }
    
    /// SSL status for display
    public var sslStatus: SSLStatus {
        sslCertificate?.status ?? .none
    }
    
    public init(
        id: UUID = UUID(),
        domain: String,
        path: String,
        status: WebsiteStatus,
        port: Int,
        framework: String,
        sslCertificate: SSLCertificate? = nil
    ) {
        self.id = id
        self.domain = domain
        self.path = path
        self.status = status
        self.port = port
        self.framework = framework
        self.sslCertificate = sslCertificate
    }
}
