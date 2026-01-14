//
//  GitPanel.swift
//  Velo
//
//  Dashboard Redesign - Git Management Panel
//  Visual staging, committing, and sync.
//

import SwiftUI

struct GitPanel: View {
    let contextManager: ContextManager
    let currentDirectory: String
    
    @State private var commitMessage: String = ""
    @State private var isCommitting = false
    @State private var selectedFiles: Set<String> = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            panelHeader
            
            Divider()
                .background(ColorTokens.border)
            
            // Sync Bar
            syncBar
            
            Divider()
                .background(ColorTokens.borderSubtle)
            
            // Files List Split
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Staged Section
                    gitSection(
                        title: "Staged Changes",
                        files: contextManager.stagedFiles,
                        icon: "checkmark.circle.fill",
                        color: ColorTokens.success
                    )
                    
                    // Modified Section
                    gitSection(
                        title: "Unstaged Changes",
                        files: contextManager.modifiedFiles,
                        icon: "pencil.circle.fill",
                        color: ColorTokens.warning
                    )
                    
                    // Untracked Section
                    gitSection(
                        title: "Untracked Files",
                        files: contextManager.untrackedFiles,
                        icon: "questionmark.circle.fill",
                        color: ColorTokens.textTertiary
                    )
                }
                .padding(16)
            }
            
            Divider()
                .background(ColorTokens.border)
            
            // Commit Footer
            commitFooter
        }
        .background(ColorTokens.layer0)
    }
    
    // MARK: - Components
    
    private var panelHeader: some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: "branch")
                    .font(.system(size: 18))
                    .foregroundStyle(ColorTokens.accentSecondary)
                
                VStack(alignment: .leading, spacing: 0) {
                    Text("Source Control")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(ColorTokens.textPrimary)
                    
                    Text(contextManager.gitBranch)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(ColorTokens.textTertiary)
                }
            }
            
            Spacer()
            
            Button {
                Task { await contextManager.refreshGitStatus() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }
    
    private var syncBar: some View {
        HStack {
            HStack(spacing: 12) {
                syncIndicator(icon: "arrow.up", count: contextManager.aheadCount, label: "Ahead")
                syncIndicator(icon: "arrow.down", count: contextManager.behindCount, label: "Behind")
            }
            
            Spacer()
            
            Button {
                // Future: run git pull/push
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Sync Changes")
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(ColorTokens.accentPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(ColorTokens.layer1.opacity(0.5))
    }
    
    private func syncIndicator(icon: String, count: Int, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text("\(count)")
                .font(.system(size: 11, weight: .bold))
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(ColorTokens.textTertiary)
        }
        .foregroundStyle(count > 0 ? ColorTokens.accentPrimary : ColorTokens.textTertiary)
    }
    
    @ViewBuilder
    private func gitSection(title: String, files: [String], icon: String, color: Color) -> some View {
        if !files.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundStyle(color)
                    
                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(ColorTokens.textSecondary)
                    
                    Spacer()
                    
                    Text("\(files.count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(ColorTokens.textTertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(ColorTokens.layer2)
                        .clipShape(Capsule())
                }
                
                VStack(spacing: 1) {
                    ForEach(files, id: \.self) { path in
                        GitFileRow(path: path, color: color)
                    }
                }
                .background(ColorTokens.layer1)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(ColorTokens.border, lineWidth: 1)
                )
            }
        }
    }
    
    private var commitFooter: some View {
        VStack(spacing: 12) {
            // Message Input
            ZStack(alignment: .topLeading) {
                if commitMessage.isEmpty {
                    Text("Commit message...")
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.textTertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                
                TextEditor(text: $commitMessage)
                    .font(.system(size: 12))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(height: 60)
            }
            .background(ColorTokens.layer2)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(ColorTokens.border, lineWidth: 1)
            )
            
            // Buttons
            HStack {
                Button {
                    // Future: AI generated commit message
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("Suggest")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(ColorTokens.accentSecondary)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button {
                    commit()
                } label: {
                    if isCommitting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Commit to \(contextManager.gitBranch)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(commitMessage.isEmpty ? ColorTokens.textTertiary : ColorTokens.success)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                .buttonStyle(.plain)
                .disabled(commitMessage.isEmpty || isCommitting)
            }
        }
        .padding(16)
        .background(ColorTokens.layer1)
    }
    
    // MARK: - Actions
    
    private func commit() {
        guard !commitMessage.isEmpty else { return }
        isCommitting = true
        
        Task {
            // Run actual git commit
            await executeGitCommand("git add -A && git commit -m \"\(commitMessage.replacingOccurrences(of: "\"", with: "\\\""))\"")
            
            await MainActor.run {
                commitMessage = ""
                isCommitting = false
            }
            
            await contextManager.refreshGitStatus()
        }
    }
    
    private func stageFile(_ path: String) {
        Task {
            await executeGitCommand("git add \"\(path)\"")
            await contextManager.refreshGitStatus()
        }
    }
    
    private func unstageFile(_ path: String) {
        Task {
            await executeGitCommand("git restore --staged \"\(path)\"")
            await contextManager.refreshGitStatus()
        }
    }
    
    private func executeGitCommand(_ command: String) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                process.arguments = ["-c", command]
                process.currentDirectoryURL = URL(fileURLWithPath: self.currentDirectory)
                
                do {
                    try process.run()
                    process.waitUntilExit()
                } catch {
                    print("Git command failed: \(error)")
                }
                
                continuation.resume()
            }
        }
    }
}

// MARK: - File Row
struct GitFileRow: View {
    let path: String
    let color: Color
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc")
                .font(.system(size: 11))
                .foregroundStyle(ColorTokens.textTertiary)
            
            Text( (path as NSString).lastPathComponent )
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ColorTokens.textPrimary)
            
            Text( (path as NSString).deletingLastPathComponent )
                .font(.system(size: 10))
                .foregroundStyle(ColorTokens.textTertiary)
                .lineLimit(1)
            
            Spacer()
            
            if isHovered {
                HStack(spacing: 2) {
                    GitFileActionButton(icon: "eye", color: ColorTokens.accentPrimary) {}
                    GitFileActionButton(icon: "plus", color: ColorTokens.success) {}
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isHovered ? ColorTokens.layer2.opacity(0.5) : Color.clear)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) {
                isHovered = hovering
            }
        }
    }
}

private struct GitFileActionButton: View {
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 22, height: 22)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }
}
