//
//  ApplicationRegistry.swift
//  Velo
//
//  Central registry for all application definitions.
//

import Foundation
import Combine

@MainActor
final class ApplicationRegistry {
    static let shared = ApplicationRegistry()

    private var applications: [String: ApplicationDefinition] = [:]

    private init() {
        registerBuiltInApplications()
    }

    // MARK: - Public API

    /// Get an application definition by ID
    func application(for id: String) -> ApplicationDefinition? {
        applications[id.lowercased()]
    }

    /// Get all registered applications
    var allApplications: [ApplicationDefinition] {
        Array(applications.values).sorted { $0.name < $1.name }
    }

    /// Get applications by category
    func applications(for category: ApplicationCategory) -> [ApplicationDefinition] {
        applications.values.filter { $0.category == category }.sorted { $0.name < $1.name }
    }

    /// Register a custom application
    func register(_ app: ApplicationDefinition) {
        applications[app.id.lowercased()] = app
    }

    // MARK: - Built-in Applications

    private func registerBuiltInApplications() {
        register(nginxDefinition)
        register(apacheDefinition)
        register(phpDefinition)
        register(mysqlDefinition)
        register(postgresqlDefinition)
        register(redisDefinition)
        register(mongoDefinition)
        register(pythonDefinition)
        register(nodeDefinition)
    }

    // MARK: - Nginx

    private var nginxDefinition: ApplicationDefinition {
        ApplicationDefinition(
            id: "nginx",
            name: "Nginx",
            slug: "nginx",
            icon: "server.rack",
            category: .webServer,
            themeColor: "#009639",
            sections: [
                SectionBuilder.service(order: 0),
                SectionBuilder.configuration(order: 1),
                SectionBuilder.configFile(order: 2),
                SectionBuilder.modules(order: 3),
                SectionBuilder.security(order: 4),
                SectionBuilder.logs(order: 5),
                SectionBuilder.status(order: 6)
            ],
            serviceConfig: ServiceConfiguration(
                serviceName: "nginx",
                configPath: "/etc/nginx/nginx.conf",
                logPaths: ["/var/log/nginx/error.log", "/var/log/nginx/access.log"],
                binaryPath: "/usr/sbin/nginx",
                pidPath: "/run/nginx.pid"
            ),
            capabilities: [.controllable, .configurable, .hasModules, .hasLogs, .hasStatus, .hasSites, .hasSecurity, .multiVersion]
        )
    }

    // MARK: - Apache

    private var apacheDefinition: ApplicationDefinition {
        ApplicationDefinition(
            id: "apache",
            name: "Apache",
            slug: "apache",
            icon: "server.rack",
            category: .webServer,
            themeColor: "#D22128",
            sections: [
                SectionBuilder.service(order: 0),
                SectionBuilder.configuration(order: 1),
                SectionBuilder.configFile(order: 2),
                SectionBuilder.modules(order: 3),
                SectionBuilder.logs(order: 4),
                SectionBuilder.status(order: 5)
            ],
            serviceConfig: ServiceConfiguration(
                serviceName: "apache2",
                configPath: "/etc/apache2/apache2.conf",
                logPaths: ["/var/log/apache2/error.log", "/var/log/apache2/access.log"],
                binaryPath: "/usr/sbin/apache2"
            ),
            capabilities: [.controllable, .configurable, .hasModules, .hasLogs, .hasStatus, .hasSites, .multiVersion]
        )
    }

    // MARK: - PHP

    private var phpDefinition: ApplicationDefinition {
        ApplicationDefinition(
            id: "php",
            name: "PHP",
            slug: "php",
            icon: "terminal",
            category: .runtime,
            themeColor: "#777BB4",
            sections: [
                SectionBuilder.service(order: 0),
                SectionBuilder.extensions(order: 1),
                SectionBuilder.disabledFunctions(order: 2),
                SectionBuilder.configuration(order: 3),
                SectionBuilder.configFile(order: 4),
                SectionBuilder.fpmProfile(order: 5),
                SectionBuilder.logs(order: 6),
                SectionBuilder.phpinfo(order: 7)
            ],
            serviceConfig: ServiceConfiguration(
                serviceName: "php-fpm",
                configPath: "/etc/php/8.2/fpm/php.ini",
                logPaths: ["/var/log/php-fpm.log", "/var/log/php8.2-fpm.log"],
                binaryPath: "/usr/bin/php",
                socketPath: "/run/php/php-fpm.sock"
            ),
            capabilities: [.controllable, .configurable, .hasExtensions, .hasLogs, .multiVersion, .hasFPM]
        )
    }

    // MARK: - MySQL

    private var mysqlDefinition: ApplicationDefinition {
        ApplicationDefinition(
            id: "mysql",
            name: "MySQL",
            slug: "mysql",
            icon: "cylinder.split.1x2",
            category: .database,
            themeColor: "#4479A1",
            sections: [
                SectionBuilder.service(order: 0),
                SectionBuilder.configuration(order: 1),
                SectionBuilder.databases(order: 2),
                SectionBuilder.users(order: 3),
                SectionBuilder.logs(order: 4),
                SectionBuilder.status(order: 5)
            ],
            serviceConfig: ServiceConfiguration(
                serviceName: "mysql",
                configPath: "/etc/mysql/mysql.conf.d/mysqld.cnf",
                logPaths: ["/var/log/mysql/error.log"],
                binaryPath: "/usr/bin/mysql",
                socketPath: "/var/run/mysqld/mysqld.sock"
            ),
            capabilities: [.controllable, .configurable, .hasDatabases, .hasUsers, .hasLogs, .hasStatus, .multiVersion]
        )
    }

