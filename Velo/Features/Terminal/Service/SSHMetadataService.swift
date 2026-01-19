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
        
        // Prepare password for injection
        var passwordToInject: String?
        // Extract user/host
        // connectionString is likely "ssh user@host" or just "user@host"
        let parts = connectionString.components(separatedBy: .whitespaces).filter { $0.contains("@") }
        if let userHost = parts.first {
            let split = userHost.components(separatedBy: "@")
            if split.count == 2 {
                let user = split[0]
                let host = split[1]
                if let conn = sshManager.connections.first(where: { $0.host == host && $0.username == user }) {
                    passwordToInject = sshManager.getPassword(for: conn)
                    // Explicitly load password if we found a connection but no password in memory yet
                    // (SSHManager usually handles this, assuming it's ready)
                }
            }
        }
        
        var passwordInjected = false
        
        // Bind to output for password injection
        shadowSession.terminalEngine.$outputLines
            .sink { [weak self] lines in
                guard let self = self, let line = lines.last else { return }
                guard let pwd = passwordToInject, !passwordInjected else { return }
                
                let text = line.text.lowercased()
                if text.contains("password:") || text.contains("passphrase:") || text.contains("password for") {
                    print("🕵️ [SSHMetadata] 🔐 Injecting password for shadow session...")
                    self.shadowSession.terminalEngine.sendInput("\(pwd)\n")
                    passwordInjected = true
                }
            }
            .store(in: &cancellables)
        
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
            // Increased delay to allow main session to stabilize and reduce CPU contention
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3s wait
            
            // 3. Verify connection by running a simple echo
            if await verifyConnection() {
                self.isConnected = true
                print("🕵️ [SSHMetadata] Shadow connection established")
                
                // 4. Initial sync
                await refreshCurrentDirectory()
            } else {
                print("🕵️ [SSHMetadata] Shadow connection failed or timed out. Aborting shadow session.")
                self.isConnected = false
                disconnect()
            }
        }
    }
    
    func disconnect() {
        connectionTask?.cancel()
        connectionTask = nil
        
        // Ensure we stop the engine
        Task {
            // Attempt graceful exit first
            if isConnected {
                _ = await SSHBaseService.shared.execute("exit", via: shadowSession, timeout: 2)
            }
            // Always terminate
            await MainActor.run {
                shadowSession.terminalEngine.terminate()
            }
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
