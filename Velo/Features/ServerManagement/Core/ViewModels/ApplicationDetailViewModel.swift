//
//  ApplicationDetailViewModel.swift
//  Velo
//
//  Unified view model for all application detail views.
//

import Foundation
import Combine
import SwiftUI

@MainActor
final class ApplicationDetailViewModel: ObservableObject {

    // MARK: - Dependencies

    let app: ApplicationDefinition
    weak var session: TerminalViewModel?

    /// Access registries lazily to avoid MainActor deadlock during init
    private var providerRegistry: SectionProviderRegistry {
        SectionProviderRegistry.shared
    }
    private var serviceResolver: ServiceResolver {
        ServiceResolver.shared
    }
    private var lifecycleManager: ApplicationLifecycleManager {
        ApplicationLifecycleManager.shared
    }

    // MARK: - Published State

    @Published var state: ApplicationState
    @Published var selectedSection: SectionDefinition
    @Published var isLoading = false
    @Published var isPerformingAction = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(app: ApplicationDefinition, session: TerminalViewModel?) {
        self.app = app
        self.session = session
        let newState = ApplicationState()
        self.state = newState
        self.selectedSection = app.defaultSection ?? app.sections.first!
        
        // Bind state changes to ViewModel changes to ensure UI updates propagate
        newState.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // Observe lifecycle state changes
        lifecycleManager.$lifecycleStates
            .map { $0[app.id] ?? .notInstalled }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newLifecycleState in
                self?.state.lifecycleState = newLifecycleState
            }
            .store(in: &cancellables)
    }

    // MARK: - Data Loading

    /// Load all initial data
    func loadData() async {
        guard session != nil else {
            errorMessage = "No SSH session available"
            return
        }

        isLoading = true
        errorMessage = nil

        // Load API data (available versions, etc.)
        await loadAPIData()
        
        // Load service status only if NOT in Service section (provider handles it there)
        // This prevents double-execution of status commands on open
        if selectedSection.name != "Service" {
            await loadServiceStatus()
        }

        // Refresh lifecycle state
        if let session = session {
            await lifecycleManager.refreshState(for: app.id, via: session)
        }

        // Load current section data
        await loadSectionData()

        isLoading = false
    }

    /// Load data for the currently selected section
    func loadSectionData() async {
        guard let session = session else { return }
        guard !state.isInstallingVersion else { return }

        do {
            try await providerRegistry.loadData(
                for: selectedSection,
                app: app,
                state: state,
                session: session
            )
        } catch {
            // Don't show error for unsupported sections
            if case SectionProviderError.notSupported = error {
                // Expected for some section types
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Load service status
    private func loadServiceStatus() async {
        guard let session = session else { return }

        guard let service = serviceResolver.resolve(for: app.id) else { return }

        let status = await service.getStatus(via: session)

        switch status {
        case .running(let ver):
            state.isRunning = true
            state.version = ver
        case .stopped(let ver):
            state.isRunning = false
            state.version = ver
        case .installed(let ver):
            state.isRunning = false // Python/Node are just runtimes, not services (usually)
            state.version = ver
        default:
            state.isRunning = false
            state.version = "Not Installed"
        }

        // Get binary path logic
        // Use configured binary path name if available, otherwise fallback to app.id
        let binaryName = app.serviceConfig.binaryPath.isEmpty ? app.id : URL(fileURLWithPath: app.serviceConfig.binaryPath).lastPathComponent
        
        // Extended binary search
        var finalBinaryPath = ""
        let directWhich = await SSHBaseService.shared.execute("which \(binaryName) 2>/dev/null", via: session)
        
        if !directWhich.output.isEmpty && directWhich.exitCode == 0 {
            finalBinaryPath = directWhich.output.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            // Fallback: Check common paths
            let commonPaths = ["/usr/sbin/\(binaryName)", "/usr/bin/\(binaryName)", "/usr/local/bin/\(binaryName)", "/usr/local/sbin/\(binaryName)", "/bin/\(binaryName)", "/sbin/\(binaryName)"]
            let checkCmd = "ls " + commonPaths.joined(separator: " ") + " 2>/dev/null | head -n 1"
            let fallbackResult = await SSHBaseService.shared.execute(checkCmd, via: session)
            
            if !fallbackResult.output.isEmpty {
                 finalBinaryPath = fallbackResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        state.binaryPath = finalBinaryPath
        
        // If no binary path found yet, and a specific path is configured, check if that path exists
        if state.binaryPath.isEmpty && !app.serviceConfig.binaryPath.isEmpty {
             let existCheck = await SSHBaseService.shared.execute("[ -f \(app.serviceConfig.binaryPath) ] && echo 'yes'", via: session)
             if existCheck.output.contains("yes") {
                 state.binaryPath = app.serviceConfig.binaryPath
             }
        }

        state.configPath = app.serviceConfig.configPath
    }

    /// Load data from API (available versions)
    private func loadAPIData() async {
        do {
            print("🔍 [AppDetail] Loading capabilities for slug: \(app.slug)")
            let capabilities = try await ApiService.shared.fetchCapabilities()
            
            if let capability = capabilities.first(where: { 
                $0.slug.lowercased() == app.slug.lowercased() || 
                $0.name.lowercased() == app.name.lowercased() 
            }) {
                print("✅ [AppDetail] Found capability match: \(capability.name)")
                
                if let versions = capability.versions, !versions.isEmpty {
                    print("✅ [AppDetail] Using \(versions.count) versions from list response")
                    state.availableVersions = versions
                } else {
                    print("⚠️ [AppDetail] Match found but no versions in list. Fetching details for \(app.slug)...")
                    do {
                        let directCap = try await ApiService.shared.fetchCapabilityDetails(slug: app.slug)
                        state.availableVersions = directCap.versions ?? []
                        print("✅ [AppDetail] Loaded \(state.availableVersions.count) versions from details")
                    } catch {
                        print("❌ [AppDetail] Detailed fetch failed: \(error)")
                        // Keep empty if failed
                        state.availableVersions = []
                    }
                }
            } else {
                print("⚠️ [AppDetail] No capability match found for \(app.slug) in \(capabilities.count) capabilities")
                // Fallback: try fetching by slug directly
                do {
                    let directCap = try await ApiService.shared.fetchCapabilityDetails(slug: app.slug)
                    state.availableVersions = directCap.versions ?? []
                    print("✅ [AppDetail] Found direct capability: \(directCap.name), versions: \(directCap.versions?.count ?? 0)")
                } catch {
                    print("⚠️ [AppDetail] Direct fetch failed: \(error)")
                }
            }
        } catch {
            print("❌ [AppDetail] Failed to fetch capabilities: \(error)")
        }
    }

    // MARK: - Service Actions

    func startService() async {
        await performAsyncAction("Start \(app.name)") {
            guard let session = self.session else { return (false, "No session") }

            let success = await self.serviceResolver.startService(for: self.app.id, via: session)

            if success {
                await self.loadServiceStatus()
                return (true, "\(self.app.name) started successfully")
            } else {
                // Try to get error details
                let status = await SSHBaseService.shared.execute(
                    "sudo systemctl status \(self.app.serviceConfig.serviceName) --no-pager -l -n 10",
                    via: session
                )
                return (false, "Failed to start \(self.app.name): \(self.stripANSI(status.output))")
            }
        }
    }

    func stopService() async {
        await performAsyncAction("Stop \(app.name)") {
            guard let session = self.session else { return (false, "No session") }

            let success = await self.serviceResolver.stopService(for: self.app.id, via: session)

            if success {
                self.state.isRunning = false
                return (true, "\(self.app.name) stopped successfully")
            } else {
                return (false, "Failed to stop \(self.app.name)")
            }
        }
    }

    func restartService() async {
        await performAsyncAction("Restart \(app.name)") {
            guard let session = self.session else { return (false, "No session") }

            let success = await self.serviceResolver.restartService(for: self.app.id, via: session)

            if success {
                await self.loadServiceStatus()
                return (true, "\(self.app.name) restarted successfully")
            } else {
                let status = await SSHBaseService.shared.execute(
                    "sudo systemctl status \(self.app.serviceConfig.serviceName) --no-pager -l -n 10",
                    via: session
                )
                return (false, "Failed to restart \(self.app.name): \(self.stripANSI(status.output))")
            }
        }
    }

    func reloadService() async {
        await performAsyncAction("Reload \(app.name)") {
            guard let session = self.session else { return (false, "No session") }

            // Test config first for web servers
            if app.capabilities.contains(.configurable) {
                let testCommand: String
                switch self.app.id.lowercased() {
                case "nginx":
                    testCommand = "sudo nginx -t"
                case "apache", "apache2":
                    testCommand = "sudo apache2ctl configtest"
                default:
                    testCommand = ""
                }

                if !testCommand.isEmpty {
                    let testResult = await SSHBaseService.shared.execute(testCommand, via: session)
                    if testResult.exitCode != 0 {
                        return (false, "Config test failed: \(testResult.output)")
                    }
                }
            }

            let success = await self.serviceResolver.reloadService(for: self.app.id, via: session)
            return (success, success ? "\(self.app.name) configuration reloaded" : "Failed to reload \(self.app.name)")
        }
    }

    // MARK: - Configuration Actions

    func updateConfigValue(_ key: String, to newValue: String) async {
        await performAsyncAction("Update \(key)") {
            guard let session = self.session else { return (false, "No session") }

            let configPath = self.state.configPath
            guard !configPath.isEmpty else { return (false, "Config path not set") }

            // Read current config
            let readResult = await SSHBaseService.shared.execute("cat '\(configPath)'", via: session)
            var content = readResult.output

            // Replace using regex based on config format
            let pattern = "(\(key)\\s*[=\\s]+)([^;\\n]+)"
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(content.startIndex..., in: content)
                let newContent = regex.stringByReplacingMatches(
                    in: content,
                    options: [],
                    range: range,
                    withTemplate: "$1\(newValue)"
                )

                if newContent != content {
                    let saveResult = await SSHBaseService.shared.writeFile(
                        at: configPath,
                        content: newContent,
                        useSudo: true,
                        via: session
                    )

                    if saveResult {
                        await self.loadSectionData()
                        return (true, "Value updated to '\(newValue)'")
                    } else {
                        return (false, "Failed to write config file")
                    }
                }
            }

            return (false, "Failed to update configuration")
        }
    }

    func saveConfigFile() async {
        await performAsyncAction("Save configuration") {
            guard let session = self.session else { return (false, "No session") }

            let configPath = self.state.configPath
            guard !configPath.isEmpty else { return (false, "Config path not set") }

            let saveResult = await SSHBaseService.shared.writeFile(
                at: configPath,
                content: self.state.configFileContent,
                useSudo: true,
                via: session
            )

            if saveResult {
                // Test config if applicable
                if self.app.capabilities.contains(.configurable) {
                    let testCommand: String
                    switch self.app.id.lowercased() {
                    case "nginx":
                        testCommand = "sudo nginx -t"
                    case "apache", "apache2":
                        testCommand = "sudo apache2ctl configtest"
                    default:
                        testCommand = ""
                    }

                    if !testCommand.isEmpty {
                        let testResult = await SSHBaseService.shared.execute(testCommand, via: session)
                        if testResult.exitCode != 0 {
                            return (false, "Config saved but validation failed: \(testResult.output)")
                        }
                    }
                }

                // Reload service
                _ = await self.serviceResolver.reloadService(for: self.app.id, via: session)
                return (true, "Configuration saved and reloaded")
            } else {
                return (false, "Failed to save configuration file")
            }
        }
    }

    // MARK: - Version Installation

    func installVersion(_ version: CapabilityVersion) async {
        guard let session = session else { return }
        guard let commands = version.installCommands else {
            errorMessage = "No install commands available for this version"
            return
        }

        // Determine OS
        let osResult = await SSHBaseService.shared.execute(
            "cat /etc/os-release | grep ^ID= | cut -d= -f2 | tr -d '\"'",
            via: session
        )
        let osId = osResult.output.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        print("[Install] Detected OS: '\(osId)'")
        print("[Install] Available command keys: \(commands.keys.joined(separator: ", "))")

        // Helper to resolve instruction
        func resolve(_ instruction: InstallInstruction?) -> [String]? {
            guard let instruction = instruction else { return nil }
            switch instruction {
            case .list(let cmds): return cmds
            case .keyed(let dict):
                if let cmd = dict["default"] ?? dict.values.first {
                    return [cmd]
                }
                return nil
            }
        }

        // Find matching commands
        // Add "linux" as a fallback
        let osCommands = resolve(commands[osId]) ?? 
                         resolve(commands["ubuntu"]) ?? 
                         resolve(commands["debian"]) ?? 
                         resolve(commands["linux"]) ?? []
                         
        guard !osCommands.isEmpty else {
            errorMessage = "No install commands for this OS (\(osId))"
            print("[Install] Failed to find commands for \(osId). Keys available: \(commands.keys)")
            return
        }

        await MainActor.run {
            state.isInstallingVersion = true
            state.installingVersionName = version.version
            state.installStatus = "Starting installation..."
        }

        for (index, originalCommand) in osCommands.enumerated() {
            await MainActor.run {
                state.installStatus = "Step \(index + 1)/\(osCommands.count): Running..."
            }
            
            // SANITIZE AND FORTIFY COMMANDS
            var command = originalCommand
            
            // 1. Force non-interactive for apt/dpkg
            // We inject the variable directly before the command to ensure it survives 'sudo' (which often drops env vars)
            // transforming "sudo apt install" -> "sudo DEBIAN_FRONTEND=noninteractive apt install"
            if command.contains("apt") || command.contains("dpkg") {
                let targets = ["apt-get", "apt ", "dpkg"]
                for target in targets {
                    if command.contains(target) && !command.contains("DEBIAN_FRONTEND=noninteractive " + target) {
                        command = command.replacingOccurrences(of: target, with: "DEBIAN_FRONTEND=noninteractive " + target)
                    }
                }
                
                // Ensure -y is used for install/upgrade/remove
                if (command.contains("install") || command.contains("upgrade") || command.contains("remove")) && !command.contains("-y") {
                     command = command + " -y"
                }
                // Fix for interactions: pass -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold"
                if command.contains("apt-get") && !command.contains("force-conf") {
                    command = command + " -o Dpkg::Options::=\"--force-confdef\" -o Dpkg::Options::=\"--force-confold\""
                }
            }
            
            // 2. Add wait for lock if apt
            if command.contains("apt") {
                // Prepend a wait for lock check (simple version)
                // "while fuser /var/lib/dpkg/lock >/dev/null 2>&1 ; do sleep 1 ; done; " is risky if user doesn't have fuser
                // Better to just rely on APT's acquire-retries if possible, but that's config.
                // We'll trust the modified command for now, but handle the specific lock error in output.
            }

            let result = await SSHBaseService.shared.execute(command, via: session, timeout: 600) // Increased timeout

            if result.exitCode != 0 {
                // Allow "apt-get update" to fail (often network issues) but warn
                if command.contains("apt-get update") {
                   print("[Install] Warning: apt-get update failed, but continuing. Output: \(result.output)")
                   continue
                }
                
                await MainActor.run {
                    state.isInstallingVersion = false
                    state.installingVersionName = ""
                    state.installStatus = ""
                    
                    // Check for lock error
                    if result.output.contains("Could not get lock") || result.output.contains("Resource temporarily unavailable") {
                        errorMessage = "System update in progress. Please wait a moment and try again."
                    } else {
                        errorMessage = "Installation failed: \(result.output)" // Show output in error
                    }
                }
                print("[Install] Command failed: \(command)")
                print("[Install] Output: \(result.output)")
                return
            }
        }

        await MainActor.run {
            state.isInstallingVersion = false
            state.installingVersionName = ""
            state.installStatus = ""
            successMessage = "\(app.name) \(version.version) installed successfully"
        }

        // Refresh data
        await loadServiceStatus()
        await loadSectionData()
    }
    
    // MARK: - Version Switching
    
    func switchVersion(_ version: CapabilityVersion) async {
        guard let session = session else { return }
        
        await performAsyncAction("Switching to \(version.version)") {
            // Logic differs by app
            if app.id == "php" {
                 // For PHP, use update-alternatives
                 // Extract version number like "8.1" from "PHP 8.1" or "8.1"
                 let ver = version.version.replacingOccurrences(of: "PHP", with: "").trimmingCharacters(in: .whitespaces)
                 
                 let cmd = "sudo update-alternatives --set php /usr/bin/php\(ver) && sudo update-alternatives --set php-fpm /usr/sbin/php-fpm\(ver) 2>/dev/null"
                 let result = await SSHBaseService.shared.execute(cmd, via: session)
                 
                 if result.exitCode == 0 {
                     await self.loadData() // Reload all info
                     return (true, "Switched to PHP \(ver)")
                 } else {
                     return (false, "Failed to switch: \(result.output)")
                 }
            } else {
                // For others like MySQL/Nginx, usually the installed version IS the active one.
                // If it's installed but not running, maybe we need to stop the other and start this one?
                // But usually package managers replace the binary.
                // We'll treat "Switch" as "Restart Service" or a no-op if detected correctly.
                return (false, "Switching not supported for \(app.name) (Reinstall to switch)")
            }
        }
    }

    // MARK: - Security Actions
    
    func toggleSecurityRule(_ key: String, enabled: Bool) async {
        guard let session = session else { return }
        
        // Dispatch based on app
        if app.id == "nginx" {
            await performAsyncAction("Toggle Security Rule") {
                // Convert string key to enum if possible, or pass string
                // NginxSecurityService uses SecurityRule enum.
                // We need to map the string key back to the enum.
                
                // Since NginxSecurityService is internal/actor, we need to access via shared.
                // We'll map the key string manually or add a helper in NginxSecurityService.
                // For now, let's map manually here for common rules.
                
                guard let rule = NginxSecurityService.SecurityRule(rawValue: key) else {
                    return (false, "Unknown rule: \(key)")
                }
                
                let success = await NginxSecurityService.shared.toggleRule(rule, enabled: enabled, via: session)
                if success {
                    // localized hardcoded for now, ideal to use String(localized:)
                    await self.loadSectionData() // Reload status
                    return (true, "\(rule.description) \(enabled ? "enabled" : "disabled")")
                } else {
                    return (false, "Failed to toggle \(rule.description)")
                }
            }
        } else {
            errorMessage = "Security control not supported for this application"
        }
    }
    
    // MARK: - Error Pages Actions
    
    func updateErrorPage(code: String, path: String) async {
         guard let session = session, app.id == "nginx" else { return }
         
         await performAsyncAction("Update Error Page \(code)") {
             let configPath = "/etc/nginx/conf.d/error_pages.conf"
             
             // Simple implementation: Read, Filter out old code, Append new
             let read = await SSHBaseService.shared.execute("cat \(configPath)", via: session)
             let content = read.output
             
             var lines = content.components(separatedBy: "\n").filter {
                 !$0.trimmingCharacters(in: .whitespaces).hasPrefix("error_page \(code)")
             }
             
             if !path.isEmpty {
                 lines.append("error_page \(code) \(path);")
             }
             
             // Ensure fastcgi_intercept_errors is on
             if !lines.contains(where: { $0.contains("fastcgi_intercept_errors") }) {
                 lines.insert("fastcgi_intercept_errors on;", at: 0)
             }
             
             // Ensure fastcgi_intercept_errors is on
             if !lines.contains(where: { $0.contains("fastcgi_intercept_errors") }) {
                 lines.insert("fastcgi_intercept_errors on;", at: 0)
             }
             
             let newContent = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
             
             let written = await SSHBaseService.shared.writeFile(
                 at: configPath,
                 content: newContent,
                 useSudo: true,
                 via: session
             )
             
             if written {
                 // FORCE: Inject location block into site configs
                 await applyGlobalErrorPagePatch(via: session)
                 
                 // Test and Reload
                 let test = await SSHBaseService.shared.execute("sudo nginx -t", via: session)
                 if test.exitCode == 0 {
                     _ = await SSHBaseService.shared.execute("sudo systemctl reload nginx", via: session)
                     await self.loadSectionData()
                     return (true, "Error page for \(code) updated and sites patched")
                 } else {
                     return (false, "Invalid configuration: \(test.output)")
                 }
             } else {
                 return (false, "Failed to write config")
             }
         }
    }
    
    // MARK: - Aggressive Patching
    
    private func applyGlobalErrorPagePatch(via session: TerminalViewModel) async {
        // Known vhost paths
        let paths = [
            "/etc/nginx/sites-enabled",
            "/etc/nginx/conf.d",
            "/www/server/panel/vhost/nginx",
            "/usr/local/nginx/conf/vhost"
        ]
        
        let locationBlock = """
        
            # Velo Error Page Support
            location ^~ /custom_errors/ {
                root /usr/share/nginx/html;
                internal;
            }
        """
        
        for path in paths {
            // List files
            let ls = await SSHBaseService.shared.execute("ls -1 \(path)/*.conf", via: session)
            let files = ls.output.components(separatedBy: "\n").filter { hasExtension($0, "conf") }
            
            for file in files {
                let filePath = file.trimmingCharacters(in: .whitespaces)
                guard !filePath.isEmpty else { continue }
                
                let read = await SSHBaseService.shared.execute("cat '\(filePath)'", via: session)
                let content = read.output
                
                // Check if meaningful server block exists and not already patched
                if content.contains("server {") && !content.contains("location ^~ /custom_errors/") {
                    // Naive Injection: Inject before the last closing brace
                    // This is risky if file has multiple server blocks or nested braces, but "Force" requested.
                    // Safer: Inject after "server {"
                    
                    if let range = content.range(of: "server {") {
                        var newContent = content
                        let insertionPoint = range.upperBound
                        newContent.insert(contentsOf: locationBlock, at: insertionPoint)
                        
                        _ = await SSHBaseService.shared.writeFile(at: filePath, content: newContent, useSudo: true, via: session)
                    }
                }
            }
        }
    }
    
    private func hasExtension(_ path: String, _ ext: String) -> Bool {
        return path.hasSuffix(".\(ext)")
    }
    
    // MARK: - Error Page Content Editing
    
    func getErrorPageContent(path: String) async -> String {
        guard let session = session else { return "" }
        // Determine absolute path. If it's a relative URL, assume mapped to /usr/share/nginx/html
        let fsPath = resolveFileSystemPath(for: path)
        let result = await SSHBaseService.shared.execute("cat '\(fsPath)'", via: session)
        return result.output
    }
    
    func saveErrorPageContent(path: String, content: String) async -> Bool {
        guard let session = session else { return false }
        let fsPath = resolveFileSystemPath(for: path)
        return await SSHBaseService.shared.writeFile(at: fsPath, content: content, useSudo: true, via: session)
    }
    
    func createDefaultErrorPage(code: String) async -> String? {
        guard let session = session else { return nil }
        
        let targetDir = "/usr/share/nginx/html/custom_errors"
        let fileName = "\(code).html"
        let fullPath = "\(targetDir)/\(fileName)"
        let urlPath = "/custom_errors/\(fileName)"
        
        // Ensure directory
        _ = await SSHBaseService.shared.execute("sudo mkdir -p \(targetDir)", via: session)
        
        // Write default template
        let template = defaultErrorTemplate(code: code)
        let written = await SSHBaseService.shared.writeFile(at: fullPath, content: template, useSudo: true, via: session)
        
        if written {
            // Update config to point to it
            await updateErrorPage(code: code, path: urlPath)
            return urlPath
        }
        return nil
    }
    
    private func resolveFileSystemPath(for urlPath: String) -> String {
        // Simple heuristic mapping
        // If starts with /, and inside typical webroot locations
        if urlPath.hasPrefix("/custom_errors/") {
            return "/usr/share/nginx/html" + urlPath
        }
        // Fallback for direct paths
        if urlPath.hasPrefix("/") {
            // It might be a direct absolute path or relative to default root
             if urlPath.contains("nginx") || urlPath.contains("www") {
                 return urlPath
             }
             return "/usr/share/nginx/html" + urlPath
        }
        return urlPath
    }
    
    private func defaultErrorTemplate(code: String) -> String {
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <title>\(code) Error</title>
            <style>
                body {
                    background-color: #0d0d0d;
                    color: white;
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
                    display: flex;
                    height: 100vh;
                    align-items: center;
                    justify-content: center;
                    margin: 0;
                    text-align: center;
                }
                .container {
                    padding: 40px;
                    background: rgba(255, 255, 255, 0.05);
                    border-radius: 20px;
                    backdrop-filter: blur(10px);
                    border: 1px solid rgba(255, 255, 255, 0.1);
                }
                h1 { font-size: 6rem; margin: 0; background: linear-gradient(to right, #4facfe 0%, #00f2fe 100%); -webkit-background-clip: text; -webkit-text-fill-color: transparent; }
                p { font-size: 1.5rem; color: #888; margin-top: 10px; }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>\(code)</h1>
                <p>Something went wrong.</p>
            </div>
        </body>
        </html>
        """
    }
    
    // MARK: - WAF Actions
    
    func blockIP(_ ip: String) async -> Bool {
        guard let session = session else { return false }
        
        await performAsyncAction("Block IP \(ip)") {
            // We'll append to security_rules.conf or a dedicated block list
            let configPath = "/etc/nginx/conf.d/security_rules.conf"
            
            // simple check if already blocked
            let check = await SSHBaseService.shared.execute("grep 'deny \(ip);' \(configPath)", via: session)
            if check.exitCode == 0 {
                return (true, "IP \(ip) is already blocked")
            }
            
            // Append deny rule
            let cmd = "echo 'deny \(ip); # Blocked via Velo WAF' | sudo tee -a \(configPath)"
            let result = await SSHBaseService.shared.execute(cmd, via: session)
            
            if result.exitCode == 0 {
                // PATCH: Ensure security_rules.conf is included
                await applySecurityConfigPatch(via: session)
                
                // Reload
                _ = await SSHBaseService.shared.execute("sudo systemctl reload nginx", via: session)
                return (true, "IP \(ip) blocked successfully")
            }
            return (false, "Failed to block IP")
        }
        return true
    }

    func unblockIP(_ ip: String) async -> Bool {
        guard let session = session else { return false }
        
        await performAsyncAction("Unblock IP \(ip)") {
            let configPath = "/etc/nginx/conf.d/security_rules.conf"
            
            // Read, Filter, Write
            let read = await SSHBaseService.shared.execute("cat \(configPath)", via: session)
            let lines = read.output.components(separatedBy: .newlines)
            
            let newLines = lines.filter { !$0.contains("deny \(ip);") }
            let newContent = newLines.joined(separator: "\n")
            
            let written = await SSHBaseService.shared.writeFile(at: configPath, content: newContent, useSudo: true, via: session)
            
            if written {
                _ = await SSHBaseService.shared.execute("sudo systemctl reload nginx", via: session)
                return (true, "IP \(ip) unblocked")
            }
            return (false, "Failed to unblock IP")
        }
        return true
    }
    
    private func applySecurityConfigPatch(via session: TerminalViewModel) async {
        // 1. Global Injection (nginx.conf)
        let globalPaths = [
             "/etc/nginx/nginx.conf",
             "/www/server/nginx/conf/nginx.conf",
             "/usr/local/nginx/conf/nginx.conf"
        ]
        
        let includeDirective = "include /etc/nginx/conf.d/security_rules.conf;"
        
        for path in globalPaths {
             let read = await SSHBaseService.shared.execute("cat \(path)", via: session)
             if read.exitCode == 0 && !read.output.contains("security_rules.conf") {
                 if let range = read.output.range(of: "http {") {
                      var newContent = read.output
                      let insertionPoint = range.upperBound
                      newContent.insert(contentsOf: "\n    \(includeDirective)\n", at: insertionPoint)
                      _ = await SSHBaseService.shared.writeFile(at: path, content: newContent, useSudo: true, via: session)
                 }
             }
        }
        
        // 2. VHost Injection (Aggressive) - DISABLED causing syntax errors
        // Many panels (like aaPanel) don't include conf.d in their vhost configs manually.
        // We force inject the security rules into every site's server block.
        
        // DISABLED LOGIC START
        // let vhostDirs = [
        //    "/etc/nginx/sites-enabled",
        //    "/etc/nginx/conf.d",
        //    "/www/server/panel/vhost/nginx",
        //    "/usr/local/nginx/conf/vhost"
        // ]
        //
        // for dir in vhostDirs {
        //    let ls = await SSHBaseService.shared.execute("ls -1 \(dir)/*.conf", via: session)
        //    let files = ls.output.components(separatedBy: "\n").filter { hasExtension($0, "conf") }
        //    
        //    for file in files {
        //        let filePath = file.trimmingCharacters(in: .whitespaces)
        //        guard !filePath.isEmpty, !filePath.hasSuffix("security_rules.conf") else { continue }
        //        
        //        let read = await SSHBaseService.shared.execute("cat '\(filePath)'", via: session)
        //        let content = read.output
        //        
        //        // If contains "server {" and doesn't already include our rules
        //        if content.contains("server {") && !content.contains("security_rules.conf") {
        //            
        //            // Inject at start of server block
        //            if let range = content.range(of: "server {") {
        //                var newContent = content
        //                let insertionPoint = range.upperBound
        //                newContent.insert(contentsOf: "\n    \(includeDirective)\n", at: insertionPoint)
        //                
        //                _ = await SSHBaseService.shared.writeFile(at: filePath, content: newContent, useSudo: true, via: session)
        //            }
        //        }
        //    }
        // }
        // DISABLED LOGIC END
    }
    
    func repairVHostConfigs() async -> String {
        guard let session = session else { return "No session" }
        var result = "Starting Smart Repair Process... 🛠️\n"
        
        let includeDirective = "include /etc/nginx/conf.d/security_rules.conf;"
        var attempt = 1
        let maxAttempts = 5
        
        // Loop: Check Config -> Find Error -> Fix File -> Repeat
        while attempt <= maxAttempts {
            result += "\n[Attempt \(attempt)] Checking configuration...\n"
            
            // 1. Run nginx -t
            let test = await SSHBaseService.shared.execute("sudo nginx -t", via: session)
            
            if test.exitCode == 0 {
                result += "✅ Configuration is valid!\n"
                break
            }
            
            // 2. Parse Error
            // Expected format: "nginx: [emerg] ... in /path/to/file:123"
            let output = test.output
            result += "❌ Config Check Failed. Analyzing...\n"
            
            // Regex to capture file path and optional line number
            // Matches: "in /path/to/file:123" or "in /path/to/file line 123"
            let pattern = "in\\s+([^:]+):(\\d+)"
            
            if let range = output.range(of: pattern, options: .regularExpression) {
                let match = String(output[range])
                let components = match.components(separatedBy: ":")
                if components.count >= 2 {
                    let filePath = components[0].replacingOccurrences(of: "in ", with: "").trimmingCharacters(in: .whitespaces)
                    let lineNumber = Int(components[1].trimmingCharacters(in: .whitespaces)) ?? 0
                    
                    result += "⚠️ Detected error in file: \(filePath) at line \(lineNumber)\n"
                    
                    // 3. Attempt Fix
                    let read = await SSHBaseService.shared.execute("cat '\(filePath)'", via: session)
                    if read.exitCode == 0 {
                        var lines = read.output.components(separatedBy: .newlines)
                        
                        // Safety: Ensure we only remove lines related to our injection
                        // If line number > 0, check that specific line
                        if lineNumber > 0 && lineNumber <= lines.count {
                            let targetLineIndex = lineNumber - 1
                            let lineContent = lines[targetLineIndex]
                            
                            if lineContent.contains("security_rules.conf") {
                                result += "Found problematic injection. Removing line...\n"
                                lines.remove(at: targetLineIndex)
                                
                                let newContent = lines.joined(separator: "\n")
                                let write = await SSHBaseService.shared.writeFile(at: filePath, content: newContent, useSudo: true, via: session)
                                if write {
                                    result += "✅ Fixed file: \(filePath)\n"
                                } else {
                                    result += "❌ Failed to write file: \(filePath)\n"
                                    break // Stop if we can't write
                                }
                            } else {
                                result += "⚠️ Line \(lineNumber) content: '\(lineContent.trimmingCharacters(in: .whitespaces))'.\n"
                                
                                // Special handling: If the error is inside 'security_rules.conf', it means the *include* is in the wrong place.
                                if filePath.hasSuffix("security_rules.conf") {
                                    result += "🚨 Error is inside the rules file itself. Triggering global cleanup & neutralization...\n"
                                    await cleanupAllInjections(via: session, directive: includeDirective)
                                    // Move to next attempt to verify fix
                                } else {
                                    result += "Aborting auto-fix for specific file safety. Falling back to global cleanup.\n"
                                    await cleanupAllInjections(via: session, directive: includeDirective)
                                }
                            }
                        }
                    }
                }
            } else {
               result += "Could not parse specific file location from error output. Trying global cleanup...\n"
               await cleanupAllInjections(via: session, directive: includeDirective)
            }
            
            attempt += 1
            // Small delay to allow file system to sync
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        
        // Final Start Attempt
        result += "\nAttempting to start Nginx...\n"
        let reload = await SSHBaseService.shared.execute("sudo systemctl start nginx", via: session)
        if reload.exitCode == 0 {
             result += "✅ Nginx started successfully.\n"
        } else {
             result += "❌ Failed to start Nginx: \(reload.output)\n"
             let status = await SSHBaseService.shared.execute("systemctl status nginx --no-pager", via: session)
             result += "\nStatus Output:\n\(status.output)"
        }
        
        return result
    }
    
    private func cleanupAllInjections(via session: TerminalViewModel, directive: String) async {
        // 1. Config Directories
        let configDirs = [
             "/etc/nginx/sites-enabled",
             "/etc/nginx/conf.d",
             "/www/server/panel/vhost/nginx",
             "/usr/local/nginx/conf/vhost"
        ]
        
        // 2. Global Config Files
        let globalFiles = [
            "/etc/nginx/nginx.conf",
            "/www/server/nginx/conf/nginx.conf",
            "/usr/local/nginx/conf/nginx.conf"
        ]
        
        var filesToScan: [String] = globalFiles
        
        // Gather all config files
        for dir in configDirs {
             let ls = await SSHBaseService.shared.execute("ls -1 \(dir)/*.conf", via: session)
             if ls.exitCode == 0 {
                 let files = ls.output.components(separatedBy: "\n").filter { hasExtension($0, "conf") }
                 filesToScan.append(contentsOf: files.map { $0.trimmingCharacters(in: .whitespaces) })
             }
        }
        
        // Regex for robust removal: 'include \s* /path... \s* ;'
        // We match optional whitespace around the path and semicolon
        let pattern = "include\\s+/etc/nginx/conf.d/security_rules\\.conf\\s*;"
        
        // Remove directive from all files
        for filePath in filesToScan {
             guard !filePath.isEmpty, !filePath.hasSuffix("security_rules.conf") else { continue }
             
             let read = await SSHBaseService.shared.execute("cat '\(filePath)'", via: session)
             if read.exitCode == 0 && read.output.contains("security_rules.conf") {
                 
                 // Use Regex replacement
                 let newContent = read.output.replacingOccurrences(
                    of: pattern,
                    with: "",
                    options: .regularExpression
                 )
                 
                 // Only write if changed
                 if newContent != read.output {
                     _ = await SSHBaseService.shared.writeFile(at: filePath, content: newContent, useSudo: true, via: session)
                 }
             }
        }
        
        // Failsafe: Truncate security_rules.conf to be empty
        // This ensures that even if 'include' remains somewhere, the file is empty/valid and won't crash Nginx.
        _ = await SSHBaseService.shared.writeFile(at: "/etc/nginx/conf.d/security_rules.conf", content: "# Neutralized by Velo Repair\n", useSudo: true, via: session)
    }

    // MARK: - WAF Pagination
    
    func loadMoreWafLogs() async {
        guard let session = session, !state.wafLogsIsLoading else { return }
        
        let nextPage = state.wafLogsPage + 1
        let pageSize = 100
        
        // Check if we reached the end
        if state.wafLogs.count >= state.wafLogsTotal && state.wafLogsTotal > 0 {
            return
        }
        
        await MainActor.run {
            state.wafLogsIsLoading = true
        }
        
        let service = NginxSecurityService.shared
        let (newLogs, _) = await service.fetchWafLogs(
            site: state.currentWafSite,
            page: nextPage,
            pageSize: pageSize,
            via: session
        )
        
        await MainActor.run {
            if !newLogs.isEmpty {
                state.wafLogs.append(contentsOf: newLogs)
                state.wafLogsPage = nextPage
            }
            state.wafLogsIsLoading = false
        }
    }

    // MARK: - Diagnostics
    
    func diagnoseSecurity() async -> String {
        guard let session = session else { return "No session" }
        
        var report = "--- Security Diagnostics ---\n"
        
        // 1. Check Config Inclusion
        report += "\n[1] Checking Config Inclusion:\n"
        let checkInclude = await SSHBaseService.shared.execute("sudo nginx -T 2>/dev/null | grep 'security_rules.conf'", via: session)
        if checkInclude.output.contains("security_rules.conf") {
            report += "✅ security_rules.conf is included in the active configuration.\n"
        } else {
            report += "❌ security_rules.conf is NOT found in the active configuration dump (nginx -T).\n"
        }
        
        // 2. Check File Content
        report += "\n[2] Checking Rule File:\n"
        let checkFile = await SSHBaseService.shared.execute("cat /etc/nginx/conf.d/security_rules.conf", via: session)
        if checkFile.exitCode == 0 {
            report += "File exists. Content:\n\(checkFile.output.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        } else {
            report += "❌ File not found at /etc/nginx/conf.d/security_rules.conf\n"
        }
        
        // 3. Check Recent Traffic (Real IP Detection)
        report += "\n[3] Recent Access Logs (Last 5):\n"
        // Try to find access log
        let findLog = await SSHBaseService.shared.execute("find /var/log/nginx /www/wwwlogs -name 'access.log' 2>/dev/null | head -n 1", via: session)
        let logPath = findLog.output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !logPath.isEmpty {
            report += "Log found at: \(logPath)\n"
            let logTail = await SSHBaseService.shared.execute("tail -n 5 \(logPath)", via: session)
            report += logTail.output
        } else {
             // Fallback to checking config for log path
             let configLog = await SSHBaseService.shared.execute("nginx -T 2>/dev/null | grep 'access_log' | head -n 1", via: session)
             report += "Could not find standard log. Config says: \(configLog.output.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        }
        
        return report
    }

    // MARK: - Helper Methods

    func performAsyncAction(
        _ actionName: String? = nil,
        action: () async -> (success: Bool, message: String?)
    ) async {
        isPerformingAction = true
        errorMessage = nil
        successMessage = nil

        let result = await action()

        if result.success {
            if let msg = result.message {
                successMessage = msg
            }
        } else {
            errorMessage = result.message ?? "An error occurred"
        }

        isPerformingAction = false
    }
    
    // Strip ANSI escape codes from a string
    func stripANSI(_ input: String) -> String {
        // Remove ANSI escape codes
        let pattern = "\\x1B\\[[0-9;]*[mGKHF]|\\[\\d*(;\\d+)*m"
        return input.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }
}
