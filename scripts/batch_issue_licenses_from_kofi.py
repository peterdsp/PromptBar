#!/usr/bin/env python3
"""
Bulk-issue PromptBar 2.0 licenses from a Ko-fi Transaction_All.csv export,
and optionally email each buyer their .promptbar file.

Designed to run on a Raspberry Pi (or any Linux box) so you never need
the Mac toolchain for batch backfill or periodic re-runs. Same Ed25519
signing as scripts/issue_license.py and scripts/pi-license-server/app.py,
so licenses verify against the public key embedded in
Helpers/LicenseValidator.swift.

Usage:

  # Sign only (no email), write licenses to ./licenses/
  python3 scripts/batch_issue_licenses_from_kofi.py \\
      --csv ~/Downloads/Transaction_All.csv \\
      --output licenses/

  # Sign and email everyone in the CSV (uses SMTP_* env vars or --env)
  python3 scripts/batch_issue_licenses_from_kofi.py \\
      --csv Transaction_All.csv \\
      --output licenses/ \\
      --email \\
      --env /home/pi/promptbar/.env

  # Re-run safely: only issue/send for buyers not already in manifest.csv
  python3 scripts/batch_issue_licenses_from_kofi.py \\
      --csv Transaction_All.csv \\
      --output licenses/ \\
      --email \\
      --skip-existing

Env vars (override on the command line with --env):
  PROMPTBAR_PRIVATE_KEY  path to license-private.key (default scripts/...)
  PROMPTBAR_MIN_VERSION  license min version (default 2.0.0)
  SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_FROM, SMTP_FROM_NAME
"""

import argparse
import csv
import json
import os
import smtplib
import sys
import time
from base64 import b64decode, b64encode
from datetime import datetime, timezone
from email.message import EmailMessage

try:
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
except ImportError:
    print("ERROR: pip3 install cryptography", file=sys.stderr)
    sys.exit(1)


# ---------------------------------------------------------------------------
# Crypto

def load_private_key(path: str) -> Ed25519PrivateKey:
    with open(path, "r") as f:
        raw_b64 = f.read().strip()
    raw = b64decode(raw_b64)
    if len(raw) != 32:
        raise ValueError(
            f"Expected 32-byte Ed25519 key in {path}, got {len(raw)} bytes"
        )
    return Ed25519PrivateKey.from_private_bytes(raw)


def canonical_json(obj: dict) -> bytes:
    """Match Swift's JSONSerialization with .sortedKeys (sorted keys, no whitespace)."""
    return json.dumps(obj, separators=(",", ":"), sort_keys=True).encode("utf-8")


def sign_license(key: Ed25519PrivateKey, email: str, order_id: str,
                 min_version: str) -> dict:
    issued_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    canonical = {
        "email": email.lower().strip(),
        "issued_at": issued_at,
        "order_id": order_id.strip(),
        "product": "PromptBar",
        "min_version": min_version,
    }
    signature = key.sign(canonical_json(canonical))
    canonical["signature"] = b64encode(signature).decode("ascii")
    return canonical


# ---------------------------------------------------------------------------
# CSV parsing

def iter_promptbar_buyers(csv_path: str):
    """Yield (email, order_id) tuples for every unique PromptBar buyer."""
    with open(csv_path, "r", newline="") as f:
        reader = csv.DictReader(f)
        seen = set()
        for row in reader:
            item = (row.get("Item") or "")
            if "promptbar" not in item.lower():
                continue
            email = (row.get("BuyerEmail") or "").strip().lower()
            if not email or "@" not in email:
                continue
            if email in seen:
                continue
            seen.add(email)
            order_id = (row.get("TransactionId") or "").strip()
            if not order_id:
                continue
            yield email, order_id


# ---------------------------------------------------------------------------
# Email

EMAIL_SUBJECT = "Your PromptBar 2.0 license, free upgrade"
EMAIL_BODY = """Hey,

Quick note: PromptBar 2.0 just shipped. It is a full rebuild, much closer
to a workbench than a wrapper.

You bought PromptBar (or MacMistral, or Mistralis, all earlier names of
the same project) on Ko-fi before, so you get 2.0 free.

Attached is your personal 2.0 license file. Two steps:

  1. Download the 2.0 .pkg installer from
     https://github.com/peterdsp/PromptBar/releases/latest
     (or grab it from the Ko-fi shop).

  2. On the first-launch screen, drop the attached .promptbar file (or
     paste its contents) and click Validate.

You are in. No new payment, no online check. The license is stored in
your macOS Keychain after validation, you will never see this screen
again on this Mac.

Reply to this email if anything breaks.

Thanks for backing the project all this time.

Petros
peterdsp.dev
"""


class Mailer:
    def __init__(self, host, port, user, password, from_addr, from_name):
        self.host = host
        self.port = int(port)
        self.user = user
        self.password = password
        self.from_addr = from_addr or user
        self.from_name = from_name or "PromptBar"

    def send(self, to_email: str, license_blob: dict):
        msg = EmailMessage()
        msg["From"] = f"{self.from_name} <{self.from_addr}>"
        msg["To"] = to_email
        msg["Subject"] = EMAIL_SUBJECT
        msg.set_content(EMAIL_BODY)
        license_text = json.dumps(license_blob, indent=2, sort_keys=True)
        msg.add_attachment(
            license_text.encode("utf-8"),
            maintype="application",
            subtype="json",
            filename="license.promptbar",
        )
        with smtplib.SMTP(self.host, self.port, timeout=30) as smtp:
            smtp.ehlo()
            smtp.starttls()
            smtp.login(self.user, self.password)
            smtp.send_message(msg)


