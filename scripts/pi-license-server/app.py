#!/usr/bin/env python3
"""
Multi-product license-issuing webhook server, designed to run 24/7 on a
Raspberry Pi (or any small Linux box).

Receives Ko-fi shop-order webhooks, verifies the verification token, and
for each configured product (PromptBar, klipa, ...) decides whether the
order matches, signs a license with that product's Ed25519 private key,
archives it, and emails the buyer the license file as an attachment.

Ko-fi only allows one webhook URL per account, so a single instance has
to serve every product sold on that account - hence the product registry
below. Each product is fully isolated: its own signing key, its own
`.ext` license file, its own Ko-fi item match, its own email copy. A
license signed for one product cannot validate another.

See README.md in this folder for setup (Cloudflare Tunnel, SMTP creds,
systemd unit).
"""

import os
import json
import logging
import smtplib
import sys
from dataclasses import dataclass, field
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
log = logging.getLogger("licenses")


# ---------------------------------------------------------------------------
# Shared config from environment

KOFI_VERIFICATION_TOKEN = os.environ.get("KOFI_VERIFICATION_TOKEN", "")
# Shared archive dir. Kept under the historical PROMPTBAR_LOG_DIR name so
# the existing PromptBar archive path is untouched; license files are
# namespaced by their per-product extension (.promptbar, .klipa, ...).
LOG_DIR = os.environ.get(
    "LICENSE_LOG_DIR",
    os.environ.get("PROMPTBAR_LOG_DIR", "/home/pi/promptbar/issued"),
)

