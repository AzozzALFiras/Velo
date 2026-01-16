//
//  SSHAdminButton.swift
//  Velo
//
//  Dedicated button for SSH Server Management
//  Observes session state for correct visibility and sheet presentation.
//

import SwiftUI

struct SSHAdminButton: View {
    
    @ObservedObject var session: TerminalViewModel
    
    var body: some View {
        // Only show if active session is SSH
        if session.isSSHActive {
            Button(action: {
                session.toggleServerManagement()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "server.rack")
                        .font(.system(size: 10))
                    Text("Server Admin")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(ColorTokens.textPrimary)
                .padding(.horizontal, 8)
                .frame(height: 24)
                .background(ColorTokens.accentPrimary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(ColorTokens.accentPrimary.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
            .help("Open Server Management Dashboard")
            // Present the Server Management View - attached to this view which observes state
            .sheet(isPresented: $session.showServerManagement) {
                ServerManagementView(session: session)
                    .frame(minWidth: 1100, maxWidth: .infinity, minHeight: 750, maxHeight: .infinity)
                    .frame(width: 1200, height: 850) // Default large size
            }
        }
    }
}
