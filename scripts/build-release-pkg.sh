#!/usr/bin/env bash
# Build, sign, and package PromptBar for distribution outside the App Store.
#
# Prerequisites in your Keychain (download from developer.apple.com):
#   - Developer ID Application: PETROS DHESPOLLARI (YTS4KJBX3P)
#   - Developer ID Installer:   PETROS DHESPOLLARI (YTS4KJBX3P)
#
# Notarization (run by the user after this script, see notes at bottom):
#   xcrun notarytool submit ... --keychain-profile <profile> --wait
#   xcrun stapler staple PromptBar-<version>.pkg
#
# Usage:
#   ./scripts/build-release-pkg.sh
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJ_DIR="${ROOT_DIR}/PromptBar"
PROJ="${PROJ_DIR}/PromptBar.xcodeproj"
SCHEME="PromptBar"
CONFIG="Release"
TEAM_ID="YTS4KJBX3P"
BUNDLE_ID="peterdsp.app.PromptBar"
APP_NAME="PromptBar"

OUT_DIR="${ROOT_DIR}/release"
BUILD_DIR="${OUT_DIR}/build"
ARCHIVE_PATH="${OUT_DIR}/${APP_NAME}.xcarchive"
EXPORT_DIR="${OUT_DIR}/export"
PKG_DIR="${OUT_DIR}/pkg"

# Pull marketing version out of the pbxproj so the .pkg is named correctly.
VERSION="$(grep -E 'MARKETING_VERSION = ' "${PROJ}/project.pbxproj" | head -1 | awk -F'= ' '{print $2}' | tr -d ' ;')"
BUILD_NUM="$(grep -E 'CURRENT_PROJECT_VERSION = ' "${PROJ}/project.pbxproj" | head -1 | awk -F'= ' '{print $2}' | tr -d ' ;')"
echo "==> ${APP_NAME} ${VERSION} (${BUILD_NUM})"

# Resolve the actual identity strings. We grep for the prefix and the team ID
# so the script works with both classic 'Developer ID Application' and the
# newer Apple-managed variants, without hardcoding the exact CN.
echo "==> Resolving signing identities for team ${TEAM_ID}"
DEV_ID_APP_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
  | grep "Developer ID Application" \
  | grep "(${TEAM_ID})" \
  | head -1 \
  | sed -E 's/^[[:space:]]*[0-9]+\)[[:space:]]+[A-F0-9]+[[:space:]]+"(.+)"$/\1/')"

DEV_ID_INSTALLER_IDENTITY="$(security find-identity -v 2>/dev/null \
  | grep "Developer ID Installer" \
  | grep "(${TEAM_ID})" \
  | head -1 \
  | sed -E 's/^[[:space:]]*[0-9]+\)[[:space:]]+[A-F0-9]+[[:space:]]+"(.+)"$/\1/')"

if [ -z "${DEV_ID_APP_IDENTITY}" ]; then
  echo "ERROR: No 'Developer ID Application' identity for team ${TEAM_ID} in Keychain."
  echo
  echo "Get it from https://developer.apple.com/account/resources/certificates/list"
  echo "Click the cert row, Download the .cer, double-click to install in Keychain."
  exit 1
fi
if [ -z "${DEV_ID_INSTALLER_IDENTITY}" ]; then
  echo "ERROR: No 'Developer ID Installer' identity for team ${TEAM_ID} in Keychain."
  echo
  echo "Get it from https://developer.apple.com/account/resources/certificates/list"
  echo "Click the cert row, Download the .cer, double-click to install in Keychain."
  exit 1
fi
echo "    Application: ${DEV_ID_APP_IDENTITY}"
echo "    Installer:   ${DEV_ID_INSTALLER_IDENTITY}"

echo "==> Cleaning previous artifacts"
rm -rf "${BUILD_DIR}" "${ARCHIVE_PATH}" "${EXPORT_DIR}" "${PKG_DIR}"
mkdir -p "${BUILD_DIR}" "${EXPORT_DIR}" "${PKG_DIR}"

