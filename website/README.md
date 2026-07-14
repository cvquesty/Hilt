# Hilt publicity site (hiltutil.org)

Static marketing + App Store support pages, deployed to:

- **Host:** server.questy.org (`68.183.117.120`)
- **Docroot:** `/var/www/html/hilt`
- **Vhost:** `hiltutil.org` (Apache `29-hiltutil.org*.conf`)
- **TLS:** Let's Encrypt → `/etc/letsencrypt/live/hiltutil.org/`

## Public URLs (App Store Connect)

| Field | URL |
|-------|-----|
| Marketing | https://hiltutil.org/ |
| Support | https://hiltutil.org/support.html |
| Privacy Policy | https://hiltutil.org/privacy.html |

## Deploy

```bash
rsync -avz --delete website/index.html website/support.html website/privacy.html \
  jsheets@68.183.117.120:/tmp/hilt-web/
rsync -avz --delete website/assets/ jsheets@68.183.117.120:/tmp/hilt-web/assets/
ssh jsheets@68.183.117.120 'sudo rsync -a /tmp/hilt-web/ /var/www/html/hilt/ && sudo chown -R apache:apache /var/www/html/hilt'
```

(Or rsync directly into a writeable docroot as done at initial setup.)
