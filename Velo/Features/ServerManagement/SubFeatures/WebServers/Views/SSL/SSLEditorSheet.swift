import SwiftUI

/// Sheet for configuring SSL - Let's Encrypt or Custom certificate
struct SSLEditorSheet: View {
    @ObservedObject var viewModel: ServerManagementViewModel
    let website: Website
    let onComplete: (SSLCertificate) -> Void
    let onDismiss: () -> Void
    
    @State private var selectedTab: SSLConfigTab = .letsEncrypt
    @State private var email: String = ""
    @State private var customCertificate: String = ""
    @State private var customPrivateKey: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var progressMessage: String?
    
    enum SSLConfigTab: String, CaseIterable {
        case letsEncrypt = "Let's Encrypt"
        case custom = "Custom Certificate"
        
        var icon: String {
            switch self {
            case .letsEncrypt: return "lock.shield"
            case .custom: return "key"
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            HStack {
                Text("Configure SSL")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(ColorTokens.textPrimary)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
            }
            
            // Domain info
            HStack {
                Image(systemName: "globe")
                    .foregroundStyle(ColorTokens.textSecondary)
                Text(website.domain)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(ColorTokens.textPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(ColorTokens.layer2)
            .cornerRadius(8)
            
            // Tab Picker
            Picker("SSL Type", selection: $selectedTab) {
                ForEach(SSLConfigTab.allCases, id: \.self) { tab in
                    HStack {
                        Image(systemName: tab.icon)
                        Text(tab.rawValue)
                    }
                    .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .disabled(isLoading)
            
            // Tab Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedTab {
                    case .letsEncrypt:
                        letsEncryptTab
                    case .custom:
                        customCertificateTab
                    }
                }
            }
            
            // Error/Progress Messages
            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(8)
            }
            
            if let progress = progressMessage {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.trailing, 8)
                    Text(progress)
                        .font(.system(size: 13))
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                .padding()
                .background(ColorTokens.layer2)
                .cornerRadius(8)
            }
            
            Spacer()
            
            // Actions
            HStack(spacing: 12) {
                Button("Cancel") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
                
                Button(action: generateCertificate) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: selectedTab == .letsEncrypt ? "sparkles" : "arrow.down.doc")
                        }
                        Text(selectedTab == .letsEncrypt ? "Generate Certificate" : "Install Certificate")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading || !isFormValid)
            }
        }
        .padding(24)
        .frame(width: 500, height: 550)
        .background(ColorTokens.layer1)
    }
    
    // MARK: - Let's Encrypt Tab
    
    private var letsEncryptTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Info box
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                    .font(.system(size: 16))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Free SSL Certificate")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ColorTokens.textPrimary)
                    
                    Text("Let's Encrypt provides free, automated SSL certificates. Certificates are valid for 90 days and will auto-renew.")
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
            
            // Email input
            VStack(alignment: .leading, spacing: 8) {
                Text("Email Address")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ColorTokens.textSecondary)
                
                TextField("admin@example.com", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isLoading)
                
                Text("Required for certificate expiry notifications")
                    .font(.system(size: 11))
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            
            // Requirements
            VStack(alignment: .leading, spacing: 8) {
                Text("Requirements")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ColorTokens.textSecondary)
                
                requirementRow(text: "Domain must point to this server", met: true)
                requirementRow(text: "Port 80 must be accessible", met: true)
                requirementRow(text: "Certbot will be installed if needed", met: true)
            }
            .padding()
            .background(ColorTokens.layer2)
            .cornerRadius(8)
        }
    }
    
    private func requirementRow(text: String, met: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: met ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(met ? .green : ColorTokens.textSecondary)
                .font(.system(size: 14))
            
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(ColorTokens.textSecondary)
        }
    }
    
    // MARK: - Custom Certificate Tab
    
    private var customCertificateTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Info box
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "key.fill")
                    .foregroundStyle(.orange)
                    .font(.system(size: 16))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Custom Certificate")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(ColorTokens.textPrimary)
                    
                    Text("Use your own SSL certificate from a Certificate Authority (CA). Paste the certificate and private key below.")
                        .font(.system(size: 12))
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
            
            // Certificate input
            VStack(alignment: .leading, spacing: 8) {
                Text("Certificate (PEM format)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ColorTokens.textSecondary)
                
                TextEditor(text: $customCertificate)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(height: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(ColorTokens.border, lineWidth: 1)
                    )
                    .disabled(isLoading)
                
                if customCertificate.isEmpty {
                    Text("Paste certificate starting with -----BEGIN CERTIFICATE-----")
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }
            
            // Private Key input
            VStack(alignment: .leading, spacing: 8) {
                Text("Private Key (PEM format)")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ColorTokens.textSecondary)
                
                TextEditor(text: $customPrivateKey)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(height: 100)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(ColorTokens.border, lineWidth: 1)
                    )
                    .disabled(isLoading)
                
                if customPrivateKey.isEmpty {
                    Text("Paste private key starting with -----BEGIN PRIVATE KEY-----")
                        .font(.system(size: 11))
                        .foregroundStyle(ColorTokens.textSecondary)
                }
            }
        }
    }
    
    // MARK: - Validation
    
    private var isFormValid: Bool {
        switch selectedTab {
        case .letsEncrypt:
            return !email.isEmpty && email.contains("@")
        case .custom:
            return !customCertificate.isEmpty && !customPrivateKey.isEmpty &&
                   customCertificate.contains("BEGIN CERTIFICATE") &&
                   customPrivateKey.contains("BEGIN")
        }
    }
    
    // MARK: - Actions
    
    private func generateCertificate() {
        isLoading = true
        errorMessage = nil
        
        Task {
            guard let session = viewModel.session else {
                await MainActor.run {
                    errorMessage = "No active session"
                    isLoading = false
                }
                return
            }
            
            let sslService = SSLService.shared
            
            switch selectedTab {
            case .letsEncrypt:
                await generateLetsEncrypt(sslService: sslService, session: session)
            case .custom:
                await installCustomCertificate(sslService: sslService, session: session)
            }
        }
    }
    
    private func generateLetsEncrypt(sslService: SSLService, session: TerminalViewModel) async {
        await MainActor.run {
            progressMessage = "Checking certbot installation..."
        }
        
        // Check certbot
        let hasCertbot = await sslService.isCertbotInstalled(via: session)
        if !hasCertbot {
            await MainActor.run {
                progressMessage = "Installing certbot (this may take a minute)..."
            }
            
            let installed = await sslService.installCertbot(via: session)
            if !installed {
                await MainActor.run {
                    errorMessage = "Failed to install certbot"
                    progressMessage = nil
                    isLoading = false
                }
                return
            }
        }
        
        await MainActor.run {
            progressMessage = "Generating SSL certificate..."
        }
        
        // Determine web server
        let webServer = viewModel.serverStatus.nginx.isInstalled ? "nginx" : "apache"
        
        // Generate certificate
        if let cert = await sslService.generateLetsEncrypt(
            domain: website.domain,
            email: email,
            webServer: webServer,
            via: session
        ) {
            await MainActor.run {
                progressMessage = nil
                isLoading = false
                
                if cert.status == .active || cert.status == .expiringSoon {
                    onComplete(cert)
                } else {
                    errorMessage = "Certificate generation completed but status is: \(cert.status.rawValue)"
                }
            }
        } else {
            await MainActor.run {
                errorMessage = "Failed to generate certificate"
                progressMessage = nil
                isLoading = false
            }
        }
    }
    
    private func installCustomCertificate(sslService: SSLService, session: TerminalViewModel) async {
        await MainActor.run {
            progressMessage = "Installing custom certificate..."
        }
        
        let webServer = viewModel.serverStatus.nginx.isInstalled ? "nginx" : "apache"
        
        if let cert = await sslService.installCustomCertificate(
            domain: website.domain,
            certificateContent: customCertificate,
            privateKeyContent: customPrivateKey,
            webServer: webServer,
            via: session
        ) {
            await MainActor.run {
                progressMessage = nil
                isLoading = false
                onComplete(cert)
            }
        } else {
            await MainActor.run {
                errorMessage = "Failed to install custom certificate"
                progressMessage = nil
                isLoading = false
            }
        }
    }
}
