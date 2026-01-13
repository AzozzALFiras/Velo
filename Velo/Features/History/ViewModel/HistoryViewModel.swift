//
//  HistoryViewModel.swift
//  Velo
//
//  AI-Powered Terminal - History Panel ViewModel
//

import SwiftUI
import Combine

// MARK: - History ViewModel
/// ViewModel for the command history wall panel
@MainActor
final class HistoryViewModel: ObservableObject {
    
    // MARK: - Published State
    @Published var searchQuery: String = ""
    @Published var searchResults: [CommandModel] = []
    @Published var selectedSection: HistorySection = .recent
    @Published var selectedCommand: CommandModel?
    @Published var isSearching: Bool = false
    @Published var commandExplanation: CommandExplanation?
    
    // MARK: - Dependencies
    let historyManager: CommandHistoryManager
    private let analyzer = CommandAnalyzer.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var displayedCommands: [CommandModel] {
        if isSearching && !searchQuery.isEmpty {
            return searchResults
        }
        
        switch selectedSection {
        case .recent:
            return historyManager.recentCommands
        case .frequent:
            return historyManager.frequentCommands
        case .sessions:
            return historyManager.currentSession?.commands ?? []
        }
    }
    
    // MARK: - Init
    init(historyManager: CommandHistoryManager) {
        self.historyManager = historyManager
        setupSearch()
    }
    
    // MARK: - Search
    private func setupSearch() {
        $searchQuery
            .debounce(for: .milliseconds(150), scheduler: DispatchQueue.main)
            .sink { [weak self] query in
                guard let self = self else { return }
                self.isSearching = !query.isEmpty
                
                if query.isEmpty {
                    self.searchResults = []
                } else {
                    self.searchResults = self.historyManager.fuzzySearch(query: query, limit: 20)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Select Section
    func selectSection(_ section: HistorySection) {
        selectedSection = section
        searchQuery = ""
        isSearching = false
    }
    
    // MARK: - Select Command
    func selectCommand(_ command: CommandModel) {
        selectedCommand = command
    }
    
    // MARK: - Explain Command
    func explainCommand(_ command: CommandModel) {
        commandExplanation = analyzer.explain(command.command)
    }
    
    // MARK: - Clear Explanation
    func clearExplanation() {
        commandExplanation = nil
    }
    
    // MARK: - Session Groups
    var sessionGroups: [SessionGroup] {
        let calendar = Calendar.current
        var groups: [Date: [SessionModel]] = [:]
        
        for session in historyManager.sessions {
            let dayStart = calendar.startOfDay(for: session.startTime)
            groups[dayStart, default: []].append(session)
        }
        
        return groups.map { SessionGroup(date: $0.key, sessions: $0.value) }
            .sorted { $0.date > $1.date }
    }
    
    // MARK: - Statistics
    var todayCommandCount: Int {
        historyManager.commandsToday()
    }
    
    var totalCommandCount: Int {
        historyManager.totalCommandCount
    }
}

// MARK: - History Section
enum HistorySection: String, CaseIterable, Identifiable {
    case recent = "Recent"
    case frequent = "Frequent"
    case sessions = "Sessions"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .recent: return "clock"
        case .frequent: return "flame"
        case .sessions: return "folder"
        }
    }
}
