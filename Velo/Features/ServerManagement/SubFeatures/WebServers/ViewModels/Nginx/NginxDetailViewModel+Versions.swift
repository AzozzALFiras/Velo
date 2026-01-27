import Foundation

extension NginxDetailViewModel {

    func loadAvailableVersions() async {
        do {
            let capability = try await ApiService.shared.fetchCapabilityDetails(slug: "nginx")
            self.availableVersions = capability.versions ?? []
        } catch {
            print("[NginxDetailViewModel] Failed to load API data: \(error)")
            self.availableVersions = []
        }
    }

    func installVersion(_ version: CapabilityVersion) async {
        guard let session = session else { return }

        isInstallingVersion = true
        installingVersionName = version.version
        installStatus = "Preparing..."

        await performAsyncAction("Install Nginx \(version.version)") {
            installStatus = "Detecting OS..."
            let osInfo = await SystemStatsService.shared.getOSInfo(via: session)
            let pm = PackageManagerCommandBuilder.detect(from: osInfo.id)

            installStatus = "Installing nginx..."
            let cmd = PackageManagerCommandBuilder.installCommand(
                packages: ["nginx"],
                packageManager: pm,
                withUpdate: true
            )

            let result = await ServerAdminService.shared.execute(cmd, via: session, timeout: 300)

            if result.exitCode == 0 {
                await loadServiceStatus()
                return (true, "Nginx installed successfully.")
            } else {
                return (false, "Installation failed: \(result.output)")
            }
        }

        isInstallingVersion = false
        installingVersionName = ""
        installStatus = ""
    }

    func switchVersion(_ version: CapabilityVersion) async {
       await installVersion(version)
    }

    // MARK: - Admin Service access is now handled via ServerAdminService.shared
}
