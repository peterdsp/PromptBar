# Mac App Store channel

The Mac App Store is a **separate distribution channel** from the Developer ID /
Ko-fi direct download. It uses different signing and a different artifact, and
the two must never be swapped.

| | Direct / Ko-fi | Mac App Store |
| --- | --- | --- |
| Artifact | notarized, stapled `.app` in a ZIP | Apple-Distribution-signed `.pkg` |
| Signing | Developer ID Application + hardened runtime + notarization | Apple Distribution + 3rd Party Mac Developer Installer |
| `EXTERNAL_DISTRIBUTION` flag | **on** (license-key prompt) | **off** (store handles entitlement) |
| App Sandbox | on | on (required) |
| Delivery | file on Ko-fi product + emailed license | App Store review then release |
| Owner | `package-direct-zip.yml` / this repo's ZIP | `appstore.yml` + `build-appstore.sh` |

Do **not** reuse `PromptBar-2.2.0.zip` (the Developer ID artifact) for the App
Store. The store rejects Developer ID binaries.

## Files

- `scripts/ExportOptions-AppStore.plist` - `app-store-connect` export options.
- `scripts/build-appstore.sh` - archive (no `EXTERNAL_DISTRIBUTION`), export a
  signed `.pkg`, validate, and optionally upload.
- `.github/workflows/appstore.yml` - CI equivalent (`workflow_dispatch`), with a
  preflight that fails fast until the required secrets exist.

## One-time credentials still required

Local keychain currently has only **Apple Development** certs, and there is no
App Store Connect API key on disk, so upload cannot run yet. To enable it:

1. **Certificates** (create in the Apple Developer portal, export as `.p12`):
   - Apple Distribution
   - 3rd Party Mac Developer Installer
2. **Mac App Store provisioning profile** for `peterdsp.app.PromptBar`
   (only needed if you switch `ExportOptions-AppStore.plist` to manual signing;
   automatic signing resolves it from the account / API key).
3. **App Store Connect API key** (`AuthKey_XXXX.p8`) with App Manager role, plus
   its Key ID and Issuer ID.

### Local use

```sh
export ASC_KEY_ID=XXXXXXXXXX
export ASC_ISSUER_ID=xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
export ASC_KEY_PATH="$HOME/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8"

./scripts/build-appstore.sh            # archive + export + validate
UPLOAD=1 ./scripts/build-appstore.sh   # also upload to App Store Connect
```

### CI use

Add these repository secrets, then run the **Package App Store** workflow
(`upload: true` to push the build):

- `APPLE_DISTRIBUTION_P12_BASE64`
- `MAC_INSTALLER_DISTRIBUTION_P12_BASE64`
- `CERTS_P12_PASSWORD`
- `CI_KEYCHAIN_PASSWORD`
- `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_API_KEY_BASE64`

## Build-number rule

App Store Connect rejects a duplicate `(MARKETING_VERSION, CURRENT_PROJECT_VERSION)`
pair. The project is currently `2.2.0` / build `6`. If build 6 was already
uploaded for 2.2.0, bump `CURRENT_PROJECT_VERSION` before re-uploading.

## After upload

The upload only delivers the binary. In App Store Connect you still must: attach
the build to the 2.2.0 version, complete metadata/screenshots/release notes, and
submit for review. Public availability follows Apple's review and your release
setting (manual or automatic).