    // MARK: - PostgreSQL

    private var postgresqlDefinition: ApplicationDefinition {
        ApplicationDefinition(
            id: "postgresql",
            name: "PostgreSQL",
            slug: "postgresql",
            icon: "cylinder.split.1x2",
            category: .database,
            themeColor: "#336791",
            sections: [
                SectionBuilder.service(order: 0),
                SectionBuilder.configuration(order: 1),
                SectionBuilder.databases(order: 2),
                SectionBuilder.users(order: 3),
                SectionBuilder.logs(order: 4),
                SectionBuilder.status(order: 5)
            ],
            serviceConfig: ServiceConfiguration(
                serviceName: "postgresql",
                configPath: "/etc/postgresql/15/main/postgresql.conf",
                logPaths: ["/var/log/postgresql/postgresql-main.log"],
                binaryPath: "/usr/bin/psql"
            ),
            capabilities: [.controllable, .configurable, .hasDatabases, .hasUsers, .hasLogs, .hasStatus, .multiVersion]
        )
    }

    // MARK: - Redis

    private var redisDefinition: ApplicationDefinition {
        ApplicationDefinition(
            id: "redis",
            name: "Redis",
            slug: "redis",
            icon: "memorychip",
            category: .cache,
            themeColor: "#DC382D",
            sections: [
                SectionBuilder.service(order: 0),
                SectionBuilder.configuration(order: 1),
                SectionBuilder.configFile(order: 2),
                SectionBuilder.databases(order: 3),
                SectionBuilder.logs(order: 4),
                SectionBuilder.status(order: 5)
            ],
            serviceConfig: ServiceConfiguration(
                serviceName: "redis-server",
                configPath: "/etc/redis/redis.conf",
                logPaths: ["/var/log/redis/redis-server.log"],
                binaryPath: "/usr/bin/redis-server",
                socketPath: "/run/redis/redis-server.sock"
            ),
            capabilities: [.controllable, .configurable, .hasDatabases, .hasLogs, .hasStatus]
        )
    }

    // MARK: - MongoDB

    private var mongoDefinition: ApplicationDefinition {
        ApplicationDefinition(
            id: "mongodb",
            name: "MongoDB",
            slug: "mongodb",
            icon: "leaf",
            category: .database,
            themeColor: "#47A248",
            sections: [
                SectionBuilder.service(order: 0),
                SectionBuilder.configuration(order: 1),
                SectionBuilder.databases(order: 2),
                SectionBuilder.users(order: 3),
                SectionBuilder.logs(order: 4)
            ],
            serviceConfig: ServiceConfiguration(
                serviceName: "mongod",
                configPath: "/etc/mongod.conf",
                logPaths: ["/var/log/mongodb/mongod.log"],
                binaryPath: "/usr/bin/mongod"
            ),
            capabilities: [.controllable, .configurable, .hasDatabases, .hasUsers, .hasLogs]
        )
    }

    // MARK: - Python

    private var pythonDefinition: ApplicationDefinition {
        ApplicationDefinition(
            id: "python",
            name: "Python",
            slug: "python",
            icon: "terminal",
            category: .runtime,
            themeColor: "#3776AB",
            sections: [
                SectionBuilder.service(order: 0),
                SectionDefinition(
                    id: "versions",
                    name: "Versions",
                    icon: "square.stack.3d.up",
                    providerType: .versions,
                    order: 1
                )
            ],
            serviceConfig: ServiceConfiguration(
                serviceName: "",
                configPath: "",
                logPaths: [],
                binaryPath: "/usr/bin/python3"
            ),
            capabilities: [.multiVersion]
        )
    }

    // MARK: - Node.js

    private var nodeDefinition: ApplicationDefinition {
        ApplicationDefinition(
            id: "node",
            name: "Node.js",
            slug: "nodejs",
            icon: "terminal",
            category: .runtime,
            themeColor: "#339933",
            sections: [
                SectionBuilder.service(order: 0),
                SectionDefinition(
                    id: "versions",
                    name: "Versions",
                    icon: "square.stack.3d.up",
                    providerType: .versions,
                    order: 1
                )
            ],
            serviceConfig: ServiceConfiguration(
                serviceName: "",
                configPath: "",
                logPaths: [],
                binaryPath: "/usr/bin/node"
            ),
            capabilities: [.multiVersion]
        )
    }
}

// MARK: - Lookup by Software Name

extension ApplicationRegistry {

    /// Find application by installed software name (handles variations)
    func applicationForSoftware(named name: String) -> ApplicationDefinition? {
        let lowercased = name.lowercased()

        // Direct match
        if let app = application(for: lowercased) {
            return app
        }

        // Handle variations
        switch lowercased {
        case "apache2", "httpd":
            return application(for: "apache")
        case "mariadb":
            return application(for: "mysql")
        case "postgres":
            return application(for: "postgresql")
        case "nodejs":
            return application(for: "node")
        case "mongo", "mongod":
            return application(for: "mongodb")
        case "redis-server":
            return application(for: "redis")
        default:
            // Check if any registered app matches
            return applications.values.first { app in
                app.slug.lowercased() == lowercased ||
                app.serviceConfig.serviceName.lowercased() == lowercased
            }
        }
    }
}
