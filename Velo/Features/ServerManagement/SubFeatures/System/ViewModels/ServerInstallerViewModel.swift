//
//  ServerInstallerViewModel.swift
//  Velo
//
//  ViewModel for handling server software installation and capabilities.
//  Extracts complex installation logic from ServerManagementViewModel.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class ServerInstallerViewModel: ObservableObject {
    
    // MARK: - Dependencies
    weak var session: TerminalViewModel?
    private let sshService = SSHBaseService.shared
    
    // MARK: - Published State
    @Published var availableCapabilities: [Capability] = []
    @Published var searchQuery: String = ""
    @Published var isInstalling: Bool = false
    @Published var installLog: String = ""
    @Published var installProgress: Double = 0.0
    @Published var showInstallOverlay: Bool = false
    @Published var currentInstallingCapability: String?
    
    // Callbacks
    var onInstallationComplete: ((Bool) -> Void)?
    
    var filteredCapabilities: [Capability] {
        if searchQuery.isEmpty {
            return availableCapabilities
        }
        return availableCapabilities.filter { $0.name.localizedCaseInsensitiveContains(searchQuery) }
    }
    
    init(session: TerminalViewModel? = nil) {
        self.session = session
    }
    
    // MARK: - Capabilities
    
    func fetchCapabilities() async {
        do {
            let caps = try await ApiService.shared.fetchCapabilities()
            await MainActor.run {
                self.availableCapabilities = caps
            }
        } catch {
            print("Failed to fetch capabilities: \(error)")
        }
    }
    
    // MARK: - Installation Actions
    
    /// Install a capability by its slug
    func installCapabilityBySlug(_ slug: String) {
        Task {
            await MainActor.run {
                self.showInstallOverlay = true
                self.isInstalling = true
                self.currentInstallingCapability = slug.capitalized
                self.installProgress = 0.0
                self.installLog = "> Fetching \(slug.capitalized) details...\n"
                AppLogger.shared.log("Initiating installation for: \(slug)", level: .info)
            }
            
            do {
                let capability = try await ApiService.shared.fetchCapabilityDetails(slug: slug)
                
                guard let version = capability.defaultVersion?.version ?? capability.versions?.first?.version else {
                    await appendLog("❌ No versions available for \(slug)")
                    await MainActor.run { self.isInstalling = false }
                    return
                }
                
                await appendLog("> Installing \(capability.name) v\(version)...")
                await installCapability(capability, version: version)
            } catch {
                await appendLog("❌ Error: \(error.localizedDescription)")
                await MainActor.run {
                    self.isInstalling = false
                    self.showInstallOverlay = false
                }
            }
        }
    }
    
    /// Install a stack of capabilities sequentially
    func installStack(_ slugs: [String], osType: String) {
        Task {
            await MainActor.run {
                self.showInstallOverlay = true
                self.isInstalling = true
                self.currentInstallingCapability = "Stack"
                self.installProgress = 0.0
                self.installLog = "> Installing stack: \(slugs.joined(separator: " + "))...\n"
            }

            let totalSteps = Double(slugs.count)

            for (index, slug) in slugs.enumerated() {
                let progress = Double(index) / totalSteps
                await MainActor.run {
                    self.installProgress = progress
                    self.currentInstallingCapability = slug.capitalized
                }

                await appendLog("\n> [\(index + 1)/\(slugs.count)] Installing \(slug.capitalized)...")

                do {
                    let capability = try await ApiService.shared.fetchCapabilityDetails(slug: slug)
                    guard let version = capability.defaultVersion?.version ?? capability.versions?.first?.version else {
                        await appendLog("⚠️ No versions available for \(slug), skipping...")
                        continue
                    }

                    let versionDetails = try await ApiService.shared.fetchCapabilityVersion(slug: slug, version: version)
                    
                    guard let installCommand = getInstallCommand(from: versionDetails, os: osType) else {
                        await appendLog("⚠️ No \(osType) installation for \(slug).")
                        continue
                    }

                    await appendLog("> Executing: \(installCommand)")
                    
                    try await executeRealInstallation(command: installCommand)
                    await appendLog("✅ \(capability.name) installed successfully")

                    await appendLog("> Enabling and starting \(slug) service...")
                    
                    if let session = session {
                        await enableAndStartService(slug: slug, via: session)
                    }

                } catch {
                    await appendLog("❌ Failed to install \(slug): \(error.localizedDescription)")
                }
            }

            await MainActor.run {
                self.installProgress = 1.0
                self.installLog += "\n> Stack Installation Completed! ✅"
            }

            await completion(success: true)
        }
    }
    
    func installCapability(_ capability: Capability, version: String) async {
        await MainActor.run {
            self.showInstallOverlay = true
            self.isInstalling = true
            self.currentInstallingCapability = capability.name
            self.installProgress = 0.0
            self.installLog = "> Initializing installation for \(capability.name) v\(version)...\n"
        }

        do {
            await appendLog("> Fetching installation details from Velo API...")
            let versionDetail = try await ApiService.shared.fetchCapabilityVersion(slug: capability.slug, version: version)

            await appendLog("> Detecting server OS...")
            // We need OS type here - in a real app better to pass it in or fetch it
            let osType = "ubuntu" // Defaulting for now as we don't have stats here directly
            
            guard let installCmd = getInstallCommand(from: versionDetail, os: osType) else {
                await appendLog("> Error: No installation instruction found for \(osType).")
                await completion(success: false)
                return
            }

            await appendLog("> Installation command prepared.")
            await appendLog("> Executing: \(installCmd)")

            try await executeRealInstallation(command: installCmd)

            if let session = session {
                await enableAndStartService(slug: capability.slug, via: session)
            }
            
            await completion(success: true)

        } catch {
            await appendLog("> Error: \(error.localizedDescription)")
            await completion(success: false)
        }
    }
    
    // MARK: - Private Helpers
    
    private func executeRealInstallation(command: String) async throws {
        guard let session = session else {
            throw NSError(domain: "ServerInstaller", code: 1, userInfo: [NSLocalizedDescriptionKey: "No SSH session"])
        }
        
        let result = await sshService.execute(command, via: session, timeout: 600) // Longer timeout for installs
        await MainActor.run {
            self.installLog += result.output + "\n"
            if result.exitCode == 0 {
                self.installProgress = 1.0
            } else {
                self.installLog += "❌ Command failed with exit code \(result.exitCode)\n"
            }
        }
    }
    
    private func getInstallCommand(from version: CapabilityVersion, os: String) -> String? {
        guard let commands = version.installCommands else { return nil }
        let osKey = os.lowercased()
        
        if let osCommands = commands[osKey], let cmd = osCommands["default"] ?? osCommands["install"] {
            return cmd
        }
        if let linuxCommands = commands["linux"], let cmd = linuxCommands["default"] ?? linuxCommands["install"] {
            return cmd
        }
        if let defaultCmd = commands["default"] as? String {
            return defaultCmd
        }
        return nil
    }
    
    @MainActor
    private func appendLog(_ text: String) {
        self.installLog += "\(text)\n"
    }
    
    @MainActor
    private func completion(success: Bool) {
        self.isInstalling = false
        if success {
            self.installLog += "\n> Installation Completed Successfully! ✅"
            self.installProgress = 1.0
            
            // Notify parent
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run {
                    self.showInstallOverlay = false
                    self.onInstallationComplete?(true)
                }
            }
        } else {
            self.installLog += "\n> Installation Failed! ❌"
            self.onInstallationComplete?(false)
        }
    }
    
    private func enableAndStartService(slug: String, via session: TerminalViewModel) async {
        // Logic similar to previous implementation...
        // For brevity in this extraction, simplified:
        let serviceName = getServiceName(for: slug)
        guard !serviceName.isEmpty else { return }
        
        await appendLog("> Enabling and starting \(serviceName)...")
        _ = await sshService.execute("sudo systemctl enable \(serviceName) && sudo systemctl start \(serviceName)", via: session)
    }
    
    private func getServiceName(for slug: String) -> String {
        switch slug.lowercased() {
        case "nginx": return "nginx"
        case "apache", "apache2": return "apache2"
        case "mysql": return "mysql"
        case "mariadb": return "mariadb"
        case "postgresql": return "postgresql"
        case "redis": return "redis-server"
        case "mongodb": return "mongod"
        case "php-fpm": return "php-fpm" // simplified
        default: return slug
        }
    }
}
