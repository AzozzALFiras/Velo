//
//  SettingsView.swift
//  Velo
//
//  Created by Velo AI
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    // Preferences
    @AppStorage("autoOpenHistory") private var autoOpenHistory = true
    @AppStorage("autoOpenAIPanel") private var autoOpenAIPanel = true
    
    // Features
    @AppStorage("isInteractiveOutputEnabled") private var isInteractiveOutputEnabled = true
    @AppStorage("isDeepFileParsingEnabled") private var isDeepFileParsingEnabled = true
    
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
                    
                    Button(action: { dismiss() }) {
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

// MARK: - Helper Components

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title.uppercased())
            .font(VeloDesign.Typography.monoSmall)
            .foregroundColor(VeloDesign.Colors.textSecondary)
            .padding(.leading, 4)
    }
}

enum IconSource {
    case system(String)
    case asset(String)
}

struct LinkRow: View {
    let icon: IconSource
    let title: String
    let url: URL
    let color: Color
    
    @State private var isHovered = false
    
    var body: some View {
        Link(destination: url) {
            HStack {
                Group {
                    switch icon {
                    case .system(let name):
                        Image(systemName: name)
                            .resizable()
                    case .asset(let name):
                        Image(name)
                            .resizable()
                    }
                }
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .foregroundColor(color)
                
                Text(title)
                    .font(VeloDesign.Typography.subheadline)
                    .foregroundColor(VeloDesign.Colors.textPrimary)
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10))
                    .foregroundColor(VeloDesign.Colors.textMuted)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? VeloDesign.Colors.glassHighlight : Color.clear)
            )
        }
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

struct ToggleRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(VeloDesign.Typography.subheadline)
                    .foregroundColor(VeloDesign.Colors.textPrimary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(VeloDesign.Typography.caption)
                        .foregroundColor(VeloDesign.Colors.textMuted)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(SwitchToggleStyle(tint: VeloDesign.Colors.neonCyan))
        }
        .padding(8)
    }
}

#Preview {
    SettingsView()
}
