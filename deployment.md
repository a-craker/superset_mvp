# Superset Reverse Proxy Setup Guide

A guide to exposing a Docker-deployed Apache Superset instance to the internet via Nginx and Let's Encrypt SSL.

---

## Prerequisites

Before starting, ensure the following are in place:

- A running Docker Superset instance (accessible locally on port `8088`)
- A registered domain name with an **A record pointing to the server's public IP**
- `sudo` access on the host machine
- Ports **80** and **443** open on the server

---

## Step 1 — Open Firewall Ports

Allow HTTP and HTTPS traffic through the firewall (or adjust IP tables directly):

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw reload
sudo ufw status
```
---

## Step 2 — Install Nginx and Certbot

```bash
sudo apt update
sudo apt install -y nginx certbot python3-certbot-nginx
```

---

## Step 3 — Create the Nginx Server Block

Create a new config file for your domain:

```bash
sudo nano /etc/nginx/sites-available/your.domain.com
```

Paste the following, replacing `your.domain.com` with your actual domain:

```nginx
server {
    listen 80;
    server_name your.domain.com;

    location / {
        proxy_pass http://127.0.0.1:8088;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support (required for Superset async features)
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        # Timeouts for long-running queries
        proxy_read_timeout 300s;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
    }
}
```

Enable the site and reload Nginx:

```bash
sudo ln -s /etc/nginx/sites-available/your.domain.com /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

---

## Step 4 — Obtain SSL Certificate via Certbot

```bash
sudo certbot --nginx -d your.domain.com
```

When prompted:
- Enter your email address
- Agree to the Terms of Service
- Choose **option 2** to redirect HTTP → HTTPS automatically

Certbot will modify your Nginx config to add SSL and set up the HTTP redirect automatically.

---

## Step 5 — Update Superset Config

Open your `superset_config.py` and add `ENABLE_PROXY_FIX = True` under the server basics section:

```python
# --- Server Basics ---
SUPERSET_WEBSERVER_ADDRESS = "0.0.0.0"
SUPERSET_WEBSERVER_PORT = 8088
SECRET_KEY = os.getenv("SUPERSET_SECRET_KEY")
ENABLE_PROXY_FIX = True
```

This tells Superset to trust the `X-Forwarded-Proto` header from Nginx so that internal URL generation, OAuth callbacks, and embedded dashboards all use `https://` correctly.

Also ensure your Talisman config has `force_https` set to `False`, since Nginx handles HTTPS termination — Superset does not need to enforce it internally:

```python
TALISMAN_CONFIG = {
    ...
    "force_https": False,
}
```

Restart the Superset container to apply changes:

```bash
docker restart superset_app
```

---

## Step 6 — Verify Auto-Renewal

Certbot installs a systemd timer that renews certificates automatically before expiry. Confirm it is active:

```bash
sudo systemctl status certbot.timer
```

Run a dry-run renewal test to confirm everything is working:

```bash
sudo certbot renew --dry-run
```

---

## Verification Checklist

| Check | Command |
|---|---|
| Nginx config is valid | `sudo nginx -t` |
| Nginx is running | `sudo systemctl status nginx` |
| Certificate is active | `sudo certbot certificates` |
| HTTPS response | `curl -I https://your.domain.com` |
| Nginx error logs | `sudo tail -f /var/log/nginx/error.log` |

A successful `curl` response will show `HTTP/2 200` or a redirect to the Superset login page.

---

## Step 7 — Install and Configure Fail2ban

Fail2ban monitors log files and automatically bans IPs that show malicious behaviour such as repeated failed logins or bot scanning.

### Install Fail2ban

```bash
sudo apt update
sudo apt install -y fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### Create a local config file

Always use `.local` files to override defaults — never edit `.conf` files directly as they get overwritten on updates:

```bash
sudo nano /etc/fail2ban/jail.local
```

Paste the following:

```ini
[DEFAULT]
# Ban duration (10 minutes)
bantime  = 600
# Time window to count failures
findtime = 600
# Number of failures before ban
maxretry = 5
# Ignore your own server and localhost
ignoreip = 127.0.0.1/8 ::1

[nginx-http-auth]
enabled  = true
port     = http,https
logpath  = /var/log/nginx/error.log

[nginx-limit-req]
enabled  = true
port     = http,https
logpath  = /var/log/nginx/error.log
maxretry = 10

[nginx-botsearch]
enabled  = true
port     = http,https
logpath  = /var/log/nginx/access.log
maxretry = 2

[sshd]
enabled  = true
port     = ssh
maxretry = 5
```

### Create a Superset-specific jail

Superset's login endpoint is the most likely brute-force target. Create a custom filter:

```bash
sudo nano /etc/fail2ban/filter.d/superset-auth.conf
```

Paste:

```ini
[Definition]
failregex = ^<HOST> .* "POST /login/.*" (401|403) .*$
            ^<HOST> .* "POST /api/v1/security/login.*" (401|403) .*$
ignoreregex =
```

Then add the jail to `jail.local`:

```bash
sudo nano /etc/fail2ban/jail.local
```

Append at the bottom:

```ini
[superset-auth]
enabled  = true
port     = http,https
filter   = superset-auth
logpath  = /var/log/nginx/access.log
maxretry = 5
findtime = 300
bantime  = 3600
```

This bans any IP that fails login **5 times in 5 minutes** for **1 hour**.

### Restart and verify

```bash
sudo systemctl restart fail2ban

# Check all jails are active
sudo fail2ban-client status

# Check a specific jail
sudo fail2ban-client status superset-auth
sudo fail2ban-client status nginx-botsearch
```

### Fail2ban management commands

| Action | Command |
|---|---|
| See all active jails | `sudo fail2ban-client status` |
| Check banned IPs | `sudo fail2ban-client status superset-auth` |
| Unban an IP | `sudo fail2ban-client set superset-auth unbanip <IP>` |
| Manually ban an IP | `sudo fail2ban-client set superset-auth banip <IP>` |
| Tail the Fail2ban log | `sudo tail -f /var/log/fail2ban.log` |
| Test a filter against logs | `sudo fail2ban-regex /var/log/nginx/access.log /etc/fail2ban/filter.d/superset-auth.conf` |

### Optional — Nginx rate limiting (first layer of defence)

Add rate limiting directly in Nginx as a first layer before Fail2ban even kicks in. Edit your site config:

```bash
sudo nano /etc/nginx/sites-available/your.domain.com
```

Add a rate limit zone at the top (outside the `server` block) and a dedicated login location block:

```nginx
# At the top of the file, before server {}
limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;

server {
    ...

    # Throttle login endpoint specifically
    location ~* ^/login {
        limit_req zone=login burst=5 nodelay;
        proxy_pass http://127.0.0.1:8088;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location / {
        proxy_pass http://127.0.0.1:8088;
        ...
    }
}
```

Reload Nginx to apply:

```bash
sudo nginx -t && sudo systemctl reload nginx
```

This limits login attempts to **5 per minute per IP** at the Nginx level, with Fail2ban then banning repeat offenders at the firewall level — two layers of protection.

---

## Final Nginx Config (Post-Certbot)

After Certbot runs, your Nginx config will look like this:

```nginx
server {
    listen 80;
    server_name your.domain.com;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name your.domain.com;

    ssl_certificate /etc/letsencrypt/live/your.domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your.domain.com/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    location / {
        proxy_pass http://127.0.0.1:8088;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";

        proxy_read_timeout 300s;
        proxy_connect_timeout 300s;
        proxy_send_timeout 300s;
    }
}
```