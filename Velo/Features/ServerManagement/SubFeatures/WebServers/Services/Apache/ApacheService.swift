//
//  ApacheService.swift
//  Velo
//
//  Public facade for all Apache/httpd operations.
//  Delegates to specialized components for detection, version resolution, path management, and service control.
//

import Foundation
import Combine

@MainActor
final class ApacheService: ObservableObject, WebServerService {
    static let shared = ApacheService()

    let baseService = SSHBaseService.shared
    var serviceName: String {
        // Apache service name varies by OS
        return detectedServiceName ?? "apache2"
    }

    private var detectedServiceName: String?

    // Sub-components
    private let detector = ApacheDetector()
    private let versionResolver = ApacheVersionResolver()
    private let pathResolver = ApachePathResolver()
    private let configValidator = ApacheConfigValidator()

    private init() {}

    // MARK: - ServerModuleService

    func isInstalled(via session: TerminalViewModel) async -> Bool {
        let installed = await detector.isInstalled(via: session)
        if installed {
            detectedServiceName = await detector.getServiceName(via: session)
        }
        return installed
    }

    func getVersion(via session: TerminalViewModel) async -> String? {
        await versionResolver.getVersion(via: session)
    }

    func isRunning(via session: TerminalViewModel) async -> Bool {
        let svcName: String
        if let detected = detectedServiceName {
            svcName = detected
        } else {
            svcName = await detector.getServiceName(via: session)
        }
        
        return await LinuxServiceHelper.isActive(serviceName: svcName, via: session)
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
        let sitesPath = await pathResolver.getSitesEnabledPath(via: session)
        let result = await baseService.execute("ls -1 '\(sitesPath)' 2>/dev/null", via: session, timeout: 10)
        let output = result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        guard !output.isEmpty && !output.contains("cannot access") else {
            return []
        }

        var sites: [Website] = []
        let lines = output.components(separatedBy: CharacterSet.newlines)

        for line in lines {
            let siteName = line.trimmingCharacters(in: .whitespaces)
            guard isValidSiteConfig(siteName) else { continue }

            let configResult = await baseService.execute(
                "grep -E '^[^#]*(ServerName|DocumentRoot|<VirtualHost)' '\(sitesPath)/\(siteName)' 2>/dev/null | head -10",
                via: session, timeout: 10
            )

            let config = parseSiteConfig(configResult.output, siteName: siteName)
            sites.append(config)
        }

        return sites
    }

    func createSite(domain: String, path: String, port: Int, phpVersion: String?, via session: TerminalViewModel) async -> Bool {
        let safeDomain = domain.lowercased().trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        var safePath = path.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)

        if safePath.isEmpty || safePath == "/var/www" {
            safePath = "/var/www/\(safeDomain.replacingOccurrences(of: ".", with: "_"))"
        }

        if !safePath.hasPrefix("/") {
            safePath = "/\(safePath)"
        }

        // Build Apache VirtualHost config
        let config = buildSiteConfig(domain: safeDomain, path: safePath, port: port)

        // Write config file using unified helper
        let configPath = await pathResolver.getSitesAvailablePath(via: session)
        let success = await baseService.writeFile(at: "\(configPath)/\(safeDomain).conf", content: config, useSudo: true, via: session)
        
        guard success else { return false }

        // Enable site
        let enableResult = await enableSite(domain: safeDomain, via: session)
        guard enableResult else { return false }

        // Validate config
        let validation = await validateConfig(via: session)
        if !validation.isValid {
            // Rollback
            await disableSite(domain: safeDomain, via: session)
            _ = await baseService.execute("sudo rm -f '\(configPath)/\(safeDomain).conf'", via: session, timeout: 10)
            return false
        }

