# Releasing Port Watcher

This document covers cutting a notarized release. Users do not need to read this.

## One-time setup

### 1. Developer ID Application certificate

Generated at <https://developer.apple.com> → Certificates → **Developer ID Application**. Install the resulting `.cer` so it appears in:

```bash
security find-identity -v -p codesigning | grep "Developer ID Application"
```

### 2. App-specific password for notarytool

Generated at <https://appleid.apple.com> → Sign-In and Security → App-Specific Passwords. Store it in the keychain so the Makefile target can use it non-interactively:

```bash
xcrun notarytool store-credentials portwatcher-notary \
    --apple-id YOUR_APPLE_ID \
    --team-id R83AAQ27AZ \
    --password APP_SPECIFIC_PASSWORD
```

That writes a keychain item named `portwatcher-notary`. The `Makefile` references it via `NOTARY_PROFILE`.

### 3. GitHub Actions secrets (only if releasing via tag push)

Export the Developer ID cert + private key from Keychain Access as a `.p12`, then in the repo's GitHub Settings → Secrets and variables → Actions, add:

| Secret | Value |
|---|---|
| `DEVELOPER_ID_CERT_BASE64` | `base64 -i cert.p12 \| pbcopy` |
| `DEVELOPER_ID_CERT_PASSWORD` | The export password you set on the `.p12` |
| `KEYCHAIN_PASSWORD` | Any random string — used to unlock the runner's temporary keychain |
| `APPLE_ID` | Your Apple ID email |
| `APPLE_TEAM_ID` | `R83AAQ27AZ` |
| `APPLE_APP_PASSWORD` | The app-specific password from step 2 |

## Cutting a release

### Local

```bash
make release
```

Produces `dist/PortWatcher.zip` — notarized, stapled, ready to upload to a GitHub Release.

### Via GitHub Actions

```bash
# Bump CFBundleShortVersionString + CFBundleVersion in PortWatcher/Info.plist first.
git tag v1.0.1
git push origin v1.0.1
```

The `Release` workflow builds, signs, notarizes, staples, and attaches the zip to a GitHub Release.

## Verifying a build is shippable

```bash
make verify
```

Expected output includes:

- `Authority=Developer ID Application: GreenFlux, LLC (R83AAQ27AZ)`
- `Runtime Version=…` (Hardened Runtime is on)
- `accepted` from `spctl` (Gatekeeper accepts it)

If `spctl` says `rejected`, the app is not notarized yet — run `make release` rather than `make build`.

## After a release

Update the Homebrew Cask:

```bash
brew bump-cask-pr port-watcher --version 1.0.1
```

(Once the cask exists. See `docs/HOMEBREW.md`.)
