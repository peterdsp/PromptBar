#!/usr/bin/env python3
"""
PromptBar license issuer, Python port for Linux (Raspberry Pi etc).

Reads the same private key file the Swift issuer writes
(scripts/license-private.key, raw 32-byte Ed25519 in base64) and produces
identical JSON to scripts/issue-license.swift. Cross-verifies against the
public key embedded in Helpers/LicenseValidator.swift.

First time setup:
    pip3 install cryptography
    # Generate the keypair via the Swift script on your Mac, then copy
    # scripts/license-private.key to the Pi at the same path.

Usage:
    python3 scripts/issue_license.py <email> <order-id> [min-version]

Outputs the signed license JSON on stdout. Redirect to a file:
    python3 scripts/issue_license.py buyer@example.com ko-fi-abc > buyer.promptbar
"""

import json
import os
import sys
from datetime import datetime, timezone
from base64 import b64decode, b64encode

try:
    from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
except ImportError:
    print("ERROR: cryptography package missing. Install with: pip3 install cryptography",
          file=sys.stderr)
    sys.exit(1)


def canonical_json(obj: dict) -> bytes:
    """Match Swift's JSONSerialization with .sortedKeys exactly.

    Swift's sortedKeys output:
      - keys sorted lexicographically
      - no whitespace, separators are ',' and ':'
    Python: json.dumps(obj, separators=(',', ':'), sort_keys=True)
    """
    return json.dumps(obj, separators=(',', ':'), sort_keys=True).encode('utf-8')


def load_private_key(path: str) -> Ed25519PrivateKey:
    with open(path, 'r') as f:
        raw_b64 = f.read().strip()
    raw = b64decode(raw_b64)
    if len(raw) != 32:
        raise ValueError(f"Expected 32-byte Ed25519 key, got {len(raw)} bytes from {path}")
    return Ed25519PrivateKey.from_private_bytes(raw)


def issue(email: str, order_id: str, min_version: str = "2.0.0",
          private_key_path: str = "scripts/license-private.key") -> dict:
    key = load_private_key(private_key_path)

    issued_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    canonical = {
        "email": email.lower().strip(),
        "issued_at": issued_at,
        "order_id": order_id.strip(),
        "product": "PromptBar",
        "min_version": min_version,
    }

    payload = canonical_json(canonical)
    signature = key.sign(payload)

    license_blob = dict(canonical)
    license_blob["signature"] = b64encode(signature).decode('ascii')
    return license_blob


def main():
    if len(sys.argv) < 3:
        print(__doc__, file=sys.stderr)
        sys.exit(1)
    email = sys.argv[1]
    order_id = sys.argv[2]
    min_version = sys.argv[3] if len(sys.argv) >= 4 else "2.0.0"

    private_key_path = os.environ.get(
        "PROMPTBAR_PRIVATE_KEY",
        "scripts/license-private.key"
    )

    license_blob = issue(email, order_id, min_version, private_key_path)
    # Pretty-printed JSON matches the Swift script's output style.
    print(json.dumps(license_blob, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
