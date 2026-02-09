import os

# 1. Pull the Secret Key from your .env
# This MUST match the variable name in your .env file
SECRET_KEY = os.environ.get('SUPERSET_SECRET_KEY')

# 2. Disable HTML Sanitization to allow your buttons
HTML_SANITIZATION = False

# 3. Allow specific attributes for your buttons
HTML_SANITIZATION_ALLOWED_ATTRIBUTES = {
    'a': ['href', 'title', 'target', 'style', 'class'],
    'div': ['style', 'class'],
    'span': ['style', 'class'],
}

# 4. Mandatory for modern Superset behind Docker/Proxies
ENABLE_PROXY_FIX = True
