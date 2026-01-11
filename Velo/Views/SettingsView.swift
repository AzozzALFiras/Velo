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

                        // MARK: - Versions
                        VStack(alignment: .leading, spacing: VeloDesign.Spacing.md) {
                            SectionHeader(title: "Version")
                            
                            HStack {
                                Image(systemName: "cube.box.fill")
                                    .foregroundColor(VeloDesign.Colors.neonCyan)
                                
                                Text("Velo Terminal")
                                    .font(VeloDesign.Typography.subheadline)
                                    .foregroundColor(VeloDesign.Colors.textPrimary)
                                
                                Spacer()
                                
                                Text("v1.0.0 (Beta)")
                                    .font(VeloDesign.Typography.monoSmall)
                                    .foregroundColor(VeloDesign.Colors.textMuted)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(VeloDesign.Colors.glassWhite))
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
}



#Preview {
    SettingsView()
}
