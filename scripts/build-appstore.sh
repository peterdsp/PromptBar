#!/usr/bin/env bash
#
# build-appstore.sh
#
# Reusable Mac App Store channel build. Produces a signed .pkg suitable for
# App Store Connect, then validates and (optionally) uploads it. This is a
# SEPARATE artifact from the Developer ID / Ko-fi ZIP:
#
#   * NO EXTERNAL_DISTRIBUTION flag        (that flag turns on the Ko-fi
#                                           license prompt; App Store builds
#                                           must never carry it).
#   * App Store distribution signing       (Apple Distribution + 3rd Party Mac
#                                           Developer Installer), not Developer
#                                           ID, and no hardened-runtime notarize.
#   * App sandbox stays ON                 (required by the store; already set
#                                           in PromptBar.entitlements).
#
# Do NOT reuse the direct-distribution notarized ZIP for the App Store. The two
# channels sign differently and the store rejects Developer ID binaries.
#
# Usage:
#   ./scripts/build-appstore.sh            # archive + export + validate
#   UPLOAD=1 ./scripts/build-appstore.sh   # also upload to App Store Connect
#
# Credentials (required only for validate/upload, read from the environment):
#   ASC_KEY_ID        App Store Connect API key id
#   ASC_ISSUER_ID     App Store Connect API issuer id
#   ASC_KEY_PATH      path to the .p8 private key  (AuthKey_XXXX.p8)
# or, as a fallback:
#   APPLE_ID          Apple ID email
#   APPLE_APP_SPECIFIC_PASSWORD  app-specific password for that Apple ID
#
set -euo pipefail

cd "$(dirname "$0")/.."

SCHEME="PromptBar"
PROJECT="PromptBar/PromptBar.xcodeproj"
CONFIGURATION="Release"
TEAM_ID="YTS4KJBX3P"
EXPORT_OPTIONS="scripts/ExportOptions-AppStore.plist"

BUILD_DIR="$(pwd)/release/appstore"
ARCHIVE_PATH="$BUILD_DIR/PromptBar.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "== Source identity =="
grep -E 'MARKETING_VERSION|CURRENT_PROJECT_VERSION|PRODUCT_BUNDLE_IDENTIFIER|MACOSX_DEPLOYMENT_TARGET' \
  "$PROJECT/project.pbxproj" | sort -u | head

echo "== Resolve SPM dependencies =="
xcodebuild -resolvePackageDependencies -project "$PROJECT" -scheme "$SCHEME"

echo "== Archive (Release, App Store signing, NO EXTERNAL_DISTRIBUTION) =="
# Compilation conditions are set explicitly WITHOUT EXTERNAL_DISTRIBUTION so a
# stray inherited value can never leak the Ko-fi license prompt into the store
# build.
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -archivePath "$ARCHIVE_PATH" \
  -destination 'generic/platform=macOS' \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  SWIFT_ACTIVE_COMPILATION_CONDITIONS='$(inherited)' \
  archive

echo "== Export signed .pkg for App Store Connect =="
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$EXPORT_OPTIONS"

PKG="$(ls "$EXPORT_PATH"/*.pkg 2>/dev/null | head -1 || true)"
if [ -z "$PKG" ]; then
  echo "::error::No .pkg produced. Check signing identity / provisioning profile."
  exit 1
fi
echo "Exported: $PKG"
shasum -a 256 "$PKG"

auth_args=()
if [ -n "${ASC_KEY_ID:-}" ] && [ -n "${ASC_ISSUER_ID:-}" ] && [ -n "${ASC_KEY_PATH:-}" ]; then
  auth_args=(--apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID")
  export API_PRIVATE_KEYS_DIR="$(dirname "$ASC_KEY_PATH")"
elif [ -n "${APPLE_ID:-}" ] && [ -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]; then
  auth_args=(--username "$APPLE_ID" --password "$APPLE_APP_SPECIFIC_PASSWORD")
else
  echo "== No App Store Connect credentials in environment =="
  echo "   .pkg built and signed, but validation/upload skipped."
  echo "   Set ASC_KEY_ID / ASC_ISSUER_ID / ASC_KEY_PATH (or APPLE_ID /"
  echo "   APPLE_APP_SPECIFIC_PASSWORD) to validate and upload."
  exit 0
fi

echo "== Validate with App Store Connect =="
xcrun altool --validate-app -f "$PKG" -t macos "${auth_args[@]}"

if [ "${UPLOAD:-0}" = "1" ]; then
  echo "== Upload to App Store Connect =="
  xcrun altool --upload-app -f "$PKG" -t macos "${auth_args[@]}"
  echo "Upload submitted. Finish in App Store Connect: attach the build to the"
  echo "2.2.0 version, complete metadata/screenshots, and submit for review."
else
  echo "== Validation passed. Re-run with UPLOAD=1 to upload. =="
fi
