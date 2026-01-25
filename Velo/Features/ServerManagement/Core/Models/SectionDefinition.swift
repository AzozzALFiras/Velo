//
//  SectionDefinition.swift
//  Velo
//
//  Defines a section within an application's detail view.
//

import Foundation

/// Defines a navigable section within an application detail view
struct SectionDefinition: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let icon: String
    let providerType: SectionProviderType
    let isDefault: Bool
    let requiresRunning: Bool
    let order: Int

    init(
        id: String,
        name: String,
        icon: String,
        providerType: SectionProviderType,
        isDefault: Bool = false,
        requiresRunning: Bool = false,
        order: Int
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.providerType = providerType
        self.isDefault = isDefault
        self.requiresRunning = requiresRunning
        self.order = order
    }
}

// MARK: - Section Provider Type

/// Identifies which provider handles data loading for a section
enum SectionProviderType: String, Codable, CaseIterable, Identifiable {
    // Common across all apps
    case service            // Service status & controls
    case versions           // Version management
    case configuration      // Key-value configuration
    case configFile         // Raw config file editor
    case logs               // Log viewer
    case status             // Status/metrics display

    // Web server specific
    case modules            // Compiled modules (nginx)
    case security           // WAF/security rules
    case wafStats           // WAF/Access Log Analytics
    case sites              // Virtual hosts/sites
    case errorPages         // Custom error pages
    
    // PHP specific
    case extensions         // PHP extensions
    case disabledFunctions  // Disabled functions
    case fpmProfile         // FPM pool configuration
    case phpinfo            // phpinfo() output
    case uploadLimits       // Upload configuration
    case timeouts           // Timeout configuration

    // Database specific
    case databases          // Database list management
    case users              // User management
    case backup             // Backup/restore

    var id: String { rawValue }

    /// Default icon for this provider type
    var defaultIcon: String {
        switch self {
        case .service: return "power"
        case .versions: return "square.stack.3d.up"
        case .configuration: return "slider.horizontal.3"
        case .configFile: return "doc.text"
        case .logs: return "list.bullet.rectangle"
        case .status: return "chart.bar.xaxis"
        case .modules: return "cpu"
        case .security: return "shield.lefthalf.filled"
        case .wafStats: return "chart.xyaxis.line"
        case .sites: return "globe"
        case .errorPages: return "exclamationmark.triangle"
        case .extensions: return "puzzlepiece.extension"
        case .disabledFunctions: return "xmark.circle"
        case .fpmProfile: return "cpu"
        case .phpinfo: return "info.circle"
        case .uploadLimits: return "arrow.up.doc"
        case .timeouts: return "clock"
        case .databases: return "cylinder"
        case .users: return "person.2"
        case .backup: return "externaldrive"
        }
    }

    /// Default display name for this provider type
    var defaultName: String {
        switch self {
        case .service: return "Service"
        case .versions: return "Versions"
        case .configuration: return "Configuration"
        case .configFile: return "Config File"
        case .logs: return "Logs"
        case .status: return "Status"
        case .modules: return "Modules"
        case .security: return "Security"
        case .wafStats: return "WAF Logs"
        case .sites: return "Sites"
        case .errorPages: return "Error Pages"
        case .extensions: return "Extensions"
        case .disabledFunctions: return "Disabled Functions"
        case .fpmProfile: return "FPM Profile"
        case .phpinfo: return "PHP Info"
        case .uploadLimits: return "Upload Limits"
        case .timeouts: return "Timeouts"
        case .databases: return "Databases"
        case .users: return "Users"
        case .backup: return "Backup"
        }
    }
}

// MARK: - Section Builder

/// Convenience builder for creating section definitions
enum SectionBuilder {

    /// Creates a service section (default for most apps)
    static func service(order: Int = 0) -> SectionDefinition {
        SectionDefinition(
            id: "service",
            name: "Service",
            icon: "power",
            providerType: .service,
            isDefault: true,
            order: order
        )
    }

    /// Creates a configuration section
    static func configuration(order: Int = 1) -> SectionDefinition {
        SectionDefinition(
            id: "configuration",
            name: "Configuration",
            icon: "slider.horizontal.3",
            providerType: .configuration,
            order: order
        )
    }

