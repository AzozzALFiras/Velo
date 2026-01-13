//
//  KeychainService.swift
//  Velo
//
//  Secure credential storage using macOS Keychain
//

import Foundation
import Security

@MainActor
final class KeychainService {
    static let shared = KeychainService()

    private init() {}

    enum KeychainKey: String {
        case openaiAPIKey = "dev.3zozz.velo.openai"
        case anthropicAPIKey = "dev.3zozz.velo.anthropic"
        case deepseekAPIKey = "dev.3zozz.velo.deepseek"

        var displayName: String {
            switch self {
            case .openaiAPIKey: return "OpenAI API Key"
            case .anthropicAPIKey: return "Anthropic API Key"
            case .deepseekAPIKey: return "DeepSeek API Key"
            }
        }
    }

    enum KeychainError: Error, LocalizedError {
        case saveFailed(OSStatus)
        case retrieveFailed(OSStatus)
        case deleteFailed(OSStatus)
        case encodingFailed
        case decodingFailed

        var errorDescription: String? {
            switch self {
            case .saveFailed(let status):
                return "Failed to save to Keychain (status: \(status))"
            case .retrieveFailed(let status):
                return "Failed to retrieve from Keychain (status: \(status))"
            case .deleteFailed(let status):
                return "Failed to delete from Keychain (status: \(status))"
            case .encodingFailed:
                return "Failed to encode data"
            case .decodingFailed:
                return "Failed to decode data"
            }
        }
    }

    // MARK: - Public API

    /// Save a string value to the Keychain
    /// - Parameters:
    ///   - key: The keychain key to store under
    ///   - value: The string value to store
    /// - Throws: KeychainError if the operation fails
    func save(key: KeychainKey, value: String) throws {
        guard let data = value.data(using: .utf8) else {
            throw KeychainError.encodingFailed
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
        ]

        // Delete any existing item first
        SecItemDelete(query as CFDictionary)

        // Add the new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    /// Retrieve a string value from the Keychain
    /// - Parameter key: The keychain key to retrieve
    /// - Returns: The stored string value, or nil if not found
    /// - Throws: KeychainError if the operation fails
    func retrieve(key: KeychainKey) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        // Item not found is not an error - just return nil
        guard status != errSecItemNotFound else {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainError.retrieveFailed(status)
        }

        guard let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.decodingFailed
        }

        return string
    }

    /// Delete a value from the Keychain
    /// - Parameter key: The keychain key to delete
    /// - Throws: KeychainError if the operation fails
    func delete(key: KeychainKey) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue
        ]

        let status = SecItemDelete(query as CFDictionary)

        // Not finding the item is not an error
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    /// Check if a key exists in the Keychain
    /// - Parameter key: The keychain key to check
    /// - Returns: true if the key exists, false otherwise
    func exists(key: KeychainKey) -> Bool {
        do {
            return try retrieve(key: key) != nil
        } catch {
            return false
        }
    }

    /// Migrate API keys from UserDefaults to Keychain
    /// This should be called once during app upgrade to transition from insecure to secure storage
    /// - Returns: A dictionary of migration results (key: success/failure)
    func migrateFromUserDefaults() -> [String: Bool] {
        var results: [String: Bool] = [:]

        let migrations: [(key: KeychainKey, userDefaultsKey: String)] = [
            (.openaiAPIKey, "openaiApiKey"),
            (.anthropicAPIKey, "anthropicApiKey"),
            (.deepseekAPIKey, "deepseekApiKey")
        ]

        for migration in migrations {
            // Check if already migrated
            if exists(key: migration.key) {
                results[migration.key.rawValue] = true
                continue
            }

            // Try to read from UserDefaults
            guard let value = UserDefaults.standard.string(forKey: migration.userDefaultsKey),
                  !value.isEmpty else {
                results[migration.key.rawValue] = true // Nothing to migrate
                continue
            }

            // Migrate to Keychain
            do {
                try save(key: migration.key, value: value)
                // Delete from UserDefaults after successful migration
                UserDefaults.standard.removeObject(forKey: migration.userDefaultsKey)
                results[migration.key.rawValue] = true
            } catch {
                print("Failed to migrate \(migration.key.displayName): \(error.localizedDescription)")
                results[migration.key.rawValue] = false
            }
        }

        return results
    }
}

// MARK: - Convenience Extensions

extension KeychainService {
    /// Batch save multiple keys
    func saveMultiple(_ values: [KeychainKey: String]) throws {
        for (key, value) in values {
            try save(key: key, value: value)
        }
    }

    /// Batch retrieve multiple keys
    func retrieveMultiple(_ keys: [KeychainKey]) throws -> [KeychainKey: String] {
        var results: [KeychainKey: String] = [:]
        for key in keys {
            if let value = try retrieve(key: key) {
                results[key] = value
            }
        }
        return results
    }

    /// Delete all Velo API keys from Keychain
    func deleteAll() throws {
        try delete(key: .openaiAPIKey)
        try delete(key: .anthropicAPIKey)
        try delete(key: .deepseekAPIKey)
    }
}
