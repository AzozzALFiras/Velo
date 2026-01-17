//
//  WebsitesViewModel.swift
//  Velo
//
//  ViewModel for website management including creation, listing, and configuration.
//  Supports both Nginx and Apache web servers.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class WebsitesViewModel: ObservableObject {

    // MARK: - Dependencies
    weak var session: TerminalViewModel?
    private let nginxService = NginxService.shared
    private let apacheService = ApacheService.shared
    private let phpService = PHPService.shared

    // MARK: - Published State

    @Published var websites: [Website] = []
    @Published var isLoading = false
    @Published var isCreating = false
    @Published var errorMessage: String?

    // Track locally-created websites that may not yet be visible on the server
    private var locallyCreatedDomains: Set<String> = []

    // Server capabilities
    @Published var hasNginx = false
    @Published var hasApache = false
    @Published var hasPHP = false
    @Published var availablePHPVersions: [String] = []

    // MARK: - Init

    init(session: TerminalViewModel? = nil) {
        self.session = session
    }

    // MARK: - Data Loading

    /// Load all websites from configured web servers
    func loadWebsites() async {
        guard let session = session else { return }

        isLoading = true
        errorMessage = nil

        // Check what's installed
        async let nginxCheck = nginxService.isInstalled(via: session)
        async let apacheCheck = apacheService.isInstalled(via: session)
        async let phpCheck = phpService.isInstalled(via: session)

        hasNginx = await nginxCheck
        hasApache = await apacheCheck
        hasPHP = await phpCheck

        if hasPHP {
            availablePHPVersions = await phpService.getInstalledVersions(via: session)
        }

        // Fetch sites from installed web servers
        var serverSites: [Website] = []

        if hasNginx {
            let nginxSites = await nginxService.fetchSites(via: session)
            serverSites.append(contentsOf: nginxSites)
            print("🌐 [WebsitesVM] Fetched \(nginxSites.count) Nginx sites")
        }

        if hasApache {
            let apacheSites = await apacheService.fetchSites(via: session)
            serverSites.append(contentsOf: apacheSites)
            print("🌐 [WebsitesVM] Fetched \(apacheSites.count) Apache sites")
        }

        // Merge: Keep locally-created sites that aren't yet on the server
        let serverDomains = Set(serverSites.map { $0.domain.lowercased() })
        let localOnlySites = websites.filter { site in
            let domainLower = site.domain.lowercased()
            return locallyCreatedDomains.contains(domainLower) && !serverDomains.contains(domainLower)
        }
        
        // Remove from tracking any sites that now appear on server
        locallyCreatedDomains = locallyCreatedDomains.filter { !serverDomains.contains($0) }
        
        // Combine: server sites first, then local-only sites
        websites = serverSites + localOnlySites
        
        print("🌐 [WebsitesVM] Total websites: \(websites.count) (server: \(serverSites.count), local-only: \(localOnlySites.count))")
        
        isLoading = false
    }

    /// Refresh websites list
    func refresh() async {
        await loadWebsites()
    }

    // MARK: - Website CRUD Operations

    /// Create a new website
    func createWebsite(domain: String, path: String, framework: String, port: Int = 80, phpVersion: String? = nil) async -> Bool {
        guard let session = session else { return false }

        isCreating = true
        errorMessage = nil

        // Determine which web server to use
        var success = false
        var webServerUsed = "Static"

        // Create document root and index file first
        let baseService = SSHBaseService.shared
        let safePath = path.isEmpty ? "/var/www/\(domain.replacingOccurrences(of: ".", with: "_"))" : path

        // Create directory
        let mkdirRes = await baseService.execute("sudo mkdir -p '\(safePath)'", via: session, timeout: 15)
        guard mkdirRes.exitCode == 0 || !mkdirRes.output.contains("denied") else {
            errorMessage = "Failed to create directory: \(mkdirRes.output)"
            isCreating = false
            return false
        }
        
        _ = await baseService.execute("sudo chown -R www-data:www-data '\(safePath)' 2>/dev/null || sudo chown -R nginx:nginx '\(safePath)' 2>/dev/null || true", via: session, timeout: 15)
        _ = await baseService.execute("sudo chmod -R 755 '\(safePath)'", via: session, timeout: 15)

        // Create default index file
        await createDefaultIndexFile(at: safePath, domain: domain, framework: framework, session: session)

        // Create web server config
        let effectivePHPVersion = framework.lowercased().contains("php") ? (phpVersion ?? availablePHPVersions.first) : nil

        if hasNginx {
            success = await nginxService.createSite(domain: domain, path: safePath, port: port, phpVersion: effectivePHPVersion, via: session)
            if success {
                webServerUsed = "Nginx"
            }
        } else if hasApache {
            success = await apacheService.createSite(domain: domain, path: safePath, port: port, phpVersion: effectivePHPVersion, via: session)
            if success {
                webServerUsed = "Apache"
            }
        }

        if success {
            // Track this domain as locally-created
            locallyCreatedDomains.insert(domain.lowercased())
            
            // Add to local state
            let newSite = Website(
                id: UUID(),
                domain: domain,
                path: safePath,
                status: .running,
                port: port,
                framework: "\(framework) (\(webServerUsed))"
            )
            websites.insert(newSite, at: 0)
            print("✅ [WebsitesVM] Website created locally: \(domain)")
        } else {
            errorMessage = "Failed to create website configuration"
        }

        isCreating = false
        return success
    }

    /// Delete a website
    func deleteWebsite(_ website: Website, deleteFiles: Bool = false) async -> Bool {
        guard let session = session else { return false }

        let isNginx = website.framework.lowercased().contains("nginx")
        let success: Bool

        if isNginx {
            success = await nginxService.deleteSite(domain: website.domain, deleteFiles: deleteFiles, via: session)
        } else {
            success = await apacheService.deleteSite(domain: website.domain, deleteFiles: deleteFiles, via: session)
        }

        if success {
            websites.removeAll { $0.id == website.id }
        }

        return success
    }

    /// Toggle website status (enable/disable)
    func toggleWebsiteStatus(_ website: Website) async -> Bool {
        guard let session = session else { return false }

        let isNginx = website.framework.lowercased().contains("nginx")
        let isRunning = website.status == .running
        var success = false

        if isRunning {
            // Disable site
            if isNginx {
                success = await nginxService.disableSite(domain: website.domain, via: session)
                if success {
                    _ = await nginxService.reload(via: session)
                }
            } else {
                success = await apacheService.disableSite(domain: website.domain, via: session)
                if success {
                    _ = await apacheService.reload(via: session)
                }
            }
        } else {
            // Enable site
            if isNginx {
                success = await nginxService.enableSite(domain: website.domain, via: session)
                if success {
                    _ = await nginxService.reload(via: session)
                }
            } else {
                success = await apacheService.enableSite(domain: website.domain, via: session)
                if success {
                    _ = await apacheService.reload(via: session)
                }
            }
        }

        if success {
            if let index = websites.firstIndex(where: { $0.id == website.id }) {
                websites[index].status = isRunning ? .stopped : .running
            }
        }

        return success
    }

    /// Restart the web server for a website
    func restartWebsite(_ website: Website) async -> Bool {
        guard let session = session else { return false }

        let isNginx = website.framework.lowercased().contains("nginx")

        if isNginx {
            return await nginxService.restart(via: session)
        } else {
            return await apacheService.restart(via: session)
        }
    }

    /// Locally update a website's state
    func updateWebsite(_ website: Website) {
        if let index = websites.firstIndex(where: { $0.id == website.id }) {
            websites[index] = website
        }
    }

    // MARK: - PHP Version Management

    /// Switch PHP version for a website (Nginx only)
    func switchPHPVersion(forWebsite website: Website, toVersion version: String) async -> Bool {
        guard let session = session else { return false }
        guard website.framework.lowercased().contains("nginx") else {
            errorMessage = "PHP version switching is only supported for Nginx sites"
            return false
        }

        let baseService = SSHBaseService.shared

        // Update nginx config to use new PHP-FPM socket
        let configPath = "/etc/nginx/sites-available/\(website.domain)"
        _ = await baseService.execute("sudo sed -i 's/php[0-9.]*-fpm.sock/php\(version)-fpm.sock/g' '\(configPath)'", via: session, timeout: 15)

        // Validate and reload
        let validation = await nginxService.validateConfig(via: session)
        if validation.isValid {
            return await nginxService.reload(via: session)
        } else {
            errorMessage = "Config validation failed: \(validation.message)"
            return false
        }
    }

    // MARK: - Private Helpers

    private func createDefaultIndexFile(at path: String, domain: String, framework: String, session: TerminalViewModel) async {
        let baseService = SSHBaseService.shared

        let fileName: String
        let content: String

        if framework.lowercased().contains("php") {
            fileName = "index.php"
            content = """
            <?php
            // Created by Velo Server Management
            ?>
            <!DOCTYPE html>
            <html lang="en">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>Welcome to \(domain)</title>
                <style>
                    body { margin: 0; padding: 0; font-family: system-ui, -apple-system, sans-serif; background: #0f172a; color: #fff; display: flex; align-items: center; justify-content: center; height: 100vh; }
                    .container { text-align: center; padding: 40px; background: #1e293b; border-radius: 16px; box-shadow: 0 10px 25px rgba(0,0,0,0.5); border: 1px solid #334155; max-width: 400px; }
                    h1 { margin: 0 0 10px; font-size: 24px; font-weight: 700; }
                    p { color: #94a3b8; margin-bottom: 24px; }
                    .badge { display: inline-block; padding: 6px 12px; background: linear-gradient(135deg, #6366f1, #8b5cf6); color: white; border-radius: 20px; font-size: 12px; font-weight: 600; text-transform: uppercase; }
                </style>
            </head>
            <body>
                <div class="container">
                    <div class="badge">Created By Velo</div>
                    <h1 style="margin-top: 20px;">\(domain)</h1>
                    <p>PHP <?php echo phpversion(); ?> is running</p>
                </div>
            </body>
            </html>
            """
        } else {
            fileName = "index.html"
            content = """
            <!DOCTYPE html>
            <html lang="en">
            <head>
                <meta charset="UTF-8">
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <title>Welcome to \(domain)</title>
                <style>
                    body { margin: 0; padding: 0; font-family: system-ui, -apple-system, sans-serif; background: #0f172a; color: #fff; display: flex; align-items: center; justify-content: center; height: 100vh; }
                    .container { text-align: center; padding: 40px; background: #1e293b; border-radius: 16px; box-shadow: 0 10px 25px rgba(0,0,0,0.5); border: 1px solid #334155; max-width: 400px; }
                    h1 { margin: 0 0 10px; font-size: 24px; font-weight: 700; }
                    p { color: #94a3b8; margin-bottom: 24px; }
                    .badge { display: inline-block; padding: 6px 12px; background: linear-gradient(135deg, #6366f1, #8b5cf6); color: white; border-radius: 20px; font-size: 12px; font-weight: 600; text-transform: uppercase; }
                </style>
            </head>
            <body>
                <div class="container">
                    <div class="badge">Created By Velo</div>
                    <h1 style="margin-top: 20px;">\(domain)</h1>
                    <p>Ready for content</p>
                </div>
            </body>
            </html>
            """
        }

        if let data = content.data(using: .utf8) {
            let base64 = data.base64EncodedString()
            
            // Use printf for maximal compatibility across shells and PTYs
            let result = await baseService.execute("printf '\(base64)' | base64 --decode > '\(path)/\(fileName)'", via: session, timeout: 20)
            
            if result.exitCode != 0 {
                print("⚠️ [WebsitesVM] Failed to write file: \(result.output)")
                // Try fallback with -d
                _ = await baseService.execute("printf '\(base64)' | base64 -d > '\(path)/\(fileName)'", via: session, timeout: 20)
            }
            
            // Verify existence
            let verify = await baseService.execute("test -f '\(path)/\(fileName)' && echo 'OK'", via: session, timeout: 5)
            if !verify.output.contains("OK") {
                print("❌ [WebsitesVM] File creation verification failed for \(fileName)")
            } else {
                print("✅ [WebsitesVM] File successfully created: \(fileName)")
            }
        }
    }
}
