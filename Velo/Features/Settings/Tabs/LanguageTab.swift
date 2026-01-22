//
//  LanguageTab.swift
//  Velo
//
//  Language settings tab for selecting app language
//

import SwiftUI

struct LanguageTab: View {
    @StateObject private var localization = LocalizationManager.shared
    @AppStorage("appLanguage") private var appLanguage = "en"
    
    var body: some View {
        VStack(alignment: .leading, spacing: VeloDesign.Spacing.xl) {
            // Header
            VStack(alignment: .leading, spacing: VeloDesign.Spacing.xs) {
                Text("language.title".localized)
                    .font(TypographyTokens.displayMd)
                    .foregroundColor(ColorTokens.textPrimary)
                
                Text("language.subtitle".localized)
                    .font(TypographyTokens.bodySm)
                    .foregroundColor(ColorTokens.textSecondary)
            }
            
            // Current Language
            VStack(alignment: .leading, spacing: VeloDesign.Spacing.md) {
                SectionHeader(title: "language.current".localized)
                
                HStack(spacing: VeloDesign.Spacing.md) {
                    Image(systemName: "globe")
                        .font(.system(size: 24))
                        .foregroundColor(ColorTokens.accentPrimary)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        if let current = localization.availableLanguages.first(where: { $0.code == localization.currentLanguage }) {
                            Text(current.name)
                                .font(TypographyTokens.body)
                                .foregroundColor(ColorTokens.textPrimary)
                            
                            Text(current.nativeName)
                                .font(TypographyTokens.bodySm)
                                .foregroundColor(ColorTokens.textSecondary)
                        }
                    }
                    
                    Spacer()
                }
                .padding(VeloDesign.Spacing.md)
                .elevated(.low)
            }
            
            // Available Languages
            VStack(alignment: .leading, spacing: VeloDesign.Spacing.md) {
                SectionHeader(title: "language.available".localized)
                
                VStack(spacing: 0) {
                    ForEach(localization.availableLanguages, id: \.code) { language in
                        LanguageRow(
                            code: language.code,
                            name: language.name,
                            nativeName: language.nativeName,
                            isSelected: localization.currentLanguage == language.code,
                            isAvailable: isLanguageAvailable(language.code)
                        ) {
                            selectLanguage(language.code)
                        }
                        
                        if language.code != localization.availableLanguages.last?.code {
                            Divider()
                                .background(ColorTokens.borderSubtle)
                                .padding(.horizontal, VeloDesign.Spacing.md)
                        }
                    }
                }
                .elevated(.low)
            }
            
            // Note about restart
            HStack(spacing: VeloDesign.Spacing.sm) {
                Image(systemName: "info.circle")
                    .foregroundColor(ColorTokens.textTertiary)
                
                Text("language.restartNote".localized)
                    .font(TypographyTokens.caption)
                    .foregroundColor(ColorTokens.textTertiary)
            }
            .padding(.top, VeloDesign.Spacing.sm)
            
            Spacer()
        }
    }
    
    // MARK: - Private Methods
    
    private func isLanguageAvailable(_ code: String) -> Bool {
        // All languages that have folders are now available
        return true
    }
    
    private func selectLanguage(_ code: String) {
        guard isLanguageAvailable(code) else { return }
        
        withAnimation(.easeInOut(duration: 0.2)) {
            localization.currentLanguage = code
            appLanguage = code
        }
    }
}

// MARK: - Language Row Component

struct LanguageRow: View {
    let code: String
    let name: String
    let nativeName: String
    let isSelected: Bool
    let isAvailable: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: VeloDesign.Spacing.md) {
                // Flag/Language Icon
                Text(flagEmoji(for: code))
                    .font(.system(size: 24))
                
                // Language Names
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(TypographyTokens.body)
                        .foregroundColor(isAvailable ? ColorTokens.textPrimary : ColorTokens.textTertiary)
                    
                    Text(nativeName)
                        .font(TypographyTokens.caption)
                        .foregroundColor(ColorTokens.textSecondary)
                }
                
                Spacer()
                
                // Status
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(ColorTokens.accentPrimary)
                        .font(.system(size: 18))
                } else if !isAvailable {
                    Text("common.comingSoon".localized)
                        .font(TypographyTokens.caption)
                        .foregroundColor(ColorTokens.textTertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(ColorTokens.layer2)
                        .cornerRadius(4)
                }
            }
            .padding(VeloDesign.Spacing.md)
            .background(isSelected ? ColorTokens.layer2.opacity(0.5) : Color.clear)
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
    }
    
    // MARK: - Flag Emoji Helper
    
    private func flagEmoji(for code: String) -> String {
        switch code {
        case "en": return "🇺🇸"
        case "ar": return "🇮🇶"
        case "es": return "🇪🇸"
        case "fr": return "🇫🇷"
        case "de": return "🇩🇪"
        case "zh": return "🇨🇳"
        case "ja": return "🇯🇵"
        case "ko": return "🇰🇷"
        case "ru": return "🇷🇺"
        case "pt": return "🇧🇷"
        default: return "🌐"
        }
    }
}

// MARK: - Preview

#Preview {
    LanguageTab()
        .frame(width: 600, height: 600)
        .background(ColorTokens.layer0)
}
