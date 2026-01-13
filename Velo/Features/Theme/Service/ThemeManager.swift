//
//  ThemeManager.swift
//  Velo
//
//  AI-Powered Terminal - Theme Management Service
//

import SwiftUI
import Combine

// MARK: - Theme Manager
@MainActor
final class ThemeManager: ObservableObject {
    
    // MARK: - Published State
    @Published private(set) var currentTheme: VeloTheme
    @Published private(set) var customThemes: [VeloTheme] = []
    @Published private(set) var allThemes: [VeloTheme] = []
    
    // MARK: - Thread-Safe Access
    nonisolated(unsafe) private var _currentThemeSnapshot: VeloTheme?
    
    nonisolated var currentThemeSnapshot: VeloTheme {
        _currentThemeSnapshot ?? .neonDark
    }
    
    // MARK: - Storage
    private let storageURL: URL
    private let currentThemeKey = "selectedThemeId"
    
    // MARK: - Init
    init() {
        // Setup storage location
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let veloDir = appSupport.appendingPathComponent("Velo", isDirectory: true)
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: veloDir, withIntermediateDirectories: true)
        
        self.storageURL = veloDir.appendingPathComponent("themes.json")
        
        // Load custom themes
        let loadedCustomThemes = Self.loadCustomThemes(from: self.storageURL)
        self.customThemes = loadedCustomThemes
        
        // Combine all themes
        self.allThemes = VeloTheme.allBuiltInThemes + loadedCustomThemes
        
        // Load selected theme
        if let savedThemeId = UserDefaults.standard.string(forKey: currentThemeKey),
           let savedThemeUUID = UUID(uuidString: savedThemeId),
           let theme = (VeloTheme.allBuiltInThemes + loadedCustomThemes).first(where: { $0.id == savedThemeUUID }) {
            self.currentTheme = theme
            self._currentThemeSnapshot = theme
        } else {
            // Default to Neon Dark
            self.currentTheme = .neonDark
            self._currentThemeSnapshot = .neonDark
        }
    }
    
    // MARK: - Theme Switching
    func setTheme(_ theme: VeloTheme) {
        currentTheme = theme
        _currentThemeSnapshot = theme
        UserDefaults.standard.set(theme.id.uuidString, forKey: currentThemeKey)
        objectWillChange.send()
    }
    
    // MARK: - Custom Theme Management
    func createCustomTheme(name: String, basedOn baseTheme: VeloTheme? = nil) -> VeloTheme {
        let base = baseTheme ?? currentTheme
        let newTheme = VeloTheme(
            name: name,
            isBuiltIn: false,
            colorScheme: base.colorScheme,
            fontScheme: base.fontScheme
        )
        
        customThemes.append(newTheme)
        allThemes = VeloTheme.allBuiltInThemes + customThemes
        saveCustomThemes()
        
        return newTheme
    }
    
    func updateCustomTheme(_ theme: VeloTheme) {
        guard !theme.isBuiltIn else { return }
        
        if let index = customThemes.firstIndex(where: { $0.id == theme.id }) {
            customThemes[index] = theme
            allThemes = VeloTheme.allBuiltInThemes + customThemes
            
            // Update current theme if it's the one being edited
            if currentTheme.id == theme.id {
                currentTheme = theme
            }
            
            saveCustomThemes()
        }
    }
    
    func deleteCustomTheme(_ theme: VeloTheme) {
        guard !theme.isBuiltIn else { return }
        
        customThemes.removeAll { $0.id == theme.id }
        allThemes = VeloTheme.allBuiltInThemes + customThemes
        
        // Switch to default if deleting current theme
        if currentTheme.id == theme.id {
            setTheme(.neonDark)
        }
        
        saveCustomThemes()
    }
    
    // MARK: - Import/Export
    func exportTheme(_ theme: VeloTheme) -> Data? {
        try? JSONEncoder().encode(theme)
    }
    
    func importTheme(from data: Data) throws -> VeloTheme {
        let theme = try JSONDecoder().decode(VeloTheme.self, from: data)
        
        // Create new theme with unique ID and name
        let importedTheme = VeloTheme(
            id: UUID(),
            name: theme.name + " (Imported)",
            isBuiltIn: false,
            colorScheme: theme.colorScheme,
            fontScheme: theme.fontScheme
        )
        
        customThemes.append(importedTheme)
        allThemes = VeloTheme.allBuiltInThemes + customThemes
        saveCustomThemes()
        
        return importedTheme
    }
    
    // MARK: - Persistence
    private func saveCustomThemes() {
        do {
            let data = try JSONEncoder().encode(customThemes)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            print("Failed to save custom themes: \(error)")
        }
    }
    
    private static func loadCustomThemes(from url: URL) -> [VeloTheme] {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let themes = try? JSONDecoder().decode([VeloTheme].self, from: data) else {
            return []
        }
        return themes
    }
}

// MARK: - Environment Key
@MainActor
struct ThemeManagerKey: EnvironmentKey {
    static let defaultValue = {
        let manager = ThemeManager()
        VeloDesign.ThemeAware.themeManager = manager
        return manager
    }()
}

extension EnvironmentValues {
    var themeManager: ThemeManager {
        get { self[ThemeManagerKey.self] }
        set { self[ThemeManagerKey.self] = newValue }
    }
}
