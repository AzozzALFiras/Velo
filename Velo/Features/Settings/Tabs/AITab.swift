//
//  AITab.swift
//  Velo
//
//  Cloud AI provider settings with secure key management
//

import SwiftUI

struct AITab: View {
    @AppStorage("selectedAIProvider") private var selectedAIProvider = "openai"

    // API Keys (now stored in Keychain)
    @State private var openaiApiKey = ""
    @State private var anthropicApiKey = ""
    @State private var deepseekApiKey = ""

    // Validation states
    @State private var openaiValidation: ValidationService.ValidationResult?
    @State private var anthropicValidation: ValidationService.ValidationResult?
    @State private var deepseekValidation: ValidationService.ValidationResult?

    // Cloud AI Service for Keychain operations
    @StateObject private var aiService = CloudAIService()

    var body: some View {
        VStack(alignment: .leading, spacing: VeloDesign.Spacing.xl) {
            // Header
            VStack(alignment: .leading, spacing: VeloDesign.Spacing.xs) {
                Text("ai.title".localized)
                    .font(TypographyTokens.displayMd)
                    .foregroundColor(ColorTokens.textPrimary)

                Text("ai.subtitle".localized)
                    .font(TypographyTokens.bodySm)
                    .foregroundColor(ColorTokens.textSecondary)
            }

            // Provider Selection
            VStack(alignment: .leading, spacing: VeloDesign.Spacing.md) {
                SectionHeader(title: "ai.provider".localized)

                VStack(spacing: VeloDesign.Spacing.md) {
                    HStack {
                        Text("ai.provider".localized)
                            .font(TypographyTokens.body)
                            .foregroundColor(ColorTokens.textPrimary)

                        Spacer()

                        Picker("", selection: $selectedAIProvider) {
                            Text("OpenAI").tag("openai")
                            Text("Anthropic").tag("anthropic")
                            Text("DeepSeek").tag("deepseek")
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 140)
                    }
                }
                .padding(VeloDesign.Spacing.md)
                .elevated(.low)
            }

            // API Key Configuration
            VStack(alignment: .leading, spacing: VeloDesign.Spacing.md) {
                SectionHeader(title: "ai.credentials".localized)

                VStack(spacing: VeloDesign.Spacing.md) {
                    // OpenAI
                    if selectedAIProvider == "openai" {
                        VStack(alignment: .leading, spacing: VeloDesign.Spacing.sm) {
                            Text("OpenAI " + "ai.credentials".localized)
                                .font(TypographyTokens.bodySm)
                                .foregroundColor(ColorTokens.textSecondary)

                            SecureFieldRow(title: "", text: $openaiApiKey, placeholder: "sk-...")
                                .onChange(of: openaiApiKey) { newValue in
                                    openaiValidation = ValidationService.validateAPIKey(key: newValue, provider: "openai")
                                    if openaiValidation?.isValid == true {
                                        saveApiKey(for: "openai", key: newValue)
                                    }
                                }

                            if let validation = openaiValidation, !openaiApiKey.isEmpty {
                                InlineMessage(
                                    type: messageType(for: validation),
                                    message: validation.message
                                )
                            }
                        }
                    }

                    // Anthropic
                    if selectedAIProvider == "anthropic" {
                        VStack(alignment: .leading, spacing: VeloDesign.Spacing.sm) {
                            Text("Anthropic " + "ai.credentials".localized)
                                .font(TypographyTokens.bodySm)
                                .foregroundColor(ColorTokens.textSecondary)

                            SecureFieldRow(title: "", text: $anthropicApiKey, placeholder: "sk-ant-...")
                                .onChange(of: anthropicApiKey) { newValue in
                                    anthropicValidation = ValidationService.validateAPIKey(key: newValue, provider: "anthropic")
                                    if anthropicValidation?.isValid == true {
                                        saveApiKey(for: "anthropic", key: newValue)
                                    }
                                }

                            if let validation = anthropicValidation, !anthropicApiKey.isEmpty {
                                InlineMessage(
                                    type: messageType(for: validation),
                                    message: validation.message
                                )
                            }
                        }
                    }

                    // DeepSeek
                    if selectedAIProvider == "deepseek" {
                        VStack(alignment: .leading, spacing: VeloDesign.Spacing.sm) {
                            Text("DeepSeek " + "ai.credentials".localized)
                                .font(TypographyTokens.bodySm)
                                .foregroundColor(ColorTokens.textSecondary)

                            SecureFieldRow(title: "", text: $deepseekApiKey, placeholder: "sk-...")
                                .onChange(of: deepseekApiKey) { newValue in
                                    deepseekValidation = ValidationService.validateAPIKey(key: newValue, provider: "deepseek")
                                    if deepseekValidation?.isValid == true {
                                        saveApiKey(for: "deepseek", key: newValue)
                                    }
                                }

                            if let validation = deepseekValidation, !deepseekApiKey.isEmpty {
                                InlineMessage(
                                    type: messageType(for: validation),
                                    message: validation.message
                                )
                            }
                        }
                    }

                    // Info message
                    HStack(spacing: VeloDesign.Spacing.sm) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(ColorTokens.success)

                        Text("ai.secureHint".localized)
                            .font(TypographyTokens.caption)
                            .foregroundColor(ColorTokens.textTertiary)
                    }
                }
                .padding(VeloDesign.Spacing.md)
                .elevated(.low)
            }

            Spacer()
        }
        .onAppear {
            loadApiKeys()
        }
    }

    // MARK: - Helper Methods

    private func loadApiKeys() {
        openaiApiKey = aiService.getApiKey(for: "openai")
        anthropicApiKey = aiService.getApiKey(for: "anthropic")
        deepseekApiKey = aiService.getApiKey(for: "deepseek")
    }

    private func saveApiKey(for provider: String, key: String) {
        do {
            try aiService.saveApiKey(for: provider, key: key)
        } catch {
            print("Failed to save API key for \(provider): \(error)")
        }
    }

    private func messageType(for validation: ValidationService.ValidationResult) -> InlineMessage.MessageType {
        switch validation {
        case .success: return .success
        case .warning: return .warning
        case .error: return .error
        }
    }
}

#Preview {
    AITab()
        .frame(width: 600, height: 600)
        .background(ColorTokens.layer0)
}
