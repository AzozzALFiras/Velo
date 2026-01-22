//
//  ConfigFileSectionProvider.swift
//  Velo
//
//  Provider for loading raw configuration file content.
//

import Foundation

/// Provides raw config file content for editing
struct ConfigFileSectionProvider: SectionProvider {
    static var providerType: SectionProviderType { .configFile }

    func loadData(
        for app: ApplicationDefinition,
        state: ApplicationState,
        session: TerminalViewModel
    ) async throws {
        let baseService = SSHBaseService.shared
        var configPath = app.serviceConfig.configPath

        // Determine config path based on app type if not specified
        if configPath.isEmpty {
            configPath = defaultConfigPath(for: app.id)
        }

        // Try reading the config file
        var result = await baseService.execute("sudo cat '\(configPath)'", via: session)

        // If primary path fails, try fallbacks
        if result.output.isEmpty || result.output.contains("No such file") {
            let fallbacks = fallbackConfigPaths(for: app.id, excluding: configPath)

            for fallbackPath in fallbacks {
                let fallbackResult = await baseService.execute("sudo cat '\(fallbackPath)'", via: session)
                if !fallbackResult.output.isEmpty && !fallbackResult.output.contains("No such file") {
                    result = fallbackResult
                    configPath = fallbackPath
                    break
                }
            }
        }

        await MainActor.run {
            state.configFileContent = result.output
            state.configPath = configPath
        }

        if result.output.isEmpty {
            throw SectionProviderError.loadFailed("Could not load config file at \(configPath)")
        }
    }

    private func defaultConfigPath(for appId: String) -> String {
        switch appId.lowercased() {
        case "nginx":
            return "/etc/nginx/nginx.conf"
        case "apache", "apache2":
            return "/etc/apache2/apache2.conf"
        case "php":
            return "/etc/php/8.2/fpm/php.ini"
        case "mysql", "mariadb":
            return "/etc/mysql/mysql.conf.d/mysqld.cnf"
        case "postgresql", "postgres":
            return "/etc/postgresql/15/main/postgresql.conf"
        case "redis":
            return "/etc/redis/redis.conf"
        case "mongodb", "mongo":
            return "/etc/mongod.conf"
        default:
            return "/etc/\(appId)/\(appId).conf"
        }
    }

    private func fallbackConfigPaths(for appId: String, excluding: String) -> [String] {
        let allPaths: [String]

        switch appId.lowercased() {
        case "nginx":
            allPaths = [
                "/etc/nginx/nginx.conf",
                "/www/server/nginx/conf/nginx.conf",
                "/usr/local/nginx/conf/nginx.conf"
            ]
        case "apache", "apache2":
            allPaths = [
                "/etc/apache2/apache2.conf",
                "/etc/httpd/conf/httpd.conf",
                "/www/server/apache/conf/httpd.conf"
            ]
        case "php":
            allPaths = [
                "/etc/php/8.3/fpm/php.ini",
                "/etc/php/8.2/fpm/php.ini",
                "/etc/php/8.1/fpm/php.ini",
                "/etc/php/8.0/fpm/php.ini",
                "/etc/php/7.4/fpm/php.ini"
            ]
        case "mysql", "mariadb":
            allPaths = [
                "/etc/mysql/mysql.conf.d/mysqld.cnf",
                "/etc/mysql/my.cnf",
                "/etc/my.cnf"
            ]
        case "postgresql", "postgres":
            allPaths = [
                "/etc/postgresql/16/main/postgresql.conf",
                "/etc/postgresql/15/main/postgresql.conf",
                "/etc/postgresql/14/main/postgresql.conf"
            ]
        case "redis":
            allPaths = [
                "/etc/redis/redis.conf",
                "/etc/redis.conf"
            ]
        default:
            allPaths = []
        }

        return allPaths.filter { $0 != excluding }
    }
}
