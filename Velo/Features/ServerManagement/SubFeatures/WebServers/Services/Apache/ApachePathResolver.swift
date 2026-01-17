//
//  ApachePathResolver.swift
//  Velo
//
//  Handles OS-specific path resolution for Apache configuration files.
//

import Foundation

struct ApachePathResolver {
    private let baseService = SSHBaseService.shared


    // Default paths for different distributions
    private let debianPaths = ApachePaths(
        configFile: "/etc/apache2/apache2.conf",
        sitesAvailable: "/etc/apache2/sites-available",
        sitesEnabled: "/etc/apache2/sites-enabled",
        modsAvailable: "/etc/apache2/mods-available",
        modsEnabled: "/etc/apache2/mods-enabled",
        confD: "/etc/apache2/conf-available",
        logDir: "/var/log/apache2",
        pidFile: "/var/run/apache2/apache2.pid",
        envVars: "/etc/apache2/envvars"
    )

    private let rhelPaths = ApachePaths(
        configFile: "/etc/httpd/conf/httpd.conf",
        sitesAvailable: "/etc/httpd/conf.d",
        sitesEnabled: "/etc/httpd/conf.d",
        modsAvailable: "/etc/httpd/conf.modules.d",
        modsEnabled: "/etc/httpd/conf.modules.d",
        confD: "/etc/httpd/conf.d",
        logDir: "/var/log/httpd",
        pidFile: "/var/run/httpd/httpd.pid",
        envVars: "/etc/sysconfig/httpd"
    )

    struct ApachePaths {
        let configFile: String
        let sitesAvailable: String
        let sitesEnabled: String
        let modsAvailable: String
        let modsEnabled: String
        let confD: String
        let logDir: String
        let pidFile: String
        let envVars: String
    }

    /// Detect OS type
    func getOSType(via session: TerminalViewModel) async -> OSType {
        let osResult = await baseService.execute("cat /etc/os-release 2>/dev/null | grep -E '^ID=' | cut -d= -f2 | tr -d '\"'", via: session, timeout: 10)
        let osId = osResult.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased()

        switch osId {
        case "debian", "ubuntu", "linuxmint", "pop":
            return .debian
        case "centos", "rhel", "fedora", "rocky", "almalinux", "amzn":
            return .rhel
        default:
            // Check if sites-available exists (Debian-style)
            let checkResult = await baseService.execute("test -d /etc/apache2/sites-available && echo 'DEBIAN'", via: session, timeout: 5)
            return checkResult.output.contains("DEBIAN") ? .debian : .rhel
        }
    }

    /// Detect OS and return appropriate paths
    func getPaths(via session: TerminalViewModel) async -> ApachePaths {
        let osType = await getOSType(via: session)
        return osType == .debian ? debianPaths : rhelPaths
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

    /// Get mods-available directory path
    func getModsAvailablePath(via session: TerminalViewModel) async -> String {
        let paths = await getPaths(via: session)
        return paths.modsAvailable
    }

    /// Get mods-enabled directory path
    func getModsEnabledPath(via session: TerminalViewModel) async -> String {
        let paths = await getPaths(via: session)
        return paths.modsEnabled
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
        let osType = await getOSType(via: session)
        return osType == .debian ? "/var/www/html" : "/var/www/html"
    }
}
