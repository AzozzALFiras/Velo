//
//  SSHPasswordSheet.swift
//  Velo
//
//  Password prompt sheet for SSH authentication
//

import SwiftUI

// MARK: - Notification Extension

extension Notification.Name {
    static let sshPasswordRequired = Notification.Name("sshPasswordRequired")
}

// MARK: - SSH Password Sheet

struct SSHPasswordSheet: View {
    let serverName: String
    @Binding var password: String
    var onSubmit: () -> Void
    var onCancel: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(ColorTokens.accentPrimary)
                
                Text("SSH Password Required")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(ColorTokens.textPrimary)
                
                Text("Enter password for \(serverName)")
                    .font(.system(size: 13))
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            .padding(.top, 8)
            
            // Password Field
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(ColorTokens.textSecondary)
                
                SecureField("Enter SSH password", text: $password)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .padding(12)
                    .background(ColorTokens.layer2)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(ColorTokens.border, lineWidth: 1)
                    )
                    .focused($isFocused)
                    .onSubmit {
                        if !password.isEmpty {
                            onSubmit()
                        }
                    }
            }
            
            // Info text
            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 11))
                Text("Password will be saved to Keychain")
                    .font(.system(size: 11))
            }
            .foregroundStyle(ColorTokens.textTertiary)
            
            // Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.plain)
                .foregroundStyle(ColorTokens.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(ColorTokens.layer2)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                Button("Connect") {
                    onSubmit()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(password.isEmpty ? ColorTokens.textTertiary : ColorTokens.accentPrimary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .disabled(password.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 360)
        .background(ColorTokens.layer1)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        .onAppear {
            isFocused = true
        }
    }
}

// MARK: - Preview

#Preview {
    SSHPasswordSheet(
        serverName: "root@192.168.1.100",
        password: .constant(""),
        onSubmit: {},
        onCancel: {}
    )
    .frame(width: 400, height: 350)
    .background(ColorTokens.layer0)
}
