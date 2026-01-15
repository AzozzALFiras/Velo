//
//  SSHConnectionSheet.swift
//  Velo
//
//  SSH Connection Progress Sheet
//  Shows connection status with cancel option
//

import SwiftUI

struct SSHConnectionSheet: View {
    let serverName: String
    let host: String
    var onCancel: () -> Void
    
    @State private var progress: Double = 0
    @State private var statusText = "Initializing..."
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Icon
            ZStack {
                Circle()
                    .fill(ColorTokens.accentPrimary.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "network")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(ColorTokens.accentPrimary)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
                    .animation(
                        .linear(duration: 2).repeatForever(autoreverses: false),
                        value: isAnimating
                    )
            }
            
            // Title
            VStack(spacing: 6) {
                Text("ssh.connecting".localized)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ColorTokens.textPrimary)
                
                Text(serverName)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(ColorTokens.accentPrimary)
                
                Text(host)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            
            // Progress bar
            VStack(spacing: 8) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .tint(ColorTokens.accentPrimary)
                
                Text(statusText)
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            .padding(.horizontal, 20)
            
            // Cancel button
            Button(action: onCancel) {
                Text("theme.cancel".localized)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ColorTokens.error)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(ColorTokens.error.opacity(0.1))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(32)
        .frame(width: 320)
        .background(ColorTokens.layer1)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(ColorTokens.border, lineWidth: 1)
        )
        .onAppear {
            isAnimating = true
            animateProgress()
        }
    }
    
    private func animateProgress() {
        // Simulate connection stages
        let stages: [(Double, String, TimeInterval)] = [
            (0.2, "Resolving host...", 0.5),
            (0.4, "Establishing connection...", 1.0),
            (0.6, "Authenticating...", 1.5),
            (0.8, "Starting session...", 2.0),
            (0.95, "Almost ready...", 2.5)
        ]
        
        for (value, text, delay) in stages {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    progress = value
                    statusText = text
                }
            }
        }
    }
}

#Preview {
    SSHConnectionSheet(
        serverName: "Production Server",
        host: "root@192.168.1.100",
        onCancel: {}
    )
    .padding()
    .background(Color.black.opacity(0.5))
}
