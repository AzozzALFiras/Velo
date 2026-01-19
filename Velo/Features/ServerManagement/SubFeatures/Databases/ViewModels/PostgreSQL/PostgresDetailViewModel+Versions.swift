//
//  PostgresDetailViewModel+Versions.swift
//  Velo
//
//  Version management for PostgreSQL.
//

import Foundation

extension PostgresDetailViewModel {
    
    func loadAPIData() async {
        do {
            let capability = try await ApiService.shared.fetchCapabilityDetails(slug: "postgresql")
            let versions = capability.versions ?? []
            
            await MainActor.run {
                self.availableVersionsFromAPI = versions
            }
        } catch {
            print("Failed to fetch PostgreSQL versions: \(error)")
            // Fallback empty or let UI handle it
            await MainActor.run {
                self.availableVersionsFromAPI = []
            }
        }
    }
    
    func installVersion(_ version: String) async {
        guard let session = session else { return }
        
        // Trigger installation
        // For PostgreSQL, usually apt install postgresql-VER
        
        isPerformingAction = true
        installStatus = "Installing PostgreSQL \(version)..."
        
        let cmd = "sudo apt-get update && sudo apt-get install -y postgresql-\(version)"
        _ = await baseService.execute(cmd, via: session)
        
        await loadData()
        isPerformingAction = false
        installStatus = ""
    }
}
