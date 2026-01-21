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

    // MARK: - Published State

    @Published var state: ApplicationState
    @Published var selectedSection: SectionDefinition
    @Published var isLoading = false
    @Published var isPerformingAction = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    // MARK: - Init

    init(app: ApplicationDefinition, session: TerminalViewModel?) {
        self.app = app
        self.session = session
        self.state = ApplicationState()
        self.selectedSection = app.defaultSection ?? app.sections.first!
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
        default:
            state.isRunning = false
            state.version = "Not Installed"
        }

        // Get binary path
        let whichResult = await SSHBaseService.shared.execute("which \(app.id)", via: session)
        if !whichResult.output.isEmpty && whichResult.exitCode == 0 {
            state.binaryPath = whichResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
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

        // Find matching commands
        let osCommands = commands[osId] ?? commands["ubuntu"] ?? commands["debian"] ?? []
        guard !osCommands.isEmpty else {
            errorMessage = "No install commands for this OS (\(osId))"
            return
        }

        state.isInstallingVersion = true
        state.installingVersionName = version.version
        state.installStatus = "Starting installation..."

        for (index, command) in osCommands.enumerated() {
            state.installStatus = "Step \(index + 1)/\(osCommands.count): Running..."

            let result = await SSHBaseService.shared.execute(command, via: session, timeout: 300)

            if result.exitCode != 0 && !command.contains("apt-get update") {
                state.isInstallingVersion = false
                state.installingVersionName = ""
                state.installStatus = ""
                errorMessage = "Installation failed at step \(index + 1)"
                return
            }
        }

        state.isInstallingVersion = false
        state.installingVersionName = ""
        state.installStatus = ""
        successMessage = "\(app.name) \(version.version) installed successfully"

        // Refresh data
        await loadServiceStatus()
        await loadSectionData()
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

    private func stripANSI(_ input: String) -> String {
        let pattern = "\\x1B\\[[0-9;]*[mGKHF]|\\[\\d*(;\\d+)*m"
        return input.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }
}
