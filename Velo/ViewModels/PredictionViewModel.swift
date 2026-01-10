//
//  PredictionViewModel.swift
//  Velo
//
//  AI-Powered Terminal - Prediction/Autocomplete ViewModel
//

import SwiftUI
import Combine

// MARK: - Prediction ViewModel
/// ViewModel for prediction dropdown and inline suggestions
@MainActor
final class PredictionViewModel: ObservableObject {
    
    // MARK: - Published State
    @Published var showingSuggestions: Bool = false
    @Published var selectedSuggestionIndex: Int = 0
    @Published var hoveredSuggestion: CommandSuggestion?
    
    // MARK: - Dependencies
    let predictionEngine: PredictionEngine
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var suggestions: [CommandSuggestion] {
        predictionEngine.suggestions
    }
    
    var inlinePrediction: String? {
        predictionEngine.inlinePrediction
    }
    
    var selectedSuggestion: CommandSuggestion? {
        guard selectedSuggestionIndex < suggestions.count else { return nil }
        return suggestions[selectedSuggestionIndex]
    }
    
    // MARK: - Init
    init(predictionEngine: PredictionEngine) {
        self.predictionEngine = predictionEngine
        setupBindings()
    }
    
    // MARK: - Navigation
    func moveSelectionUp() {
        guard !suggestions.isEmpty else { return }
        
        if selectedSuggestionIndex > 0 {
            selectedSuggestionIndex -= 1
        } else {
            selectedSuggestionIndex = suggestions.count - 1
        }
    }
    
    func moveSelectionDown() {
        guard !suggestions.isEmpty else { return }
        
        if selectedSuggestionIndex < suggestions.count - 1 {
            selectedSuggestionIndex += 1
        } else {
            selectedSuggestionIndex = 0
        }
    }
    
    func resetSelection() {
        selectedSuggestionIndex = 0
    }
    
    // MARK: - Show/Hide
    func show() {
        showingSuggestions = true
    }
    
    func hide() {
        showingSuggestions = false
        resetSelection()
    }
    
    func toggle() {
        if showingSuggestions {
            hide()
        } else {
            show()
        }
    }
    
    // MARK: - Private
    private func setupBindings() {
        // Show suggestions when available and hide when empty
        predictionEngine.$suggestions
            .sink { [weak self] suggestions in
                guard let self = self else { return }
                self.showingSuggestions = !suggestions.isEmpty
                
                // Reset selection if it's out of bounds
                if self.selectedSuggestionIndex >= suggestions.count {
                    self.selectedSuggestionIndex = 0
                }
            }
            .store(in: &cancellables)
    }
}
