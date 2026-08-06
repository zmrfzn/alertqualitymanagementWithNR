#!/bin/bash

# Nginx Quick Install & Proxy Setup for Instruqt Environment
# Automatically retrieves SSL certificates from GCP metadata service
# Run with: sudo bash nginx-setup.sh

set -e  # Exit on any error

echo "🚀 Starting nginx installation and HTTPS proxy setup for Instruqt environment..."

# Create SSL directories if they don't exist
echo "📁 Creating SSL certificate directories..."
mkdir -p /etc/ssl/certs
mkdir -p /etc/ssl/private

# Retrieve SSL certificates from GCP metadata service
echo "🔐 Retrieving SSL certificates from GCP metadata service..."
curl -s -o /etc/ssl/certs/sandbox.crt -H "Metadata-Flavor: Google" \
    "http://metadata.google.internal/computeMetadata/v1/instance/attributes/ssl-certificate"

curl -s -o /etc/ssl/private/sandbox.key -H "Metadata-Flavor: Google" \
    "http://metadata.google.internal/computeMetadata/v1/instance/attributes/ssl-certificate-key"

# Verify certificates were downloaded
if [ ! -s /etc/ssl/certs/sandbox.crt ]; then
    echo "❌ Error: Failed to retrieve SSL certificate"
    exit 1
fi

if [ ! -s /etc/ssl/private/sandbox.key ]; then
    echo "❌ Error: Failed to retrieve SSL private key"
    exit 1
fi

# Set proper permissions on private key
chmod 600 /etc/ssl/private/sandbox.key
chmod 644 /etc/ssl/certs/sandbox.crt

echo "✅ SSL certificates retrieved successfully"

# Get hostname and sandbox ID from environment or metadata
HOSTNAME=$(hostname)
if [ -z "$_SANDBOX_ID" ]; then
    echo "⚠️  _SANDBOX_ID not set in environment, attempting to retrieve from metadata..."
    _SANDBOX_ID=$(curl -s -H "Metadata-Flavor: Google" \
        "http://metadata.google.internal/computeMetadata/v1/instance/attributes/sandbox-id" 2>/dev/null || echo "")
fi

if [ -z "$_SANDBOX_ID" ]; then
    echo "❌ Error: Could not determine SANDBOX_ID"
    echo "Please set _SANDBOX_ID environment variable or ensure it's available in metadata"
    exit 1
fi

DOMAIN="${HOSTNAME}.${_SANDBOX_ID}.instruqt.io"
echo "🌐 Configuring for domain: $DOMAIN"

# Update package list
echo "📦 Updating package list..."
apt update

# Install nginx
echo "⚙️  Installing nginx..."
apt install -y nginx

# Start and enable nginx
echo "▶️  Starting nginx service..."
systemctl start nginx
systemctl enable nginx

# Create backup of default config
echo "💾 Backing up default nginx config..."
cp /etc/nginx/sites-available/default /etc/nginx/sites-available/default.backup

# Create new nginx configuration with HTTPS and Instruqt certificates
echo "📝 Creating HTTPS proxy configuration for Instruqt environment..."
cat > /etc/nginx/sites-available/default << EOL
# HTTP server - redirect to HTTPS
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name ${DOMAIN} *.${HOSTNAME}.${_SANDBOX_ID}.instruqt.io;
    
    # Redirect all HTTP requests to HTTPS
    return 301 https://\$server_name\$request_uri;
}

# HTTPS server - proxy to app on port 3000
server {
    listen 443 ssl http2 default_server;
    listen [::]:443 ssl http2 default_server;
    
    server_name ${DOMAIN} *.${HOSTNAME}.${_SANDBOX_ID}.instruqt.io;

    # SSL Configuration with Instruqt certificates
    ssl_certificate /etc/ssl/certs/sandbox.crt;
    ssl_certificate_key /etc/ssl/private/sandbox.key;
    
    # SSL Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options SAMEORIGIN always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        proxy_redirect off;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffer settings for better performance
        proxy_buffering on;
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;
    }

    # Health check endpoint (optional)
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOL

# Test nginx configuration
echo "🔍 Testing nginx configuration..."
nginx -t

# Reload nginx to apply changes
echo "🔄 Reloading nginx..."
systemctl reload nginx

# Configure firewall for HTTP and HTTPS (if ufw is available)
if command -v ufw &> /dev/null; then
    echo "🔥 Configuring firewall..."
    ufw allow 'Nginx Full'
fi

# Check nginx status
echo "📊 Checking nginx status..."
systemctl status nginx --no-pager -l

# Display certificate information
echo "🔍 Certificate information:"
openssl x509 -in /etc/ssl/certs/sandbox.crt -noout -subject -dates -issuer | head -10

echo ""
echo "✅ Nginx installation and HTTPS proxy setup complete for Instruqt!"
echo ""
echo "📋 Summary:"
echo "   - Nginx is running with SSL/HTTPS enabled using Instruqt certificates"
echo "   - HTTP requests (port 80) are redirected to HTTPS (port 443)"
echo "   - HTTPS requests are proxied to localhost:3000"
echo "   - Certificates automatically retrieved from GCP metadata service"
echo "   - Configured for domain: $DOMAIN"
echo "   - Wildcard support: *.${HOSTNAME}.${_SANDBOX_ID}.instruqt.io"
echo ""
echo "🎯 Access your app:"
echo "   - HTTPS: https://$DOMAIN"
echo "   - HTTP: http://$DOMAIN (redirects to HTTPS)"
echo ""
echo "🔒 SSL Configuration:"
echo "   - TLS 1.2 and 1.3 enabled"
echo "   - Security headers configured"
echo "   - HTTP/2 enabled"
echo "   - Certificate: /etc/ssl/certs/sandbox.crt"
echo "   - Private Key: /etc/ssl/private/sandbox.key"
echo ""
echo "🛠️  Useful commands:"
echo "   - Check nginx status: sudo systemctl status nginx"
echo "   - Test SSL config: sudo nginx -t"
echo "   - Reload nginx: sudo systemctl reload nginx"
echo "   - Edit config: sudo nano /etc/nginx/sites-available/default"
echo "   - View certificate: sudo openssl x509 -in /etc/ssl/certs/sandbox.crt -text -noout"
echo "   - Test HTTPS: curl -I https://$DOMAIN"
echo ""
echo "📝 Environment Variables:"
echo "   - HOSTNAME: $HOSTNAME"
echo "   - SANDBOX_ID: $_SANDBOX_ID"
echo "   - DOMAIN: $DOMAIN"