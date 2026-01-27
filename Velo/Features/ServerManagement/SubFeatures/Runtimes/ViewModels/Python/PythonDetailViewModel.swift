import Foundation
import Combine
import SwiftUI

@MainActor
class PythonDetailViewModel: ObservableObject {
    
    // MARK: - Dependencies
    weak var session: TerminalViewModel?
    let service = PythonService.shared
    
    // MARK: - Published State
    @Published var version: String = "..."
    @Published var isRunning: Bool = false // Python management is mostly about environments/scripts, not a single service usually, but we check if python3 exists
    @Published var installedEnvironments: [PythonEnvironment] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    init(session: TerminalViewModel?) {
        self.session = session
    }
    
    func loadData() async {
        guard let session = session else { return }
        isLoading = true
        
        // 1. Check Python Version
        let result = await ServerAdminService.shared.execute("python3 --version", via: session)
        if result.exitCode == 0 {
            version = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            isRunning = true
        } else {
            version = "Not Installed"
            isRunning = false
        }
        
        // 2. Load Environments (Placeholder logic for now)
        // In a real app we might scan ~/.virtualenvs or similar
        // For now, we just list global pip packages as one "Global" env
        await loadGlobalPackages()
        
        isLoading = false
    }
    
    func loadGlobalPackages() async {
        guard let session = session else { return }
        
        let result = await ServerAdminService.shared.execute("pip3 list --format=json", via: session)
        if let data = result.output.data(using: .utf8),
           let packages = try? JSONDecoder().decode([PythonPackageJSON].self, from: data) {
            
            let mappedPackages = packages.map {
                PythonPackage(name: $0.name, version: $0.version, location: nil)
            }
            
            let globalEnv = PythonEnvironment(
                path: "/usr/bin/python3",
                version: version,
                packages: mappedPackages
            )
            
            self.installedEnvironments = [globalEnv]
        }
    }
}

// Helper for JSON decoding pip list
struct PythonPackageJSON: Codable {
    let name: String
    let version: String
}