SMTP_HOST = os.environ.get("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = int(os.environ.get("SMTP_PORT", "587"))
SMTP_USER = os.environ.get("SMTP_USER", "")
SMTP_PASS = os.environ.get("SMTP_PASS", "")
SMTP_FROM = os.environ.get("SMTP_FROM", SMTP_USER)
SMTP_FROM_NAME = os.environ.get("SMTP_FROM_NAME", "Petros Dhespollari")

# Admin emails get a free license per product auto-archived at startup so
# the operator can /activate at any time, and receive BCC of every
# license email so there's a permanent inbox record. Comma-separated.
ADMIN_EMAILS = [
    s.strip().lower() for s in
    os.environ.get("ADMIN_EMAILS", "info@peterdsp.dev").split(",")
    if s.strip()
]
BCC_LICENSE_EMAILS = [
    s.strip().lower() for s in
    os.environ.get("BCC_LICENSE_EMAILS", ",".join(ADMIN_EMAILS)).split(",")
    if s.strip()
]


def _env_codes(name: str) -> set:
    return set(filter(None, (s.strip() for s in os.environ.get(name, "").split(","))))


# ---------------------------------------------------------------------------
# Product registry

@dataclass
class Product:
    key: str                 # registry key / ?product= value, e.g. "klipa"
    name: str                # signed "product" field + email copy, e.g. "klipa"
    ext: str                 # license file extension, e.g. "klipa"
    private_key_path: str
    min_version: str
    link_codes: set          # Ko-fi direct_link_code allow list
    name_match: str          # lowercase substring fallback match
    email_subject: str
    email_body: str
    # When False, the /activate email-lookup convenience is disabled for
    # this product: the only way to unlock is the signed license file we
    # email, so knowing a buyer's address alone is not enough.
    email_activation: bool = True
    # When True, the signed license JSON is also embedded inline in the
    # email body (in addition to the attachment) so buyers can copy it
    # straight from the message.
    inline_license: bool = False
    private_key: object = field(default=None)  # loaded Ed25519PrivateKey

    def safe_email(self, email: str) -> str:
        norm = email.strip().lower()
        return norm.replace("@", "_at_").replace(".", "_").replace("+", "_plus_")

    def archive_path(self, email: str) -> str:
        return os.path.join(LOG_DIR, f"{self.safe_email(email)}.{self.ext}")


PROMPTBAR_EMAIL_BODY = """Hey,

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

KLIPA_EMAIL_BODY = """Hey,

Thanks for buying klipa. Your license is the signed block at the bottom
of this email (also attached as license.klipa). To unlock the app:

  1. Install klipa from https://klipa.peterdsp.dev (or via Homebrew).
  2. Select and copy the whole LICENSE block below (or open the attached
     license.klipa file and copy its contents).
  3. Click the klipa menu bar icon, then "Activate" - klipa reads the
     license from your clipboard, verifies it, and unlocks. No network
     needed.

Keep this license safe - it is your proof of purchase and works offline
on any Mac.

Reply to this email if anything breaks.

Thanks for backing the project.

Petros
peterdsp.dev
"""


def _build_registry() -> dict:
    products = {}

    # PromptBar - unchanged env vars so the live deployment keeps working.
    products["promptbar"] = Product(
        key="promptbar",
        name="PromptBar",
        ext="promptbar",
        private_key_path=os.environ.get(
            "PROMPTBAR_PRIVATE_KEY", "/home/pi/promptbar/license-private.key"),
        min_version=os.environ.get("PROMPTBAR_MIN_VERSION", "2.0.0"),
        link_codes=_env_codes("PROMPTBAR_LINK_CODES"),
        name_match=os.environ.get("PROMPTBAR_NAME_MATCH", "promptbar").lower(),
        email_subject="Your PromptBar 2.0 license",
        email_body=PROMPTBAR_EMAIL_BODY,
    )

    # klipa - only registered when its signing key path is configured, so
    # a Pi that hasn't been given the klipa key simply ignores klipa
    # orders instead of erroring.
    klipa_key = os.environ.get("KLIPA_PRIVATE_KEY", "")
    if klipa_key:
        products["klipa"] = Product(
            key="klipa",
            name="klipa",
            ext="klipa",
            private_key_path=klipa_key,
            min_version=os.environ.get("KLIPA_MIN_VERSION", "0.4.0"),
            link_codes=_env_codes("KLIPA_LINK_CODES"),
            name_match=os.environ.get("KLIPA_NAME_MATCH", "klipa").lower(),
            email_subject="Your klipa license",
            email_body=KLIPA_EMAIL_BODY,
            email_activation=False,
            inline_license=True,
        )

    # Load each product's signing key; drop products whose key won't load.
    ready = {}
    for pkey, product in products.items():
        try:
            product.private_key = _load_private_key(product.private_key_path)
            ready[pkey] = product
            log.info("Product '%s' ready (key %s)", pkey, product.private_key_path)
        except Exception as e:
            log.error("Product '%s' disabled: cannot load key %s: %s",
                      pkey, product.private_key_path, e)
    return ready


# ---------------------------------------------------------------------------
# Crypto

def _load_private_key(path: str) -> Ed25519PrivateKey:
    with open(path, "r") as f:
        raw_b64 = f.read().strip()
    raw = b64decode(raw_b64)
    if len(raw) != 32:
        raise RuntimeError(f"Expected 32-byte Ed25519 key in {path}, got {len(raw)}")
    return Ed25519PrivateKey.from_private_bytes(raw)


def _canonical_json(obj: dict) -> bytes:
    return json.dumps(obj, separators=(",", ":"), sort_keys=True).encode("utf-8")


def issue_license(product: Product, email: str, order_id: str) -> dict:
    issued_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    canonical = {
        "email": email.lower().strip(),
        "issued_at": issued_at,
        "order_id": order_id.strip(),
        "product": product.name,
        "min_version": product.min_version,
    }
    signature = product.private_key.sign(_canonical_json(canonical))
    canonical["signature"] = b64encode(signature).decode("ascii")
    return canonical


PRODUCTS = _build_registry()


def _bootstrap_admin_licenses():
    """Ensure every admin email has an archived license for every product,
    so the operator can /activate from any Mac at any time. Idempotent."""
    if not ADMIN_EMAILS:
        return
    try:
        os.makedirs(LOG_DIR, exist_ok=True)
    except Exception as e:
        log.error("Cannot create LOG_DIR %s: %s", LOG_DIR, e)
        return
    for product in PRODUCTS.values():
        for raw in ADMIN_EMAILS:
            email = raw.strip().lower()
            if not email or "@" not in email:
                continue
            path = product.archive_path(email)
            if os.path.exists(path):
                continue
            blob = issue_license(product, email, f"admin-{email}")
            try:
                with open(path, "w") as f:
                    json.dump(blob, f, indent=2, sort_keys=True)
                log.info("Bootstrapped %s admin license for %s", product.key, email)
            except Exception as e:
                log.error("Failed to write %s admin license for %s: %s",
                          product.key, email, e)


_bootstrap_admin_licenses()


# ---------------------------------------------------------------------------
# Email delivery

def send_license_email(product: Product, to_email: str, license_blob: dict):
    msg = EmailMessage()
    msg["From"] = f"{SMTP_FROM_NAME} <{SMTP_FROM}>"
    msg["To"] = to_email
    if BCC_LICENSE_EMAILS:
        bcc = [a for a in BCC_LICENSE_EMAILS if a != to_email.lower()]
        if bcc:
            msg["Bcc"] = ", ".join(bcc)
    msg["Subject"] = product.email_subject
    license_text = json.dumps(license_blob, indent=2, sort_keys=True)
    body = product.email_body
    if product.inline_license:
        body += (
            "\n\n----- LICENSE (copy everything between the lines) -----\n"
            + license_text
            + "\n----- END LICENSE -----\n"
        )
    msg.set_content(body)

    msg.add_attachment(
        license_text.encode("utf-8"),
        maintype="application",
        subtype="json",
        filename=f"license.{product.ext}"
    )

    with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=30) as smtp:
        smtp.ehlo()
        smtp.starttls()
        smtp.login(SMTP_USER, SMTP_PASS)
        smtp.send_message(msg)
    log.info("Emailed %s license to %s (bcc=%s)",
             product.key, to_email, msg.get("Bcc") or "-")


# ---------------------------------------------------------------------------
# Matching + archiving

def _matches(product: Product, payload: dict) -> bool:
    items = payload.get("shop_items") or []
    if isinstance(items, list):
        for item in items:
            if not isinstance(item, dict):
                continue
            code = (item.get("direct_link_code") or "").strip()
            if code and code in product.link_codes:
                return True
            name = (item.get("variation_name") or "").lower()
            if product.name_match and product.name_match in name:
                return True
    # Fallback: some Ko-fi shop events flatten items into the message field.
    msg = (payload.get("message") or "").lower()
    if product.name_match and product.name_match in msg:
        return True
    return False


def _archive(product: Product, email: str, license_blob: dict):
    try:
        os.makedirs(LOG_DIR, exist_ok=True)
        path = product.archive_path(email)
        with open(path, "w") as f:
            json.dump(license_blob, f, indent=2, sort_keys=True)
        log.info("Archived %s license at %s", product.key, path)
    except Exception as e:
        log.warning("Archive failed for %s: %s", product.key, e)


# ---------------------------------------------------------------------------
# Routes

@app.route("/health", methods=["GET"])
def health():
    return jsonify({
        "ok": True,
        "products": {
            p.key: {"min_version": p.min_version} for p in PRODUCTS.values()
        },
        "smtp_configured": bool(SMTP_USER and SMTP_PASS),
    })


@app.route("/activate", methods=["POST"])
def activate():
    """
    App-driven activation: the buyer's app POSTs {"email": "...",
    "product": "klipa"} and we return the signed license JSON if that
    email has a license on file for that product. `product` defaults to
    "promptbar" so the existing PromptBar app (which sends no product
    field) keeps working unchanged.

    For privacy, we don't reveal whether an unknown address exists, only
    that no license was found.
    """
    body = request.get_json(silent=True) or {}
    raw_email = (body.get("email") or "").strip().lower()
    product_key = (body.get("product") or request.args.get("product") or "promptbar").strip().lower()

    if not raw_email or "@" not in raw_email:
        return jsonify({"error": "invalid email"}), 400

    product = PRODUCTS.get(product_key)
    if product is None:
        return jsonify({"error": "unknown product"}), 404

    # Some products (klipa) deliberately disable email-lookup activation:
    # the signed license file is the only key, so a known address alone
    # can't unlock. We don't hand out the license here.
    if not product.email_activation:
        return jsonify({
            "error": "email activation is disabled for this product",
            "hint": "Use the license file that was emailed to you: copy its "
                    "contents and paste them into the app's Activate action.",
        }), 403

    archive_path = product.archive_path(raw_email)
    if os.path.exists(archive_path):
        try:
            with open(archive_path, "r") as f:
                license_blob = json.load(f)
            log.info("Activated %s for %s from archive", product_key, raw_email)
            return jsonify(license_blob), 200
        except Exception as e:
            log.error("Failed to read archived %s license for %s: %s",
                      product_key, raw_email, e)
            return jsonify({"error": "archive read failed"}), 500

    log.info("Activation requested for unknown %s email %s", product_key, raw_email)
    return jsonify({
        "error": "no license on file for that email",
        "hint": "Use the email you typed on Ko-fi at checkout. If you bought "
                "with a different one, reply to your Ko-fi receipt or contact "
                "the developer."
    }), 404


@app.route("/webhook", methods=["POST"])
def kofi_webhook():
    """
    Ko-fi webhook receiver. Ko-fi posts form data with a single 'data'
    field holding the JSON payload. We verify the token, then offer the
    order to every product; the first one that matches gets issued.
    """
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

    for product in PRODUCTS.values():
        if not _matches(product, payload):
            continue
        order_id = payload.get("kofi_transaction_id") or payload.get("message_id") or "unknown"
        try:
            license_blob = issue_license(product, email, order_id)
        except Exception as e:
            log.error("Failed to issue %s license for %s: %s", product.key, email, e)
            return jsonify({"error": "sign failed"}), 500
        _archive(product, email, license_blob)
        try:
            send_license_email(product, email, license_blob)
        except Exception as e:
            log.error("Failed to email %s license to %s: %s", product.key, email, e)
            return jsonify({"error": "email failed"}), 500
        return jsonify({
            "ok": True, "product": product.key,
            "issued_to": email, "order_id": order_id
        }), 200

    log.info("Shop order for %s matched no product, skipping", email)
    return jsonify({"ok": True, "matched": False}), 200


# ---------------------------------------------------------------------------
# Dev server entry point. In production use gunicorn (see systemd unit).

if __name__ == "__main__":
    port = int(os.environ.get("PORT", "8000"))
    app.run(host="0.0.0.0", port=port, debug=False)
