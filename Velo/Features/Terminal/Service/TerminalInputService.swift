//
//  TerminalInputService.swift
//  Velo
//
//  Interactive Terminal Input Service
//  Handles character-by-character input, password prompts, and stdin management
//

import Foundation
import Combine

// MARK: - Input Mode
enum TerminalInputMode {
    case normal          // Standard line-by-line input
    case interactive     // Character-by-character (for password prompts, y/n, etc.)
    case password        // Hidden input mode (no echo)
    case multiline       // Multi-line editing (heredoc, etc.)
}

// MARK: - Prompt Detection
struct PromptPattern {
    let regex: NSRegularExpression
    let mode: TerminalInputMode
    let description: String

    static let patterns: [PromptPattern] = [
        // Password prompts
        PromptPattern(pattern: "(?i)password\\s*:", mode: .password, description: "Password prompt"),
        PromptPattern(pattern: "(?i)passphrase\\s*:", mode: .password, description: "Passphrase prompt"),
        PromptPattern(pattern: "(?i)password for", mode: .password, description: "Password for user"),
        PromptPattern(pattern: "\\[sudo\\]", mode: .password, description: "Sudo password"),

        // Y/N prompts
        PromptPattern(pattern: "(?i)\\[y/n\\]", mode: .interactive, description: "Yes/No prompt"),
        PromptPattern(pattern: "(?i)\\(yes/no\\)", mode: .interactive, description: "Yes/No confirmation"),
        PromptPattern(pattern: "(?i)continue\\?", mode: .interactive, description: "Continue prompt"),
        PromptPattern(pattern: "(?i)proceed\\?", mode: .interactive, description: "Proceed prompt"),
        PromptPattern(pattern: "(?i)overwrite\\?", mode: .interactive, description: "Overwrite prompt"),

        // SSH host verification
        PromptPattern(pattern: "(?i)are you sure you want to continue connecting", mode: .interactive, description: "SSH host verification"),
        PromptPattern(pattern: "(?i)fingerprint", mode: .interactive, description: "SSH fingerprint"),

        // Interactive editors
        PromptPattern(pattern: "(?i)press enter to continue", mode: .interactive, description: "Press Enter"),
        PromptPattern(pattern: "(?i)press any key", mode: .interactive, description: "Press any key"),
    ]

    init(pattern: String, mode: TerminalInputMode, description: String) {
        self.regex = try! NSRegularExpression(pattern: pattern, options: [])
        self.mode = mode
        self.description = description
    }

    func matches(_ text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }
}

// MARK: - Terminal Input Service
@MainActor
final class TerminalInputService: ObservableObject {

    // MARK: - Published State
    @Published private(set) var inputMode: TerminalInputMode = .normal
    @Published private(set) var isAwaitingInput: Bool = false
    @Published private(set) var promptDescription: String = ""
    @Published private(set) var inputBuffer: String = ""

    // MARK: - Input History
    @Published var inputHistory: [String] = []
    private var historyIndex: Int = -1

    // MARK: - Publishers
    let inputSubmittedPublisher = PassthroughSubject<String, Never>()
    let characterInputPublisher = PassthroughSubject<Character, Never>()
    let specialKeyPublisher = PassthroughSubject<SpecialKey, Never>()

    // MARK: - Dependencies
    private weak var ptyProcess: PTYProcess?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Output Monitoring
    private var recentOutput: String = ""
    private let outputWindowSize = 500 // Characters to keep for prompt detection

    // MARK: - Init
    init() {}

    // MARK: - Configure PTY
    func configure(with ptyProcess: PTYProcess?) {
        self.ptyProcess = ptyProcess
    }

    // MARK: - Process Output
    /// Called when terminal output is received - detects prompts and updates input mode
    func processOutput(_ text: String) {
        // Append to recent output window
        recentOutput += text
        if recentOutput.count > outputWindowSize {
            recentOutput = String(recentOutput.suffix(outputWindowSize))
        }

        // Detect prompt patterns
        detectPrompt(in: text)
    }

