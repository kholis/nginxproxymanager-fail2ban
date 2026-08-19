#!/bin/bash
# Installation script for fail2ban configuration for Nginx Proxy Manager

set -e

# ============================================================================
# LOAD ENVIRONMENT VARIABLES
# ============================================================================
# Load .env file if it exists
if [ -f .env ]; then
    echo "📄 Loading .env file..."
    set -a
    . .env
    set +a
fi

# ============================================================================
# CONFIGURATION
# ============================================================================
# NPM_DATA_DIR - Path to Nginx Proxy Manager data directory
# Default: /apps/nginxproxymanager/data
# Can be overridden by:
#   1. Setting NPM_DATA_DIR environment variable
#   2. Creating a .env file with NPM_DATA_DIR=/your/path
# ============================================================================
NPM_DATA_DIR="${NPM_DATA_DIR:-/apps/nginxproxymanager/data}"

# Paths
FILTER_DIR="/etc/fail2ban/filter.d"
JAIL_DIR="/etc/fail2ban/jail.d"

echo "========================================="
echo "Fail2ban Configuration for Nginx Proxy Manager"
echo "========================================="
echo ""
echo "Configuration:"
echo "  NPM_DATA_DIR: ${NPM_DATA_DIR}"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ Error: Please run this script with sudo"
    exit 1
fi

# Check if NPM data directory exists
if [ ! -d "${NPM_DATA_DIR}/logs" ]; then
    echo "❌ Error: NPM log directory not found: ${NPM_DATA_DIR}/logs"
    echo ""
    echo "Please set the correct NPM_DATA_DIR:"
    echo "  Option 1: Set environment variable"
    echo "    NPM_DATA_DIR=/path/to/npm/data ./install.sh"
    echo ""
    echo "  Option 2: Create .env file"
    echo "    cp .env.example .env"
    echo "    nano .env  # Edit NPM_DATA_DIR"
    echo "    sudo ./install.sh"
    echo ""
    echo "Common NPM data directory locations:"
    echo "  - /apps/nginxproxymanager/data (docker compose)"
    echo "  - /var/lib/docker/volumes/npm_data/_data (docker volume)"
    echo "  - /opt/nginxproxymanager/data (manual)"
    echo "  - /var/snap/nginxproxymanager/common/data (snap)"
    exit 1
fi

# Create temp directory for processed files
TEMP_DIR=$(mktemp -d)
trap "rm -rf ${TEMP_DIR}" EXIT

# ============================================================================
# INSTALL FILTERS
# ============================================================================
echo "📋 Copying filters to ${FILTER_DIR}..."
if cp filter.d/nginx-proxy-manager*.conf "${FILTER_DIR}/" 2>/dev/null; then
    echo "   ✓ Filters installed"
else
    echo "   ❌ Failed to copy filters"
    exit 1
fi

# ============================================================================
# INSTALL JAILS (with path substitution)
# ============================================================================
echo "📋 Copying jails to ${JAIL_DIR}..."

# Process each jail file, replacing {{NPM_DATA_DIR}} with actual path
jails_installed=0
jails_failed=0

for jail_file in jail.d/nginx-proxy-manager*.local; do
    if [ -f "$jail_file" ]; then
        jail_name=$(basename "$jail_file")
        echo "   Processing: ${jail_name}"
        if sed "s|{{NPM_DATA_DIR}}|${NPM_DATA_DIR}|g" "$jail_file" > "${TEMP_DIR}/${jail_name}"; then
            if cp "${TEMP_DIR}/${jail_name}" "${JAIL_DIR}/"; then
                ((jails_installed++))
                echo "     ✓ Installed with path: ${NPM_DATA_DIR}/logs"
            else
                ((jails_failed++))
                echo "     ✗ Failed to copy"
            fi
        else
            ((jails_failed++))
            echo "     ✗ Failed to process"
        fi
    fi
done

if [ $jails_installed -eq 0 ]; then
    echo "   ❌ No jails were installed"
    exit 1
fi

echo "   ✓ $jails_installed jail(s) installed successfully"
if [ $jails_failed -gt 0 ]; then
    echo "   ⚠ $jails_failed jail(s) failed to install"
fi

# ============================================================================
# TEST REGEX PATTERNS
# ============================================================================
echo ""
echo "🧪 Testing regex patterns..."
echo "==============================================="

# Test access log filter if fallback_access.log exists
if [ -f "${NPM_DATA_DIR}/logs/fallback_access.log" ]; then
    echo "Testing access log filter..."
    if fail2ban-regex "${NPM_DATA_DIR}/logs/fallback_access.log" "${FILTER_DIR}/nginx-proxy-manager.conf" 2>&1 | head -5; then
        echo "   ✓ Access log filter test completed"
    fi
else
    echo "⚠ Warning: fallback_access.log not found, skipping access log test"
fi
echo "==============================================="

# Test error log filter if fallback_error.log exists
if [ -f "${NPM_DATA_DIR}/logs/fallback_error.log" ]; then
    echo "Testing error log filter..."
    if fail2ban-regex "${NPM_DATA_DIR}/logs/fallback_error.log" "${FILTER_DIR}/nginx-proxy-manager-error.conf" 2>&1 | head -5; then
        echo "   ✓ Error log filter test completed"
    fi
else
    echo "⚠ Warning: fallback_error.log not found, skipping error log test"
fi
echo "==============================================="

# ============================================================================
# RESTART FAIL2BAN
# ============================================================================
echo ""
echo "🔄 Restarting fail2ban..."
if systemctl is-active --quiet fail2ban; then
    if systemctl restart fail2ban; then
        echo "   ✓ Fail2ban restarted successfully"
    else
        echo "   ⚠ Warning: Fail2ban restart had issues"
        echo "   Check status with: sudo systemctl status fail2ban"
    fi
else
    echo "   ℹ Fail2ban is not running, starting it..."
    if systemctl start fail2ban; then
        echo "   ✓ Fail2ban started successfully"
    else
        echo "   ⚠ Warning: Failed to start fail2ban"
        exit 1
    fi
fi

# ============================================================================
# SHOW STATUS
# ============================================================================
echo ""
echo "========================================="
echo "✅ Installation complete!"
echo "========================================="
echo ""
echo "Installed Jails:"
jail_list=("nginx-proxy-manager" "nginx-proxy-manager-error" "nginx-proxy-manager-rapid")
for jail in "${jail_list[@]}"; do
    if sudo fail2ban-client status "$jail" &>/dev/null; then
        echo "   ✓ ${jail}"
    else
        echo "   ✗ ${jail} (not active)"
    fi
done
echo ""
echo "Log paths monitored:"
echo "   ${NPM_DATA_DIR}/logs/*_access.log"
echo "   ${NPM_DATA_DIR}/logs/*_error.log"
echo "   ${NPM_DATA_DIR}/logs/fallback_access.log"
echo "   ${NPM_DATA_DIR}/logs/fallback_error.log"
echo ""
echo "Useful Commands:"
echo "  Check status:"
echo "    sudo fail2ban-client status nginx-proxy-manager"
echo "    sudo fail2ban-client status nginx-proxy-manager-error"
echo "    sudo fail2ban-client status nginx-proxy-manager-rapid"
echo ""
echo "  View banned IPs:"
echo "    sudo fail2ban-client status nginx-proxy-manager"
echo ""
echo "  Unban an IP:"
echo "    sudo fail2ban-client set nginx-proxy-manager unbanip <IP>"
echo ""
echo "  View monitored logs:"
echo "    sudo fail2ban-client get nginx-proxy-manager logpath"
echo "========================================="
