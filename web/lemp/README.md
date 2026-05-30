# web/lemp/

One-command LEMP stack setup on Ubuntu/Debian.

---

## `nginx-lemp.sh`

Installs Nginx, PHP-FPM, MariaDB, and optionally configures SSL via Let's Encrypt. When SSL is enabled, delegates to [`../ssl/ssl-auto.sh`](../ssl/) — no duplicated certbot logic.

**Run as root:**

```bash
curl -fsSL https://raw.githubusercontent.com/sultanbayup/linux-automation/main/web/lemp/nginx-lemp.sh | sudo bash
```

Or locally (SSL will use the local `ssl-auto.sh` automatically):

```bash
sudo bash web/lemp/nginx-lemp.sh
```

Prompts for domain name, PHP version, MariaDB root password, and whether to enable SSL.

Blog: [sultanbp.com/blog/one-command-lemp-stack](https://sultanbp.com/blog/one-command-lemp-stack/)
