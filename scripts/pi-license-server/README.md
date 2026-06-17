# PromptBar license-issuing webhook server

Tiny Flask service that lives on a Raspberry Pi (or any always-on Linux
box), receives Ko-fi shop-order webhooks, signs an Ed25519 license, and
emails the buyer the `.promptbar` file. Fully automated, no manual
license issuance ever again.

The cryptography matches the embedded public key in
`Helpers/LicenseValidator.swift` (`p6N4XJLDCrc9J9BhnT4PlLCQ9QLbENOdmuAE4oM5cCY=`)
so licenses issued by this Pi service are indistinguishable from licenses
issued by `scripts/issue-license.swift` or `scripts/issue_license.py`.

## Architecture

```
Ko-fi shop sale
    │
    │  HTTPS POST (form-encoded, "data" = JSON payload)
    ▼
Cloudflare Tunnel  ─────────►  Raspberry Pi
                                 (gunicorn + Flask on :8000)
                                       │
                                       ├─► Verify token (env)
                                       ├─► Filter for PromptBar item
                                       ├─► Sign Ed25519 license
                                       ├─► Archive to disk
                                       └─► SMTP email to buyer
```

## One-time setup on the Pi

### 1. Install Python + dependencies

```bash
sudo apt update
sudo apt install -y python3 python3-venv python3-pip
mkdir -p /home/pi/promptbar
cd /home/pi/promptbar
python3 -m venv venv
source venv/bin/activate
git clone https://github.com/peterdsp/PromptBar.git /tmp/PromptBar
cp -r /tmp/PromptBar/scripts/pi-license-server license-server
cp license-server/env.example .env
chmod 600 .env
pip install -r license-server/requirements.txt
```

### 2. Copy the private key from your Mac

The key must be the same 32-byte Ed25519 base64 blob that produced the
public key in `LicenseValidator.swift`. Generate it once on your Mac (see
the project root README), then copy it across:

```bash
# From your Mac:
scp scripts/license-private.key pi@RASPBERRY_PI_HOSTNAME:/home/pi/promptbar/
ssh pi@RASPBERRY_PI_HOSTNAME chmod 600 /home/pi/promptbar/license-private.key
```

### 3. Fill in `.env`

```bash
nano /home/pi/promptbar/.env
```

Required:
- `KOFI_VERIFICATION_TOKEN`, found in Ko-fi dashboard → More → API.
- `SMTP_USER`, `SMTP_PASS`, your Gmail address + app-specific password
  from https://myaccount.google.com/apppasswords.
- `PROMPTBAR_LINK_CODES`, the `direct_link_code` of your Ko-fi PromptBar
  listing (find it in any webhook log entry or in the Ko-fi shop edit URL).

### 4. Install the systemd unit

```bash
sudo cp license-server/promptbar-licenses.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable promptbar-licenses
sudo systemctl start promptbar-licenses
sudo systemctl status promptbar-licenses
```

Check it's listening:

```bash
curl http://localhost:8000/health
# {"min_version":"2.0.0","ok":true,"private_key_loaded":true,"smtp_configured":true}
```

### 5. Expose with Cloudflare Tunnel (recommended)

No port forwarding, free TLS, ~5 min setup:

```bash
# Install
curl -L https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 \
  -o cloudflared
chmod +x cloudflared
sudo mv cloudflared /usr/local/bin/

# Login and create the tunnel
cloudflared tunnel login              # opens browser, pick your Cloudflare domain
cloudflared tunnel create promptbar
cloudflared tunnel route dns promptbar licenses.yourdomain.com

# Config file
mkdir -p ~/.cloudflared
cat > ~/.cloudflared/config.yml <<EOF
tunnel: promptbar
credentials-file: /home/pi/.cloudflared/promptbar.json
ingress:
  - hostname: licenses.yourdomain.com
    service: http://localhost:8000
  - service: http_status:404
EOF

# Install as a service
sudo cloudflared service install
sudo systemctl enable cloudflared
sudo systemctl start cloudflared
```

Now `https://licenses.yourdomain.com/webhook` reaches your Pi.

