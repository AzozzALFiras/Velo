//
//  ConfigurationSectionProvider.swift
//  Velo
//
//  Provider for loading structured configuration key-value pairs.
//

import Foundation

/// Provides structured configuration data for the Configuration section
struct ConfigurationSectionProvider: SectionProvider {
    static var providerType: SectionProviderType { .configuration }

    func loadData(
        for app: ApplicationDefinition,
        state: ApplicationState,
        session: TerminalViewModel
    ) async throws {
        let baseService = ServerAdminService.shared

        let configPath = state.configPath.isEmpty ? app.serviceConfig.configPath : state.configPath

        // Read the config file
        let result = await baseService.execute("cat '\(configPath)'", via: session)
        let content = result.output

        // Parse based on app type
        let configValues: [SharedConfigValue]

        switch app.id.lowercased() {
        case "git":
            configValues = await parseGitConfig(session: session)
        case "nginx":
            configValues = parseNginxConfig(content)
        case "apache", "apache2":
            configValues = parseApacheConfig(content)
        case "php":
            configValues = parsePHPConfig(content)
        case "mysql", "mariadb":
            configValues = parseMySQLConfig(content)
        case "postgresql", "postgres":
            configValues = parsePostgresConfig(content)
        case "redis":
            configValues = parseRedisConfig(content)
        default:
            configValues = parseGenericConfig(content)
        }

        await MainActor.run {
            state.configValues = configValues
        }
    }

    // MARK: - Git Config

    private func parseGitConfig(session: TerminalViewModel) async -> [SharedConfigValue] {
        let gitConfig = await GitService.shared.getGlobalConfig(via: session)

        return gitConfig.map { key, value in
            SharedConfigValue(
                key: key,
                value: value,
                displayName: key,
                description: "Git global configuration",
                type: .string
            )
        }.sorted { $0.key < $1.key }
    }

    // MARK: - Nginx Config

    private func parseNginxConfig(_ content: String) -> [SharedConfigValue] {
        let directives: [(String, String, String)] = [
            ("worker_processes", "Worker Processes", "Number of worker processes (auto or number)"),
            ("worker_connections", "Worker Connections", "Max connections per worker"),
            ("keepalive_timeout", "Keepalive Timeout", "Timeout for keep-alive connections"),
            ("client_max_body_size", "Max Body Size", "Maximum allowed size of the client request body"),
            ("server_tokens", "Server Tokens", "Show/Hide nginx version (on/off)"),
            ("gzip", "Gzip Compression", "Enable/Disable gzip compression (on/off)")
        ]

        return parseDirectives(content, directives: directives)
    }

    // MARK: - Apache Config

    private func parseApacheConfig(_ content: String) -> [SharedConfigValue] {
        let directives: [(String, String, String)] = [
            ("Timeout", "Timeout", "Request timeout in seconds"),
            ("KeepAlive", "Keep Alive", "Enable persistent connections (On/Off)"),
            ("MaxKeepAliveRequests", "Max Keep Alive Requests", "Max requests per connection"),
            ("KeepAliveTimeout", "Keep Alive Timeout", "Timeout between requests"),
            ("ServerTokens", "Server Tokens", "Information revealed about server"),
            ("ServerSignature", "Server Signature", "Footer on server-generated pages")
        ]

        return parseDirectives(content, directives: directives)
    }

    // MARK: - PHP Config

    private func parsePHPConfig(_ content: String) -> [SharedConfigValue] {
        let directives: [(String, String, String)] = [
            ("memory_limit", "Memory Limit", "Maximum amount of memory a script may consume"),
            ("max_execution_time", "Max Execution Time", "Maximum time a script can run (seconds)"),
            ("max_input_time", "Max Input Time", "Maximum time parsing request data (seconds)"),
            ("post_max_size", "Post Max Size", "Maximum size of POST data"),
            ("upload_max_filesize", "Upload Max Filesize", "Maximum size of uploaded files"),
            ("max_file_uploads", "Max File Uploads", "Maximum number of simultaneous uploads"),
            ("display_errors", "Display Errors", "Display PHP errors (On/Off)"),
            ("error_reporting", "Error Reporting", "Error reporting level"),
            ("date.timezone", "Timezone", "Default timezone for date functions")
        ]

        return parseINIDirectives(content, directives: directives)
    }

    // MARK: - MySQL Config

    private func parseMySQLConfig(_ content: String) -> [SharedConfigValue] {
        let directives: [(String, String, String)] = [
            ("max_connections", "Max Connections", "Maximum number of concurrent connections"),
            ("max_allowed_packet", "Max Allowed Packet", "Maximum packet size"),
            ("innodb_buffer_pool_size", "InnoDB Buffer Pool", "Size of the buffer pool"),
            ("query_cache_size", "Query Cache Size", "Size of query cache"),
            ("key_buffer_size", "Key Buffer Size", "Size of the key buffer"),
            ("thread_cache_size", "Thread Cache Size", "Number of threads to cache"),
            ("slow_query_log", "Slow Query Log", "Enable slow query logging (0/1)")
        ]

        return parseINIDirectives(content, directives: directives)
    }

