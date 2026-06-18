# Release automation

The `.github/workflows/release.yml` workflow builds, signs, notarizes, and
publishes the Ko-fi `.pkg` on every version tag. Existing users see the new
release via the in-app updater (`UpdateChecker` polls the GitHub
`releases/latest` endpoint).

## How it triggers

| Trigger | What happens |
|---|---|
| Push a tag matching `v*` (`git tag v2.0.1 && git push --tags`) | Full pipeline runs, release created with that tag |
| Manual run via Actions UI (workflow_dispatch) | Same pipeline, tag defaults to `manual-<timestamp>` if no tag |

## Pipeline

1. `validate` builds Debug + Release on a fresh macOS-15 runner with no signing
2. `package` imports your Apple certs into a temporary keychain, runs
   `scripts/build-release-pkg.sh`, submits the result to Apple notary service,
   waits for `Accepted`, staples, and uploads the pkg to a GitHub release

## One-time setup: secrets

Go to **Settings → Secrets and variables → Actions → New repository secret**
and add each of the following.

### Certificate secrets

Export the two Developer ID certs from your local Keychain as `.p12` files.

```bash
# Find the names exactly as Keychain shows them
security find-identity -v -p codesigning | grep "Developer ID Application"
security find-identity -v               | grep "Developer ID Installer"

# Export each (Keychain Access GUI is easiest):
#   1. Right-click the certificate -> Export
#   2. Format: Personal Information Exchange (.p12)
#   3. Pick a password (the SAME password for both .p12s, since the workflow
#      uses one CERTS_P12_PASSWORD for both)
#   4. Save as developer-id-application.p12 and developer-id-installer.p12
```

Then base64-encode and copy each:

```bash
base64 -i developer-id-application.p12 | pbcopy   # paste into DEVELOPER_ID_APPLICATION_P12_BASE64
base64 -i developer-id-installer.p12   | pbcopy   # paste into DEVELOPER_ID_INSTALLER_P12_BASE64
```

| Secret | Value |
|---|---|
| `DEVELOPER_ID_APPLICATION_P12_BASE64` | base64 of `developer-id-application.p12` |
| `DEVELOPER_ID_INSTALLER_P12_BASE64`   | base64 of `developer-id-installer.p12`   |
| `CERTS_P12_PASSWORD`                  | the password you set when exporting     |

### Notarization secrets

| Secret | Value | Where it comes from |
|---|---|---|
| `APPLE_ID`                       | `peterdsp29@gmail.com` | Your Apple ID account |
| `APPLE_APP_SPECIFIC_PASSWORD`    | e.g. `abcd-efgh-ijkl-mnop` | https://appleid.apple.com → Sign-In and Security → App-Specific Passwords. Name it something like "PromptBar CI". |
| `CI_KEYCHAIN_PASSWORD`           | any random string, never used outside CI | Generate one: `openssl rand -base64 24` |

`APPLE_TEAM_ID` is hard-coded in the workflow as `YTS4KJBX3P`. If that ever
changes, update `env.TEAM_ID` in `release.yml`.

## Cutting a release

After your code changes are merged into `main`:

```bash
# Bump MARKETING_VERSION and CURRENT_PROJECT_VERSION in the pbxproj first
git tag v2.0.1
git push --tags
```

The workflow runs (about 12-20 minutes for the full pipeline), produces
`PromptBar-2.0.1.pkg`, and attaches it to `https://github.com/peterdsp/PromptBar/releases/v2.0.1`.

Every installed Ko-fi copy of PromptBar checking for updates after that point
will offer the new version.

## Failure modes worth knowing

- **`certificate is not trusted`** during sign: the workflow imports the cert
  but Apple's trust chain may require the intermediate Developer ID CA. The
  `macos-15` runner already has these. If a future runner version doesn't,
  add a step that downloads
  `https://www.apple.com/certificateauthority/DeveloperIDCA.cer` and imports
  it into the temp keychain.
- **`Status: Invalid`** from notarytool: the certificate must be a *Developer
  ID* cert, not Apple-managed. Apple-managed certs cannot sign for outside
  distribution.
- **Notarization hangs**: Apple's notary service has rare slow periods.
  `--wait` will eventually return; the job has a 45-minute timeout.
- **`stapler` says "in-progress"**: the notarization completed but the staple
  ticket isn't propagated yet. Adding a `sleep 30` between submit and staple
  helps, but `--wait` usually makes it redundant.

## Tagging discipline

The `UpdateChecker` reads `tag_name` from the GitHub release JSON. If a tag
doesn't start with `v`, the in-app version comparator may treat it as older
than the installed version (you'll see "you're on the latest" forever). Stick
to `v<semver>`.
