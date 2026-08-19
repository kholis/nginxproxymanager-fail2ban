# Nginx Proxy Manager - Fail2ban Configuration

Fail2ban filters and jails to protect your Nginx Proxy Manager installation from attacks.

## Features

- ✅ Blocks `.env`, `.git`, and sensitive file access
- ✅ Blocks WordPress attack paths (wp-login, wp-admin, wp-config, wp-content)
- ✅ Blocks PHP exploits (xmlrpc.php, phpunit, composer, laravel, vendor, eval-stdin.php)
- ✅ Blocks directory traversal attacks
- ✅ Rate limiting for rapid scanners/bots
- ✅ Configurable NPM data directory path

## Quick Start

```bash
git clone <repo-url>
cd nginxproxymanager-fail2ban
sudo ./install.sh
```

For custom NPM data directory:
```bash
NPM_DATA_DIR=/your/path ./install.sh
# or
cp .env.example .env && nano .env  # Edit NPM_DATA_DIR
sudo ./install.sh
```

## Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `NPM_DATA_DIR` | Path to NPM data directory | `/apps/nginxproxymanager/data` |

### Common NPM Data Paths

| Installation Type | Path |
|-------------------|------|
| Docker Compose | `/apps/nginxproxymanager/data` |
| Docker Volume | `/var/lib/docker/volumes/npm_data/_data` |
| Manual Install | `/opt/nginxproxymanager/data` |
| Snap Package | `/var/snap/nginxproxymanager/common/data` |

## Deployment Scenarios

```bash
# Docker Compose (default)
sudo ./install.sh

# Docker Volume
VOLUME_PATH=$(docker volume inspect npm_data | grep Mountpoint | cut -d'"' -f4)
NPM_DATA_DIR=$VOLUME_PATH sudo ./install.sh

# Manual Install
echo "NPM_DATA_DIR=/opt/nginxproxymanager/data" > .env
sudo ./install.sh

# Snap Package
NPM_DATA_DIR=/var/snap/nginxproxymanager/common/data sudo ./install.sh
```

## What's Included

### Filters

| Filter | Purpose |
|--------|---------|
| `nginx-proxy-manager.conf` | Blocks sensitive file access (.env, .git, WordPress, PHP exploits) |
| `nginx-proxy-manager-error.conf` | Blocks error log attacks (RCE, traversal) |
| `nginx-proxy-manager-rapid.conf` | Rate limiting for scanners |

### Jails

| Jail | Max Retry | Find Time | Ban Time | Purpose |
|------|-----------|-----------|----------|---------|
| `nginx-proxy-manager` | 2 | 1h | 1 day | Sensitive file access |
| `nginx-proxy-manager-error` | 3 | 10m | 2h | Error log attacks |
| `nginx-proxy-manager-rapid` | 30 | 1m | 2h | Rapid scanners |

## What Gets Blocked

**Sensitive Files:** `.env`, `.git`, `.htaccess`, `.htpasswd`, `config.php`, `wp-login.php`, `wp-admin`, `wp-config.php`, `wp-content`

**PHP Exploits:** `xmlrpc.php`, `phpunit`, `composer`, `laravel`, `vendor`, `eval-stdin.php`

**Directory Traversal:** `../`, `/etc/`, `/var/`, `/usr/`

**Rapid Access:** IPs making 30+ requests in 1 minute


## Commands

```bash
# Check jail status
sudo fail2ban-client status nginx-proxy-manager

# View banned IPs
sudo fail2ban-client status nginx-proxy-manager

# View monitored logs
sudo fail2ban-client get nginx-proxy-manager logpath

# Unban IP
sudo fail2ban-client set nginx-proxy-manager unbanip <IP>

# Test regex patterns
fail2ban-regex ${NPM_DATA_DIR}/logs/fallback_access.log /etc/fail2ban/filter.d/nginx-proxy-manager.conf

# Reload after changes
sudo fail2ban-client reload
```

## Customization

### Change NPM Data Directory
```bash
sudo nano /etc/fail2ban/jail.d/nginx-proxy-manager.local
# Update logpath lines
sudo fail2ban-client reload
```

### Adjust Ban Times
Edit jail file (`bantime`, `maxretry`, `findtime`):
```bash
sudo nano /etc/fail2ban/jail.d/nginx-proxy-manager.local
sudo fail2ban-client reload
```

### Allow More Webhooks
```bash
sudo nano /etc/fail2ban/filter.d/nginx-proxy-manager.conf
# Add to ignoreregex:
ignoreregex = ^\[.*?\] - 200 200 - POST .* ".*\/your-webhook.*"
sudo fail2ban-client reload nginx-proxy-manager
```

### Exclude IPs
Create `/etc/fail2ban/jail.d/whitelist.local`:
```ini
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1
          110.239.72.0/24  # Your trusted network
```

## Troubleshooting

### Logs Not Being Monitored
```bash
sudo fail2ban-client get nginx-proxy-manager logpath
ls -la ${NPM_DATA_DIR}/logs/*_access.log
```

### Jails Not Starting
```bash
sudo tail -f /var/log/fail2ban.log
sudo fail2ban-client -d nginx-proxy-manager
```

### Webhook Being Blocked
```bash
grep "smn-webhook" ${NPM_DATA_DIR}/logs/*_access.log | head -1 > /tmp/test.log
fail2ban-regex /tmp/test.log /etc/fail2ban/filter.d/nginx-proxy-manager.conf
```

## File Structure

```
nginxproxymanager-fail2ban/
├── filter.d/
│   ├── nginx-proxy-manager.conf
│   ├── nginx-proxy-manager-error.conf
│   └── nginx-proxy-manager-rapid.conf
├── jail.d/
│   ├── nginx-proxy-manager.local
│   ├── nginx-proxy-manager-error.local
│   └── nginx-proxy-manager-rapid.local
├── .env.example
├── install.sh
├── test-path-replacement.sh
└── README.md
```

## Uninstallation

```bash
sudo rm /etc/fail2ban/jail.d/nginx-proxy-manager*.local
sudo rm /etc/fail2ban/filter.d/nginx-proxy-manager*.conf
sudo fail2ban-client reload
```

## License

MIT License
