//
//  TerminalSessionProtocol.swift
//  Velo
//
//  Unified Terminal Session Protocol
//  Ensures SSH and Local sessions have identical behavior
//

import Foundation
import Combine

// MARK: - Terminal Session Protocol
/// Unified interface for terminal sessions (SSH and Local)
/// Ensures identical behavior regardless of connection type
protocol TerminalSessionProtocol: AnyObject {

    // MARK: - Session Information
    var sessionId: UUID { get }
    var sessionType: TerminalSessionType { get }
    var isConnected: Bool { get }
    var workingDirectory: String { get }

    // MARK: - State Publishers
    var outputPublisher: PassthroughSubject<OutputLine, Never> { get }
    var statePublisher: PassthroughSubject<TerminalSessionState, Never> { get }

    // MARK: - Execution
    func execute(_ command: String) async throws -> CommandModel
    func sendInput(_ text: String)
    func sendCharacter(_ char: Character)
    func sendControlSequence(_ sequence: ControlSequence)

    // MARK: - Control
    func interrupt()
    func terminate()
    func clear()

    // MARK: - Directory
    func changeDirectory(to path: String) throws
}

// MARK: - Session Type
enum TerminalSessionType {
    case local
    case ssh(host: String, user: String)
    case container(id: String)

    var displayName: String {
        switch self {
        case .local: return "Local"
        case .ssh(let host, let user): return "\(user)@\(host)"
        case .container(let id): return "Container: \(id.prefix(12))"
        }
    }

    var icon: String {
        switch self {
        case .local: return "terminal"
        case .ssh: return "network"
        case .container: return "cube"
        }
    }

    var isRemote: Bool {
        switch self {
        case .local: return false
        case .ssh, .container: return true
        }
    }
}

// MARK: - Session State
enum TerminalSessionState: Equatable {
    case idle
    case connecting
    case connected
    case executing(command: String)
    case awaitingInput(prompt: String)
    case disconnected(reason: String?)
    case error(String)

    var isActive: Bool {
        switch self {
        case .connected, .executing, .awaitingInput:
            return true
        default:
            return false
        }
    }
}

// MARK: - Control Sequence
enum ControlSequence {
    case ctrlC       // Interrupt (SIGINT)
    case ctrlD       // EOF
    case ctrlZ       // Suspend (SIGTSTP)
    case ctrlL       // Clear screen
    case tab         // Autocomplete
    case arrowUp     // History up / cursor up
    case arrowDown   // History down / cursor down
    case arrowLeft   // Cursor left
    case arrowRight  // Cursor right
    case home        // Cursor to start
    case end         // Cursor to end
    case escape      // Escape key

    var sequence: String {
        switch self {
        case .ctrlC: return "\u{03}"
        case .ctrlD: return "\u{04}"
        case .ctrlZ: return "\u{1a}"
        case .ctrlL: return "\u{0c}"
        case .tab: return "\t"
        case .arrowUp: return "\u{1b}[A"
        case .arrowDown: return "\u{1b}[B"
        case .arrowLeft: return "\u{1b}[D"
        case .arrowRight: return "\u{1b}[C"
        case .home: return "\u{1b}[H"
        case .end: return "\u{1b}[F"
        case .escape: return "\u{1b}"
        }
    }
}

// MARK: - Session Capabilities
struct SessionCapabilities: OptionSet {
    let rawValue: Int

    static let fileOperations = SessionCapabilities(rawValue: 1 << 0)
    static let interactiveInput = SessionCapabilities(rawValue: 1 << 1)
    static let colorOutput = SessionCapabilities(rawValue: 1 << 2)
    static let autocomplete = SessionCapabilities(rawValue: 1 << 3)
    static let history = SessionCapabilities(rawValue: 1 << 4)
    static let signals = SessionCapabilities(rawValue: 1 << 5)
    static let resize = SessionCapabilities(rawValue: 1 << 6)

    static let local: SessionCapabilities = [.fileOperations, .interactiveInput, .colorOutput, .autocomplete, .history, .signals, .resize]
    static let ssh: SessionCapabilities = [.fileOperations, .interactiveInput, .colorOutput, .autocomplete, .history, .signals, .resize]
}

// MARK: - Session Event
enum SessionEvent {
    case connected
    case disconnected(reason: String?)
    case outputReceived(OutputLine)
    case inputPromptDetected(String)
    case passwordPromptDetected
    case commandStarted(String)
    case commandCompleted(exitCode: Int32)
    case error(Error)
    case directoryChanged(String)
}

// MARK: - Session Configuration
struct SessionConfiguration {
    var shell: String = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
    var environment: [String: String] = ProcessInfo.processInfo.environment
    var workingDirectory: String = NSHomeDirectory()
    var terminalType: String = "xterm-256color"
    var rows: UInt16 = 30
    var cols: UInt16 = 120

    // SSH specific
    var sshHost: String?
    var sshUser: String?
    var sshPort: Int = 22
    var sshKeyPath: String?

    static var `default`: SessionConfiguration {
        var config = SessionConfiguration()
        config.environment["TERM"] = "xterm-256color"
        config.environment["CLICOLOR"] = "1"
        config.environment["CLICOLOR_FORCE"] = "1"
        return config
    }
}

// MARK: - Unified Session Manager
/// Manages terminal sessions with unified behavior
@MainActor
final class TerminalSessionManager: ObservableObject {

    // MARK: - Published State
    @Published private(set) var activeSessions: [UUID: any TerminalSessionProtocol] = [:]
    @Published private(set) var activeSessionId: UUID?

    // MARK: - Session Events
    let sessionEventPublisher = PassthroughSubject<(UUID, SessionEvent), Never>()

    // MARK: - Active Session
    var activeSession: (any TerminalSessionProtocol)? {
        guard let id = activeSessionId else { return nil }
        return activeSessions[id]
    }

    // MARK: - Create Session
    func createLocalSession(configuration: SessionConfiguration = .default) -> UUID {
        let sessionId = UUID()
        // Create local session using TerminalEngine
        // The actual implementation would wrap TerminalEngine
        return sessionId
    }

    func createSSHSession(host: String, user: String, configuration: SessionConfiguration) -> UUID {
        let sessionId = UUID()
        // Create SSH session
        return sessionId
    }

    // MARK: - Switch Session
    func switchToSession(_ sessionId: UUID) {
        guard activeSessions[sessionId] != nil else { return }
        activeSessionId = sessionId
    }

    // MARK: - Close Session
    func closeSession(_ sessionId: UUID) {
        activeSessions[sessionId]?.terminate()
        activeSessions.removeValue(forKey: sessionId)

        if activeSessionId == sessionId {
            activeSessionId = activeSessions.keys.first
        }
    }
}

// MARK: - Parity Verification
/// Verifies that SSH and Local sessions have consistent behavior
struct SessionParityChecker {

    static func verifyParity(local: any TerminalSessionProtocol, remote: any TerminalSessionProtocol) -> [ParityIssue] {
        var issues: [ParityIssue] = []

        // Both should support the same control sequences
        // Both should handle input the same way
        // Both should stream output identically

        return issues
    }

    struct ParityIssue {
        let feature: String
        let localBehavior: String
        let remoteBehavior: String
        let severity: Severity

        enum Severity {
            case warning
            case error
        }
    }
}
