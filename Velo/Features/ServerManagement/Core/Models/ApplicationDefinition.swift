//
//  ApplicationDefinition.swift
//  Velo
//
//  Unified Application Definition for the capability-based architecture.
//

import Foundation

/// Defines an application that can be managed through the unified detail view
struct ApplicationDefinition: Identifiable, Hashable {
    let id: String              // "nginx", "php", "mysql"
    let name: String            // "Nginx", "PHP", "MySQL"
    let slug: String            // API slug for icons/data
    let icon: String            // SF Symbol or URL
    let category: ApplicationCategory
    let themeColor: String      // Hex color for UI theming
    let sections: [SectionDefinition]
    let serviceConfig: ServiceConfiguration
    let capabilities: Set<ApplicationCapability>

    // Convenience initializer with defaults
    init(
        id: String,
        name: String,
        slug: String? = nil,
        icon: String,
        category: ApplicationCategory,
        themeColor: String,
        sections: [SectionDefinition],
        serviceConfig: ServiceConfiguration,
        capabilities: Set<ApplicationCapability>
    ) {
        self.id = id
        self.name = name
        self.slug = slug ?? id
        self.icon = icon
        self.category = category
        self.themeColor = themeColor
        self.sections = sections
        self.serviceConfig = serviceConfig
        self.capabilities = capabilities
    }

    // MARK: - Computed Properties

    var defaultSection: SectionDefinition? {
        sections.first { $0.isDefault } ?? sections.first
    }

    var sortedSections: [SectionDefinition] {
        sections.sorted { $0.order < $1.order }
    }

    var iconURL: URL? {
        URL(string: "https://velo.3zozz.com/assets/icons/\(slug).png")
    }

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: ApplicationDefinition, rhs: ApplicationDefinition) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Application Category

enum ApplicationCategory: String, Codable, CaseIterable, Identifiable {
    case webServer = "web_server"
    case database = "database"
    case runtime = "runtime"
    case cache = "cache"
    case tool = "tool"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .webServer: return "Web Server"
        case .database: return "Database"
        case .runtime: return "Runtime"
        case .cache: return "Cache"
        case .tool: return "Tool"
        }
    }

    var icon: String {
        switch self {
        case .webServer: return "server.rack"
        case .database: return "cylinder.split.1x2"
        case .runtime: return "terminal"
        case .cache: return "memorychip"
        case .tool: return "wrench.and.screwdriver"
        }
    }
}

// MARK: - Application Capability

enum ApplicationCapability: String, Codable, CaseIterable {
    case controllable       // Can start/stop/restart
    case configurable       // Has configuration settings
    case hasModules         // Has loadable modules (nginx)
    case hasExtensions      // Has extensions (php)
    case hasDatabases       // Manages databases (mysql, postgres)
    case hasUsers           // Manages users (mysql, postgres)
    case hasLogs            // Has viewable logs
    case multiVersion       // Supports multiple versions
    case hasStatus          // Has status/metrics endpoint
    case hasSites           // Manages websites/virtual hosts
    case hasSecurity        // Has security/WAF features
    case hasFPM             // Has FPM process manager (php)
}

// MARK: - Service Configuration

struct ServiceConfiguration: Codable, Hashable {
    let serviceName: String     // e.g., "nginx", "php8.2-fpm"
    let configPath: String      // Main config file path
    let logPaths: [String]      // Log file paths
    let binaryPath: String      // Binary executable path
    let pidPath: String?        // PID file path
    let socketPath: String?     // Unix socket path

    init(
        serviceName: String,
        configPath: String,
        logPaths: [String] = [],
        binaryPath: String,
        pidPath: String? = nil,
        socketPath: String? = nil
    ) {
        self.serviceName = serviceName
        self.configPath = configPath
        self.logPaths = logPaths
        self.binaryPath = binaryPath
        self.pidPath = pidPath
        self.socketPath = socketPath
    }
}
