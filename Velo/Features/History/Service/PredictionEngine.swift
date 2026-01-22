//
//  PredictionEngine.swift
//  Velo
//
//  Enhanced Command Prediction Engine
//  Context-aware suggestions with frequency/recency scoring
//

import Foundation
import Combine

// MARK: - Prediction Context
struct PredictionContext {
    let workingDirectory: String
    let remoteItems: [String]
    let isSSH: Bool
    let serverHost: String?
    let projectType: ProjectType?

    enum ProjectType: String {
        case node       // package.json present
        case python     // requirements.txt, setup.py, pyproject.toml
        case ruby       // Gemfile
        case rust       // Cargo.toml
        case go         // go.mod
        case swift      // Package.swift
        case php        // composer.json
        case laravel    // artisan file present
        case generic
    }
}

// MARK: - Prediction Engine

/// Provides intelligent command predictions with context awareness
@MainActor
final class PredictionEngine: ObservableObject {

    // MARK: - Published Properties

    @Published var inlinePrediction: String?
    @Published var suggestions: [CommandSuggestion] = []
    @Published var showingSuggestions = false
    @Published var selectedIndex: Int = 0

    // MARK: - Dependencies

    private let historyManager: CommandHistoryManager
    private var cancellables = Set<AnyCancellable>()

    // MARK: - State

    private var currentContext: PredictionContext?
    private var lastInput: String = ""
    private var cachedProjectType: PredictionContext.ProjectType?
    private var projectTypeCache: [String: PredictionContext.ProjectType] = [:]

    // MARK: - Context-Specific Commands

    private let nodeCommands = ["npm install", "npm run build", "npm start", "npm test", "npm run dev", "yarn", "yarn build", "yarn dev", "npx"]
    private let pythonCommands = ["python", "python3", "pip install", "pip3 install", "pytest", "python -m venv", "source venv/bin/activate"]
    private let gitCommands = ["git status", "git add .", "git commit -m", "git push", "git pull", "git checkout", "git branch", "git log", "git diff"]
    private let dockerCommands = ["docker ps", "docker images", "docker-compose up", "docker-compose down", "docker build", "docker run"]
    private let laravelCommands = ["php artisan", "php artisan migrate", "php artisan serve", "php artisan tinker", "composer install"]

    // MARK: - Init

    init(historyManager: CommandHistoryManager) {
        self.historyManager = historyManager
    }

    // MARK: - Predict

    func predict(
        for input: String,
        workingDirectory: String,
        remoteItems: [String] = [],
        isSSH: Bool = false,
        serverHost: String? = nil
    ) {
        lastInput = input

        guard !input.isEmpty else {
            clear()
            return
        }

        // Detect project type
        let projectType = detectProjectType(in: workingDirectory)

        // Build context
        currentContext = PredictionContext(
            workingDirectory: workingDirectory,
            remoteItems: remoteItems,
            isSSH: isSSH,
            serverHost: serverHost,
            projectType: projectType
        )

        var allSuggestions: [CommandSuggestion] = []
        let lowercaseInput = input.lowercased()

        // 1. History-based predictions with smart scoring
        allSuggestions += getHistorySuggestions(input: lowercaseInput, context: currentContext!)

        // 2. Context-aware command suggestions
        allSuggestions += getContextualSuggestions(input: lowercaseInput, context: currentContext!)

        // 3. File/folder completions
        allSuggestions += getFileSuggestions(input: input, context: currentContext!)

        // Remove duplicates and sort by confidence
        var seen = Set<String>()
        let uniqueSuggestions = allSuggestions.filter { suggestion in
            guard !seen.contains(suggestion.command) else { return false }
            seen.insert(suggestion.command)
            return true
        }.sorted { $0.confidence > $1.confidence }

        suggestions = Array(uniqueSuggestions.prefix(10))
        showingSuggestions = !suggestions.isEmpty
        selectedIndex = 0

        // Set inline prediction (first match)
        if let first = suggestions.first {
            inlinePrediction = first.command
        } else {
            inlinePrediction = nil
        }
    }

