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

Allow HTTP and HTTPS traffic through the firewall:

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw reload
sudo ufw status
```

> If you are using a cloud provider (AWS, GCP, Azure, etc.), also open ports 80 and 443 in the instance's security group or firewall rules via the provider's console.

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