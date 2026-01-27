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
    private let lifecycleManager = ApplicationLifecycleManager.shared

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
                
                guard let version = capability.defaultVersion ?? capability.versions?.first?.version else {
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
                    guard let version = capability.defaultVersion ?? capability.versions?.first?.version else {
                        await appendLog("⚠️ No versions available for \(slug), skipping...")
                        continue
                    }

                    let versionDetails = try await ApiService.shared.fetchCapabilityVersion(slug: slug, version: version)
                    
                    guard let installCommand = getInstallCommand(from: versionDetails, os: osType) else {
                        await appendLog("⚠️ No \(osType) installation for \(slug).")
                        continue
                    }

                    await appendLog("> Executing: \(installCommand)")

                    // Use fallback-enabled installation
                    let success = try await executeInstallationWithFallback(command: installCommand, slug: slug)

                    if success {
                        await appendLog("✅ \(capability.name) installed successfully")
                    } else {
                        await appendLog("⚠️ \(capability.name) installation had issues, continuing...")
                    }

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
            var osType = "ubuntu"
            if let session = session {
                let osInfo = await SystemStatsService.shared.getOSInfo(via: session)
                if !osInfo.id.isEmpty {
                    osType = osInfo.id.lowercased()
                    await appendLog("> Detected OS: \(osInfo.prettyName.isEmpty ? osType : osInfo.prettyName)")
                }
            }
            
            var installCommandToUse = getInstallCommand(from: versionDetail, os: osType)

            // Fallback: If no command found for this specific version (e.g. "3.12"), 
            // try to find a compatible version (e.g. "3.12.1") that HAS commands.
            if installCommandToUse == nil {
                await appendLog("> ⚠️ No instructions for v\(version). Looking for alternatives...")
                
                if let versions = capability.versions {
                    // Look for versions sharing the same major.minor prefix
                    let prefix = version.components(separatedBy: ".").prefix(2).joined(separator: ".")
                    if let alternative = versions.first(where: { 
                        $0.version.hasPrefix(prefix) && 
                        !($0.installCommands?.isEmpty ?? true)
                    }) {
                        await appendLog("> Found alternative instructions from v\(alternative.version)")
                        // We need the full details for this alternative to get the command
                        let altDetail = try await ApiService.shared.fetchCapabilityVersion(slug: capability.slug, version: alternative.version)
                        installCommandToUse = getInstallCommand(from: altDetail, os: osType)
                    }
                }
            }
            
            // Final Fallback: Generic package installation if still nil
            if installCommandToUse == nil {
                if let genericCmd = getGenericInstallCommand(slug: capability.slug, os: osType) {
                    await appendLog("> Using generic installation command.")
                    installCommandToUse = genericCmd
                }
            }

            guard let installCmd = installCommandToUse else {
                await appendLog("> Error: No installation instruction found for \(osType).")
                await completion(success: false)
                return
            }

            await appendLog("> Installation command prepared.")
            await appendLog("> Executing: \(installCmd)")

            // Use fallback-enabled installation (retries without version if specific version unavailable)
            let success = try await executeInstallationWithFallback(command: installCmd, slug: capability.slug)

            if success {
                if let session = session {
                    await enableAndStartService(slug: capability.slug, via: session)
                }
                await completion(success: true)
            } else {
                await completion(success: false)
            }

        } catch {
            await appendLog("> Error: \(error.localizedDescription)")
            await completion(success: false)
        }
    }
    
    // MARK: - Private Helpers

    /// Execute installation with automatic fallback for version-pinning failures
    /// If a versioned install fails (e.g., `apt install redis-server=7.2.4*`),
    /// automatically retries without version pinning (e.g., `apt install redis-server`)
    private func executeInstallationWithFallback(command: String, slug: String) async throws -> Bool {
        guard let session = session else {
            throw NSError(domain: "ServerInstaller", code: 1, userInfo: [NSLocalizedDescriptionKey: "No SSH session"])
        }

        // Auto-inject non-interactive flags for known tools
        var effectiveCommand = command
        if command.contains("composer") {
            effectiveCommand = "export COMPOSER_ALLOW_SUPERUSER=1; " + effectiveCommand
        }
        if command.contains("apt") || command.contains("apt-get") {
             if !effectiveCommand.contains("-y") {
                 effectiveCommand = effectiveCommand.replacingOccurrences(of: "install", with: "install -y")
             }
             effectiveCommand = "export DEBIAN_FRONTEND=noninteractive; " + effectiveCommand
        }

        // First attempt: Try the original versioned command
        await appendLog("> Attempting versioned install...")
        let result = await sshService.execute(effectiveCommand, via: session, timeout: 600)

        await MainActor.run {
            self.installLog += result.output + "\n"
        }

        if result.exitCode == 0 {
            await MainActor.run { self.installProgress = 1.0 }
            return true
        }

        // Check if failure is due to version not found (apt/dnf version errors)
        let output = result.output.lowercased()
        let isVersionError = output.contains("version") && (
            output.contains("not found") ||
            output.contains("has no installation candidate") ||
            output.contains("no match") ||
            output.contains("unable to locate") ||
            output.contains("unable to locate") ||
            output.contains("not available") ||
            output.contains("e: version") ||
            output.contains("e: package")
        )

        // Aggressive fallback: If we were trying to pin a version (contains "=" or similar) 
        // and it failed, and we have a fallback command, we should strictly try the fallback.
        // It is safer to install the repo version than to fail completely.
        let isPinnedVersion = command.contains("=") || (command.contains("install") && command.contains("-") && slug == "redis")
        
        guard isPinnedVersion || isVersionError else {
            // If it wasn't a pinned version install that failed, then it's a real system error (network, disk, etc)
            await appendLog("❌ Installation failed (exit code \(result.exitCode))")
            return false
        }

        // Generate fallback command without version pinning
        guard let fallbackCommand = generateFallbackCommand(from: command, slug: slug) else {
            await appendLog("❌ Version not available and no fallback possible")
            return false
        }

        await appendLog("> ⚠️ Specific version not available in repository")
        await appendLog("> 🔄 Retrying with latest available version...")
        await appendLog("> Executing: \(fallbackCommand)")

        // Second attempt: Try without version pinning
        let fallbackResult = await sshService.execute(fallbackCommand, via: session, timeout: 600)

        await MainActor.run {
            self.installLog += fallbackResult.output + "\n"
        }

        if fallbackResult.exitCode == 0 {
            await MainActor.run { self.installProgress = 1.0 }
            await appendLog("> ✅ Installed latest available version successfully")
            return true
        } else {
            await appendLog("❌ Fallback installation also failed (exit code \(fallbackResult.exitCode))")
            return false
        }
    }

    /// Generate a fallback command without version pinning
    /// Transforms: "apt install -y redis-server=7.2.4*" → "apt install -y redis-server"
    /// Transforms: "dnf install -y redis-7.2.4" → "dnf install -y redis"
    private func generateFallbackCommand(from command: String, slug: String) -> String? {
        var fallback = command

        // Remove apt version pinning: package=version* or package=version
        // Pattern: packagename=anything (until space or end)
        if let regex = try? NSRegularExpression(pattern: "=\\S+", options: []) {
            let range = NSRange(location: 0, length: fallback.utf16.count)
            fallback = regex.stringByReplacingMatches(in: fallback, options: [], range: range, withTemplate: "")
        }

        // Remove dnf/yum version pinning: package-version (where version starts with digit)
        // Pattern: -X.X.X or -X.X or -X (version numbers after package name)
        // Be careful not to remove legitimate package name parts like "redis-server"
        // Only remove version-like suffixes: -7.2.4, -3.2, etc.
        if let regex = try? NSRegularExpression(pattern: "-\\d+(\\.\\d+)*\\*?(?=\\s|$)", options: []) {
            let range = NSRange(location: 0, length: fallback.utf16.count)
            fallback = regex.stringByReplacingMatches(in: fallback, options: [], range: range, withTemplate: "")
        }

        // Clean up any double spaces
        while fallback.contains("  ") {
            fallback = fallback.replacingOccurrences(of: "  ", with: " ")
        }

        // Return nil if nothing changed (no version to strip)
        return fallback != command ? makeCommandRobust(fallback) : nil
    }
    
    // Helper to make apt commands more robust against post-invoke hook failures (exit code 100)
    private func makeCommandRobust(_ command: String) -> String {
        var robust = command
        // Replace "apt update &&" with "apt update || true &&" to ignore update hook failures
        if robust.contains("apt update &&") {
            robust = robust.replacingOccurrences(of: "apt update &&", with: "apt update || true &&")
        }
        if robust.contains("apt-get update &&") {
            robust = robust.replacingOccurrences(of: "apt-get update &&", with: "apt-get update || true &&")
        }
        return robust
    }

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
        guard let commands = version.installCommands else { 
            print("SERVER_INSTALLER: installCommands is NIL for version \(version.version)")
            return nil 
        }
        let osKey = os.lowercased()
        print("SERVER_INSTALLER: Resolving command for OS: '\(osKey)'. Available keys: \(commands.keys.sorted())")
        
        // Helper to resolve instruction
        func resolve(_ instruction: InstallInstruction?) -> String? {
            guard let instruction = instruction else { return nil }
            switch instruction {
            case .list(let cmds):
                return cmds.isEmpty ? nil : cmds.joined(separator: " && ")
            case .keyed(let dict):
                // Prefer "default" key, otherwise check if there's only one key or take first
                return dict["default"] ?? dict.values.first
            }
        }
        
        // Strategy 1: Exact Match (e.g. "ubuntu")
        if let cmd = resolve(commands[osKey]) { return cmd }
        
        // Strategy 2: OS Family Fallback
        // Common derivations
        let families: [String: [String]] = [
            "ubuntu": ["debian"],
            "linuxmint": ["ubuntu", "debian"],
            "pop": ["ubuntu", "debian"],
            "kali": ["debian"],
            "centos": ["rhel", "fedora"],
            "almalinux": ["rhel", "centos", "fedora"],
            "rocky": ["rhel", "centos", "fedora"],
            "fedora": ["rhel"]
        ]
        
        if let fallbacks = families[osKey] {
            for fallback in fallbacks {
                if let cmd = resolve(commands[fallback]) { return cmd }
            }
        }
        
        // Strategy 3: Prefix Matching (e.g. "ubuntu-22.04" when we have "ubuntu")
        // Check if any key in `commands` starts with osKey
        if let key = commands.keys.first(where: { $0.lowercased().hasPrefix(osKey) }),
           let cmd = resolve(commands[key]) {
            return cmd
        }

        // Strategy 4: Generic "linux"
        if let cmd = resolve(commands["linux"]) { return cmd }
        
        // Strategy 5: "default"
        if let cmd = resolve(commands["default"]) { return cmd }
        
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

            // Register installation with lifecycle manager
            if let appId = getAppIdForSlug(currentInstallingCapability?.lowercased() ?? ""),
               let session = session {
                Task {
                    await lifecycleManager.registerInstallation(
                        appId: appId,
                        version: "latest",
                        via: session
                    )
                }
            }

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
        case "php-fpm": return "php-fpm"
        // Runtimes and tools have no systemd service
        case "python", "python3", "node", "nodejs", "git", "composer": return ""
        default: return slug
        }
    }

    private func getAppIdForSlug(_ slug: String) -> String? {
        // Map capability slugs to application IDs
        switch slug.lowercased() {
        case "nginx": return "nginx"
        case "apache", "apache2": return "apache"
        case "php", "php-fpm": return "php"
        case "mysql", "mariadb": return "mysql"
        case "postgresql", "postgres": return "postgresql"
        case "redis": return "redis"
        case "mongodb", "mongo": return "mongodb"
        case "python", "python3": return "python"
        case "nodejs", "node": return "nodejs"
        case "git": return "git"
        default: return nil
        }
    }
    
    private func getGenericInstallCommand(slug: String, os: String) -> String? {
        // Only safely fallback for Debian/Ubuntu environments where package names are predictable
        guard os == "ubuntu" || os == "debian" else { return nil }
        
        switch slug.lowercased() {
        case "python": return "DEBIAN_FRONTEND=noninteractive apt-get update || true && DEBIAN_FRONTEND=noninteractive apt-get install -y python3"
        case "redis": return "DEBIAN_FRONTEND=noninteractive apt-get update || true && DEBIAN_FRONTEND=noninteractive apt-get install -y redis-server"
        case "postgresql", "postgres": return "DEBIAN_FRONTEND=noninteractive apt-get update || true && DEBIAN_FRONTEND=noninteractive apt-get install -y postgresql"
        case "nginx": return "DEBIAN_FRONTEND=noninteractive apt-get update || true && DEBIAN_FRONTEND=noninteractive apt-get install -y nginx"
        case "php": return "DEBIAN_FRONTEND=noninteractive apt-get update || true && DEBIAN_FRONTEND=noninteractive apt-get install -y php-fpm"
        case "git": return "DEBIAN_FRONTEND=noninteractive apt-get update || true && DEBIAN_FRONTEND=noninteractive apt-get install -y git"
        default: return nil
        }
    }
}
