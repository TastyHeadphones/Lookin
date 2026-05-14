# Release checklist

Lookin releases produce a signed, notarized `Lookin-<version>.zip`
attached to a GitHub Release, plus a Cask update in the
`homebrew-lookin` tap repo.

## One-time setup (per fork / new repo)

Add the following secrets under **Settings → Secrets and variables →
Actions**:

| Secret | What it is |
|---|---|
| `MACOS_CERTIFICATE_BASE64` | `Developer ID Application` cert exported as `.p12`, then base64-encoded |
| `MACOS_CERTIFICATE_PASSWORD` | Password set when exporting the `.p12` |
| `KEYCHAIN_PASSWORD` | Anything random; used to lock the temp keychain on the runner |
| `DEVELOPMENT_TEAM` | Apple Developer team ID (10 chars) |
| `APPLE_ID` | Apple ID used for notarization |
| `APPLE_APP_SPECIFIC_PASSWORD` | App-specific password from appleid.apple.com |
| `APPLE_TEAM_ID` | Same as `DEVELOPMENT_TEAM` for `notarytool` |

The [release workflow](../.github/workflows/release.yml) fails fast
with a clear error message if any of the signing secrets are missing.

To produce the base64 cert:

```sh
base64 -i Developer\ ID\ Application.p12 | pbcopy
```

## Cutting a release

1. Bump `MARKETING_VERSION` in `Lookin.xcodeproj` for the `LookinClient`
   target. Commit on `Develop`.
2. Tag the commit and push:

   ```sh
   git tag v1.0.8
   git push origin v1.0.8
   ```

   The `release.yml` workflow triggers on tags matching `v*`, archives
   the app, signs with the Developer ID certificate, notarizes via
   `notarytool`, staples the ticket, packages a zip, and uploads to a
   GitHub Release.
3. Verify the published release. The release body includes the
   artifact `sha256` — copy it.
4. In the `homebrew-lookin` tap repo:

   ```sh
   sed -i '' \
     -e 's/version ".*"/version "1.0.8"/' \
     -e 's/sha256 ".*"/sha256 "<paste-from-release-body>"/' \
     Casks/lookin.rb
   git commit -am "chore: lookin 1.0.8"
   git push
   ```

5. Smoke test from a clean machine (or in a VM):

   ```sh
   brew uninstall --cask lookin 2>/dev/null || true
   brew untap TastyHeadphones/lookin 2>/dev/null || true
   brew tap TastyHeadphones/lookin
   brew install --cask lookin
   open -a Lookin
   ```

## Manual / dry-run releases

To build a signed artifact **without** tagging (e.g. to test the
pipeline), use **Actions → Release → Run workflow** on the `Develop`
branch. The dispatch form takes:

- `notarize` (default `false`) — set `true` to also notarize and
  staple.
- `draft_release` (default `true`) — uploads the artifact to a draft
  GitHub Release with a synthesized tag name so reviewers can install
  it without publishing.

The unsigned PR-validation path lives in the `macos-app-unsigned` job
of [ci.yml](../.github/workflows/ci.yml) — that's the one PRs from
forks (without secret access) run.

## Rollback

If a release breaks, do **not** delete the tag — Homebrew users have
already pulled the URL. Instead:

1. Mark the GitHub Release as a pre-release (un-attach from "Latest").
2. Push a new tag `v<old>+1` with the fix.
3. Re-bump the Cask to the new version.

`brew upgrade --cask lookin` will pick up the new release on next run.