# ---------------------------------------------------------------------------
# Helpers

def load_env_file(path: str):
    """Tiny .env loader (KEY=value, ignores comments and blank lines)."""
    with open(path, "r") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            os.environ.setdefault(k.strip(), v.strip())


def sanitize_filename(email: str) -> str:
    return (
        email.replace("@", "_at_")
             .replace(".", "_")
             .replace("+", "_plus_")
    )


def load_existing_manifest(manifest_path: str) -> set:
    if not os.path.exists(manifest_path):
        return set()
    seen = set()
    with open(manifest_path, "r", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            email = (row.get("email") or "").strip().lower()
            if email:
                seen.add(email)
    return seen


def append_manifest(manifest_path: str, email: str, order_id: str,
                    filename: str, emailed: bool):
    new_file = not os.path.exists(manifest_path)
    with open(manifest_path, "a", newline="") as f:
        writer = csv.writer(f)
        if new_file:
            writer.writerow(["email", "order_id", "license_file", "emailed_at"])
        emailed_at = (
            datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
            if emailed else ""
        )
        writer.writerow([email, order_id, filename, emailed_at])


# ---------------------------------------------------------------------------
# Main

def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--csv", required=True,
                        help="Path to Ko-fi Transaction_All.csv")
    parser.add_argument("--output", default="licenses",
                        help="Directory for .promptbar files and manifest.csv")
    parser.add_argument("--env", default=None,
                        help="Optional .env file with SMTP_* and PROMPTBAR_* settings")
    parser.add_argument("--email", action="store_true",
                        help="Also send each license to its buyer over SMTP")
    parser.add_argument("--skip-existing", action="store_true",
                        help="Skip emails already present in manifest.csv (safe re-runs)")
    parser.add_argument("--dry-run", action="store_true",
                        help="List who would be processed without writing or sending")
    parser.add_argument("--rate-limit", type=float, default=0.0,
                        help="Seconds to sleep between emails (default: 0)")
    args = parser.parse_args()

    if args.env:
        load_env_file(args.env)

    private_key_path = os.environ.get("PROMPTBAR_PRIVATE_KEY",
                                      "scripts/license-private.key")
    min_version = os.environ.get("PROMPTBAR_MIN_VERSION", "2.0.0")

    if not os.path.exists(private_key_path):
        print(f"ERROR: private key not found at {private_key_path}", file=sys.stderr)
        sys.exit(1)
    key = load_private_key(private_key_path)

    mailer = None
    if args.email and not args.dry_run:
        required = ["SMTP_HOST", "SMTP_PORT", "SMTP_USER", "SMTP_PASS"]
        missing = [k for k in required if not os.environ.get(k)]
        if missing:
            print(f"ERROR: --email requires {missing} set in env or --env file",
                  file=sys.stderr)
            sys.exit(1)
        mailer = Mailer(
            host=os.environ["SMTP_HOST"],
            port=os.environ["SMTP_PORT"],
            user=os.environ["SMTP_USER"],
            password=os.environ["SMTP_PASS"],
            from_addr=os.environ.get("SMTP_FROM", os.environ["SMTP_USER"]),
            from_name=os.environ.get("SMTP_FROM_NAME", "PromptBar"),
        )

    os.makedirs(args.output, exist_ok=True)
    manifest_path = os.path.join(args.output, "manifest.csv")

    already_handled = (
        load_existing_manifest(manifest_path) if args.skip_existing else set()
    )

    signed = 0
    emailed = 0
    skipped_existing = 0
    failures = []

    for email, order_id in iter_promptbar_buyers(args.csv):
        if email in already_handled:
            skipped_existing += 1
            continue

        if args.dry_run:
            print(f"DRY-RUN would issue: {email}  order={order_id}")
            continue

        license_blob = sign_license(key, email, order_id, min_version)

        filename = f"{sanitize_filename(email)}.promptbar"
        out_path = os.path.join(args.output, filename)
        with open(out_path, "w") as f:
            json.dump(license_blob, f, indent=2, sort_keys=True)
        signed += 1

        delivered = False
        if mailer is not None:
            try:
                mailer.send(email, license_blob)
                emailed += 1
                delivered = True
                if args.rate_limit > 0:
                    time.sleep(args.rate_limit)
            except Exception as e:
                failures.append((email, str(e)))
                print(f"  EMAIL FAIL {email}: {e}", file=sys.stderr)

        append_manifest(manifest_path, email, order_id, filename, delivered)
        print(f"  signed {email}{'  emailed' if delivered else ''}")

    print()
    print(f"Signed:           {signed}")
    print(f"Emailed:          {emailed}")
    print(f"Skipped (existing): {skipped_existing}")
    print(f"Email failures:   {len(failures)}")
    print(f"Manifest:         {manifest_path}")
    if failures and not args.email:
        print("(no --email passed, so 'failures' is moot)")
    if failures:
        print()
        print("Failures (re-run later with --skip-existing to avoid duplicates):")
        for email, msg in failures:
            print(f"  - {email}: {msg}")


if __name__ == "__main__":
    main()
