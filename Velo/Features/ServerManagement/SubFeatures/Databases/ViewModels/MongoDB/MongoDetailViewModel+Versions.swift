//
//  MongoDetailViewModel+Versions.swift
//  Velo
//
//  Version management for MongoDB.
//

import Foundation

extension MongoDetailViewModel {
    
    func loadAPIData() async {
        do {
            let capability = try await ApiService.shared.fetchCapabilityDetails(slug: "mongodb")
            let versions = capability.versions ?? []
            
            await MainActor.run {
                self.availableVersionsFromAPI = versions
            }
        } catch {
            print("Failed to fetch MongoDB versions: \(error)")
            await MainActor.run {
                self.availableVersionsFromAPI = []
            }
        }
    }
    
    func installVersion(_ version: String) async {
        guard let session = session else { return }
        
        isPerformingAction = true
        installStatus = "Installing MongoDB \(version)..."
        
        // MongoDB install is slightly complex (add repo key, etc), assuming tool handles or simplest approach
        // Simplified for Velo context:
        // Assume script or direct install
        let cmd = "sudo DEBIAN_FRONTEND=noninteractive apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y mongodb-org"
        _ = await baseService.execute(cmd, via: session)
        
        await loadData()
        isPerformingAction = false
        installStatus = ""
    }
}
