//
//  ServerSettingsView.swift
//  Velo
//
//  Server-wide settings and information.
//

import SwiftUI

struct ServerSettingsView: View {
    @ObservedObject var viewModel: ServerManagementViewModel

    @State private var showingRootPassAlert = false
    @State private var showingDBPassAlert = false
    @State private var newPassBuffer = ""
    @State private var isRestartingNginx = false
    @State private var isRestartingMySQL = false
    @State private var showSuccessMessage: String? = nil
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Server Settings")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(ColorTokens.textPrimary)
                        Text("Manage your server configuration and security")
                            .font(.system(size: 13))
                            .foregroundStyle(ColorTokens.textSecondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 32)
                .padding(.top, 32)
                
                // Server Info Cards
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    infoCard(title: "Hostname", value: viewModel.serverHostname, icon: "desktopcomputer")
                    infoCard(title: "IPv4 Address", value: viewModel.serverIP, icon: "network")
                    infoCard(title: "OS Version", value: viewModel.serverOS, icon: "terminal.fill")
                    infoCard(title: "System Uptime", value: viewModel.serverUptime, icon: "clock.fill")
                    infoCard(title: "CPU Load", value: "\(viewModel.cpuUsage)%", icon: "cpu")
                    infoCard(title: "RAM Usage", value: "\(viewModel.ramUsage)%", icon: "memorychip")
                }
                .padding(.horizontal, 32)
                
                // Configuration Sections
                VStack(spacing: 24) {
                    // Security Section
                    settingsSection(title: "Security & Passwords", icon: "lock.shield.fill") {
                        VStack(spacing: 12) {
                            settingsActionRow(
                                title: "Root Password",
                                description: "Change the primary administrative password",
                                actionLabel: "Change",
                                color: ColorTokens.accentPrimary
                            ) {
                                showingRootPassAlert = true
                            }
                            
                            Divider().opacity(0.1)
                            
                            settingsActionRow(
                                title: "Database Root Password",
                                description: "Update the MySQL/MariaDB root access key",
                                actionLabel: "Change",
                                color: ColorTokens.accentPrimary
                            ) {
                                showingDBPassAlert = true
                            }
                        }
                    }
                    
                    // Service Controls - Show based on what's installed
                    settingsSection(title: "Service Controls", icon: "gearshape.fill") {
                        VStack(spacing: 12) {
                            // Web Server
                            if viewModel.serverStatus.nginx.isInstalled {
                                serviceRestartRow(
                                    title: "Nginx Web Server",
                                    description: "Restart the web server to apply new configs",
                                    isRestarting: $isRestartingNginx,
                                    serviceName: "nginx"
                                )
                            } else if viewModel.serverStatus.apache.isInstalled {
                                serviceRestartRow(
                                    title: "Apache Web Server",
                                    description: "Restart the web server to apply new configs",
                                    isRestarting: $isRestartingNginx,
                                    serviceName: "apache2"
                                )
                            }

                            if viewModel.serverStatus.hasWebServer && viewModel.serverStatus.hasDatabase {
                                Divider().opacity(0.1)
                            }

                            // Database
                            if viewModel.serverStatus.mysql.isInstalled {
                                serviceRestartRow(
                                    title: "MySQL Database",
                                    description: "Restart the database engine",
                                    isRestarting: $isRestartingMySQL,
                                    serviceName: "mysql"
                                )
                            } else if viewModel.serverStatus.mariadb.isInstalled {
                                serviceRestartRow(
                                    title: "MariaDB Database",
                                    description: "Restart the database engine",
                                    isRestarting: $isRestartingMySQL,
                                    serviceName: "mariadb"
                                )
                            } else if viewModel.serverStatus.postgresql.isInstalled {
                                serviceRestartRow(
                                    title: "PostgreSQL Database",
                                    description: "Restart the database engine",
                                    isRestarting: $isRestartingMySQL,
                                    serviceName: "postgresql"
                                )
                            }

                            if !viewModel.serverStatus.hasWebServer && !viewModel.serverStatus.hasDatabase {
                                Text("No services installed yet")
                                    .font(.system(size: 13))
                                    .foregroundStyle(ColorTokens.textTertiary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .background(ColorTokens.layer0)
        // Success message overlay
        .overlay(alignment: .top) {
            if let message = showSuccessMessage {
                Text(message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.green)
                    .clipShape(Capsule())
                    .padding(.top, 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation { showSuccessMessage = nil }
                        }
                    }
            }
        }
        // Alert for changing passwords
        .alert("Change Root Password", isPresented: $showingRootPassAlert) {
            SecureField("New Password", text: $newPassBuffer)
            Button("Cancel", role: .cancel) { newPassBuffer = "" }
            Button("Update") {
                Task {
                    let success = await viewModel.changeRootPassword(newPass: newPassBuffer)
                    await MainActor.run {
                        if success {
                            withAnimation { showSuccessMessage = "Root password updated" }
                        }
                    }
                }
                newPassBuffer = ""
            }
        } message: {
            Text("Enter a secure new password for the root user.")
        }
        .alert("Change DB Password", isPresented: $showingDBPassAlert) {
            SecureField("New Password", text: $newPassBuffer)
            Button("Cancel", role: .cancel) { newPassBuffer = "" }
            Button("Update") {
                Task {
                    let success = await viewModel.changeDBPassword(newPass: newPassBuffer)
                    await MainActor.run {
                        if success {
                            withAnimation { showSuccessMessage = "Database password updated" }
                        }
                    }
                }
                newPassBuffer = ""
            }
        } message: {
            Text("Enter a secure new password for the database root user.")
        }
    }

    // MARK: - Service Restart Row

    @ViewBuilder
    private func serviceRestartRow(title: String, description: String, isRestarting: Binding<Bool>, serviceName: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ColorTokens.textPrimary)
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.textSecondary)
            }

            Spacer()

            Button(action: {
                isRestarting.wrappedValue = true
                Task {
                    let success = await viewModel.restartService(serviceName)
                    await MainActor.run {
                        isRestarting.wrappedValue = false
                        if success {
                            withAnimation { showSuccessMessage = "\(title) restarted successfully" }
                        }
                    }
                }
            }) {
                HStack(spacing: 6) {
                    if isRestarting.wrappedValue {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                    Text(isRestarting.wrappedValue ? "Restarting..." : "Restart")
                        .font(.system(size: 12, weight: .bold))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .foregroundStyle(.orange)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isRestarting.wrappedValue)
        }
    }
    
    // MARK: - Components
    
    private func infoCard(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(ColorTokens.accentPrimary)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(ColorTokens.textTertiary)
                    .textCase(.uppercase)
                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ColorTokens.textPrimary)
            }
        }
        .padding(16)
        .background(ColorTokens.layer1)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.05), lineWidth: 1))
    }
    
    private func settingsSection<Content: View>(title: String, icon: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(ColorTokens.textSecondary)
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(ColorTokens.textPrimary)
            }
            
            content()
                .padding(20)
                .background(ColorTokens.layer1)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.05), lineWidth: 1))
        }
    }
    
    private func settingsActionRow(title: String, description: String, actionLabel: String, color: Color, action: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ColorTokens.textPrimary)
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            
            Spacer()
            
            Button(action: action) {
                Text(actionLabel)
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(color.opacity(0.1))
                    .foregroundStyle(color)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}