    // MARK: - Detect Prompt
    private func detectPrompt(in text: String) {
        // Check against known patterns
        for pattern in PromptPattern.patterns {
            if pattern.matches(text) {
                setInputMode(pattern.mode, description: pattern.description)
                return
            }
        }

        // Check for shell prompt (indicates command completed)
        let shellPromptPatterns = [
            "\\$\\s*$",      // Standard shell prompt
            "#\\s*$",        // Root prompt
            "❯\\s*$",        // Custom prompt
            ">\\s*$",        // Basic prompt
        ]

        for promptPattern in shellPromptPatterns {
            if let regex = try? NSRegularExpression(pattern: promptPattern, options: []),
               regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) != nil {
                // Back to normal mode after command completes
                if inputMode != .normal {
                    setInputMode(.normal, description: "")
                }
                return
            }
        }
    }

    // MARK: - Set Input Mode
    private func setInputMode(_ mode: TerminalInputMode, description: String) {
        guard mode != inputMode else { return }

        inputMode = mode
        promptDescription = description
        isAwaitingInput = (mode != .normal)

        // Clear input buffer when entering interactive mode
        if mode != .normal {
            inputBuffer = ""
        }
    }

    // MARK: - Handle Character Input
    /// Process a single character input (for interactive modes)
    func handleCharacter(_ char: Character) {
        switch inputMode {
        case .normal:
            // In normal mode, buffer characters
            inputBuffer.append(char)

        case .interactive:
            // Send character immediately
            sendCharacter(char)

        case .password:
            // Buffer password characters but don't echo
            inputBuffer.append(char)

        case .multiline:
            inputBuffer.append(char)
        }
    }

    // MARK: - Handle Special Keys
    func handleSpecialKey(_ key: SpecialKey) {
        switch key {
        case .enter:
            submitCurrentInput()

        case .tab:
            handleTab()

        case .backspace:
            handleBackspace()

        case .arrowUp:
            navigateHistoryUp()

        case .arrowDown:
            navigateHistoryDown()

        case .arrowLeft, .arrowRight:
            // Handle cursor movement in future
            break

        case .ctrlC:
            handleInterrupt()

        case .ctrlD:
            handleEOF()

        case .escape:
            handleEscape()
        }

        specialKeyPublisher.send(key)
    }

    // MARK: - Submit Input
    func submitCurrentInput() {
        let input = inputBuffer

        switch inputMode {
        case .normal:
            // Add to history if non-empty
            if !input.isEmpty {
                addToHistory(input)
            }
            // Send with newline
            sendInput(input + "\n")

        case .interactive:
            // Send with newline for y/n prompts
            sendInput(input + "\n")

        case .password:
            // Send password with newline, don't add to history
            sendInput(input + "\n")

        case .multiline:
            sendInput(input + "\n")
        }

        inputBuffer = ""
        historyIndex = -1

        inputSubmittedPublisher.send(input)
    }

    // MARK: - Submit External Input
    /// For when the ViewModel wants to submit input directly
    func submitInput(_ text: String, addNewline: Bool = true) {
        let finalText = addNewline ? text + "\n" : text
        sendInput(finalText)

        if !text.isEmpty && addNewline {
            addToHistory(text)
        }
    }

    // MARK: - Send Raw Character
    func sendCharacter(_ char: Character) {
        sendInput(String(char))
        characterInputPublisher.send(char)
    }

    // MARK: - Private Send
    private func sendInput(_ text: String) {
        ptyProcess?.write(text)
    }

    // MARK: - Tab Handling
    private func handleTab() {
        switch inputMode {
        case .normal:
            // Send Tab character to shell for built-in completion
            sendInput("\t")

        case .interactive, .password, .multiline:
            // Ignore Tab in these modes
            break
        }
    }

    // MARK: - Backspace Handling
    private func handleBackspace() {
        guard !inputBuffer.isEmpty else { return }
        inputBuffer.removeLast()

        // In normal mode, might want to send backspace to PTY
        if inputMode == .normal {
            sendInput("\u{7f}") // DEL character
        }
    }

    // MARK: - History Navigation
    private func addToHistory(_ command: String) {
        // Don't add duplicates at the end
        if inputHistory.last != command {
            inputHistory.append(command)
        }
        // Keep reasonable size
        if inputHistory.count > 500 {
            inputHistory.removeFirst()
        }
    }

    func navigateHistoryUp() {
        guard !inputHistory.isEmpty else { return }

        if historyIndex < 0 {
            historyIndex = inputHistory.count - 1
        } else if historyIndex > 0 {
            historyIndex -= 1
        }

        inputBuffer = inputHistory[historyIndex]
    }

    func navigateHistoryDown() {
        guard historyIndex >= 0 else { return }

        if historyIndex < inputHistory.count - 1 {
            historyIndex += 1
            inputBuffer = inputHistory[historyIndex]
        } else {
            historyIndex = -1
            inputBuffer = ""
        }
    }

    // MARK: - Control Characters
    private func handleInterrupt() {
        // Send Ctrl+C
        sendInput("\u{03}")
        inputBuffer = ""
        setInputMode(.normal, description: "")
    }

    private func handleEOF() {
        // Send Ctrl+D
        sendInput("\u{04}")
    }

    private func handleEscape() {
        // Send ESC
        sendInput("\u{1b}")
        inputBuffer = ""
    }

    // MARK: - Reset
    func reset() {
        inputMode = .normal
        isAwaitingInput = false
        promptDescription = ""
        inputBuffer = ""
        historyIndex = -1
        recentOutput = ""
    }

    // MARK: - Get Current Buffer
    func getCurrentBuffer() -> String {
        return inputBuffer
    }

    // MARK: - Set Buffer Externally
    func setBuffer(_ text: String) {
        inputBuffer = text
    }
}

// MARK: - Special Keys
enum SpecialKey {
    case enter
    case tab
    case backspace
    case arrowUp
    case arrowDown
    case arrowLeft
    case arrowRight
    case ctrlC
    case ctrlD
    case escape
}
