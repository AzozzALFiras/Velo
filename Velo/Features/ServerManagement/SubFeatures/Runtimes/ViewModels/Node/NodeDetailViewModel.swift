import Foundation
import Combine
import SwiftUI

@MainActor
class NodeDetailViewModel: ObservableObject {
    
    // MARK: - Dependencies
    weak var session: TerminalViewModel?
    let service = NodeService.shared
    
    // MARK: - Published State
    @Published var version: String = "..."
    @Published var npmVersion: String = "..."
    @Published var isRunning: Bool = false
    @Published var globalPackages: [NodePackage] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    init(session: TerminalViewModel?) {
        self.session = session
    }
    
    func loadData() async {
        guard let session = session else { return }
        isLoading = true
        
        // 1. Check Node Version
        let result = await SSHBaseService.shared.execute("node -v", via: session)
        if result.exitCode == 0 {
            version = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            isRunning = true
        } else {
            version = "Not Installed"
            isRunning = false
        }
        
        // 2. Check NPM Version
        let npmResult = await SSHBaseService.shared.execute("npm -v", via: session)
        if npmResult.exitCode == 0 {
            npmVersion = npmResult.output.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 3. Load Global Packages
        await loadGlobalPackages()
        
        isLoading = false
    }
    
    func loadGlobalPackages() async {
        guard let session = session else { return }
        
        // npm list -g --json --depth=0
        let result = await SSHBaseService.shared.execute("npm list -g --json --depth=0", via: session)
        if let data = result.output.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let dependencies = json["dependencies"] as? [String: [String: Any]] {
            
            var pkgs: [NodePackage] = []
            
            for (key, val) in dependencies {
                let ver = val["version"] as? String ?? "?"
                pkgs.append(NodePackage(
                    name: key,
                    version: ver,
                    isGlobal: true,
                    path: nil
                ))
            }
            
            self.globalPackages = pkgs.sorted { $0.name < $1.name }
        }
    }
}
