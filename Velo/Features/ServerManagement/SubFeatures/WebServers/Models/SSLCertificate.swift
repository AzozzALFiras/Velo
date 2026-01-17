import Foundation

/// Represents an SSL certificate for a website
public struct SSLCertificate: Codable, Equatable {
    public var domain: String
    public var issuer: String
    public var expiryDate: Date?
    public var isAutoRenew: Bool
    public var type: SSLType
    public var status: SSLStatus
    
    /// Certificate file path (for custom certificates)
    public var certPath: String?
    /// Private key file path (for custom certificates)
    public var keyPath: String?
    
    public init(
        domain: String,
        issuer: String = "Unknown",
        expiryDate: Date? = nil,
        isAutoRenew: Bool = true,
        type: SSLType = .letsencrypt,
        status: SSLStatus = .none,
        certPath: String? = nil,
        keyPath: String? = nil
    ) {
        self.domain = domain
        self.issuer = issuer
        self.expiryDate = expiryDate
        self.isAutoRenew = isAutoRenew
        self.type = type
        self.status = status
        self.certPath = certPath
        self.keyPath = keyPath
    }
    
    /// Days remaining until certificate expires
    public var daysRemaining: Int? {
        guard let expiry = expiryDate else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: expiry).day
        return days
    }
    
    /// Whether certificate is expiring soon (less than 30 days)
    public var isExpiringSoon: Bool {
        guard let days = daysRemaining else { return false }
        return days > 0 && days <= 30
    }
    
    /// Whether certificate has expired
    public var isExpired: Bool {
        guard let days = daysRemaining else { return false }
        return days <= 0
    }
    
    /// Formatted expiry date string
    public var expiryDateFormatted: String {
        guard let expiry = expiryDate else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: expiry)
    }
}

/// Type of SSL certificate
public enum SSLType: String, Codable, CaseIterable {
    case letsencrypt = "Let's Encrypt"
    case custom = "Custom"
    
    public var icon: String {
        switch self {
        case .letsencrypt: return "lock.shield"
        case .custom: return "key"
        }
    }
}

/// Status of SSL certificate
public enum SSLStatus: String, Codable, CaseIterable {
    case none = "No SSL"
    case pending = "Pending"
    case active = "Active"
    case expiringSoon = "Expiring Soon"
    case expired = "Expired"
    case error = "Error"
    
    public var color: String {
        switch self {
        case .none: return "gray"
        case .pending: return "orange"
        case .active: return "green"
        case .expiringSoon: return "yellow"
        case .expired: return "red"
        case .error: return "red"
        }
    }
    
    public var icon: String {
        switch self {
        case .none: return "lock.open"
        case .pending: return "clock"
        case .active: return "lock.fill"
        case .expiringSoon: return "exclamationmark.triangle"
        case .expired: return "xmark.circle"
        case .error: return "exclamationmark.circle"
        }
    }
}
