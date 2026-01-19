import Foundation
import Combine

/// Service to maintain a "Shadow" SSH session for metadata fetching
/// (Directory listings, current path, etc.) without blocking the main interactive session.
@MainActor
final class SSHMetadataService: ObservableObject {
    
    // MARK: - Published State
    @Published var isConnected: Bool = false
    @Published var currentRemoteDirectory: String?
    
    // MARK: - Dependencies
    private let sshManager = SSHManager()
    
    // MARK: - Shadow Session
    // We use a headless TerminalViewModel to leverage the existing SSHBaseService infrastructure
    private let shadowSession: TerminalViewModel
    
    // MARK: - Cancellation
    private var connectionTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        self.shadowSession = TerminalViewModel(isShadow: true)
        setupBindings()
        
        // Silence the shadow session to avoid clutter (though it's headless anyway)
        // We'll rely on explicit command output parsing
    }
    
    private func setupBindings() {
        shadowSession.$isExecuting
            .sink { [weak self] isExecuting in
                // If we need to track execution state of the shadow session
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Connection Management
    
    func connect(connectionString: String) {
        disconnect()
        
        print("🕵️ [SSHMetadata] Starting shadow connection to: \(connectionString)")
        
        connectionTask = Task {
            // 1. Start the SSH command in the shadow session
            // We strip 'ssh' from the input since we're constructing our own command with -tt
            var args = connectionString.trimmingCharacters(in: .whitespaces)
            if args.hasPrefix("ssh ") {
                args = String(args.dropFirst(4))
            }
            let cmd = "ssh -tt \(args)"
            
            // Execute in shadow session
            // Note: We don't await this directly because it runs indefinitely.
            // We just kick it off.
            shadowSession.inputText = cmd
            shadowSession.executeCommand()
            
            // 2. Wait a bit for connection to establish and run a handshake
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s wait
            
            // 3. Verify connection by running a simple echo
            if await verifyConnection() {
                self.isConnected = true
                print("🕵️ [SSHMetadata] Shadow connection established")
                
                // 4. Initial sync
                await refreshCurrentDirectory()
            } else {
                print("🕵️ [SSHMetadata] Shadow connection failed or timed out")
                self.isConnected = false
                disconnect()
            }
        }
    }
    
    func disconnect() {
        connectionTask?.cancel()
        connectionTask = nil
        
        if isConnected {
            // Send exit to be polite
            Task {
                await SSHBaseService.shared.execute("exit", via: shadowSession, timeout: 2)
                shadowSession.terminalEngine.terminate() // Force kill if needed
            }
        } else {
            shadowSession.terminalEngine.terminate()
        }
        
        isConnected = false
        currentRemoteDirectory = nil
    }
    
    private func verifyConnection() async -> Bool {
        let result = await SSHBaseService.shared.execute("echo 'SHADOW_PING'", via: shadowSession, timeout: 5)
        return result.output.contains("SHADOW_PING")
    }
    
    // MARK: - Operations
    
    /// List contents of a directory
    func listDirectory(path: String) async -> [String] {
        guard isConnected else { return [] }
        
        // ls -1F: One entry per line, classify (append / to dirs)
        let cmd = "ls -1F \"\(path)\""
        let result = await SSHBaseService.shared.execute(cmd, via: shadowSession, timeout: 10)
        
        guard result.exitCode == 0 else {
            print("🕵️ [SSHMetadata] List failed: \(result.output)")
            return []
        }
        
        // Parse output
        let lines = result.output.components(separatedBy: .newlines)
        return lines
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
    
    /// Get current working directory of the shadow session
    /// (This might diverge from main session if not synced, so we usually pass path explicity)
    func refreshCurrentDirectory() async {
        guard isConnected else { return }
        
        let result = await SSHBaseService.shared.execute("pwd", via: shadowSession, timeout: 5)
        if result.exitCode == 0 {
            let dir = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !dir.isEmpty {
                self.currentRemoteDirectory = dir
            }
        }
    }
    
    /// Sync shadow session CWD to match main session
    func syncDirectory(to path: String) async {
        guard isConnected else { return }
        _ = await SSHBaseService.shared.execute("cd \"\(path)\"", via: shadowSession, timeout: 5)
        self.currentRemoteDirectory = path
    }
}
