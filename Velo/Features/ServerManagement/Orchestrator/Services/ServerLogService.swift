//
//  ServerLogService.swift
//  Velo
//
//  Service for fetching and streaming logs from the remote server.
//

import Foundation
import Combine


@MainActor
final class ServerLogService: ObservableObject {
    static let shared = ServerLogService()
    
    private let baseService = SSHBaseService.shared
    
    private init() {}
    
    /// Fetch the last N lines of a log file
    /// - Parameters:
    ///   - path: Full path to the log file on the server
    ///   - lines: Number of lines to fetch (default 50)
    ///   - via: The SSH session
    /// - Returns: Array of log lines
    func fetchLogs(path: String, lines: Int = 50, via session: TerminalViewModel) async -> [String] {
        let command = "sudo tail -n \(lines) \"\(path)\" 2>/dev/null"
        let result = await baseService.execute(command, via: session, timeout: 10)
        
        if result.exitCode != 0 || result.output.isEmpty {
            return ["No logs found at \(path) or permission denied."]
        }
        
        return result.output.components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
    
    /// Stream logs (not fully implemented in the current terminal engine, but provides a placeholder for tail -f)
    func getTailCommand(path: String, lines: Int = 20) -> String {
        return "tail -n \(lines) -f \"\(path)\""
    }
}
