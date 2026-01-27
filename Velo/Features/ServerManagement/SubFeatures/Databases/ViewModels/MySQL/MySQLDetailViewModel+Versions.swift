
import Foundation

extension MySQLDetailViewModel {
    
    // MARK: - API Data
    
    func loadAPIData() async {
        do {
            let capability = try await ApiService.shared.fetchCapabilityDetails(slug: "mysql")
            capabilityIcon = capability.icon
            availableVersionsFromAPI = capability.versions ?? []
        } catch {
            print("[MySQLDetailViewModel] Failed to load API data: \(error)")
        }
    }
    
    // MARK: - Version Installation
    
    /// Install a new MySQL version from API
    func installVersion(_ version: CapabilityVersion) async {
        guard let session = session else { return }

        isInstallingVersion = true
        installingVersionName = version.version
        installStatus = "Detecting OS..."
        errorMessage = nil

        // Detect OS using centralized service
        let osInfo = await SystemStatsService.shared.getOSInfo(via: session)
        let osName = osInfo.id.isEmpty ? "ubuntu" : osInfo.id.lowercased()

        print("[MySQLDetailVM] Detected OS: '\(osName)', installCommands: \(version.installCommands ?? [:])")

        installStatus = "Preparing installation..."

        // Resolve install commands from API
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

        guard let installCommands = version.installCommands,
              let commandsList = resolve(installCommands[osName]) ?? resolve(installCommands["ubuntu"]) ?? resolve(installCommands["debian"]),
              !commandsList.isEmpty else {
            errorMessage = "No install commands available for \(osName)"
            isInstallingVersion = false
            installStatus = ""
            return
        }

        let installCommand = commandsList.joined(separator: " && ")

        print("[MySQLDetailVM] Executing install command: \(installCommand.prefix(100))...")

        installStatus = "Installing MySQL \(version.version)..."

        // Execute via centralized admin service
        let result = await ServerAdminService.shared.execute(installCommand, via: session, timeout: 1200)

        if result.exitCode == 0 || result.output.contains("is already") || result.output.contains("newest version") {
            installStatus = "Verifying installation..."
            successMessage = "MySQL \(version.version) installed successfully"

            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await loadData()
        } else {
            errorMessage = "Failed to install MySQL \(version.version)"
            print("[MySQLDetailVM] Install error: \(result.output.suffix(200))")
        }

        isInstallingVersion = false
        installingVersionName = ""
        installStatus = ""
    }

    // MARK: - Admin Service access is now handled via ServerAdminService.shared
}
