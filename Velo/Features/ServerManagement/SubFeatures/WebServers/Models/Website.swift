import Foundation

// WebServerType moved to Enums/WebServerType.swift

public struct Website: Identifiable, Codable {
    public var id = UUID()
    public var domain: String
    public var path: String
    public var status: WebsiteStatus
    public var port: Int
    public var framework: String // e.g., "Node.js", "PHP", "Static"
    public var sslCertificate: SSLCertificate?
    public var webServer: WebServerType = .nginx
    
    /// Whether website has SSL configured
    public var hasSSL: Bool {
        return sslCertificate != nil
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
        sslCertificate: SSLCertificate? = nil,
        webServer: WebServerType = .nginx
    ) {
        self.id = id
        self.domain = domain
        self.path = path
        self.status = status
        self.port = port
        self.framework = framework
        self.sslCertificate = sslCertificate
        self.webServer = webServer
    }
}
