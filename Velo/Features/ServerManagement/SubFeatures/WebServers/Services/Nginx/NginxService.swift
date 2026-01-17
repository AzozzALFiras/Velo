//
//  NginxService.swift
//  Velo
//
//  Public facade for all Nginx operations.
//  Delegates to specialized components for detection, version resolution, path management, and service control.
//

import Foundation
import Combine


@MainActor
final class NginxService: ObservableObject, WebServerService {
    static let shared = NginxService()

    let baseService = SSHBaseService.shared
    let serviceName = "nginx"

    // Sub-components
    private let detector = NginxDetector()
    private let versionResolver = NginxVersionResolver()
    private let pathResolver = NginxPathResolver()
    private let configValidator = NginxConfigValidator()

    private init() {}

    // MARK: - ServerModuleService

    func isInstalled(via session: TerminalViewModel) async -> Bool {
        await detector.isInstalled(via: session)
    }

    func getVersion(via session: TerminalViewModel) async -> String? {
        await versionResolver.getVersion(via: session)
    }

    func isRunning(via session: TerminalViewModel) async -> Bool {
        await LinuxServiceHelper.isActive(serviceName: serviceName, via: session)
    }

    func getStatus(via session: TerminalViewModel) async -> SoftwareStatus {
        guard await isInstalled(via: session) else {
            return .notInstalled
        }

        let version = await getVersion(via: session) ?? "installed"
        let running = await isRunning(via: session)

        return running ? .running(version: version) : .stopped(version: version)
    }

    // MARK: - WebServerService