    // MARK: - PostgreSQL Config

    private func parsePostgresConfig(_ content: String) -> [SharedConfigValue] {
        let directives: [(String, String, String)] = [
            ("max_connections", "Max Connections", "Maximum number of concurrent connections"),
            ("shared_buffers", "Shared Buffers", "Amount of memory for shared buffers"),
            ("effective_cache_size", "Effective Cache Size", "Estimate of available memory"),
            ("work_mem", "Work Memory", "Memory for internal sort operations"),
            ("maintenance_work_mem", "Maintenance Work Mem", "Memory for maintenance operations"),
            ("checkpoint_completion_target", "Checkpoint Completion", "Target for checkpoint completion"),
            ("wal_buffers", "WAL Buffers", "Amount of memory for WAL data")
        ]

        return parsePostgresDirectives(content, directives: directives)
    }

    // MARK: - Redis Config

    private func parseRedisConfig(_ content: String) -> [SharedConfigValue] {
        let directives: [(String, String, String)] = [
            ("maxmemory", "Max Memory", "Maximum amount of memory Redis can use"),
            ("maxmemory-policy", "Memory Policy", "How Redis handles memory limits"),
            ("timeout", "Timeout", "Client connection timeout (0 = no timeout)"),
            ("tcp-keepalive", "TCP Keep Alive", "TCP keepalive interval"),
            ("databases", "Databases", "Number of databases"),
            ("save", "RDB Save", "RDB persistence configuration")
        ]

        return parseRedisDirectives(content, directives: directives)
    }

    // MARK: - Parsing Helpers

    private func parseDirectives(_ content: String, directives: [(String, String, String)]) -> [SharedConfigValue] {
        var values: [SharedConfigValue] = []

        for (key, name, desc) in directives {
            // Match "key value;" pattern
            if let range = content.range(of: "\(key)\\s+([^;]+);", options: .regularExpression) {
                let match = String(content[range])
                var value = match.replacingOccurrences(of: key, with: "")
                    .replacingOccurrences(of: ";", with: "")
                    .trimmingCharacters(in: .whitespaces)

                values.append(SharedConfigValue(
                    key: key,
                    value: value,
                    displayName: name,
                    description: desc,
                    type: nil,
                    section: nil
                ))
            }
        }

        return values
    }

    private func parseINIDirectives(_ content: String, directives: [(String, String, String)]) -> [SharedConfigValue] {
        var values: [SharedConfigValue] = []

        for (key, name, desc) in directives {
            // Match "key = value" pattern (INI style)
            let pattern = "^\(key)\\s*=\\s*(.+)$"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines),
               let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)) {
                if let valueRange = Range(match.range(at: 1), in: content) {
                    let value = String(content[valueRange]).trimmingCharacters(in: CharacterSet.whitespaces)
                    values.append(SharedConfigValue(
                        key: key,
                        value: value,
                        displayName: name,
                        description: desc,
                        type: nil,
                        section: nil
                    ))
                }
            }
        }

        return values
    }

    private func parsePostgresDirectives(_ content: String, directives: [(String, String, String)]) -> [SharedConfigValue] {
        var values: [SharedConfigValue] = []

        for (key, name, desc) in directives {
            // Match "key = value" or "key = 'value'" pattern
            let patterns = [
                "^\(key)\\s*=\\s*'([^']+)'",
                "^\(key)\\s*=\\s*(\\S+)"
            ]

            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines),
                   let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)) {
                    if match.numberOfRanges > 1 {
                        let valueRange = Range(match.range(at: 1), in: content)!
                        let value = String(content[valueRange])
                        values.append(SharedConfigValue(
                            key: key,
                            value: value,
                            displayName: name,
                            description: desc,
                            type: nil,
                            section: nil
                        ))
                        break
                    }
                }
            }
        }

        return values
    }

    private func parseRedisDirectives(_ content: String, directives: [(String, String, String)]) -> [SharedConfigValue] {
        var values: [SharedConfigValue] = []

        for (key, name, desc) in directives {
            // Match "key value" pattern (Redis style, no equals sign)
            let pattern = "^\(key)\\s+(.+)$"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines),
               let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
               let valueRange = Range(match.range(at: 1), in: content) {
                let matchedValue = String(content[valueRange])
                if !matchedValue.isEmpty {
                    let value = matchedValue.trimmingCharacters(in: CharacterSet.whitespaces)
                    values.append(SharedConfigValue(
                        key: key,
                        value: value,
                        displayName: name,
                        description: desc,
                        type: nil,
                        section: nil
                    ))
                }
            }
        }

        return values
    }

    private func parseGenericConfig(_ content: String) -> [SharedConfigValue] {
        // Generic parsing for unknown config formats
        return []
    }
}
