import Foundation
import Combine

@MainActor
final class GitService: ObservableObject, ServerModuleService {
    @Published var statusUpdate: Bool = false
    static let shared = GitService()
    
    let baseService = SSHBaseService.shared
    
    private init() {}
    
    func isInstalled(via session: TerminalViewModel) async -> Bool {
        let result = await baseService.execute("which git 2>/dev/null", via: session, timeout: 5)
        return !result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty
    }
    
    func getVersion(via session: TerminalViewModel) async -> String? {
        let result = await baseService.execute("git --version 2>/dev/null | head -n 1 | awk '{print $3}'", via: session, timeout: 5)
        let output = result.output.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return output.isEmpty ? nil : output
    }
    
    func isRunning(via session: TerminalViewModel) async -> Bool {
        return false
    }
    
    func getStatus(via session: TerminalViewModel) async -> SoftwareStatus {
        guard await isInstalled(via: session) else { return .notInstalled }
        let version = await getVersion(via: session) ?? "installed"
        return .installed(version: version)
    }
}
