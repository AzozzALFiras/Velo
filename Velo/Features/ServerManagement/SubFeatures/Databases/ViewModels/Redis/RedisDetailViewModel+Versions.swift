//
//  RedisDetailViewModel+Versions.swift
//  Velo
//
//  Version management for Redis.
//

import Foundation

extension RedisDetailViewModel {
    
    func loadAPIData() async {
        do {
            let capability = try await ApiService.shared.fetchCapabilityDetails(slug: "redis")
            let versions = capability.versions ?? []
            
            await MainActor.run {
                self.availableVersionsFromAPI = versions
            }
        } catch {
            print("Failed to fetch Redis versions: \(error)")
            await MainActor.run {
                self.availableVersionsFromAPI = []
            }
        }
    }
    
    func installVersion(_ version: String) async {
        guard let session = session else { return }

        isPerformingAction = true
        installStatus = "Detecting OS..."

        let osInfo = await SystemStatsService.shared.getOSInfo(via: session)
        let pm = PackageManagerCommandBuilder.detect(from: osInfo.id)

        installStatus = "Installing Redis \(version)..."
        let cmd = PackageManagerCommandBuilder.installCommand(
            packages: ["redis-server"],
            packageManager: pm,
            withUpdate: true
        )

        _ = await ServerAdminService.shared.execute(cmd, via: session, timeout: 600)

        await loadData()
        isPerformingAction = false
        installStatus = ""
    }

    // MARK: - Admin Service access is now handled via ServerAdminService.shared
}
