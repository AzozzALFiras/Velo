//
//  ServerAdminService.swift
//  Velo
//
//  Centralized service for managing Server Admin execution.
//  Maintains a pool of dedicated hidden SSH connections for admin tasks.
//

import Foundation
import Combine

@MainActor
final class ServerAdminService: ObservableObject {
    
    static let shared = ServerAdminService()
    
    private var engines: [String: ServerAdminTerminalEngine] = [:]
    private var pendingConnections: [String: Task<ServerAdminTerminalEngine?, Never>] = [:]
    private let manager = SSHManager()
    
    private init() {}
    
    /// Get or create an admin engine for a given terminal session.
    /// Includes automatic retry logic to handle transient connection timeouts.
    func getEngine(for terminal: TerminalViewModel) async -> ServerAdminTerminalEngine? {
        guard let conn = manager.findConnection(for: terminal) else {
            print("❌ [ServerAdminService] Could not find connection for terminal \(terminal.id)")
            return nil
        }

        let key = "\(conn.username)@\(conn.host):\(conn.port)"

        // Return existing engine if available
        if let existing = engines[key] {
            return existing
        }

        // If there's already a pending connection for this key, wait for it
        if let pendingTask = pendingConnections[key] {
            return await pendingTask.value
        }

        // Create a new connection task with retry logic
        let maxAttempts = 3
        let task = Task<ServerAdminTerminalEngine?, Never> {
            let password = manager.getPassword(for: conn)

            for attempt in 1...maxAttempts {
                let engine = ServerAdminTerminalEngine()

                do {
                    try await engine.connect(using: conn, password: password)
                    if attempt > 1 {
                        print("✅ [ServerAdminService] Admin engine connected on attempt \(attempt)/\(maxAttempts)")
                    }
                    return engine
                } catch {
                    print("❌ [ServerAdminService] Admin engine connection attempt \(attempt)/\(maxAttempts) failed: \(error)")
                    if attempt < maxAttempts {
                        print("🔄 [ServerAdminService] Retrying in 3 seconds...")
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                    }
                }
            }

            print("❌ [ServerAdminService] All \(maxAttempts) connection attempts failed")
            return nil
        }

        // Register the pending task
        pendingConnections[key] = task

        // Wait for the connection
        let result = await task.value

        // Clean up pending and store result
        pendingConnections[key] = nil
        if let engine = result {
            engines[key] = engine
        }

        return result
    }

    /// Pre-warm the admin engine connection.
    /// Call before firing parallel detection tasks to avoid race conditions.
    func ensureConnected(for terminal: TerminalViewModel) async -> Bool {
        return await getEngine(for: terminal) != nil
    }
    
    /// Execute a command using the dedicated admin engine
    func execute(_ command: String, via terminal: TerminalViewModel, timeout: Int = 600) async -> SSHCommandResult {
        guard let engine = await getEngine(for: terminal) else {
            return SSHCommandResult(
                command: command,
                output: "Error: Could not establish a dedicated admin connection. Please check your server credentials.",
                exitCode: -1,
                executionTime: 0
            )
        }
        
        return await engine.execute(command, timeout: timeout)
    }

    /// Write a file via the dedicated admin engine
    func writeFile(at path: String, content: String, useSudo: Bool = true, via terminal: TerminalViewModel) async -> Bool {
        guard let engine = await getEngine(for: terminal) else { return false }
        
        let safePath = path.replacingOccurrences(of: "'", with: "'\\''")
        let tempPath = "/tmp/vadm_upload_\(UUID().uuidString.prefix(8))"
        
        // 1. Initialize Temp File
        let initResult = await engine.execute("printf '' > '\(tempPath)' && echo 'INIT_OK'", timeout: 10)
        guard initResult.output.contains("INIT_OK") else { return false }
        
        guard let data = content.data(using: .utf8) else { return false }
        
        let chunkSize = 300 // Slightly larger for admin channel as it's cleaner
        let totalBytes = data.count
        var offset = 0
        
        // 2. Upload Loop
        while offset < totalBytes {
            let length = min(chunkSize, totalBytes - offset)
            let chunkData = data.subdata(in: offset..<offset+length)
            let hexEscaped = chunkData.map { String(format: "\\x%02x", $0) }.joined()
            
            let cmd = "printf %b '\(hexEscaped)' >> '\(tempPath)' && echo 'C_OK'"
            let result = await engine.execute(cmd, timeout: 10)
            
            if !result.output.contains("C_OK") {
                _ = await engine.execute("rm -f '\(tempPath)'", timeout: 5)
                return false
            }
            offset += length
        }
        
        // 3. Finalize
        let installCmd = "\(useSudo ? "sudo " : "")cat '\(tempPath)' | \(useSudo ? "sudo " : "")tee '\(safePath)' > /dev/null && echo 'INSTALL_OK'"
        let installResult = await engine.execute(installCmd, timeout: 30)
        
        _ = await engine.execute("rm -f '\(tempPath)'", timeout: 5)
        
        return installResult.output.contains("INSTALL_OK")
    }

    /// Read a file via the dedicated admin engine
    func readFile(at path: String, via terminal: TerminalViewModel) async -> String? {
        guard let engine = await getEngine(for: terminal) else { return nil }
        let result = await engine.execute("sudo cat '\(path)' 2>/dev/null", timeout: 20)
        return result.exitCode == 0 ? result.output : nil
    }
    
    /// Disconnect all admin engines
    func disconnectAll() async {
        for engine in engines.values {
            await engine.disconnect()
        }
        engines.removeAll()
    }
}
