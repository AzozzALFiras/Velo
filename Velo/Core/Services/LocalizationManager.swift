//
//  LocalizationManager.swift
//  Velo
//
//  Manages app localization using JSON files
//  Supports dynamic language switching without app restart
//

import SwiftUI
import Foundation
import Combine

// MARK: - Localization Manager

/// Singleton manager for handling app localization
/// Loads translations from JSON files and provides localized strings
final class LocalizationManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = LocalizationManager()
    
    // MARK: - Published Properties
    
    /// Current language code (e.g., "en", "ar")
    @Published var currentLanguage: String {
        didSet {
            if oldValue != currentLanguage {
                loadTranslations()
                UserDefaults.standard.set(currentLanguage, forKey: "appLanguage")
            }
        }
    }
    
    /// Available languages with their display names
    let availableLanguages: [(code: String, name: String, nativeName: String)] = [
        ("en", "English", "English"),
        ("ar", "Arabic", "العربية"),
        ("es", "Spanish", "Español"),
        ("fr", "French", "Français"),
        ("de", "German", "Deutsch"),
        ("zh", "Chinese", "中文"),
        ("ja", "Japanese", "日本語"),
        ("ko", "Korean", "한국어"),
        ("ru", "Russian", "Русский"),
        ("pt", "Portuguese", "Português")
    ]
    
    // MARK: - Private Properties
    
    private var translations: [String: String] = [:]
    private let defaultLanguage = "en"
    
    // MARK: - Initialization
    
    private init() {
        // 1. Check for saved language preference
        if let savedLanguage = UserDefaults.standard.string(forKey: "appLanguage") {
            self.currentLanguage = savedLanguage
        } else {
            // 2. Fallback to system language if available in our supported list
            let systemLang = Locale.current.language.languageCode?.identifier ?? "en"
            let isSupported = availableLanguages.contains { $0.code == systemLang }
            self.currentLanguage = isSupported ? systemLang : defaultLanguage
            
            // Save it for future consistency
            UserDefaults.standard.set(self.currentLanguage, forKey: "appLanguage")
        }
        
        loadTranslations()
    }
    
    // MARK: - Public Methods
    
    /// Get localized string for a key
    /// - Parameter key: The translation key (e.g., "settings.title")
    /// - Returns: The localized string, or the key itself if not found
    func localized(_ key: String) -> String {
        return translations[key] ?? key
    }
    
    /// Get localized string with format arguments
    /// - Parameters:
    ///   - key: The translation key
    ///   - arguments: Format arguments to insert
    /// - Returns: The formatted localized string
    func localized(_ key: String, _ arguments: CVarArg...) -> String {
        let format = translations[key] ?? key
        return String(format: format, arguments: arguments)
    }
    
    /// Check if a language is RTL (Right-to-Left)
    /// - Parameter code: Language code
    /// - Returns: True if the language is RTL
    func isRTL(_ code: String? = nil) -> Bool {
        let lang = code ?? currentLanguage
        return lang == "ar" || lang == "he" || lang == "fa" || lang == "ur"
    }
    
    /// Get layout direction for current language
    var layoutDirection: LayoutDirection {
        return isRTL() ? .rightToLeft : .leftToRight
    }
    
    // MARK: - Private Methods
    
    /// Load translations from JSON files for current language
    private func loadTranslations() {
        // 1. Try to load current language
        if let currentTranslations = loadFiles(for: currentLanguage) {
            translations = currentTranslations
            print("[Localization] Loaded \(translations.count) keys for \(currentLanguage)")
            return
        }
        
        // 2. Fallback to default language (en)
        if currentLanguage != defaultLanguage {
            print("[Localization] Warning: Falling back to '\(defaultLanguage)'")
            if let fallbackTranslations = loadFiles(for: defaultLanguage) {
                translations = fallbackTranslations
                return
            }
        }
        
        // 3. Catastrophic fallback: use minimal hardcoded English keys to avoid empty UI
        translations = [
            "app.name": "Velo",
            "common.error": "Error",
            "common.ok": "OK"
        ]
        print("[Localization] Critical Error: Could not load any translations from bundle")
    }
    
    /// Load all segmented JSON files for a specific language
    private func loadFiles(for langCode: String) -> [String: String]? {
        let fileNames = ["common", "workspace", "settings", "terminal", "intelligence", "ssh", "git", "docker", "editor", "server", "apps", "files", "theme"]
        var mergedTranslations: [String: String] = [:]
        var foundAny = false
        
        for name in fileNames {
            // Try multiple strategies to find the localized JSON files
            let url = 
                // Strategy A: Standard Localization (Xcode handles .lproj)
                Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "Localization", localization: langCode) ??
                Bundle.main.url(forResource: name, withExtension: "json", subdirectory: nil, localization: langCode) ??
                // Strategy B: Manual path (if added as folder references)
                Bundle.main.url(forResource: "\(langCode).lproj/\(name)", withExtension: "json", subdirectory: "Localization") ??
                Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "Localization/\(langCode).lproj")
            
            if let url = url, let decoded = parseJSON(at: url) {
                mergedTranslations.merge(decoded) { (_, new) in new }
                foundAny = true
            }
        }
        
        return foundAny ? mergedTranslations : nil
    }
    
    /// Parse JSON file at URL (supports flat and nested structures if needed, but keeping it flat for now)
    private func parseJSON(at url: URL) -> [String: String]? {
        do {
            let data = try Data(contentsOf: url)
            // Use [String: Any] if we want to support nested JSON, but the current system expects [String: String]
            let decoded = try JSONDecoder().decode([String: String].self, from: data)
            return decoded
        } catch {
            print("[Localization] Error parsing JSON at \(url.lastPathComponent): \(error)")
            return nil
        }
    }
}

// MARK: - SwiftUI Extensions

/// Property wrapper for localized strings
@propertyWrapper
struct Localized: DynamicProperty {
    @ObservedObject private var manager = LocalizationManager.shared
    private let key: String
    
    init(_ key: String) {
        self.key = key
    }
    
    var wrappedValue: String {
        manager.localized(key)
    }
}

// MARK: - String Extension

extension String {
    /// Get localized version of this string key
    var localized: String {
        LocalizationManager.shared.localized(self)
    }
    
    /// Get localized string with format arguments
    func localized(_ arguments: CVarArg...) -> String {
        let format = LocalizationManager.shared.localized(self)
        return String(format: format, arguments: arguments)
    }
}

// MARK: - View Extension

extension View {
    /// Apply RTL layout direction if current language requires it
    func localizedLayout() -> some View {
        self.environment(\.layoutDirection, LocalizationManager.shared.layoutDirection)
    }
}
