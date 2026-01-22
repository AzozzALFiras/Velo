//
//  ValidationService.swift
//  Velo
//
//  Input validation for settings and forms
//

import Foundation

enum ValidationService {

    // MARK: - Validation Result

    enum ValidationResult {
        case success(String)
        case warning(String)
        case error(String)

        var isValid: Bool {
            if case .error = self {
                return false
            }
            return true
        }

        var message: String {
            switch self {
            case .success(let msg): return msg
            case .warning(let msg): return msg
            case .error(let msg): return msg
            }
        }
    }

    // MARK: - API Key Validation Strategy
    
    /// Strategy protocol for API key validation
    private protocol APIKeyValidator {
        func validate(_ key: String) -> ValidationResult
    }
    
    // Concrete strategies
    private struct OpenAIValidator: APIKeyValidator {
        func validate(_ key: String) -> ValidationResult {
            guard key.hasPrefix("sk-") else { return .error("OpenAI keys should start with 'sk-'") }
            guard key.count > 20 else { return .error("OpenAI key appears too short") }
            if key.count > 200 { return .warning("API key seems unusually long") }
            return .success("API key format is valid")
        }
    }
    
    private struct AnthropicValidator: APIKeyValidator {
        func validate(_ key: String) -> ValidationResult {
            guard key.hasPrefix("sk-ant-") else { return .error("Anthropic keys should start with 'sk-ant-'") }
            guard key.count > 20 else { return .error("Anthropic key appears too short") }
            return .success("API key format is valid")
        }
    }
    
    private struct DeepSeekValidator: APIKeyValidator {
        func validate(_ key: String) -> ValidationResult {
            guard key.hasPrefix("sk-") else { return .error("DeepSeek keys should start with 'sk-'") }
            guard key.count > 20 else { return .error("DeepSeek key appears too short") }
            return .success("API key format is valid")
        }
    }
    
    private struct DefaultValidator: APIKeyValidator {
        func validate(_ key: String) -> ValidationResult {
            guard key.count > 10 else { return .error("API key appears too short") }
            return .success("API key format is valid")
        }
    }
    
    // Registry
    private static let validators: [String: APIKeyValidator] = [
        "openai": OpenAIValidator(),
        "anthropic": AnthropicValidator(),
        "deepseek": DeepSeekValidator()
    ]

    /// Validate API key format for different providers (Open/Closed Principle)
    static func validateAPIKey(key: String, provider: String) -> ValidationResult {
        // Empty check
        guard !key.isEmpty else { return .error("API key cannot be empty") }
        
        // Whitespace check
        if key.contains(" ") || key.contains("\t") || key.contains("\n") {
            return .error("API key contains invalid whitespace")
        }
        
        // Use strategy
        let validator = validators[provider.lowercased()] ?? DefaultValidator()
        return validator.validate(key)
    }

    // MARK: - SSH Connection Validation

    /// Validate SSH connection parameters
    static func validateSSHConnection(host: String, port: Int, username: String) -> ValidationResult {
        // Host validation
        guard !host.isEmpty else {
            return .error("Host cannot be empty")
        }

        if host.contains(" ") {
            return .warning("Host contains spaces - is this correct?")
        }

        // Check for localhost variations
        if host == "localhost" || host == "127.0.0.1" {
            // Valid but worth noting
        }

        // Port validation
        guard port > 0 && port <= 65535 else {
            return .error("Port must be between 1 and 65535")
        }

        if port != 22 {
            return .warning("Non-standard SSH port \(port)")
        }

        // Username validation
        guard !username.isEmpty else {
            return .error("Username cannot be empty")
        }

        if username.contains(" ") {
            return .error("Username cannot contain spaces")
        }

        return .success("Connection details are valid")
    }

    // MARK: - Theme Validation

    /// Validate theme name
    static func validateThemeName(_ name: String) -> ValidationResult {
        guard !name.isEmpty else {
            return .error("Theme name cannot be empty")
        }

        guard name.count <= 50 else {
            return .error("Theme name must be 50 characters or less")
        }

        // Check for invalid characters
        let invalidChars = CharacterSet(charactersIn: "/\\:*?\"<>|")
        if name.rangeOfCharacter(from: invalidChars) != nil {
            return .error("Theme name contains invalid characters")
        }

        return .success("Theme name is valid")
    }

    // MARK: - Color Hex Validation

    /// Validate hex color format
    static func validateHexColor(_ hex: String) -> ValidationResult {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)

        guard cleaned.count == 3 || cleaned.count == 6 || cleaned.count == 8 else {
            return .error("Hex color must be 3, 6, or 8 characters")
        }

        // Check if all characters are valid hex digits
        let hexSet = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
        guard cleaned.rangeOfCharacter(from: hexSet.inverted) == nil else {
            return .error("Invalid hex color format")
        }

        return .success("Valid hex color")
    }
}
