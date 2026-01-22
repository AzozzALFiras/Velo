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
        // 1. Check directory structure first (most accurate for configuration)
        let checkResult = await baseService.execute("""
            if [ -d /etc/apache2 ]; then echo 'DEBIAN';
            elif [ -d /etc/httpd ]; then echo 'RHEL';
            else echo 'UNKNOWN'; fi
        """, via: session, timeout: 5)
        
        let structure = checkResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if structure == "DEBIAN" {
            return .debian
        } else if structure == "RHEL" {
            return .rhel
        }

        // 2. Fallback to OS ID
        let osResult = await baseService.execute("cat /etc/os-release 2>/dev/null | grep -E '^ID=' | cut -d= -f2 | tr -d '\"'", via: session, timeout: 10)
        let osId = osResult.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased()

        switch osId {
        case "debian", "ubuntu", "linuxmint", "pop":
            return .debian
        case "centos", "rhel", "fedora", "rocky", "almalinux", "amzn":
            return .rhel
        default:
            return .debian
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

    /// Get all potential sites-available directory paths
    func getAllSitesAvailablePaths(via session: TerminalViewModel) async -> [String] {
        var paths = ["/etc/apache2/sites-available", "/etc/httpd/conf.d"]
        
        // Add panel-specific paths
        paths.append("/www/server/panel/vhost/apache") // aaPanel / BT
        
        return paths
    }

    /// Get all potential sites-enabled directory paths
    func getAllSitesEnabledPaths(via session: TerminalViewModel) async -> [String] {
        var paths = ["/etc/apache2/sites-enabled", "/etc/httpd/conf.d"]
        
        // Add panel-specific paths
        paths.append("/www/server/panel/vhost/apache")
        
        return paths
    }

    /// Get sites-available directory path (legacy/fallback)
    func getSitesAvailablePath(via session: TerminalViewModel) async -> String {
        let paths = await getPaths(via: session)
        return paths.sitesAvailable
    }

    /// Get sites-enabled directory path (legacy/fallback)
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

    func getDefaultDocumentRoot(via session: TerminalViewModel) async -> String {
        let enabledPaths = await getAllSitesEnabledPaths(via: session)
        
        // 1. Try to find the most common DocumentRoot from enabled sites
        let pathsStr = enabledPaths.joined(separator: "' '")
        let scanCommand = """
        grep -rhE "^\\s*DocumentRoot\\s+" '\(pathsStr)' 2>/dev/null | awk '{print $2}' | tr -d '"' | sed 's/\\/*$//' | sort | uniq -c | sort -rn | head -n 5
        """
        
        let scanResult = await baseService.execute(scanCommand, via: session, timeout: 10)
        let output = scanResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !output.isEmpty {
            let lines = output.components(separatedBy: .newlines)
            for line in lines {
                let parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if parts.count >= 2 {
                    let path = parts[1]
                    let parent = (path as NSString).deletingLastPathComponent
                    if !parent.isEmpty && parent != "/" && parent != "/var" {
                        print("🔍 [ApachePathResolver] Detected common root parent: \(parent)")
                        return parent
                    }
                }
            }
        }
        
        // 2. Check for panel/custom locations
        let panelPaths = ["/www/wwwroot", "/home/wwwroot", "/var/www"]
        for p in panelPaths {
            let check = await baseService.execute("test -d '\(p)' && echo 'YES'", via: session, timeout: 5)
            if check.output.contains("YES") {
                return p
            }
        }
        
        // 3. OS default fallback
        let osType = await getOSType(via: session)
        return "/var/www"
    }
}
