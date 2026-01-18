import SwiftUI

/// View for managing SSL certificate for a website
struct SSLManagementView: View {
    @ObservedObject var viewModel: ServerManagementViewModel
    let website: Website
    let onDismiss: () -> Void
    
    @State private var isLoading = false
    @State private var showingEditor = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var currentCertificate: SSLCertificate?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("web.ssl.title".localized)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(ColorTokens.textPrimary)
                    
                    Text(website.domain)
                        .font(.system(size: 14))
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(ColorTokens.textSecondary)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // SSL Status Card
            sslStatusCard
            
            // Certificate Details (if exists)
            if let cert = currentCertificate, cert.status != .none {
                certificateDetailsCard(cert)
            }
            
            // Error/Success Messages
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
            
            if let success = successMessage {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(success)
                        .font(.system(size: 13))
                        .foregroundStyle(.green)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
            
            // Actions
            actionsSection
        }
        .padding(24)
        .frame(width: 500, height: 550)
        .background(ColorTokens.layer1)
        .onAppear {
            currentCertificate = website.sslCertificate
            Task {
                await refreshCertificateInfo()
            }
        }
        .sheet(isPresented: $showingEditor) {
            SSLEditorSheet(
                viewModel: viewModel,
                website: website,
                onComplete: { cert in
                    currentCertificate = cert
                    showingEditor = false
                    successMessage = "SSL certificate configured successfully!"
                    Task {
                        await viewModel.websitesVM.loadWebsites()
                    }
                },
                onDismiss: {
                    showingEditor = false
                }
            )
        }
    }
    
    // MARK: - SSL Status Card
    
    private var sslStatusCard: some View {
        HStack(spacing: 16) {
            // Status Icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: statusIcon)
                    .font(.system(size: 28))
                    .foregroundStyle(statusColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(statusTitle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ColorTokens.textPrimary)
                
                Text(statusDescription)
                    .font(.system(size: 13))
                    .foregroundStyle(ColorTokens.textSecondary)
            }
            
            Spacer()
            
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(16)
        .background(ColorTokens.layer2)
        .cornerRadius(12)
    }
    
    // MARK: - Certificate Details Card
    
    private func certificateDetailsCard(_ cert: SSLCertificate) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Certificate Details")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(ColorTokens.textSecondary)
            
            VStack(spacing: 12) {
                detailRow(label: "Type", value: cert.type.rawValue, icon: cert.type.icon)
                detailRow(label: "Issuer", value: cert.issuer, icon: "building.2")
                detailRow(label: "Expires", value: cert.expiryDateFormatted, icon: "calendar")
                
                if let days = cert.daysRemaining {
                    detailRow(
                        label: "Days Remaining",
                        value: "\(days) days",
                        icon: "clock",
                        valueColor: days <= 30 ? (days <= 7 ? .red : .orange) : .green
                    )
                }
                
                if cert.isAutoRenew {
                    detailRow(label: "Auto-Renew", value: "Enabled", icon: "arrow.clockwise", valueColor: .green)
                }
            }
        }
        .padding(16)
        .background(ColorTokens.layer2)
        .cornerRadius(12)
    }
    
    private func detailRow(label: String, value: String, icon: String, valueColor: Color = ColorTokens.textPrimary) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(ColorTokens.textSecondary)
                .frame(width: 20)
            
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(ColorTokens.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(valueColor)
        }
    }
    
    // MARK: - Actions Section
    
    private var actionsSection: some View {
        HStack(spacing: 12) {
            if currentCertificate?.status == .active || currentCertificate?.status == .expiringSoon {
                // Renew button
                Button(action: renewCertificate) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("web.ssl.renew".localized)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
                
                // Remove button
                Button(action: removeCertificate) {
                    HStack {
                        Image(systemName: "trash")
                        Text("web.ssl.remove".localized)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(isLoading)
            } else {
                // Configure SSL button
                Button(action: { showingEditor = true }) {
                    HStack {
                        Image(systemName: "lock.shield")
                        Text("web.ssl.configure".localized)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var statusColor: Color {
        switch currentCertificate?.status ?? .none {
        case .active: return .green
        case .expiringSoon: return .orange
        case .expired, .error: return .red
        case .pending: return .orange
        case .none: return .gray
        }
    }
    
    private var statusIcon: String {
        currentCertificate?.status.icon ?? "lock.open"
    }
    
    private var statusTitle: String {
        switch currentCertificate?.status ?? .none {
        case .active: return "SSL Active"
        case .expiringSoon: return "Expiring Soon"
        case .expired: return "Certificate Expired"
        case .error: return "SSL Error"
        case .pending: return "Pending"
        case .none: return "No SSL"
        }
    }
    
    private var statusDescription: String {
        switch currentCertificate?.status ?? .none {
        case .active:
            if let days = currentCertificate?.daysRemaining {
                return "Valid for \(days) more days"
            }
            return "Your connection is secure"
        case .expiringSoon:
            if let days = currentCertificate?.daysRemaining {
                return "Expires in \(days) days - renew soon!"
            }
            return "Certificate will expire soon"
        case .expired:
            return "Certificate has expired - visitors will see warnings"
        case .error:
            return "There was an issue with SSL configuration"
        case .pending:
            return "SSL certificate is being configured"
        case .none:
            return "No SSL certificate configured"
        }
    }
    
    // MARK: - Actions
    
    private func refreshCertificateInfo() async {
        isLoading = true
        errorMessage = nil
        
        // Fetch latest certificate info from server
        if let session = viewModel.session {
            let sslService = SSLService.shared
            if let cert = await sslService.getCertificateInfo(domain: website.domain, via: session) {
                await MainActor.run {
                    currentCertificate = cert
                }
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    private func renewCertificate() {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        Task {
            guard let session = viewModel.session else {
                await MainActor.run {
                    errorMessage = "No active session"
                    isLoading = false
                }
                return
            }
            
            let sslService = SSLService.shared
            let success = await sslService.renewCertificate(domain: website.domain, via: session)
            
            await MainActor.run {
                if success {
                    successMessage = "Certificate renewed successfully!"
                    Task {
                        await refreshCertificateInfo()
                    }
                } else {
                    errorMessage = "Failed to renew certificate"
                }
                isLoading = false
            }
        }
    }
    
    private func removeCertificate() {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        Task {
            guard let session = viewModel.session else {
                await MainActor.run {
                    errorMessage = "No active session"
                    isLoading = false
                }
                return
            }
            
            let sslService = SSLService.shared
            let success = await sslService.removeCertificate(domain: website.domain, via: session)
            
            await MainActor.run {
                if success {
                    currentCertificate = nil
                    successMessage = "SSL certificate removed"
                    Task {
                        await viewModel.websitesVM.loadWebsites()
                    }
                } else {
                    errorMessage = "Failed to remove certificate"
                }
                isLoading = false
            }
        }
    }
}
