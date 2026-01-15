//
//  PredictionEngine.swift
//  Velo
//
//  Command prediction engine using history and context
//  Re-created as minimal implementation after cleanup
//

import Foundation
import Combine

// MARK: - Prediction Engine

/// Provides command predictions and inline suggestions
final class PredictionEngine: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var inlinePrediction: String?
    @Published var suggestions: [CommandSuggestion] = []
    @Published var showingSuggestions = false
    
    // MARK: - Dependencies
    
    private let historyManager: CommandHistoryManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init
    
    init(historyManager: CommandHistoryManager) {
        self.historyManager = historyManager
    }
    
    // MARK: - Predict
    
    func predict(
        for input: String,
        workingDirectory: String,
        remoteItems: [String] = [],
        isSSH: Bool = false
    ) {
        guard !input.isEmpty else {
            clear()
            return
        }
        
        var allSuggestions: [CommandSuggestion] = []
        
        // 1. History-based predictions
        let recentCommands = historyManager.recentCommands
        for cmd in recentCommands.prefix(20) {
            if cmd.command.lowercased().hasPrefix(input.lowercased()) {
                allSuggestions.append(CommandSuggestion(
                    command: cmd.command,
                    source: .history,
                    confidence: 0.8
                ))
            }
        }
        
        // 2. File/folder completions for local
        if !isSSH {
            let localItems = getLocalItems(in: workingDirectory, matching: input)
            for item in localItems.prefix(10) {
                allSuggestions.append(CommandSuggestion(
                    command: item,
                    source: .filesystem,
                    confidence: 0.7
                ))
            }
        }
        
        // 3. Remote items for SSH
        if isSSH {
            for item in remoteItems where item.lowercased().hasPrefix(input.lowercased()) {
                allSuggestions.append(CommandSuggestion(
                    command: item,
                    source: .filesystem,
                    confidence: 0.6
                ))
            }
        }
        
        // Remove duplicates and sort by confidence
        let uniqueSuggestions = Array(Set(allSuggestions)).sorted { $0.confidence > $1.confidence }
        
        suggestions = Array(uniqueSuggestions.prefix(8))
        showingSuggestions = !suggestions.isEmpty
        
        // Set inline prediction
        if let first = suggestions.first {
            inlinePrediction = first.command
        }
    }
    
    // MARK: - Clear
    
    func clear() {
        inlinePrediction = nil
        suggestions = []
        showingSuggestions = false
    }
    
    // MARK: - Accept
    
    func acceptInlinePrediction() -> String? {
        let prediction = inlinePrediction
        clear()
        return prediction
    }
    
    func moveSelectionUp() {
        // For UI navigation in suggestions list
    }
    
    func moveSelectionDown() {
        // For UI navigation in suggestions list
    }
    
    // MARK: - Private Methods
    
    private func getLocalItems(in directory: String, matching prefix: String) -> [String] {
        let fm = FileManager.default
        let url = URL(fileURLWithPath: directory)
        
        guard let contents = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else {
            return []
        }
        
        let lastComponent = (prefix as NSString).lastPathComponent.lowercased()
        
        return contents
            .map { $0.lastPathComponent }
            .filter { $0.lowercased().hasPrefix(lastComponent) }
            .sorted()
    }
}

// MARK: - Command Suggestion

struct CommandSuggestion: Identifiable, Hashable {
    let id = UUID()
    let command: String
    let source: SuggestionSource
    let confidence: Double
    
    enum SuggestionSource: String {
        case history
        case filesystem
        case ai
        case builtin
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(command)
    }
    
    static func == (lhs: CommandSuggestion, rhs: CommandSuggestion) -> Bool {
        return lhs.command == rhs.command
    }
}
