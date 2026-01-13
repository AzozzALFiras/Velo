//
//  CommandHistoryManager.swift
//  Velo
//
//  AI-Powered Terminal - Command History & Persistence
//

import Foundation
import Combine

// MARK: - Command History Manager
/// Manages persistent command history with search and analytics
@MainActor
final class CommandHistoryManager: ObservableObject {
    
    // MARK: - Published State
    @Published private(set) var recentCommands: [CommandModel] = []
    @Published private(set) var frequentCommands: [CommandModel] = []
    @Published private(set) var sessions: [SessionModel] = []
    @Published private(set) var currentSession: SessionModel?
    
    // MARK: - Private Properties
    private let storageURL: URL
    private let maxHistorySize = 10000
    private var allCommands: [CommandModel] = []
    private var frequencyMap: [String: Int] = [:]
    
    // MARK: - Init
    init() {
        // Setup storage location
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let veloDir = appSupport.appendingPathComponent("Velo", isDirectory: true)
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: veloDir, withIntermediateDirectories: true)
        
        self.storageURL = veloDir.appendingPathComponent("history.json")
        
        // Load existing history
        Task {
            await loadHistory()
            startNewSession()
        }
    }
    
    // MARK: - Add Command
    func addCommand(_ command: CommandModel) {
        // Update all commands
        allCommands.insert(command, at: 0)
        
        // Limit history size
        if allCommands.count > maxHistorySize {
            allCommands = Array(allCommands.prefix(maxHistorySize))
        }
        
        // Update frequency
        let normalizedCommand = normalizeCommand(command.command)
        frequencyMap[normalizedCommand, default: 0] += 1
        
        // Update current session
        if var session = currentSession {
            session.commands.append(command)
            currentSession = session
        }
        
        // Update published arrays
        updatePublishedArrays()
        
        // Persist
        Task {
            await saveHistory()
        }
    }
    
    // MARK: - Search
    func search(query: String, limit: Int = 50) -> [CommandModel] {
        guard !query.isEmpty else { return recentCommands }
        
        let lowercasedQuery = query.lowercased()
        
        return allCommands
            .filter { $0.command.lowercased().contains(lowercasedQuery) }
            .prefix(limit)
            .map { $0 }
    }
    
    // MARK: - Fuzzy Search
    func fuzzySearch(query: String, limit: Int = 10) -> [CommandModel] {
        guard !query.isEmpty else { return [] }
        
        let lowercasedQuery = query.lowercased()
        
        // Score commands by match quality
        let scored = allCommands.compactMap { command -> (CommandModel, Double)? in
            let score = fuzzyScore(command.command.lowercased(), query: lowercasedQuery)
            return score > 0 ? (command, score) : nil
        }
        
        return scored
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map { $0.0 }
    }
    
    // MARK: - Get by Context
    func commands(forContext context: CommandContext, limit: Int = 20) -> [CommandModel] {
        return allCommands
            .filter { $0.context == context }
            .prefix(limit)
            .map { $0 }
    }
    
    // MARK: - Session Management
    func startNewSession() {
        // End current session
        if var session = currentSession {
            session.endTime = Date()
            session.isActive = false
            session.detectContext()
            sessions.insert(session, at: 0)
        }
        
        // Start new session
        currentSession = SessionModel(
            workingDirectory: FileManager.default.currentDirectoryPath
        )
    }
    
    // MARK: - Clear History
    func clearHistory() {
        allCommands.removeAll()
        frequencyMap.removeAll()
        recentCommands.removeAll()
        frequentCommands.removeAll()
        sessions.removeAll()
        
        Task {
            await saveHistory()
        }
    }
    
    // MARK: - Get Command by ID
    func command(withId id: UUID) -> CommandModel? {
        return allCommands.first { $0.id == id }
    }
    
    // MARK: - Statistics
    var totalCommandCount: Int { allCommands.count }
    var uniqueCommandCount: Int { frequencyMap.count }
    
    func commandsToday() -> Int {
        let calendar = Calendar.current
        return allCommands.filter { calendar.isDateInToday($0.timestamp) }.count
    }
    
    // MARK: - Private Methods
    private func updatePublishedArrays() {
        // Recent: last 20 unique commands
        var seen = Set<String>()
        recentCommands = allCommands.filter { command in
            let normalized = normalizeCommand(command.command)
            if seen.contains(normalized) { return false }
            seen.insert(normalized)
            return true
        }.prefix(20).map { $0 }
        
        // Frequent: top 15 by frequency
        let sortedByFrequency = allCommands
            .reduce(into: [String: CommandModel]()) { result, command in
                let normalized = normalizeCommand(command.command)
                if result[normalized] == nil {
                    result[normalized] = command
                }
            }
            .values
            .sorted { frequencyMap[normalizeCommand($0.command), default: 0] > 
                     frequencyMap[normalizeCommand($1.command), default: 0] }
        
        frequentCommands = Array(sortedByFrequency.prefix(15))
    }
    
    private func normalizeCommand(_ command: String) -> String {
        // Remove extra whitespace, normalize for grouping
        return command.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
    
    private func fuzzyScore(_ text: String, query: String) -> Double {
        var score: Double = 0
        var textIndex = text.startIndex
        var queryIndex = query.startIndex
        var consecutiveMatches = 0
        
        while textIndex < text.endIndex && queryIndex < query.endIndex {
            if text[textIndex] == query[queryIndex] {
                score += 1 + Double(consecutiveMatches) * 0.5
                consecutiveMatches += 1
                queryIndex = query.index(after: queryIndex)
            } else {
                consecutiveMatches = 0
            }
            textIndex = text.index(after: textIndex)
        }
        
        // Bonus for starting match
        if text.hasPrefix(query) {
            score *= 2
        }
        
        // Only count if all query characters were found
        return queryIndex == query.endIndex ? score : 0
    }
    
    // MARK: - Persistence
    private func loadHistory() async {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        
        do {
            let data = try Data(contentsOf: storageURL)
            let decoded = try JSONDecoder().decode(HistoryData.self, from: data)
            
            allCommands = decoded.commands
            frequencyMap = decoded.frequencyMap
            sessions = decoded.sessions
            
            updatePublishedArrays()
        } catch {
            print("Failed to load history: \(error)")
        }
    }
    
    private func saveHistory() async {
        let data = HistoryData(
            commands: allCommands,
            frequencyMap: frequencyMap,
            sessions: sessions
        )
        
        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: storageURL, options: .atomic)
        } catch {
            print("Failed to save history: \(error)")
        }
    }
}

// MARK: - History Data
private struct HistoryData: Codable {
    let commands: [CommandModel]
    let frequencyMap: [String: Int]
    let sessions: [SessionModel]
}
