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
        installStatus = "Installing Redis \(version)..."
        
        // Basic install command
        let cmd = "sudo apt-get update && sudo apt-get install -y redis-server"
        _ = await baseService.execute(cmd, via: session)
        
        await loadData()
        isPerformingAction = false
        installStatus = ""
    }
}