    // MARK: - History Suggestions

    private func getHistorySuggestions(input: String, context: PredictionContext) -> [CommandSuggestion] {
        var suggestions: [CommandSuggestion] = []
        let recentCommands = historyManager.recentCommands

        for cmd in recentCommands.prefix(50) {
            let command = cmd.command.lowercased()
            guard command.hasPrefix(input) else { continue }

            // Calculate smart confidence score
            var confidence: Double = 0.5

            // Boost for frequency
            let frequencyBoost = min(0.2, Double(cmd.frequency) * 0.02)
            confidence += frequencyBoost

            // Boost for recency (within last 24 hours)
            let hoursSince = Date().timeIntervalSince(cmd.timestamp) / 3600
            if hoursSince < 24 {
                confidence += 0.15 * (1.0 - hoursSince / 24.0)
            }

            // Boost for same directory
            if cmd.workingDirectory == context.workingDirectory {
                confidence += 0.1
            }

            // Boost for matching server (SSH)
            if context.isSSH, let host = context.serverHost {
                if cmd.command.contains(host) {
                    confidence += 0.1
                }
            }

            // Boost for exact prefix match ratio
            let matchRatio = Double(input.count) / Double(cmd.command.count)
            confidence += matchRatio * 0.1

            confidence = min(1.0, confidence)

            suggestions.append(CommandSuggestion(
                command: cmd.command,
                source: .history,
                confidence: confidence,
                description: formatTimeAgo(cmd.timestamp)
            ))
        }

        return suggestions
    }

    // MARK: - Contextual Suggestions

    private func getContextualSuggestions(input: String, context: PredictionContext) -> [CommandSuggestion] {
        var suggestions: [CommandSuggestion] = []

        // Get relevant commands based on project type
        var contextCommands: [String] = []

        switch context.projectType {
        case .node:
            contextCommands = nodeCommands
        case .python:
            contextCommands = pythonCommands
        case .php, .laravel:
            contextCommands = laravelCommands
        default:
            break
        }

        // Always include git commands
        contextCommands += gitCommands

        // Docker commands if likely
        contextCommands += dockerCommands

        for cmd in contextCommands {
            guard cmd.lowercased().hasPrefix(input) else { continue }

            suggestions.append(CommandSuggestion(
                command: cmd,
                source: .builtin,
                confidence: 0.65,
                description: "Suggested"
            ))
        }

        return suggestions
    }

    // MARK: - File Suggestions

    private func getFileSuggestions(input: String, context: PredictionContext) -> [CommandSuggestion] {
        var suggestions: [CommandSuggestion] = []

        // Check if input looks like a path completion
        let parts = input.components(separatedBy: .whitespaces)
        guard let lastPart = parts.last, !lastPart.isEmpty else { return suggestions }

        // Handle SSH remote items
        if context.isSSH {
            for item in context.remoteItems where item.lowercased().hasPrefix(lastPart.lowercased()) {
                let isDir = item.hasSuffix("/")
                suggestions.append(CommandSuggestion(
                    command: item,
                    source: .filesystem,
                    confidence: 0.55,
                    description: isDir ? "Directory" : "File"
                ))
            }
            return suggestions
        }

        // Local file system completion
        let localItems = getLocalItems(in: context.workingDirectory, matching: lastPart)
        for item in localItems.prefix(10) {
            let isDir = item.hasSuffix("/")
            suggestions.append(CommandSuggestion(
                command: item,
                source: .filesystem,
                confidence: 0.6,
                description: isDir ? "Directory" : "File"
            ))
        }

        return suggestions
    }

    // MARK: - Project Type Detection

