import Foundation

public struct Database: Identifiable, Codable {
    public var id = UUID()
    public var name: String
    public var type: DatabaseType
    public var username: String?
    public var password: String?
    public var sizeBytes: Int64
    public var status: DatabaseStatus
    
    public init(id: UUID = UUID(), name: String, type: DatabaseType, username: String? = nil, password: String? = nil, sizeBytes: Int64, status: DatabaseStatus) {
        self.id = id
        self.name = name
        self.type = type
        self.username = username
        self.password = password
        self.sizeBytes = sizeBytes
        self.status = status
    }
    
    public var sizeString: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}
