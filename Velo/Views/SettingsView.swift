//
//  SettingsView.swift
//  Velo
//
//  Created by Velo AI
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    var onClose: (() -> Void)? = nil
    
    // Preferences
    @AppStorage("autoOpenHistory") private var autoOpenHistory = true
    @AppStorage("autoOpenAIPanel") private var autoOpenAIPanel = true
    
    // Features
    @AppStorage("isInteractiveOutputEnabled") private var isInteractiveOutputEnabled = true
    @AppStorage("isDeepFileParsingEnabled") private var isDeepFileParsingEnabled = true
    
    // Cloud AI
    @AppStorage("selectedAIProvider") private var selectedAIProvider = "openai"
    @AppStorage("openaiApiKey") private var openaiApiKey = ""
    @AppStorage("anthropicApiKey") private var anthropicApiKey = ""
    @AppStorage("deepseekApiKey") private var deepseekApiKey = ""
    
    // Social Links
    private let githubURL = URL(string: "https://github.com/azozzalfiras")!
    private let xURL = URL(string: "https://x.com/dev_3zozz")!
    private let websiteURL = URL(string: "https://dev.3zozz.com")!
    
    // Updates
    @State private var isCheckingUpdate = false
    @State private var updateStatus: UpdateStatus? = nil
    
    struct UpdateStatus {
        let isUpdateAvailable: Bool
        let message: String
        let updateURL: String
    }
    
    var body: some View {
        ZStack {
            VeloDesign.Colors.deepSpace.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Settings")
                        .font(VeloDesign.Typography.headline)
                        .foregroundColor(VeloDesign.Colors.textPrimary)
                    
                    Spacer()
                    
                    Button(action: { 
                        if let onClose = onClose {
                            onClose()
                        } else {
                            dismiss()
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(VeloDesign.Colors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(VeloDesign.Colors.cardBackground.opacity(0.8))
                
                ScrollView {
                    VStack(spacing: VeloDesign.Spacing.xl) {
                        
                        // MARK: - Theme
                        ThemeSettingsView()
                        
                        // MARK: - General
                        VStack(alignment: .leading, spacing: VeloDesign.Spacing.md) {
                            SectionHeader(title: "General")
                            
                            VStack(spacing: 0) {
                                ToggleRow(
                                    title: "Auto-Open Left Page", 
                                    subtitle: "Automatically open the command history sidebar on launch.",
                                    isOn: $autoOpenHistory
                                )
                                Divider().background(VeloDesign.Colors.glassBorder)
                                ToggleRow(
                                    title: "Auto-Open Right Page", 
                                    subtitle: "Automatically open the AI insight panel on launch.",
                                    isOn: $autoOpenAIPanel
                                )
                            }
                            .padding()
                            .glassCard()
                        }

                        

                        
                        // MARK: - Features
                        VStack(alignment: .leading, spacing: VeloDesign.Spacing.md) {
                            SectionHeader(title: "Features")
                            
                            VStack(spacing: 0) {
                                ToggleRow(
                                    title: "Interactive Output", 
                                    subtitle: "Enable clickable file paths and hover effects in the terminal output.",
                                    isOn: $isInteractiveOutputEnabled
                                )
                                Divider().background(VeloDesign.Colors.glassBorder)
                                ToggleRow(
                                    title: "Deep File Parsing", 
                                    subtitle: "Scan output lines for file paths. Disable for better performance.",
                                    isOn: $isDeepFileParsingEnabled
                                )
                            }
                            .padding()
                            .glassCard()
                        }
                        
                        // MARK: - Cloud AI
                        VStack(alignment: .leading, spacing: VeloDesign.Spacing.md) {
                            SectionHeader(title: "Cloud AI")
                            
                            VStack(spacing: VeloDesign.Spacing.md) {
                                // Provider Selection
                                HStack {
                                    Text("Provider")
                                        .font(VeloDesign.Typography.monoFont)
                                        .foregroundColor(VeloDesign.Colors.textPrimary)
                                    Spacer()
                                    Picker("", selection: $selectedAIProvider) {
                                        Text("OpenAI").tag("openai")
                                        Text("Anthropic").tag("anthropic")
                                        Text("DeepSeek").tag("deepseek")
                                    }
                                    .labelsHidden()
                                    .pickerStyle(.menu)
                                    .frame(width: 120)
                                }
                                
                                Divider().background(VeloDesign.Colors.glassBorder)
                                
                                // API Keys
                                Group {
                                    if selectedAIProvider == "openai" {
                                        SecureFieldRow(title: "OpenAI API Key", text: $openaiApiKey, placeholder: "sk-...")
                                    } else if selectedAIProvider == "anthropic" {
                                        SecureFieldRow(title: "Anthropic API Key", text: $anthropicApiKey, placeholder: "sk-ant-...")
                                    } else if selectedAIProvider == "deepseek" {
                                        SecureFieldRow(title: "DeepSeek API Key", text: $deepseekApiKey, placeholder: "sk-...")
                                    }
                                }
                            }
                            .padding()
                            .glassCard()
                        }

                        // MARK: - App Version & Updates
                        VStack(alignment: .leading, spacing: VeloDesign.Spacing.md) {
                            SectionHeader(title: "Version & Updates")
                            
                            VStack(spacing: VeloDesign.Spacing.md) {
                                HStack {
                                    Image(systemName: "cube.box.fill")
                                        .foregroundColor(VeloDesign.Colors.neonCyan)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Velo Terminal")
                                            .font(VeloDesign.Typography.subheadline)
                                            .foregroundColor(VeloDesign.Colors.textPrimary)
                                        Text("v\(ApiService.shared.appVersion)")
                                            .font(VeloDesign.Typography.monoSmall)
                                            .foregroundColor(VeloDesign.Colors.textMuted)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: checkUpdate) {
                                        if isCheckingUpdate {
                                            ProgressView()
                                                .controlSize(.small)
                                        } else {
                                            Text("Check for Update")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(VeloDesign.Colors.neonCyan)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5)
                                                .background(VeloDesign.Colors.neonCyan.opacity(0.1))
                                                .cornerRadius(6)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isCheckingUpdate)
                                }
                                
                                if let status = updateStatus {
                                    Divider().background(VeloDesign.Colors.glassBorder)
                                    
                                    HStack {
                                        Image(systemName: status.isUpdateAvailable ? "arrow.up.circle.fill" : "checkmark.circle.fill")
                                            .foregroundColor(status.isUpdateAvailable ? VeloDesign.Colors.warning : VeloDesign.Colors.success)
                                        
                                        Text(status.message)
                                            .font(VeloDesign.Typography.caption)
                                            .foregroundColor(VeloDesign.Colors.textSecondary)
                                        
                                        if status.isUpdateAvailable {
                                            Spacer()
                                            Link("Update", destination: URL(string: status.updateURL) ?? websiteURL)
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(VeloDesign.Colors.neonPurple)
                                        }
                                    }
                                }
                            }
                            .padding()
                            .glassCard()
                        }
                        
                        // MARK: - Developer
                        VStack(alignment: .leading, spacing: VeloDesign.Spacing.md) {
                            SectionHeader(title: "Developer")
                            
                            HStack {
                                Image(systemName: "hammer.fill")
                                    .foregroundColor(VeloDesign.Colors.neonPurple)
                                
                                Text("Azozz ALFiras")
                                    .font(VeloDesign.Typography.subheadline)
                                    .foregroundColor(VeloDesign.Colors.textPrimary)
                                
                                Spacer()
                                
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(VeloDesign.Colors.success)
                            }
                            .padding()
                            .glassCard()
                        }
                        
                        // MARK: - Connect
                        VStack(alignment: .leading, spacing: VeloDesign.Spacing.md) {
                            SectionHeader(title: "Connect")
                            
                            VStack(spacing: VeloDesign.Spacing.sm) {
                                LinkRow(icon: .system("globe"), title: "Website", url: websiteURL, color: VeloDesign.Colors.neonGreen)
                                LinkRow(icon: .asset("GitHub"), title: "GitHub", url: githubURL, color: .white)
                                LinkRow(icon: .asset("X"), title: "X (Twitter)", url: xURL, color: VeloDesign.Colors.neonCyan)
                            }
                            .padding()
                            .glassCard()
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 450, height: 600)
    }
    
    private func checkUpdate() {
        isCheckingUpdate = true
        
        Task {
            do {
                let info = try await ApiService.shared.checkForUpdates()
                await MainActor.run {
                    isCheckingUpdate = false
                    if info.latestVersion != ApiService.shared.appVersion {
                        updateStatus = UpdateStatus(
                            isUpdateAvailable: true,
                            message: "New version v\(info.latestVersion) available!",
                            updateURL: info.pageUpdate
                        )
                    } else {
                        updateStatus = UpdateStatus(
                            isUpdateAvailable: false,
                            message: "You are on the latest version.",
                            updateURL: ""
                        )
                    }
                }
            } catch {
                await MainActor.run {
                    isCheckingUpdate = false
                    updateStatus = UpdateStatus(
                        isUpdateAvailable: false,
                        message: "Failed to check for updates.",
                        updateURL: ""
                    )
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
