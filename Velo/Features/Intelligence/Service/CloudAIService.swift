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
    // Singleton
    static let shared = CloudAIService()

    @MainActor @Published var messages: [AIChatMessage] = []
    @MainActor @Published var isThinking = false
    @MainActor @Published var errorMessage: String?
    @MainActor @Published var availableModels: [AIModelConfig] = []

    // Dependencies (Settings)
    @AppStorage("selectedAIProvider") private var selectedProviderId = "openai"

    private let urlSession = URLSession.shared
    private let keychainService = KeychainService.shared

    private init() {
        Task {
            await loadModels()
        }
    }
    
    // MARK: - Actions
    
    @MainActor
    func loadModels() async {
        do {
            let models = try await ApiService.shared.fetchAIModels()
            self.availableModels = models
        } catch {
            print("Failed to load AI models: \(error)")
            // Fallback to minimal defaults if API fails
            self.availableModels = [
                AIModelConfig(id: "openai", name: "OpenAI", endpoint: "https://api.openai.com/v1/chat/completions", model: "gpt-4-turbo-preview", description: ""),
                AIModelConfig(id: "anthropic", name: "Anthropic", endpoint: "https://api.anthropic.com/v1/messages", model: "claude-3-opus-20240229", description: ""),
                AIModelConfig(id: "deepseek", name: "DeepSeek", endpoint: "https://api.deepseek.com/chat/completions", model: "deepseek-chat", description: "")
            ]
        }
    }
    
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
        guard let config = await MainActor.run(body: { availableModels.first { $0.id == selectedProviderId } }) else {
            throw AIError.unknownProvider
        }
        
        guard let provider = ProviderFlavor(rawValue: config.id) else {
            throw AIError.unknownProvider
        }
        
        let apiKey = getApiKey(for: provider)
        if apiKey.isEmpty {
            throw AIError.missingApiKey(config.name)
        }
        
        // Prepare Request
        guard let url = URL(string: config.endpoint) else {
            throw AIError.networkError
        }
        
        var request = URLRequest(url: url)
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
                "model": config.model,
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
                "model": config.model,
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
            struct AnthropicResponse: Decodable {
                struct Content: Decodable { var text: String }
                var content: [Content]
            }
            let result = try JSONDecoder().decode(AnthropicResponse.self, from: data)
            return result.content.first?.text ?? ""
        } else {
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
    
    private func getApiKey(for provider: ProviderFlavor) -> String {
        let key: KeychainService.KeychainKey
        switch provider {
        case .openai: key = .openaiAPIKey
        case .anthropic: key = .anthropicAPIKey
        case .deepseek: key = .deepseekAPIKey
        }

        do {
            return try keychainService.retrieve(key: key) ?? ""
        } catch {
            print("Failed to retrieve API key for \(provider): \(error)")
            return ""
        }
    }

    // MARK: - API Key Management

    /// Save an API key to Keychain
    @MainActor
    func saveApiKey(for provider: String, key: String) throws {
        let keychainKey: KeychainService.KeychainKey
        switch provider {
        case "openai": keychainKey = .openaiAPIKey
        case "anthropic": keychainKey = .anthropicAPIKey
        case "deepseek": keychainKey = .deepseekAPIKey
        default: throw AIError.unknownProvider
        }

        try keychainService.save(key: keychainKey, value: key)
    }

    /// Retrieve an API key from Keychain
    @MainActor
    func getApiKey(for provider: String) -> String {
        let keychainKey: KeychainService.KeychainKey
        switch provider {
        case "openai": keychainKey = .openaiAPIKey
        case "anthropic": keychainKey = .anthropicAPIKey
        case "deepseek": keychainKey = .deepseekAPIKey
        default: return ""
        }

        do {
            return try keychainService.retrieve(key: keychainKey) ?? ""
        } catch {
            print("Failed to retrieve API key: \(error)")
            return ""
        }
    }

    /// Delete an API key from Keychain
    @MainActor
    func deleteApiKey(for provider: String) throws {
        let keychainKey: KeychainService.KeychainKey
        switch provider {
        case "openai": keychainKey = .openaiAPIKey
        case "anthropic": keychainKey = .anthropicAPIKey
        case "deepseek": keychainKey = .deepseekAPIKey
        default: throw AIError.unknownProvider
        }

        try keychainService.delete(key: keychainKey)
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
    
    private enum ProviderFlavor: String {
        case openai
        case anthropic
        case deepseek
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
