//
//  TabManager.swift
//  Velo
//
//  AI-Powered Terminal - Multi-Tab Manager
//
//

import SwiftUI
import Combine

// MARK: - Tab Manager
/// Manages multiple terminal sessions (tabs)
@MainActor
final class TabManager: ObservableObject {
    
    // MARK: - Published State
    @Published var sessions: [TerminalViewModel] = []
    @Published var activeSessionId: UUID?
    
    // MARK: - Dependencies
    private let historyManager: CommandHistoryManager
    
    // MARK: - Init
    init(historyManager: CommandHistoryManager) {
        self.historyManager = historyManager
        
        // Start with one default tab
        addSession()
    }
    
    // MARK: - Computed Properties
    var activeSession: TerminalViewModel? {
        sessions.first { $0.id == activeSessionId }
    }
    
    // MARK: - Actions
    func addSession() {
        let engine = TerminalEngine()
        let newSession = TerminalViewModel(
            terminalEngine: engine,
            historyManager: historyManager
        )
        // Default title
        newSession.title = "Terminal \(sessions.count + 1)"
        
        sessions.append(newSession)
        activeSessionId = newSession.id
    }
    
    func closeSession(id: UUID) {
        // Don't close the last tab
        guard sessions.count > 1 else { return }
        
        guard let index = sessions.firstIndex(where: { $0.id == id }) else { return }
        
        let sessionToRemove = sessions[index]
        // Cleanup resources if needed (e.g. terminate process)
        sessionToRemove.terminalEngine.interrupt() // Use interrupt or a new terminate method if available
        
        sessions.remove(at: index)
        
        // If we closed the active session, switch to another one
        if activeSessionId == id {
            // Try to go to the one before, or the one after
            if index > 0 {
                activeSessionId = sessions[index - 1].id
            } else {
                activeSessionId = sessions.first?.id
            }
        }
    }
    
    func switchToSession(id: UUID) {
        activeSessionId = id
    }
    
    // MARK: - SSH Sessions
    func createSSHSession(host: String, user: String, port: Int, keyPath: String? = nil) {
        let engine = TerminalEngine()
        let newSession = TerminalViewModel(
            terminalEngine: engine,
            historyManager: historyManager
        )
        
        // Set SSH tab title with icon indicator
        newSession.title = "SSH: \(user)@\(host)"
        
        sessions.append(newSession)
        activeSessionId = newSession.id
        
        // Build and execute SSH command
        var sshCommand = "ssh"
        if port != 22 {
            sshCommand += " -p \(port)"
        }
        if let keyPath = keyPath, !keyPath.isEmpty {
            sshCommand += " -i \(keyPath)"
        }
        sshCommand += " \(user)@\(host)"
        
        // Execute SSH command in the new session
        Task {
            try? await Task.sleep(for: .milliseconds(100))
            newSession.inputText = sshCommand
            newSession.executeCommand()
        }
    }
}