        // Reload Apache
        return await reload(via: session)
    }

    func deleteSite(domain: String, deleteFiles: Bool, via session: TerminalViewModel) async -> Bool {
        let availablePath = await pathResolver.getSitesAvailablePath(via: session)
        let enabledPath = await pathResolver.getSitesEnabledPath(via: session)

        // Get document root before deleting config
        var docRoot: String? = nil
        if deleteFiles {
            let rootResult = await baseService.execute(
                "grep -E '^[^#]*DocumentRoot' '\(availablePath)/\(domain).conf' 2>/dev/null | head -1 | awk '{print $2}'",
                via: session, timeout: 10
            )
            docRoot = rootResult.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        }

        // Disable site first
        _ = await disableSite(domain: domain, via: session)

        // Remove config
        _ = await baseService.execute("sudo rm -f '\(availablePath)/\(domain).conf'", via: session, timeout: 10)

        // Delete files if requested
        if deleteFiles, let root = docRoot, !root.isEmpty && root != "/" && root != "/var" && root != "/var/www" {
            _ = await baseService.execute("sudo rm -rf '\(root)'", via: session, timeout: 30)
        }

        return await reload(via: session)
    }

    func enableSite(domain: String, via session: TerminalViewModel) async -> Bool {
        let osType = await pathResolver.getOSType(via: session)

        if osType == .debian {
            let result = await baseService.execute("sudo a2ensite '\(domain).conf' 2>&1 && echo 'ENABLED'", via: session, timeout: 15)
            return result.output.contains("ENABLED") || result.output.contains("already enabled")
        } else {
            // RHEL-style: sites are enabled by placing them in conf.d
            let availablePath = await pathResolver.getSitesAvailablePath(via: session)
            let enabledPath = await pathResolver.getSitesEnabledPath(via: session)
            let result = await baseService.execute(
                "sudo ln -sf '\(availablePath)/\(domain).conf' '\(enabledPath)/\(domain).conf' && echo 'LINKED'",
                via: session, timeout: 10
            )
            return result.output.contains("LINKED")
        }
    }

    func disableSite(domain: String, via session: TerminalViewModel) async -> Bool {
        let osType = await pathResolver.getOSType(via: session)

        if osType == .debian {
            let result = await baseService.execute("sudo a2dissite '\(domain).conf' 2>&1 || true", via: session, timeout: 15)
            return true // a2dissite doesn't fail if site doesn't exist
        } else {
            let enabledPath = await pathResolver.getSitesEnabledPath(via: session)
            let result = await baseService.execute("sudo rm -f '\(enabledPath)/\(domain).conf'", via: session, timeout: 10)
            return true
        }
    }

    func validateConfig(via session: TerminalViewModel) async -> (isValid: Bool, message: String) {
        await configValidator.validate(via: session)
    }

    // MARK: - ControllableService Override

    func reload(via session: TerminalViewModel) async -> Bool {
        await LinuxServiceHelper.executeAction(.reload, serviceName: serviceName, via: session)
    }

    // MARK: - Private Helpers

    private func isValidSiteConfig(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count >= 3, trimmed.count < 100 else { return false }

        let junk = ["welcome", "ubuntu", "nginx", "apache", "mysql", "php", "active", "___velo", "echo ", "root@", "vmi", "[0", "total ", "drw", "password", "ver ", "Ver ", "(ubuntu)", "inactive"]
        for j in junk {
            if trimmed.lowercased().contains(j) { return false }
        }

        if trimmed == "000-default.conf" || trimmed == "default-ssl.conf" { return false }

        let allowedChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_"))
        guard trimmed.unicodeScalars.allSatisfy({ allowedChars.contains($0) }) else { return false }

        return true
    }

    private func parseSiteConfig(_ output: String, siteName: String) -> Website {
        var domain = siteName.replacingOccurrences(of: ".conf", with: "")
        var path = "/var/www/html"
        var port = 80

        let lines = output.components(separatedBy: CharacterSet.newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.contains("ServerName") {
                let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if parts.count >= 2 {
                    domain = parts[1]
                }
            }
            if trimmed.contains("DocumentRoot") {
                let parts = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if parts.count >= 2 {
                    path = parts[1].replacingOccurrences(of: "\"", with: "")
                }
            }
            if trimmed.contains("<VirtualHost") {
                if let portMatch = trimmed.range(of: ":(\\d+)", options: .regularExpression) {
                    let portStr = String(trimmed[portMatch]).dropFirst()
                    port = Int(portStr) ?? 80
                }
            }
        }

        return Website(domain: domain, path: path, status: .running, port: port, framework: "Apache")
    }

    private func buildSiteConfig(domain: String, path: String, port: Int) -> String {
        return """
        <VirtualHost *:\(port)>
            ServerName \(domain)
            ServerAlias www.\(domain)
            DocumentRoot \(path)

            <Directory \(path)>
                Options Indexes FollowSymLinks
                AllowOverride All
                Require all granted
            </Directory>

            ErrorLog ${APACHE_LOG_DIR}/\(domain)_error.log
            CustomLog ${APACHE_LOG_DIR}/\(domain)_access.log combined
        </VirtualHost>
        """
    }
}