If you don't own a Cloudflare-managed domain, alternatives:

| Tool | Notes |
|---|---|
| ngrok (paid) | Reserved subdomain, ~$10/mo |
| Tailscale Funnel | Free, requires Tailscale on Pi |
| Direct port forward | Configure your router, use Let's Encrypt or DuckDNS |

### 6. Point Ko-fi at the webhook

Ko-fi dashboard → More → API → Webhook URL.
Paste `https://licenses.yourdomain.com/webhook` and save.

Ko-fi sends a test POST you can see in the Pi logs:

```bash
sudo journalctl -u promptbar-licenses -f
tail -f /home/pi/promptbar/access.log
```

## Testing without spending €4.99

Use `curl` from your Mac with a forged payload (the verification token
must match what's in `.env`):

```bash
curl -X POST https://licenses.yourdomain.com/webhook \
  -d 'data={"verification_token":"YOUR_TOKEN","type":"Shop Order","email":"test@example.com","kofi_transaction_id":"test-abc","shop_items":[{"direct_link_code":"b1ef047a6f","variation_name":"PromptBar","quantity":1}]}'
```

Check your inbox for the test email with the `.promptbar` attachment.

## Periodic batch backfill

When you export a fresh Ko-fi `Transaction_All.csv` and want to mass-issue
licenses (e.g. backfilling everyone who bought before the webhook was
live, or re-sending after an inbox migration), use the batch script.
It signs and optionally emails every PromptBar buyer in the CSV, in one
command.

```bash
# 1. scp the latest Ko-fi export to the Pi
scp ~/Downloads/Transaction_All.csv pi@RASPBERRY_PI_HOSTNAME:/home/pi/promptbar/

# 2. SSH in and run the batch issuer
ssh pi@RASPBERRY_PI_HOSTNAME
cd /home/pi/promptbar
source venv/bin/activate

# Dry-run first to see what would happen
python3 license-server/batch_issue_licenses_from_kofi.py \
    --csv Transaction_All.csv \
    --output issued/ \
    --dry-run

# Sign + email everyone, safely skipping anyone already in manifest.csv
python3 license-server/batch_issue_licenses_from_kofi.py \
    --csv Transaction_All.csv \
    --output issued/ \
    --email \
    --env .env \
    --skip-existing \
    --rate-limit 1.0
```

`--rate-limit 1.0` sleeps a second between emails so Gmail doesn't
throttle. For ~150 buyers it takes about 3 minutes.

You can also use this on your Mac without the webhook server, the script
has no Pi-specific dependencies:

```bash
python3 scripts/batch_issue_licenses_from_kofi.py \
    --csv ~/Downloads/Transaction_All.csv \
    --output licenses/
```

The Swift counterpart (`scripts/batch-issue-licenses-from-kofi.swift`)
still works on macOS if you prefer not to install Python deps locally.
Both produce identical signatures, so you can mix and match.

## Updating

When the private key rotates (rare), re-copy `license-private.key` and
restart the service:

```bash
sudo systemctl restart promptbar-licenses
```

When you ship a new major version that needs a fresh license cohort,
bump `PROMPTBAR_MIN_VERSION` in `.env` and restart.

## Operational notes

- Every issued license is also archived in `/home/pi/promptbar/issued/` so
  you can re-send if the email bounces.
- Logs in `/home/pi/promptbar/{access,error,stdout,stderr}.log`.
- The service runs as user `pi`, sandboxed via systemd (`ProtectSystem`,
  `NoNewPrivileges`, read-only home, private tmp).
- The webhook endpoint is idempotent in the sense that re-sending the
  same Ko-fi order id will produce a NEW license file but it will email
  the same buyer again. If duplicate emails are a concern, add a tiny
  SQLite check on `kofi_transaction_id`.

## Serverless alternative (no Pi)

If you'd rather not run hardware, the same logic ports cleanly to:

- Cloudflare Workers (Node ed25519 + Mailgun/Postmark API)
- Vercel functions
- AWS Lambda

The signing payload format and canonical-JSON convention are the same;
only the runtime changes. The Pi version is the cheapest long-term if
you already have the Pi powered on.
