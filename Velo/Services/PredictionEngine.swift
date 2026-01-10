//
//  PredictionEngine.swift
//  Velo
//
//  AI-Powered Terminal - Intelligent Command Predictions
//

import Foundation
import Combine

// MARK: - Prediction Engine
/// Generates intelligent command predictions based on history and context
@MainActor
final class PredictionEngine: ObservableObject {
    
    // MARK: - Published State
    @Published private(set) var suggestions: [CommandSuggestion] = []
    @Published private(set) var inlinePrediction: String?
    
    // MARK: - Dependencies
    private let historyManager: CommandHistoryManager
    private let analyzer = CommandAnalyzer.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    private let maxSuggestions = 8
    private let minQueryLength = 1
    
    // MARK: - Init
    init(historyManager: CommandHistoryManager) {
        self.historyManager = historyManager
    }
    
    // MARK: - Generate Predictions
    /// Generate predictions for the current input
    func predict(for input: String, workingDirectory: String) {
        guard input.count >= minQueryLength else {
            suggestions = []
            inlinePrediction = nil
            return
        }
        
        var allPredictions: [CommandSuggestion] = []
        
        // 1. Prefix matches from history (highest priority)
        let prefixMatches = generatePrefixMatches(input)
        allPredictions.append(contentsOf: prefixMatches)
        
        // 2. Fuzzy matches from history
        let fuzzyMatches = generateFuzzyMatches(input)
        allPredictions.append(contentsOf: fuzzyMatches)
        
        // 3. Sequential predictions
        let sequentialPredictions = generateSequentialPredictions()
        allPredictions.append(contentsOf: sequentialPredictions)
        
        // 4. Contextual suggestions
        let contextualSuggestions = generateContextualSuggestions(workingDirectory: workingDirectory)
        allPredictions.append(contentsOf: contextualSuggestions)
        
        // Deduplicate and sort by priority
        let deduplicated = deduplicateSuggestions(allPredictions)
        suggestions = Array(deduplicated.prefix(maxSuggestions))
        
        // Set inline prediction to best match
        inlinePrediction = suggestions.first?.command
    }
    
    // MARK: - Clear
    func clear() {
        suggestions = []
        inlinePrediction = nil
    }
    
    // MARK: - Accept Suggestion
    func acceptInlinePrediction() -> String? {
        return inlinePrediction
    }
    
    // MARK: - Private Methods
    private func generatePrefixMatches(_ input: String) -> [CommandSuggestion] {
        let lowercasedInput = input.lowercased()
        
        return historyManager.recentCommands
            .filter { $0.command.lowercased().hasPrefix(lowercasedInput) }
            .prefix(5)
            .enumerated()
            .map { index, command in
                let range = command.command.startIndex..<command.command.index(command.command.startIndex, offsetBy: min(input.count, command.command.count))
                return CommandSuggestion(
                    command: command.command,
                    description: command.context.rawValue.capitalized,
                    matchRange: range,
                    source: .recent,
                    priority: 100 - index
                )
            }
    }
    
    private func generateFuzzyMatches(_ input: String) -> [CommandSuggestion] {
        return historyManager.fuzzySearch(query: input, limit: 5)
            .enumerated()
            .map { index, command in
                CommandSuggestion(
                    command: command.command,
                    description: "Matched: \(command.context.rawValue)",
                    source: .frequent,
                    priority: 50 - index
                )
            }
    }
    
    private func generateSequentialPredictions() -> [CommandSuggestion] {
        let predictions = analyzer.predictNextInSequence(after: historyManager.recentCommands)
        
        return predictions.prefix(3).enumerated().map { index, prediction in
            CommandSuggestion(
                command: prediction.suggestedCommand,
                description: prediction.reason,
                source: .sequential,
                priority: 80 - index * 10
            )
        }
    }
    
    private func generateContextualSuggestions(workingDirectory: String) -> [CommandSuggestion] {
        let context = analyzer.analyzeContext(
            commands: historyManager.recentCommands,
            workingDirectory: workingDirectory
        )
        
        var suggestions: [CommandSuggestion] = []
        
        // Add context-specific suggestions
        switch context.primary {
        case .git:
            suggestions.append(CommandSuggestion(
                command: "git status",
                description: "Check repository status",
                source: .contextual,
                priority: 40
            ))
        case .npm:
            suggestions.append(CommandSuggestion(
                command: "npm run dev",
                description: "Start development server",
                source: .contextual,
                priority: 40
            ))
        case .docker:
            suggestions.append(CommandSuggestion(
                command: "docker ps",
                description: "List running containers",
                source: .contextual,
                priority: 40
            ))
        default:
            break
        }
        
        return suggestions
    }
    
    private func deduplicateSuggestions(_ suggestions: [CommandSuggestion]) -> [CommandSuggestion] {
        var seen = Set<String>()
        var result: [CommandSuggestion] = []
        
        // Sort by priority first
        let sorted = suggestions.sorted { $0.priority > $1.priority }
        
        for suggestion in sorted {
            let normalized = suggestion.command.trimmingCharacters(in: .whitespaces)
            if !seen.contains(normalized) {
                seen.insert(normalized)
                result.append(suggestion)
            }
        }
        
        return result
    }
}

// MARK: - Builtin Commands Database
/// Common commands for contextual suggestions
struct BuiltinCommands {
    static let git = [
        "git status",
        "git add .",
        "git commit -m \"\"",
        "git push",
        "git pull",
        "git checkout",
        "git branch",
        "git log --oneline -10",
        "git diff",
        "git stash",
    ]
    
    static let npm = [
        "npm install",
        "npm run dev",
        "npm run build",
        "npm test",
        "npm start",
        "npm update",
    ]
    
    static let docker = [
        "docker ps",
        "docker images",
        "docker build -t",
        "docker run",
        "docker-compose up",
        "docker-compose down",
    ]
    
    static let filesystem = [
        "ls -la",
        "cd ..",
        "pwd",
        "mkdir",
        "touch",
        "cat",
        "less",
    ]
}
