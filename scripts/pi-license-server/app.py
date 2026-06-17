#!/usr/bin/env python3
"""
PromptBar license-issuing webhook server, designed to run 24/7 on a
Raspberry Pi (or any small Linux box).

Receives Ko-fi shop-order webhooks, verifies the verification token,
filters for PromptBar purchases, signs a license with the private
Ed25519 key, and emails the buyer the .promptbar file as an attachment.

See README.md in this folder for setup (Cloudflare Tunnel, SMTP creds,
systemd unit).
"""

import os
import json
import logging
import smtplib
import sys
from datetime import datetime, timezone
from email.message import EmailMessage
from base64 import b64decode, b64encode

from flask import Flask, request, jsonify

try:
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
except ImportError:
    print("ERROR: pip3 install cryptography flask", file=sys.stderr)
    sys.exit(1)


app = Flask(__name__)
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s"
)
log = logging.getLogger("promptbar-licenses")


# ---------------------------------------------------------------------------
# Config from environment

KOFI_VERIFICATION_TOKEN = os.environ.get("KOFI_VERIFICATION_TOKEN", "")
PRIVATE_KEY_PATH        = os.environ.get("PROMPTBAR_PRIVATE_KEY",
                                         "/home/pi/promptbar/license-private.key")
MIN_VERSION             = os.environ.get("PROMPTBAR_MIN_VERSION", "2.0.0")
LOG_DIR                 = os.environ.get("PROMPTBAR_LOG_DIR",
                                         "/home/pi/promptbar/issued")

SMTP_HOST = os.environ.get("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = int(os.environ.get("SMTP_PORT", "587"))
SMTP_USER = os.environ.get("SMTP_USER", "")
SMTP_PASS = os.environ.get("SMTP_PASS", "")
SMTP_FROM = os.environ.get("SMTP_FROM", SMTP_USER)
SMTP_FROM_NAME = os.environ.get("SMTP_FROM_NAME", "Petros Dhespollari")

# Which Ko-fi shop items count as PromptBar purchases. Ko-fi sends a
# direct_link_code per item; you can also match on the variation_name
# field. Comma-separated env var, falls back to a name substring check.
PROMPTBAR_LINK_CODES = set(filter(
    None,
    (s.strip() for s in os.environ.get("PROMPTBAR_LINK_CODES", "").split(","))
))
PROMPTBAR_NAME_MATCH = os.environ.get("PROMPTBAR_NAME_MATCH", "promptbar").lower()


# ---------------------------------------------------------------------------
# Crypto: load the Ed25519 private key once at startup.

def _load_private_key(path: str) -> Ed25519PrivateKey:
    with open(path, "r") as f:
        raw_b64 = f.read().strip()
    raw = b64decode(raw_b64)
    if len(raw) != 32:
        raise RuntimeError(f"Expected 32-byte Ed25519 key in {path}, got {len(raw)}")
    return Ed25519PrivateKey.from_private_bytes(raw)


try:
    PRIVATE_KEY = _load_private_key(PRIVATE_KEY_PATH)
    log.info("Loaded private key from %s", PRIVATE_KEY_PATH)
except Exception as e:
    log.error("Failed to load private key: %s", e)
    PRIVATE_KEY = None


def _canonical_json(obj: dict) -> bytes:
    return json.dumps(obj, separators=(",", ":"), sort_keys=True).encode("utf-8")


def issue_license(email: str, order_id: str) -> dict:
    issued_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    canonical = {
        "email": email.lower().strip(),
        "issued_at": issued_at,
        "order_id": order_id.strip(),
        "product": "PromptBar",
        "min_version": MIN_VERSION,
    }
    signature = PRIVATE_KEY.sign(_canonical_json(canonical))
    canonical["signature"] = b64encode(signature).decode("ascii")
    return canonical


# ---------------------------------------------------------------------------
# Email delivery

EMAIL_SUBJECT = "Your PromptBar 2.0 license"
EMAIL_BODY = """Hey,

Thanks for buying PromptBar 2.0. Two things attached/linked:

1. Your personal .promptbar license file (attached).
2. The signed and notarized .pkg installer:
   https://github.com/peterdsp/PromptBar/releases/latest

Install steps:

  1. Open the .pkg, install to Applications.
  2. Launch PromptBar from Applications.
  3. On the welcome screen, drop the .promptbar file (or paste its contents).
  4. Done. The license is stored in your macOS Keychain.

Reply to this email if anything breaks.

Thanks for backing the project.

Petros
peterdsp.dev
"""


def send_license_email(to_email: str, license_blob: dict):
    msg = EmailMessage()
    msg["From"] = f"{SMTP_FROM_NAME} <{SMTP_FROM}>"
    msg["To"] = to_email
    msg["Subject"] = EMAIL_SUBJECT
    msg.set_content(EMAIL_BODY)

    license_text = json.dumps(license_blob, indent=2, sort_keys=True)
    msg.add_attachment(
        license_text.encode("utf-8"),
        maintype="application",
        subtype="json",
        filename="license.promptbar"
    )

    with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=30) as smtp:
        smtp.ehlo()
        smtp.starttls()
        smtp.login(SMTP_USER, SMTP_PASS)
        smtp.send_message(msg)
    log.info("Emailed license to %s", to_email)


# ---------------------------------------------------------------------------
# Routes