    private func detectProjectType(in directory: String) -> PredictionContext.ProjectType? {
        // Check cache
        if let cached = projectTypeCache[directory] {
            return cached
        }

        let fm = FileManager.default

        // Check for various project indicators
        if fm.fileExists(atPath: (directory as NSString).appendingPathComponent("package.json")) {
            projectTypeCache[directory] = .node
            return .node
        }

        if fm.fileExists(atPath: (directory as NSString).appendingPathComponent("artisan")) {
            projectTypeCache[directory] = .laravel
            return .laravel
        }

        if fm.fileExists(atPath: (directory as NSString).appendingPathComponent("composer.json")) {
            projectTypeCache[directory] = .php
            return .php
        }

        let pythonFiles = ["requirements.txt", "setup.py", "pyproject.toml", "Pipfile"]
        for file in pythonFiles {
            if fm.fileExists(atPath: (directory as NSString).appendingPathComponent(file)) {
                projectTypeCache[directory] = .python
                return .python
            }
        }

        if fm.fileExists(atPath: (directory as NSString).appendingPathComponent("Cargo.toml")) {
            projectTypeCache[directory] = .rust
            return .rust
        }

        if fm.fileExists(atPath: (directory as NSString).appendingPathComponent("go.mod")) {
            projectTypeCache[directory] = .go
            return .go
        }

        if fm.fileExists(atPath: (directory as NSString).appendingPathComponent("Package.swift")) {
            projectTypeCache[directory] = .swift
            return .swift
        }

        if fm.fileExists(atPath: (directory as NSString).appendingPathComponent("Gemfile")) {
            projectTypeCache[directory] = .ruby
            return .ruby
        }

        return .generic
    }

    // MARK: - Clear

    func clear() {
        inlinePrediction = nil
        suggestions = []
        showingSuggestions = false
        selectedIndex = 0
    }

    // MARK: - Accept

    func acceptInlinePrediction() -> String? {
        let prediction = inlinePrediction
        clear()
        return prediction
    }

    // MARK: - Navigation

    func moveSelectionUp() {
        guard !suggestions.isEmpty else { return }
        selectedIndex = selectedIndex > 0 ? selectedIndex - 1 : suggestions.count - 1
        inlinePrediction = suggestions[selectedIndex].command
    }

    func moveSelectionDown() {
        guard !suggestions.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % suggestions.count
        inlinePrediction = suggestions[selectedIndex].command
    }

    func acceptSelectedSuggestion() -> CommandSuggestion? {
        guard !suggestions.isEmpty, selectedIndex < suggestions.count else { return nil }
        let suggestion = suggestions[selectedIndex]
        clear()
        return suggestion
    }

    // MARK: - Private Methods

    private func getLocalItems(in directory: String, matching prefix: String) -> [String] {
        let fm = FileManager.default
        let url = URL(fileURLWithPath: directory)

        guard let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return []
        }

        let lastComponent = (prefix as NSString).lastPathComponent.lowercased()

        return contents
            .compactMap { url -> String? in
                let name = url.lastPathComponent
                guard name.lowercased().hasPrefix(lastComponent) else { return nil }

                // Skip hidden files unless prefix starts with .
                if name.hasPrefix(".") && !lastComponent.hasPrefix(".") { return nil }

                let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                return isDir ? "\(name)/" : name
            }
            .sorted()
    }

    private func formatTimeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)

        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let mins = Int(interval / 60)
            return "\(mins)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }
}

// MARK: - Command Suggestion

struct CommandSuggestion: Identifiable, Hashable {
    let id = UUID()
    let command: String
    let source: SuggestionSource
    let confidence: Double
    let description: String?

    enum SuggestionSource: String {
        case history
        case filesystem
        case ai
        case builtin
    }

    init(command: String, source: SuggestionSource, confidence: Double, description: String? = nil) {
        self.command = command
        self.source = source
        self.confidence = confidence
        self.description = description
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(command)
    }

    static func == (lhs: CommandSuggestion, rhs: CommandSuggestion) -> Bool {
        return lhs.command == rhs.command
    }

    // Icon for suggestion source
    var icon: String {
        switch source {
        case .history: return "clock.arrow.circlepath"
        case .filesystem: return "folder"
        case .ai: return "sparkles"
        case .builtin: return "terminal"
        }
    }
}