echo "==> Archiving (${CONFIG})"
xcodebuild \
  -project "${PROJ}" \
  -scheme "${SCHEME}" \
  -configuration "${CONFIG}" \
  -archivePath "${ARCHIVE_PATH}" \
  -destination 'generic/platform=macOS' \
  CODE_SIGN_IDENTITY="${DEV_ID_APP_IDENTITY}" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM="${TEAM_ID}" \
  archive

# Write an export options plist that matches Developer ID distribution.
EXPORT_OPTS="${OUT_DIR}/exportOptions.plist"
cat >"${EXPORT_OPTS}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
    <key>signingStyle</key>
    <string>manual</string>
    <key>signingCertificate</key>
    <string>${DEV_ID_APP_IDENTITY}</string>
</dict>
</plist>
EOF

echo "==> Exporting signed .app"
xcodebuild \
  -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportPath "${EXPORT_DIR}" \
  -exportOptionsPlist "${EXPORT_OPTS}"

APP_PATH="${EXPORT_DIR}/${APP_NAME}.app"
if [ ! -d "${APP_PATH}" ]; then
  echo "ERROR: Exported .app not found at ${APP_PATH}"
  exit 1
fi

echo "==> Verifying signature"
codesign --verify --deep --strict --verbose=2 "${APP_PATH}"

echo "==> Building component .pkg"
COMPONENT_PKG="${PKG_DIR}/${APP_NAME}-component.pkg"
pkgbuild \
  --component "${APP_PATH}" \
  --install-location "/Applications" \
  --identifier "${BUNDLE_ID}" \
  --version "${VERSION}" \
  "${COMPONENT_PKG}"

echo "==> Building distribution .pkg"
DISTRIBUTION_XML="${PKG_DIR}/distribution.xml"
cat >"${DISTRIBUTION_XML}" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>${APP_NAME} ${VERSION}</title>
    <organization>${TEAM_ID}</organization>
    <domains enable_anywhere="false" enable_currentUserHome="false" enable_localSystem="true"/>
    <options customize="never" require-scripts="false" rootVolumeOnly="true"/>
    <volume-check>
        <allowed-os-versions>
            <os-version min="26.0"/>
        </allowed-os-versions>
    </volume-check>
    <choices-outline>
        <line choice="default">
            <line choice="${BUNDLE_ID}"/>
        </line>
    </choices-outline>
    <choice id="default"/>
    <choice id="${BUNDLE_ID}" visible="false">
        <pkg-ref id="${BUNDLE_ID}"/>
    </choice>
    <pkg-ref id="${BUNDLE_ID}" version="${VERSION}" onConclusion="none">${APP_NAME}-component.pkg</pkg-ref>
</installer-gui-script>
EOF

FINAL_PKG="${OUT_DIR}/${APP_NAME}-${VERSION}.pkg"
productbuild \
  --distribution "${DISTRIBUTION_XML}" \
  --package-path "${PKG_DIR}" \
  --sign "${DEV_ID_INSTALLER_IDENTITY}" \
  "${FINAL_PKG}"

echo "==> Verifying .pkg signature"
pkgutil --check-signature "${FINAL_PKG}"

echo
echo "================================================================"
echo "  Built: ${FINAL_PKG}"
echo "================================================================"
echo
echo "Next steps (these need your Apple ID, so run them yourself):"
echo
echo "  1. One-time keychain profile setup (only if you haven't already):"
echo
echo "       xcrun notarytool store-credentials promptbar-notary \\"
echo "         --apple-id <your-apple-id-email> \\"
echo "         --team-id ${TEAM_ID} \\"
echo "         --password <app-specific-password>"
echo
echo "     Generate the app-specific password at https://appleid.apple.com -> Sign-In and Security -> App-Specific Passwords."
echo
echo "  2. Submit for notarization (waits until done):"
echo
echo "       xcrun notarytool submit \\"
echo "         ${FINAL_PKG} \\"
echo "         --keychain-profile promptbar-notary --wait"
echo
echo "  3. Staple the notarization ticket onto the .pkg:"
echo
echo "       xcrun stapler staple ${FINAL_PKG}"
echo
echo "  4. Sanity check:"
echo
echo "       spctl --assess --type install -vvv ${FINAL_PKG}"
echo
echo "  5. Ship it. Upload to GitHub Releases for v${VERSION} or attach to your Ko-fi listing."
