
import Foundation
import Combine

@MainActor
class ApacheDetailViewModel: ObservableObject {
    let session: TerminalViewModel?
    
    @Published var isRunning = false
    @Published var isPerformingAction = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    init(session: TerminalViewModel?) {
        self.session = session
    }
    
    func loadStatus() async {
        guard let session = session else { return }
        // Simple check for now
        let result = await SSHBaseService.shared.execute("systemctl is-active apache2", via: session)
        isRunning = result.output.trimmingCharacters(in: .whitespacesAndNewlines) == "active"
    }
    
    func startService() async {
        await performAction("Start", command: "sudo systemctl start apache2")
    }
    
    func stopService() async {
        await performAction("Stop", command: "sudo systemctl stop apache2")
    }
    
    func restartService() async {
        await performAction("Restart", command: "sudo systemctl restart apache2")
    }
    
    private func performAction(_ name: String, command: String) async {
        guard let session = session else { return }
        isPerformingAction = true
        errorMessage = nil
        successMessage = nil
        
        let result = await SSHBaseService.shared.execute(command, via: session)
        
        if result.exitCode == 0 {
            successMessage = "\(name) successful"
            await loadStatus()
        } else {
            errorMessage = "Failed to \(name.lowercased()): \(result.output)"
        }
        
        isPerformingAction = false
    }
}