    func fetchSites(via session: TerminalViewModel) async -> [Website] {
        let availablePaths = await pathResolver.getAllSitesAvailablePaths(via: session)
        let enabledPaths = await pathResolver.getAllSitesEnabledPaths(via: session)
        
        print("🔍 [NginxService] Multi-path scan starting: \(availablePaths)")
        
        var allSites: [Website] = []
        var detectedDomains = Set<String>()
        var allEnabledFiles = Set<String>()
        
        // 1. Collect all enabled files across all potential paths
        for path in enabledPaths {
            print("🔍 [NginxService] Collecting enabled sites from: \(path)")
            let enabledResult = await baseService.execute("ls -1 --color=never '\(path)' 2>/dev/null", via: session, timeout: 5)
            let output = stripANSICodes(enabledResult.output.trimmingCharacters(in: .whitespacesAndNewlines))
            if !output.isEmpty {
                let files = output.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespaces) }
                for file in files {
                    allEnabledFiles.insert(file)
                }
            }
        }
        
        // 2. Scan each available path
        for availablePath in availablePaths {
            print("🔍 [NginxService] Scanning available path: \(availablePath)")
            
            let result = await baseService.execute("ls -1 --color=never '\(availablePath)' 2>/dev/null", via: session, timeout: 10)
            let output = stripANSICodes(result.output.trimmingCharacters(in: .whitespacesAndNewlines))
            
            guard !output.isEmpty && !output.contains("cannot access") else {
                continue
            }
            
            let lines = output.components(separatedBy: .newlines)
            print("🔍 [NginxService] Found \(lines.count) lines in \(availablePath)")

            for line in lines {
                let siteName = line.trimmingCharacters(in: .whitespaces)
                guard isValidSiteConfig(siteName) else { continue }
                
                let configResult = await baseService.execute(
                    "grep -Ei '^[^#]*(server_name|root|listen|fastcgi_pass|php|proxy_pass|ssl_certificate|index|include)' '\(availablePath)/\(siteName)' 2>/dev/null | head -40",
                    via: session, timeout: 10
                )
                
                if let config = await parseSiteConfig(configResult.output, siteName: siteName, via: session) {
                    var finalConfig = config
                    
                    // Avoid duplicates by domain
                    if detectedDomains.contains(finalConfig.domain) {
                        print("🔍 [NginxService] Skipping duplicate domain: \(finalConfig.domain)")
                        continue
                    }
                    detectedDomains.insert(finalConfig.domain)
                    
                    finalConfig.webServer = .nginx
                    
                    // Check if site is enabled
                    let isEnabled = allEnabledFiles.contains(siteName) || 
                                  allEnabledFiles.contains("\(siteName).conf") ||
                                  (siteName.hasSuffix(".conf") && allEnabledFiles.contains(siteName.replacingOccurrences(of: ".conf", with: "")))
                    
                    finalConfig.status = isEnabled ? .running : .stopped
                    
                    if finalConfig.hasSSL {
                        finalConfig.sslCertificate = await SSLService.shared.getCertificateInfo(domain: finalConfig.domain, via: session)
                    }
                    
                    allSites.append(finalConfig)
                }
            }
        }
        
        print("🔍 [NginxService] Multi-path scan complete. Found \(allSites.count) sites.")
        return allSites
    }

    func createSite(domain: String, path: String, port: Int, phpVersion: String?, via session: TerminalViewModel) async -> Bool {
        let safeDomain = domain.lowercased().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        var safePath = path.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        if safePath.isEmpty {
            let defaultRoot = await pathResolver.getDefaultDocumentRoot(via: session)
            safePath = "\(defaultRoot)/\(safeDomain.replacingOccurrences(of: ".", with: "_"))"
        }

        if !safePath.hasPrefix("/") {
            safePath = "/\(safePath)"
        }

        // Detect PHP-FPM socket if PHP is specified
        var phpSocketPath: String? = nil
        if let php = phpVersion {
            phpSocketPath = await detectPHPFPMSocket(version: php, via: session)
        }

        // Build Nginx config
        let config = buildSiteConfig(domain: safeDomain, path: safePath, port: port, phpSocket: phpSocketPath)

        // Write config file using unified helper
        let configPath = await pathResolver.getSitesAvailablePath(via: session)
        let success = await baseService.writeFile(at: "\(configPath)/\(safeDomain)", content: config, useSudo: true, via: session)
        
        guard success else { return false }

        // Enable site
        let enableResult = await enableSite(domain: safeDomain, via: session)
        guard enableResult else { return false }

        // Validate config
        let validation = await validateConfig(via: session)
        if !validation.isValid {
            // Rollback
            await disableSite(domain: safeDomain, via: session)
            _ = await baseService.execute("sudo rm -f '\(configPath)/\(safeDomain)'", via: session, timeout: 10)
            return false
        }

        // Reload nginx
        return await reload(via: session)
    }

    func deleteSite(domain: String, deleteFiles: Bool, via session: TerminalViewModel) async -> Bool {
        let availablePath = await pathResolver.getSitesAvailablePath(via: session)
        let enabledPath = await pathResolver.getSitesEnabledPath(via: session)

        // Get document root before deleting config
        var docRoot: String? = nil
        if deleteFiles {
            let rootResult = await baseService.execute(
                "grep -E '^[^#]*root' '\(enabledPath)/\(domain)' 2>/dev/null | head -1 | awk '{print $2}' | tr -d ';'",
                via: session, timeout: 10
            )
            docRoot = rootResult.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        }

        // Disable and remove config
        _ = await baseService.execute("sudo rm -f '\(enabledPath)/\(domain)'", via: session, timeout: 10)
        _ = await baseService.execute("sudo rm -f '\(availablePath)/\(domain)'", via: session, timeout: 10)

        // Delete files if requested
        if deleteFiles, let root = docRoot, !root.isEmpty && root != "/" && root != "/var" && root != "/var/www" {
            _ = await baseService.execute("sudo rm -rf '\(root)'", via: session, timeout: 30)
        }

        return await reload(via: session)
    }

    func enableSite(domain: String, via session: TerminalViewModel) async -> Bool {
        let availablePath = await pathResolver.getSitesAvailablePath(via: session)
        let enabledPath = await pathResolver.getSitesEnabledPath(via: session)

        let result = await baseService.execute(
            "sudo ln -sf '\(availablePath)/\(domain)' '\(enabledPath)/\(domain)' && echo 'LINKED'",
            via: session, timeout: 10
        )

        return result.output.contains("LINKED")
    }

    func disableSite(domain: String, via session: TerminalViewModel) async -> Bool {
        let enabledPath = await pathResolver.getSitesEnabledPath(via: session)
        let result = await baseService.execute("sudo rm -f '\(enabledPath)/\(domain)' && echo 'REMOVED'", via: session, timeout: 10)
        return result.output.contains("REMOVED")
    }

    func validateConfig(via session: TerminalViewModel) async -> (isValid: Bool, message: String) {
        await configValidator.validate(via: session)
    }

    func getDefaultDocumentRoot(via session: TerminalViewModel) async -> String {
        await pathResolver.getDefaultDocumentRoot(via: session)
    }

    // MARK: - Private Helpers

    private func isValidSiteConfig(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count >= 3, trimmed.count < 100 else { return false }

        // Filter out aaPanel/BT internal files and common junk
        if trimmed.hasPrefix("0.") || trimmed.hasPrefix(".") { return false }
        
        let junk = [
            "welcome", "ubuntu", "nginx", "apache", "mysql", "php", "active", "___velo", 
            "echo ", "root@", "vmi", "[0", "total ", "drw", "password", "ver ", "Ver ", 
            "(ubuntu)", "inactive", "btwaf", "well-known", "phpinfo", "rewrite", 
            "proxy", "waf", "redirect", "monitor", "websocket"
        ]
        
        for j in junk {
            if trimmed.lowercased().contains(j) { return false }
        }

        if trimmed == "default" || trimmed == "000-default.conf" || trimmed == "default.conf" { return false }

        let allowedChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_"))
        guard trimmed.unicodeScalars.allSatisfy({ allowedChars.contains($0) }) else { return false }

        return true
    }
    
    /// Strips ANSI escape codes from a string (e.g., color codes from ls output)
    private func stripANSICodes(_ input: String) -> String {
        // ANSI escape sequences: ESC [ ... m (where ESC is \u{1B} or \u{001B})
        // Also handles sequences like [0m, [01;36m, etc.
        let pattern = "\\x1B\\[[0-9;]*[mGKHF]|\\[\\d*(;\\d+)*m"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return input
        }
        let range = NSRange(input.startIndex..., in: input)
        return regex.stringByReplacingMatches(in: input, options: [], range: range, withTemplate: "")
    }

    private func parseSiteConfig(_ output: String, siteName: String, via session: TerminalViewModel) async -> Website? {
        var domain = siteName.replacingOccurrences(of: ".conf", with: "")
        var path = "" // Empty path initially to detect if 'root' is present
        var port = 80
        var detectedFramework = "Static HTML"
        var hasSSL = false
        var hasValidServerName = false

        let lines = output.components(separatedBy: CharacterSet.newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.contains("server_name") {
                let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if parts.count >= 2 {
                    let rawDomain = parts[1].replacingOccurrences(of: ";", with: "").replacingOccurrences(of: "\"", with: "")
                    let domainCandidate = rawDomain.hasPrefix("SSL.") ? String(rawDomain.dropFirst(4)) : rawDomain
                    
                    if domainCandidate != "_" && domainCandidate != "localhost" {
                        domain = domainCandidate
                        hasValidServerName = true
                    }
                }
            }
            if trimmed.contains("root") && !trimmed.contains("root@") {
                let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if parts.count >= 2 {
                    path = parts[1].replacingOccurrences(of: ";", with: "").replacingOccurrences(of: "\"", with: "")
                }
            }
            if trimmed.contains("listen") {
                if trimmed.contains("443") || trimmed.contains("ssl") {
                    hasSSL = true
                }
                if let portMatch = trimmed.range(of: "\\d+", options: .regularExpression) {
                    port = Int(trimmed[portMatch]) ?? 80
                }
            }
            
            if trimmed.contains("ssl_certificate") {
                hasSSL = true
            }
            
            // Detect PHP - look for fastcgi_pass, php, or index.php
            let lowerTrimmed = trimmed.lowercased()
            if lowerTrimmed.contains("fastcgi_pass") || 
               lowerTrimmed.contains("php") || 
               (lowerTrimmed.contains("index") && lowerTrimmed.contains(".php")) {
                detectedFramework = "PHP"
            }
            
            // Detect Node.js/Python - look for proxy_pass to common ports
            if lowerTrimmed.contains("proxy_pass") {
                if trimmed.contains("3000") || trimmed.contains("8080") || trimmed.contains("8000") {
                    // Only override if we haven't detected PHP or if it's explicitly proxying
                    if detectedFramework == "Static HTML" {
                        detectedFramework = "Proxy"
                    }
                }
            }
        }

        // If no server_name found, it's likely a generic config or snippet
        guard hasValidServerName else { return nil }

        // Fallback path if none found
        if path.isEmpty {
            let defaultRoot = await pathResolver.getDefaultDocumentRoot(via: session)
            path = "\(defaultRoot)/\(domain)"
        }

        var website = Website(domain: domain, path: path, status: .running, port: port, framework: detectedFramework, webServer: .nginx)
        if hasSSL {
            website.sslCertificate = SSLCertificate(domain: domain, issuer: "Detected", type: .custom, status: .active)
        }
        return website
    }

    private func buildSiteConfig(domain: String, path: String, port: Int, phpSocket: String?) -> String {
        var config = """
        server {
            listen 80;
            listen [::]:80;

            server_name \(domain) www.\(domain);
            root \(path);
            index index.html index.htm index.php;

            location / {
                try_files $uri $uri/ =404;
            }
        """

        if let socketPath = phpSocket {
            config += """


            location ~ \\.php$ {
                include snippets/fastcgi-php.conf;
                fastcgi_pass unix:\(socketPath);
            }

            location ~ /\\.ht {
                deny all;
            }
        """
        }

        config += "\n}"
        return config
    }

    private func detectPHPFPMSocket(version: String, via session: TerminalViewModel) async -> String? {
        let possibleSockets = [
            "/var/run/php/php\(version)-fpm.sock",
            "/run/php/php\(version)-fpm.sock",
            "/var/run/php-fpm/php\(version)-fpm.sock",
            "/run/php-fpm.sock"
        ]

        for socketPath in possibleSockets {
            let checkResult = await baseService.execute("test -S '\(socketPath)' && echo 'EXISTS'", via: session, timeout: 5)
            if checkResult.output.contains("EXISTS") {
                return socketPath
            }
        }

        // Fallback: search for any PHP-FPM socket
        let findResult = await baseService.execute("find /var/run/php /run/php -name '*.sock' 2>/dev/null | head -1", via: session, timeout: 10)
        let foundSocket = findResult.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if !foundSocket.isEmpty && foundSocket.hasPrefix("/") {
            return foundSocket
        }

        return "/var/run/php/php\(version)-fpm.sock"
    }
}
