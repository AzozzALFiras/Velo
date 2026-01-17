import Foundation

/// Generates and updates SSL configuration for web servers
struct SSLConfigGenerator {
    
    // MARK: - Nginx SSL Configuration
    
    /// Generate Nginx SSL server block
    static func generateNginxSSLConfig(
        domain: String,
        rootPath: String,
        certPath: String,
        keyPath: String,
        includeWWW: Bool = true
    ) -> String {
        let serverNames = includeWWW ? "\(domain) www.\(domain)" : domain
        
        return """
        server {
            listen 443 ssl http2;
            listen [::]:443 ssl http2;
            
            server_name \(serverNames);
            root \(rootPath);
            index index.html index.htm index.php;
            
            # SSL Configuration
            ssl_certificate \(certPath);
            ssl_certificate_key \(keyPath);
            
            # SSL Security Settings
            ssl_protocols TLSv1.2 TLSv1.3;
            ssl_prefer_server_ciphers on;
            ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384;
            ssl_session_cache shared:SSL:10m;
            ssl_session_timeout 1d;
            ssl_session_tickets off;
            
            # HSTS (optional but recommended)
            add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
            
            location / {
                try_files $uri $uri/ =404;
            }
            
            # PHP handling (if applicable)
            location ~ \\.php$ {
                include snippets/fastcgi-php.conf;
                fastcgi_pass unix:/var/run/php/php-fpm.sock;
            }
            
            location ~ /\\.ht {
                deny all;
            }
        }
        
        # HTTP to HTTPS redirect
        server {
            listen 80;
            listen [::]:80;
            server_name \(serverNames);
            return 301 https://$server_name$request_uri;
        }
        """
    }
    
    /// Generate command to update Nginx config with SSL
    static func nginxSSLUpdateCommand(
        domain: String,
        certPath: String,
        keyPath: String
    ) -> String {
        let configPath = "/etc/nginx/sites-available/\(domain)"
        
        return """
        # Backup original config
        cp '\(configPath)' '\(configPath).bak' 2>/dev/null || true
        
        # Check if SSL block already exists
        if grep -q 'listen 443 ssl' '\(configPath)'; then
            echo 'SSL already configured'
        else
            # Add SSL listen directive and certificate paths
            sed -i '/listen 80;/a\\    listen 443 ssl http2;' '\(configPath)'
            sed -i '/listen \\[::\\]:80;/a\\    listen [::]:443 ssl http2;' '\(configPath)'
            sed -i '/server_name/a\\    ssl_certificate \(certPath);\\n    ssl_certificate_key \(keyPath);' '\(configPath)'
        fi
        
        # Test and reload
        nginx -t && systemctl reload nginx
        """
    }
    
    // MARK: - Apache SSL Configuration
    
    /// Generate Apache SSL VirtualHost
    static func generateApacheSSLConfig(
        domain: String,
        rootPath: String,
        certPath: String,
        keyPath: String,
        chainPath: String? = nil
    ) -> String {
        let chainDirective = chainPath.map { "SSLCertificateChainFile \($0)" } ?? ""
        
        return """
        <VirtualHost *:443>
            ServerName \(domain)
            ServerAlias www.\(domain)
            DocumentRoot \(rootPath)
            
            SSLEngine on
            SSLCertificateFile \(certPath)
            SSLCertificateKeyFile \(keyPath)
            \(chainDirective)
            
            # SSL Security Settings
            SSLProtocol all -SSLv2 -SSLv3 -TLSv1 -TLSv1.1
            SSLHonorCipherOrder on
            SSLCipherSuite ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384
            
            # HSTS Header
            Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
            
            <Directory \(rootPath)>
                Options Indexes FollowSymLinks
                AllowOverride All
                Require all granted
            </Directory>
            
            ErrorLog ${APACHE_LOG_DIR}/\(domain)-ssl-error.log
            CustomLog ${APACHE_LOG_DIR}/\(domain)-ssl-access.log combined
        </VirtualHost>
        
        # HTTP to HTTPS redirect
        <VirtualHost *:80>
            ServerName \(domain)
            ServerAlias www.\(domain)
            Redirect permanent / https://\(domain)/
        </VirtualHost>
        """
    }
    
    /// Generate command to enable Apache SSL module
    static func apacheEnableSSLCommand() -> String {
        return """
        a2enmod ssl headers rewrite 2>/dev/null || true
        systemctl restart apache2
        """
    }
    
    // MARK: - Config Update Commands
    
    /// Generate full SSL setup command for Nginx with Let's Encrypt paths
    static func letsEncryptNginxSetupCommand(domain: String) -> String {
        return """
        # Test nginx config
        nginx -t && systemctl reload nginx
        """
    }
    
    /// Generate full SSL setup command for Apache with Let's Encrypt paths
    static func letsEncryptApacheSetupCommand(domain: String) -> String {
        return """
        # Enable SSL module if not enabled
        a2enmod ssl 2>/dev/null || true
        
        # Restart Apache
        systemctl restart apache2
        """
    }
}