    /// Creates a config file section
    static func configFile(order: Int = 2) -> SectionDefinition {
        SectionDefinition(
            id: "configFile",
            name: "Config File",
            icon: "doc.text",
            providerType: .configFile,
            order: order
        )
    }

    /// Creates a logs section
    static func logs(order: Int = 3) -> SectionDefinition {
        SectionDefinition(
            id: "logs",
            name: "Logs",
            icon: "list.bullet.rectangle",
            providerType: .logs,
            order: order
        )
    }

    /// Creates a status section
    static func status(order: Int = 4) -> SectionDefinition {
        SectionDefinition(
            id: "status",
            name: "Status",
            icon: "chart.bar.xaxis",
            providerType: .status,
            requiresRunning: true,
            order: order
        )
    }

    /// Creates a modules section (for web servers)
    static func modules(order: Int = 5) -> SectionDefinition {
        SectionDefinition(
            id: "modules",
            name: "Modules",
            icon: "cpu",
            providerType: .modules,
            order: order
        )
    }

    /// Creates a security section
    static func security(order: Int = 6) -> SectionDefinition {
        SectionDefinition(
            id: "security",
            name: "Security",
            icon: "shield.lefthalf.filled",
            providerType: .security,
            order: order
        )
    }

    /// Creates an error pages section
    static func errorPages(order: Int = 7) -> SectionDefinition {
        SectionDefinition(
            id: "errorPages",
            name: "Error Pages",
            icon: "exclamationmark.triangle",
            providerType: .errorPages,
            order: order
        )
    }

    /// Creates a WAF Stats section
    static func wafStats(order: Int = 8) -> SectionDefinition {
        SectionDefinition(
            id: "wafStats",
            name: "WAF Logs",
            icon: "chart.xyaxis.line",
            providerType: .wafStats,
            order: order
        )
    }

    /// Creates an extensions section (for PHP)
    static func extensions(order: Int = 1) -> SectionDefinition {
        SectionDefinition(
            id: "extensions",
            name: "Extensions",
            icon: "puzzlepiece.extension",
            providerType: .extensions,
            order: order
        )
    }

    /// Creates a disabled functions section (for PHP)
    static func disabledFunctions(order: Int = 2) -> SectionDefinition {
        SectionDefinition(
            id: "disabledFunctions",
            name: "Disabled Functions",
            icon: "xmark.circle",
            providerType: .disabledFunctions,
            order: order
        )
    }

    /// Creates an FPM profile section (for PHP)
    static func fpmProfile(order: Int = 5) -> SectionDefinition {
        SectionDefinition(
            id: "fpmProfile",
            name: "FPM Profile",
            icon: "cpu",
            providerType: .fpmProfile,
            order: order
        )
    }

    /// Creates a phpinfo section
    static func phpinfo(order: Int = 9) -> SectionDefinition {
        SectionDefinition(
            id: "phpinfo",
            name: "PHP Info",
            icon: "info.circle",
            providerType: .phpinfo,
            requiresRunning: true,
            order: order
        )
    }

    /// Creates a databases section
    static func databases(order: Int = 2) -> SectionDefinition {
        SectionDefinition(
            id: "databases",
            name: "Databases",
            icon: "cylinder",
            providerType: .databases,
            requiresRunning: true,
            order: order
        )
    }

    /// Creates a users section
    static func users(order: Int = 3) -> SectionDefinition {
        SectionDefinition(
            id: "users",
            name: "Users",
            icon: "person.2",
            providerType: .users,
            requiresRunning: true,
            order: order
        )
    }

    /// Creates a custom section
    static func section(
        id: String,
        name: String,
        icon: String,
        providerType: SectionProviderType,
        isDefault: Bool = false,
        requiresRunning: Bool = false,
        order: Int
    ) -> SectionDefinition {
        SectionDefinition(
            id: id,
            name: name,
            icon: icon,
            providerType: providerType,
            isDefault: isDefault,
            requiresRunning: requiresRunning,
            order: order
        )
    }
}
