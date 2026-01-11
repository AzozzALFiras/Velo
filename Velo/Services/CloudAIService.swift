//
//  CloudAIService.swift
//  Velo
//
//  Created by Velo AI
//

import Foundation
import SwiftUI
import Combine

// MARK: - Models
struct AIChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date
    
    enum Role: String, Codable {
        case user
        case assistant
        case system
    }
    
    init(role: Role, content: String) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}

// MARK: - Service
class CloudAIService: ObservableObject {
    @MainActor @Published var messages: [AIChatMessage] = []
    @MainActor @Published var isThinking = false
    @MainActor @Published var errorMessage: String?
    
    // Dependencies (Settings)
    @AppStorage("selectedAIProvider") private var selectedProviderName = "OpenAI"
    @AppStorage("openaiApiKey") private var openaiKey = ""
    @AppStorage("anthropicApiKey") private var anthropicKey = ""
    @AppStorage("deepseekApiKey") private var deepseekKey = ""
    
    private let urlSession = URLSession.shared
    
    // MARK: - Actions
    
    @MainActor
    func sendMessage(_ text: String) async {
        let userMsg = AIChatMessage(role: .user, content: text)
        messages.append(userMsg)
        isThinking = true
        errorMessage = nil
        
        do {
            let response = try await fetchResponse(history: messages)
            let aiMsg = AIChatMessage(role: .assistant, content: response)
            messages.append(aiMsg)
        } catch {
            errorMessage = error.localizedDescription
            print("AI Error: \(error)")
        }
        
        isThinking = false
    }
    
    @MainActor
    func clearHistory() {
        messages = []
        errorMessage = nil
    }
    
    // MARK: - API Logic
    
    private func fetchResponse(history: [AIChatMessage]) async throws -> String {
        guard let provider = Provider(rawValue: selectedProviderName) else {
            throw AIError.unknownProvider
        }
        
        let apiKey = getApiKey(for: provider)
        if apiKey.isEmpty {
            throw AIError.missingApiKey(provider.rawValue)
        }
        
        // Prepare Request
        var request = URLRequest(url: provider.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any]
        
        switch provider {
        case .openai, .deepseek:
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            
            let systemPrompt = generateSystemPrompt()
            
            var apiMessages: [[String: String]] = [
                ["role": "system", "content": systemPrompt]
            ]
            
            apiMessages.append(contentsOf: history.map { msg in
                ["role": msg.role.rawValue, "content": msg.content]
            })
            
            body = [
                "model": provider.model,
                "messages": apiMessages,
                "temperature": 0.7
            ]
            
        case .anthropic:
            request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            
            let systemPrompt = generateSystemPrompt()
            
            let apiMessages = history.map { msg in
                ["role": msg.role.rawValue, "content": msg.content]
            }
            
            body = [
                "model": provider.model,
                "system": systemPrompt,
                "messages": apiMessages,
                "max_tokens": 1024
            ]
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // Execute
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.networkError
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIError.apiError(code: httpResponse.statusCode, message: errorBody)
        }
        
        // Parse Response
        if provider == .anthropic {
            // Anthropic response format
            struct AnthropicResponse: Decodable {
                struct Content: Decodable { var text: String }
                var content: [Content]
            }
            let result = try JSONDecoder().decode(AnthropicResponse.self, from: data)
            return result.content.first?.text ?? ""
        } else {
            // OpenAI/DeepSeek response format
            struct OpenAIResponse: Decodable {
                struct Choice: Decodable {
                    struct Message: Decodable { var content: String }
                    var message: Message
                }
                var choices: [Choice]
            }
            let result = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            return result.choices.first?.message.content ?? ""
        }
    }
    
    private func getApiKey(for provider: Provider) -> String {
        switch provider {
        case .openai: return openaiKey
        case .anthropic: return anthropicKey
        case .deepseek: return deepseekKey
        }
    }
    
    private func generateSystemPrompt() -> String {
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        let cores = ProcessInfo.processInfo.processorCount
        let ram = ProcessInfo.processInfo.physicalMemory / 1024 / 1024 / 1024
        
        return """
        You are Velo, an intelligent AI terminal assistant running on macOS.
        System Info: macOS \(os), \(cores) Cores, \(ram)GB RAM.
        
        Guidelines:
        - Provide concise, technical, and helpful answers.
        - ALWAYS format shell commands in markdown code blocks (```bash ... ```) so the user can run them easily.
        - If listing separate commands, put them in separate blocks.
        - Be expert-level for git, unix, and coding tasks.
        """
    }

    // MARK: - Enums
    
    private enum Provider: String {
        case openai = "OpenAI"
        case anthropic = "Anthropic"
        case deepseek = "DeepSeek"
        
        var endpoint: URL {
            switch self {
            case .openai: return URL(string: "https://api.openai.com/v1/chat/completions")!
            case .anthropic: return URL(string: "https://api.anthropic.com/v1/messages")!
            case .deepseek: return URL(string: "https://api.deepseek.com/chat/completions")!
            }
        }
        
        var model: String {
            switch self {
            case .openai: return "gpt-4-turbo-preview"
            case .anthropic: return "claude-3-opus-20240229"
            case .deepseek: return "deepseek-chat"
            }
        }
    }
    
    enum AIError: LocalizedError {
        case unknownProvider
        case missingApiKey(String)
        case networkError
        case apiError(code: Int, message: String)
        
        var errorDescription: String? {
            switch self {
            case .unknownProvider: return "Unknown AI Provider selected."
            case .missingApiKey(let p): return "Missing API Key for \(p). Please check Settings."
            case .networkError: return "Network connection failed."
            case .apiError(let c, let m): return "API Error (\(c)): \(m)"
            }
        }
    }
}
