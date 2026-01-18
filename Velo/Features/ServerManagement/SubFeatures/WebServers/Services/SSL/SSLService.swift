import Foundation

/// Service for managing SSL certificates via Let's Encrypt (certbot) and custom certificates
actor SSLService {
    private let baseService = SSHBaseService.shared
    
    static let shared = SSLService()
    
    // MARK: - Certbot Management
    
    /// Check if certbot is installed on the server
    func isCertbotInstalled(via session: TerminalViewModel) async -> Bool {
        let result = await baseService.execute("which certbot 2>/dev/null", via: session, timeout: 10)
        return !result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// Install certbot on the server
    func installCertbot(via session: TerminalViewModel) async -> Bool {
        print("🔐 [SSLService] Installing certbot...")
        
        // Detect OS first
        let osResult = await baseService.execute(
            "cat /etc/os-release 2>/dev/null | grep -E '^ID=' | cut -d= -f2 | tr -d '\"'",
            via: session, timeout: 10
        )
        let osId = osResult.output.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        var installCmd: String
        if osId == "ubuntu" || osId == "debian" {
            installCmd = "apt-get update && apt-get install -y certbot python3-certbot-nginx python3-certbot-apache"
        } else if osId == "centos" || osId == "rhel" || osId == "fedora" || osId == "rocky" || osId == "almalinux" {
            installCmd = "yum install -y certbot python3-certbot-nginx python3-certbot-apache || dnf install -y certbot python3-certbot-nginx python3-certbot-apache"
        } else {
            print("⚠️ [SSLService] Unknown OS: \(osId), trying apt-get")
            installCmd = "apt-get update && apt-get install -y certbot python3-certbot-nginx"
        }
        
        let result = await baseService.execute(installCmd, via: session, timeout: 120)
        let success = result.exitCode == 0
        print(success ? "✅ [SSLService] Certbot installed" : "❌ [SSLService] Failed to install certbot")
        return success
    }
    
    // MARK: - Let's Encrypt Certificate Generation
    
    /// Generate a Let's Encrypt certificate for a domain
    func generateLetsEncrypt(
        domain: String,
        email: String,
        webServer: String, // "nginx" or "apache"
        via session: TerminalViewModel
    ) async -> SSLCertificate? {
        print("🔐 [SSLService] Generating Let's Encrypt certificate for \(domain)...")
        
        // Check if certbot is installed
        // Check if certbot is installed
        if !(await isCertbotInstalled(via: session)) {
            print("⚠️ [SSLService] Certbot not installed, installing...")
            guard await installCertbot(via: session) else {
                print("❌ [SSLService] Failed to install certbot")
                return nil
            }
        }
        
        // Determine plugin based on web server
        let plugin = webServer.lowercased() == "apache" ? "apache" : "nginx"
        
        // Try with both domain and www.domain first
        // Note: For subdomains, www often doesn't exist, so we handle failure
        let certbotCmd = """
        certbot --\(plugin) -d \(domain) -d www.\(domain) \
        --non-interactive --agree-tos --email \(email) \
        --redirect --expand 2>&1
        """
        
        var result = await baseService.execute(certbotCmd, via: session, timeout: 180)
        
        // If it failed and we suspect it's because of the www subdomain (e.g. NXDOMAIN)
        if result.exitCode != 0 && (result.output.contains("NXDOMAIN") || result.output.contains("DNS problem")) {
            print("⚠️ [SSLService] Failed with www subdomain, retrying with only \(domain)...")
            let retryCmd = """
            certbot --\(plugin) -d \(domain) \
            --non-interactive --agree-tos --email \(email) \
            --redirect --expand 2>&1
            """
            result = await baseService.execute(retryCmd, via: session, timeout: 180)
        }
        
        if result.exitCode == 0 || result.output.contains("Congratulations") || result.output.contains("Certificate not yet due for renewal") {
            print("✅ [SSLService] Certificate generated successfully for \(domain)")
            // Fetch the certificate info
            return await getCertificateInfo(domain: domain, via: session)
        } else {
            print("❌ [SSLService] Failed to generate certificate: \(result.output)")
            return SSLCertificate(
                domain: domain,
                issuer: "Let's Encrypt",
                type: .letsencrypt,
                status: .error
            )
        }
    }
    
    // MARK: - Certificate Information
    
    /// Get certificate information for a domain
    func getCertificateInfo(domain: String, via session: TerminalViewModel) async -> SSLCertificate? {
        print("🔍 [SSLService] Fetching certificate info for \(domain)...")
        
        // Check Let's Encrypt certificate first
        let certPath = "/etc/letsencrypt/live/\(domain)/fullchain.pem"
        let checkCmd = """
        if [ -f '\(certPath)' ]; then
            openssl x509 -in '\(certPath)' -noout -enddate -issuer 2>/dev/null
        else
            # Try to find certificate in nginx/apache config
            openssl s_client -connect \(domain):443 -servername \(domain) </dev/null 2>/dev/null | openssl x509 -noout -enddate -issuer 2>/dev/null
        fi
        """
        
        let result = await baseService.execute(checkCmd, via: session, timeout: 30)
        let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if output.isEmpty {
            print("⚠️ [SSLService] No certificate found for \(domain)")
            return nil
        }
        
        // Parse expiry date
        var expiryDate: Date?
        var issuer = "Unknown"
        
        // Parse lines for expiry and issuer
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            let lowerLine = line.lowercased()
            if lowerLine.contains("notafter=") {
                // Handle formats like: notAfter=Mar 15 12:00:00 2025 GMT or notAfter=2025-03-15...
                let dateStr = line.replacingOccurrences(of: "notAfter=", with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespaces)
                
                // Try multiple common formats
                let formats = [
                    "MMM dd HH:mm:ss yyyy zzz",
                    "MMM  d HH:mm:ss yyyy zzz", // Support double space in date
                    "yyyy-MM-dd HH:mm:ss"
                ]
                
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                for format in formats {
                    formatter.dateFormat = format
                    if let date = formatter.date(from: dateStr) {
                        expiryDate = date
                        break
                    }
                }
            }
            if lowerLine.contains("issuer=") {
                // Extract CN from issuer (e.g. /C=US/O=Let's Encrypt/CN=R3 or C=US, O=Let's Encrypt, CN=R3)
                if let cnRange = line.range(of: "CN\\s?=\\s?", options: [.regularExpression, .caseInsensitive]) {
                    let afterCN = line[cnRange.upperBound...]
                    issuer = String(afterCN.prefix(while: { $0 != "," && $0 != "/" })).trimmingCharacters(in: .whitespaces)
                } else if line.contains("Let's Encrypt") || line.contains("ZeroSSL") || line.contains("Google") {
                    // Fallback to full line if it contains known CA
                    issuer = line.replacingOccurrences(of: "issuer=", with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespaces)
                }
            }
        }
        
        // Determine certificate type
        let isLetsEncrypt = issuer.contains("Let's Encrypt") || issuer.contains("R3") || issuer.contains("R10") || issuer.contains("E1")
        
        // Determine status
        var status: SSLStatus = .active
        if let expiry = expiryDate {
            let daysRemaining = Calendar.current.dateComponents([.day], from: Date(), to: expiry).day ?? 0
            if daysRemaining <= 0 {
                status = .expired
            } else if daysRemaining <= 30 {
                status = .expiringSoon
            }
        }
        
        let cert = SSLCertificate(
            domain: domain,
            issuer: issuer,
            expiryDate: expiryDate,
            isAutoRenew: isLetsEncrypt,
            type: isLetsEncrypt ? .letsencrypt : .custom,
            status: status,
            certPath: isLetsEncrypt ? certPath : nil,
            keyPath: isLetsEncrypt ? "/etc/letsencrypt/live/\(domain)/privkey.pem" : nil
        )
        
        print("✅ [SSLService] Certificate info: \(cert.issuer), expires: \(cert.expiryDateFormatted), status: \(cert.status)")
        return cert
    }
    
    // MARK: - Certificate Renewal
    
    /// Renew a Let's Encrypt certificate
    func renewCertificate(domain: String, via session: TerminalViewModel) async -> Bool {
        print("🔄 [SSLService] Renewing certificate for \(domain)...")
        
        let result = await baseService.execute(
            "certbot renew --cert-name \(domain) --force-renewal 2>&1",
            via: session, timeout: 180
        )
        
        let success = result.exitCode == 0 || result.output.contains("Congratulations")
        print(success ? "✅ [SSLService] Certificate renewed" : "❌ [SSLService] Renewal failed")
        return success
    }
    
    // MARK: - Custom Certificate Installation
    
    /// Install a custom SSL certificate
    func installCustomCertificate(
        domain: String,
        certificateContent: String,
        privateKeyContent: String,
        webServer: String,
        via session: TerminalViewModel
    ) async -> SSLCertificate? {
        print("🔐 [SSLService] Installing custom certificate for \(domain)...")
        
        let certDir = "/etc/ssl/\(domain)"
        let certPath = "\(certDir)/fullchain.pem"
        let keyPath = "\(certDir)/privkey.pem"
        
        // Create directory
        let mkdirResult = await baseService.execute("mkdir -p '\(certDir)'", via: session, timeout: 10)
        guard mkdirResult.exitCode == 0 else {
            print("❌ [SSLService] Failed to create certificate directory")
            return nil
        }
        
        // Write certificate file
        let certWritten = await baseService.writeFile(at: certPath, content: certificateContent, useSudo: true, via: session)
        guard certWritten else {
            print("❌ [SSLService] Failed to write certificate file")
            return nil
        }
        
        // Write private key file
        let keyWritten = await baseService.writeFile(at: keyPath, content: privateKeyContent, useSudo: true, via: session)
        guard keyWritten else {
            print("❌ [SSLService] Failed to write private key file")
            return nil
        }
        
        // Secure key file
        _ = await baseService.execute("sudo chmod 600 '\(keyPath)'", via: session, timeout: 5)
        
        print("✅ [SSLService] Custom certificate installed at \(certPath)")
        
        // Get certificate info
        return await getCertificateInfo(domain: domain, via: session)
    }
    
    // MARK: - Certificate Removal
    
    /// Remove SSL certificate
    func removeCertificate(domain: String, via session: TerminalViewModel) async -> Bool {
        print("🗑️ [SSLService] Removing certificate for \(domain)...")
        
        // Try to delete Let's Encrypt certificate
        let deleteCmd = """
        certbot delete --cert-name \(domain) --non-interactive 2>/dev/null || true
        rm -rf /etc/ssl/\(domain) 2>/dev/null || true
        """
        
        let result = await baseService.execute(deleteCmd, via: session, timeout: 30)
        print("✅ [SSLService] Certificate removed for \(domain)")
        return true
    }
    
    // MARK: - Auto-renewal Setup
    
    /// Setup auto-renewal cron job for certbot
    func setupAutoRenewal(via session: TerminalViewModel) async -> Bool {
        print("⏰ [SSLService] Setting up auto-renewal...")
        
        // Check if cron job already exists
        let checkCmd = "crontab -l 2>/dev/null | grep -q certbot && echo 'EXISTS'"
        let checkResult = await baseService.execute(checkCmd, via: session, timeout: 10)
        
        if checkResult.output.contains("EXISTS") {
            print("✅ [SSLService] Auto-renewal already configured")
            return true
        }
        
        // Add certbot renewal cron job (runs twice daily)
        let cronCmd = "(crontab -l 2>/dev/null; echo '0 0,12 * * * certbot renew --quiet') | crontab -"
        let result = await baseService.execute(cronCmd, via: session, timeout: 10)
        
        let success = result.exitCode == 0
        print(success ? "✅ [SSLService] Auto-renewal configured" : "❌ [SSLService] Failed to configure auto-renewal")
        return success
    }
}
