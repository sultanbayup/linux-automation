# web/ssl/

Standalone SSL certificate automation via Let's Encrypt. Works with any running Nginx or Apache.

---

## `ssl-auto.sh`

Issues a Let's Encrypt certificate for a domain, configures HTTPS on the detected web server, and verifies auto-renewal is active. Includes preflight checks for port 80 availability and DNS resolution before touching anything.

**Can be used two ways:**

**1. Standalone — run directly on a server with Nginx or Apache already running:**

```bash
curl -fsSL https://raw.githubusercontent.com/sultanbayup/linux-automation/main/web/ssl/ssl-auto.sh | sudo bash
```

Or locally:

```bash
sudo bash web/ssl/ssl-auto.sh
```

Prompts for domain, whether to include `www`, and an optional email for expiry notices.

**2. Non-interactive — called from another script via environment variables:**

```bash
DOMAIN=example.com INCLUDE_WWW=y CERT_EMAIL=you@example.com WEBSERVER=nginx \
  bash web/ssl/ssl-auto.sh
```

| Variable | Required | Description |
|----------|----------|-------------|
| `DOMAIN` | Yes | Domain to issue certificate for |
| `INCLUDE_WWW` | No | Include `www.DOMAIN` in cert (`y`/`N`, default: `N`) |
| `CERT_EMAIL` | No | Email for Let's Encrypt expiry notices (omit to skip) |
| `WEBSERVER` | No | `nginx` or `apache` — auto-detected if not set |

**Preflight checks (run before making any changes):**
- Port 80 is listening (required for ACME HTTP-01 challenge)
- DNS resolves to this server (best-effort, warns if mismatch)
- Existing certificate detected (prompts before renewing)
