//
//  NginxPathResolver.swift
//  Velo
//
//  Handles OS-specific path resolution for Nginx configuration files.
//

import Foundation

struct NginxPathResolver {
    private let baseService = SSHBaseService.shared

    // Default paths for different distributions
    private let debianPaths = NginxPaths(
        configFile: "/etc/nginx/nginx.conf",
        sitesAvailable: "/etc/nginx/sites-available",
        sitesEnabled: "/etc/nginx/sites-enabled",
        confD: "/etc/nginx/conf.d",
        logDir: "/var/log/nginx",
        pidFile: "/run/nginx.pid"
    )

    private let rhelPaths = NginxPaths(
        configFile: "/etc/nginx/nginx.conf",
        sitesAvailable: "/etc/nginx/conf.d",  // RHEL uses conf.d instead of sites-available
        sitesEnabled: "/etc/nginx/conf.d",
        confD: "/etc/nginx/conf.d",
        logDir: "/var/log/nginx",
        pidFile: "/run/nginx.pid"
    )

    struct NginxPaths {
        let configFile: String
        let sitesAvailable: String
        let sitesEnabled: String
        let confD: String
        let logDir: String
        let pidFile: String
    }

    /// Detect OS and return appropriate paths
    func getPaths(via session: TerminalViewModel) async -> NginxPaths {
        let osResult = await baseService.execute("cat /etc/os-release 2>/dev/null | grep -E '^ID=' | cut -d= -f2 | tr -d '\"'", via: session, timeout: 10)
        let osId = osResult.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased()

        switch osId {
        case "debian", "ubuntu", "linuxmint", "pop":
            return debianPaths
        case "centos", "rhel", "fedora", "rocky", "almalinux", "amzn":
            return rhelPaths
        default:
            // Check if sites-available exists (Debian-style)
            let checkResult = await baseService.execute("test -d /etc/nginx/sites-available && echo 'DEBIAN'", via: session, timeout: 5)
            return checkResult.output.contains("DEBIAN") ? debianPaths : rhelPaths
        }
    }

    /// Get the main config file path
    func getConfigFilePath(via session: TerminalViewModel) async -> String {
        let paths = await getPaths(via: session)
        return paths.configFile
    }

    /// Get sites-available directory path
    func getSitesAvailablePath(via session: TerminalViewModel) async -> String {
        let paths = await getPaths(via: session)
        return paths.sitesAvailable
    }

    /// Get sites-enabled directory path
    func getSitesEnabledPath(via session: TerminalViewModel) async -> String {
        let paths = await getPaths(via: session)
        return paths.sitesEnabled
    }

    /// Get conf.d directory path
    func getConfDPath(via session: TerminalViewModel) async -> String {
        let paths = await getPaths(via: session)
        return paths.confD
    }

    /// Get log directory path
    func getLogDirPath(via session: TerminalViewModel) async -> String {
        let paths = await getPaths(via: session)
        return paths.logDir
    }

    /// Get error log path
    func getErrorLogPath(via session: TerminalViewModel) async -> String {
        let logDir = await getLogDirPath(via: session)
        return "\(logDir)/error.log"
    }

    /// Get access log path
    func getAccessLogPath(via session: TerminalViewModel) async -> String {
        let logDir = await getLogDirPath(via: session)
        return "\(logDir)/access.log"
    }

    /// Get default document root
    func getDefaultDocumentRoot(via session: TerminalViewModel) async -> String {
        // Check common locations
        let checkResult = await baseService.execute("""
            if [ -d /var/www/html ]; then echo '/var/www/html';
            elif [ -d /usr/share/nginx/html ]; then echo '/usr/share/nginx/html';
            else echo '/var/www/html'; fi
        """, via: session, timeout: 5)
        return checkResult.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
}