@app.route("/health", methods=["GET"])
def health():
    return jsonify({
        "ok": True,
        "private_key_loaded": PRIVATE_KEY is not None,
        "min_version": MIN_VERSION,
        "smtp_configured": bool(SMTP_USER and SMTP_PASS),
    })


@app.route("/activate", methods=["POST"])
def activate():
    """
    App-driven activation: the buyer types their Ko-fi email in PromptBar,
    the app POSTs {"email": "..."} here, and we return the signed license
    JSON if the email has a license on file. Zero file handling for the
    buyer.

    For privacy, we don't tell unknown emails whether the address exists,
    just that no license was found.
    """
    if PRIVATE_KEY is None:
        return jsonify({"error": "server misconfigured"}), 500

    body = request.get_json(silent=True) or {}
    raw_email = (body.get("email") or "").strip().lower()
    if not raw_email or "@" not in raw_email:
        return jsonify({"error": "invalid email"}), 400

    # Look the email up in the archive directory. If found, hand it back.
    safe = raw_email.replace("@", "_at_").replace(".", "_").replace("+", "_plus_")
    archive_path = os.path.join(LOG_DIR, f"{safe}.promptbar")
    if os.path.exists(archive_path):
        try:
            with open(archive_path, "r") as f:
                license_blob = json.load(f)
            log.info("Activated %s from archive", raw_email)
            return jsonify(license_blob), 200
        except Exception as e:
            log.error("Failed to read archived license for %s: %s", raw_email, e)
            return jsonify({"error": "archive read failed"}), 500

    log.info("Activation requested for unknown email %s", raw_email)
    return jsonify({
        "error": "no license on file for that email",
        "hint": "Use the email you typed on Ko-fi at checkout. If you bought "
                "with a different one, reply to your Ko-fi receipt or contact "
                "the developer."
    }), 404


@app.route("/webhook", methods=["POST"])
def kofi_webhook():
    """
    Ko-fi webhook receiver.

    Ko-fi posts as form data with a single 'data' field that contains the
    JSON payload (this is documented in their developer docs). We pull
    that out, verify the token, decide whether this purchase qualifies
    for a license, sign one, and email it.
    """
    if PRIVATE_KEY is None:
        log.error("Refusing webhook: private key not loaded")
        return jsonify({"error": "server misconfigured"}), 500

    # Ko-fi sends form data, not JSON
    raw = request.form.get("data") or request.get_data(as_text=True)
    try:
        payload = json.loads(raw)
    except Exception as e:
        log.warning("Bad webhook payload: %s", e)
        return jsonify({"error": "bad payload"}), 400

    token = payload.get("verification_token", "")
    if not KOFI_VERIFICATION_TOKEN or token != KOFI_VERIFICATION_TOKEN:
        log.warning("Verification token mismatch from %s", request.remote_addr)
        return jsonify({"error": "unauthorized"}), 401

    event_type = (payload.get("type") or "").lower()
    if event_type not in ("shop order", "shop_order", "shoporder"):
        log.info("Ignoring event type: %s", event_type)
        return jsonify({"ok": True, "ignored": event_type}), 200

    email = (payload.get("email") or "").strip()
    if not email:
        log.warning("Shop order without buyer email, skipping")
        return jsonify({"error": "no email"}), 400

    if not _is_promptbar_purchase(payload):
        log.info("Shop order for %s is not a PromptBar item, skipping", email)
        return jsonify({"ok": True, "matched": False}), 200

    order_id = payload.get("kofi_transaction_id") or payload.get("message_id") or "unknown"

    try:
        license_blob = issue_license(email, order_id)
    except Exception as e:
        log.error("Failed to issue license for %s: %s", email, e)
        return jsonify({"error": "sign failed"}), 500

    _archive(email, order_id, license_blob)

    try:
        send_license_email(email, license_blob)
    except Exception as e:
        log.error("Failed to email license to %s: %s", email, e)
        return jsonify({"error": "email failed"}), 500

    return jsonify({"ok": True, "issued_to": email, "order_id": order_id}), 200


def _is_promptbar_purchase(payload: dict) -> bool:
    items = payload.get("shop_items") or []
    if not isinstance(items, list):
        return False
    for item in items:
        if not isinstance(item, dict):
            continue
        code = (item.get("direct_link_code") or "").strip()
        if code and code in PROMPTBAR_LINK_CODES:
            return True
        name = (item.get("variation_name") or "").lower()
        if PROMPTBAR_NAME_MATCH and PROMPTBAR_NAME_MATCH in name:
            return True
    # Fallback: some Ko-fi shop events flatten items into a single message
    msg = (payload.get("message") or "").lower()
    if PROMPTBAR_NAME_MATCH and PROMPTBAR_NAME_MATCH in msg:
        return True
    return False


def _archive(email: str, order_id: str, license_blob: dict):
    try:
        os.makedirs(LOG_DIR, exist_ok=True)
        safe_email = email.replace("@", "_at_").replace(".", "_")
        path = os.path.join(LOG_DIR, f"{safe_email}.promptbar")
        with open(path, "w") as f:
            json.dump(license_blob, f, indent=2, sort_keys=True)
        log.info("Archived license at %s", path)
    except Exception as e:
        log.warning("Archive failed: %s", e)


# ---------------------------------------------------------------------------
# Dev server entry point. In production use gunicorn (see systemd unit).

if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8000"))
    app.run(host="0.0.0.0", port=port, debug=False)
