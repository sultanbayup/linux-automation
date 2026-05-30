# web/

Scripts for web server setup and SSL certificate automation on Ubuntu/Debian.

---

## Scripts

| Script | What it does |
|--------|-------------|
| [`lemp/nginx-lemp.sh`](lemp/) | One-command LEMP stack — Nginx, PHP-FPM, MariaDB, optional SSL |
| [`ssl/ssl-auto.sh`](ssl/) | Standalone SSL automation — works with any running Nginx or Apache |

`nginx-lemp.sh` calls `ssl-auto.sh` internally when SSL is enabled — no duplicated certbot logic.

See the README in each subfolder for usage details.
