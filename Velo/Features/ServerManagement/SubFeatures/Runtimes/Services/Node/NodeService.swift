import Foundation
import Combine


@MainActor
final class NodeService: ObservableObject, ServerModuleService {
    static let shared = NodeService()
    
    let baseService = SSHBaseService.shared
    
    // Node doesn't really have a single systemd service name usually (often managed by pm2, or just binary), 
    // for detection we rely on binary check.
    
    private init() {}
    
    func isInstalled(via session: TerminalViewModel) async -> Bool {
        let result = await baseService.execute("which node 2>/dev/null", via: session, timeout: 5)
        let path = result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return !path.isEmpty && path.hasPrefix("/")
    }
    
    func getVersion(via session: TerminalViewModel) async -> String? {
        let result = await baseService.execute("node -v 2>/dev/null | head -n 1", via: session, timeout: 5)
        let output = result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return output.isEmpty ? nil : output
    }
    
    func isRunning(via session: TerminalViewModel) async -> Bool {
        // Node itself isn't a service, it's a runtime. Always return false for "service running" 
        // unless we check specific pm2 processes, which is out of scope for basic check.
        return false 
    }
    
    func getNPMStatus(via session: TerminalViewModel) async -> SoftwareStatus {
        let result = await baseService.execute("which npm 2>/dev/null", via: session, timeout: 5)
        if result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty {
            return .notInstalled
        }
        
        let versionRes = await baseService.execute("npm -v 2>/dev/null | head -n 1", via: session, timeout: 5)
        let version = versionRes.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return .installed(version: version.isEmpty ? "installed" : version)
    }
    
    func getStatus(via session: TerminalViewModel) async -> SoftwareStatus {
        guard await isInstalled(via: session) else { return .notInstalled }
        let version = await getVersion(via: session) ?? "installed"
        return .installed(version: version)
    }
}
