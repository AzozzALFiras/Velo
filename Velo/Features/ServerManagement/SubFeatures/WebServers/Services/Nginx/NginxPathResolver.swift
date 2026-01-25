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
        // 1. Try to detect by directory structure (most reliable)
        let checkResult = await baseService.execute("""
            if [ -d /etc/nginx/sites-available ] && [ -d /etc/nginx/sites-enabled ]; then echo 'DEBIAN';
            elif [ -d /etc/nginx/conf.d ]; then echo 'RHEL';
            else echo 'UNKNOWN'; fi
        """, via: session, timeout: 5)
        
        let structure = checkResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if structure == "DEBIAN" {
            return debianPaths
        } else if structure == "RHEL" {
            return rhelPaths
        }

        // 2. Fallback to OS detection
        let osResult = await baseService.execute("cat /etc/os-release 2>/dev/null | grep -E '^ID=' | cut -d= -f2 | tr -d '\"'", via: session, timeout: 5)
        let osId = osResult.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).lowercased()

        switch osId {
        case "debian", "ubuntu", "linuxmint", "pop":
            return debianPaths
        case "centos", "rhel", "fedora", "rocky", "almalinux", "amzn":
            return rhelPaths
        default:
            // Check if nginx directory even exists
            let nginxExist = await baseService.execute("test -d /etc/nginx && echo 'YES'", via: session, timeout: 5)
            if nginxExist.output.contains("YES") {
                // If it's a non-standard layout, conf.d is a safer bet for common single-file inclusion
                return rhelPaths 
            }
            return debianPaths // Final blind fallback
        }
    }

    /// Get the main config file path
    func getConfigFilePath(via session: TerminalViewModel) async -> String {
        let paths = await getPaths(via: session)
        return paths.configFile
    }

    /// Get all potential sites-available directory paths
    func getAllSitesAvailablePaths(via session: TerminalViewModel) async -> [String] {
        var paths = ["/etc/nginx/sites-available", "/etc/nginx/conf.d"]
        
        // Add panel-specific paths
        paths.append("/www/server/panel/vhost/nginx") // aaPanel / BT
        paths.append("/usr/local/nginx/conf/vhost")   // Custom installs
        
        return paths
    }

    /// Get all potential sites-enabled directory paths
    func getAllSitesEnabledPaths(via session: TerminalViewModel) async -> [String] {
        var paths = ["/etc/nginx/sites-enabled", "/etc/nginx/conf.d"]
        
        // Add panel-specific paths
        paths.append("/www/server/panel/vhost/nginx")
        paths.append("/usr/local/nginx/conf/vhost")
        
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

    func getDefaultDocumentRoot(via session: TerminalViewModel) async -> String {
        // 1. Try to find the most common root from enabled sites
        let enabledPaths = await getAllSitesEnabledPaths(via: session)
        
        // Build a multi-path grep command
        let pathsStr = enabledPaths.joined(separator: "' '")
        let scanCommand = """
        grep -rhE "^\\s*root\\s+" '\(pathsStr)' 2>/dev/null | awk '{print $2}' | tr -d ';' | sed 's/\\/*$//' | sort | uniq -c | sort -rn | head -n 5
        """
        
        let scanResult = await baseService.execute(scanCommand, via: session, timeout: 10)
        let output = scanResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !output.isEmpty {
            let lines = output.components(separatedBy: .newlines)
            for line in lines {
                let parts = line.trimmingCharacters(in: .whitespaces).components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if parts.count >= 2 {
                    let path = parts[1]
                    // If it's a deep path like /var/www/site1/public, we want the parent /var/www
                    let parent = (path as NSString).deletingLastPathComponent
                    if !parent.isEmpty && parent != "/" && parent != "/var" {
                        print("🔍 [NginxPathResolver] Detected common root parent: \(parent)")
                        return parent
                    }
                }
            }
        }
        
        // 2. Check for common non-standard installations (BT-Panel, aaPanel, etc.)
        let panelPaths = ["/www/wwwroot", "/home/wwwroot", "/var/www/wwwroot"]
        for p in panelPaths {
            let check = await baseService.execute("test -d '\(p)' && echo 'YES'", via: session, timeout: 5)
            if check.output.contains("YES") {
                print("🔍 [NginxPathResolver] Detected panel root: \(p)")
                return p
            }
        }
        
        // 3. Check official/standard locations
        let standardPaths = ["/var/www/html", "/usr/share/nginx/html"]
        for p in standardPaths {
            let check = await baseService.execute("test -d '\(p)' && echo 'YES'", via: session, timeout: 5)
            if check.output.contains("YES") {
                return "/var/www" // Return parent
            }
        }
        
        // 4. Final fallback
        return "/var/www"
    }

    /// Check if two paths point to the same directory
    func isSamePath(_ path1: String, _ path2: String) -> Bool {
        let p1 = path1.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "//", with: "/")
        let p2 = path2.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "//", with: "/")
        
        // Remove trailing slashes for comparison
        let cleanP1 = p1.hasSuffix("/") && p1.count > 1 ? String(p1.dropLast()) : p1
        let cleanP2 = p2.hasSuffix("/") && p2.count > 1 ? String(p2.dropLast()) : p2
        
        return cleanP1 == cleanP2
    }
}
