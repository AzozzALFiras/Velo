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
    func predict(for input: String, workingDirectory: String, remoteItems: [String] = []) {
        guard input.count >= minQueryLength else {
            suggestions = []
            inlinePrediction = nil
            return
        }
        
        var allPredictions: [CommandSuggestion] = []
        
        // 0. Remote/parsed directory suggestions for cd command (highest priority for SSH)
        if input.lowercased().hasPrefix("cd ") {
            let remoteSuggestions = generateRemoteDirectorySuggestions(input: input, items: remoteItems)
            allPredictions.append(contentsOf: remoteSuggestions)
            
            // Also add local suggestions if not in SSH
            if remoteItems.isEmpty {
                let dirSuggestions = generateDirectorySuggestions(input: input, workingDirectory: workingDirectory)
                allPredictions.append(contentsOf: dirSuggestions)
            }
        }
        
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
    
    // MARK: - Remote Directory Suggestions
    private func generateRemoteDirectorySuggestions(input: String, items: [String]) -> [CommandSuggestion] {
        guard !items.isEmpty else { return [] }
        
        // Extract the path part after "cd "
        let pathPart = String(input.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        let filter = pathPart.lowercased()
        
        return items
            .filter { filter.isEmpty || $0.lowercased().hasPrefix(filter) }
            .prefix(10)
            .enumerated()
            .map { index, item in
                CommandSuggestion(
                    command: "cd \(item)",
                    description: "📁 Remote folder",
                    source: .contextual,
                    priority: 150 - index  // Higher priority than local suggestions
                )
            }
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
    
    // MARK: - Directory Suggestions
    private func generateDirectorySuggestions(input: String, workingDirectory: String) -> [CommandSuggestion] {
        // Extract the path part after "cd "
        let pathPart = String(input.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        
        // Determine the base directory and partial name to match
        let basePath: String
        let partialName: String
        
        if pathPart.isEmpty {
            basePath = workingDirectory
            partialName = ""
        } else if pathPart.hasPrefix("~") {
            let expanded = (pathPart as NSString).expandingTildeInPath
            if pathPart.hasSuffix("/") {
                basePath = expanded
                partialName = ""
            } else {
                basePath = (expanded as NSString).deletingLastPathComponent
                partialName = (expanded as NSString).lastPathComponent.lowercased()
            }
        } else if pathPart.hasPrefix("/") {
            if pathPart.hasSuffix("/") {
                basePath = pathPart
                partialName = ""
            } else {
                basePath = (pathPart as NSString).deletingLastPathComponent
                partialName = (pathPart as NSString).lastPathComponent.lowercased()
            }
        } else {
            let fullPath = (workingDirectory as NSString).appendingPathComponent(pathPart)
            if pathPart.hasSuffix("/") {
                basePath = fullPath
                partialName = ""
            } else {
                basePath = (fullPath as NSString).deletingLastPathComponent
                partialName = (fullPath as NSString).lastPathComponent.lowercased()
            }
        }
        
        // List directories in basePath
        var suggestions: [CommandSuggestion] = []
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: basePath)
            var isDir: ObjCBool = false
            
            for item in contents.prefix(20) {
                let fullPath = (basePath as NSString).appendingPathComponent(item)
                
                // Only include directories
                if FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir), isDir.boolValue {
                    // Match partial name
                    if partialName.isEmpty || item.lowercased().hasPrefix(partialName) {
                        // Build the suggestion
                        let suggestionPath: String
                        if pathPart.isEmpty {
                            suggestionPath = item
                        } else if pathPart.hasSuffix("/") {
                            suggestionPath = pathPart + item
                        } else if pathPart.contains("/") {
                            let prefix = (pathPart as NSString).deletingLastPathComponent
                            suggestionPath = prefix.isEmpty ? item : prefix + "/" + item
                        } else {
                            suggestionPath = item
                        }
                        
                        suggestions.append(CommandSuggestion(
                            command: "cd \(suggestionPath)",
                            description: "📁 Directory",
                            source: .contextual,
                            priority: 120
                        ))
                    }
                }
            }
        } catch {
            // Ignore errors
        }
        
        return suggestions
    }
}



