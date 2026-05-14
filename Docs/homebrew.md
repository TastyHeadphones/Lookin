# Distributing Lookin via Homebrew

Lookin ships a Homebrew Cask so users can install the signed macOS
build with `brew install --cask lookin`. The Cask itself is small
([Casks/lookin.rb](../Casks/lookin.rb) in this repo for reference); the
question is *where* it lives.

## Recommended layout: separate tap repo

Homebrew expects taps to live in repositories named
`<org>/homebrew-<tap>`. Create a dedicated tap repo so:

- `brew tap` works without surprise (`brew tap TastyHeadphones/lookin`
  resolves to `github.com/TastyHeadphones/homebrew-lookin`).
- The main `Lookin` repo doesn't need a `Casks/` PR every release —
  only the tap repo bumps version + sha256.
- The tap repo can be public even if Lookin's main repo policies
  change later.

### Initial setup

1. Create `github.com/TastyHeadphones/homebrew-lookin`.
2. Add `Casks/lookin.rb` to the new repo (copy from this repo's
   [Casks/lookin.rb](../Casks/lookin.rb)).
3. Commit and push to `main`.

That's it — `brew tap` discovers the cask automatically.

### Install from the tap

```sh
brew tap TastyHeadphones/lookin
brew install --cask lookin
```

Or one-shot:

```sh
brew install --cask TastyHeadphones/lookin/lookin
```

## Why not put the Cask inline in the Lookin repo?

`brew tap <user>/<repo>` can target any GitHub repo if you pass
`--force-auto-update`, but the canonical naming convention is the
`homebrew-*` prefix. Users who don't read docs will type
`brew tap TastyHeadphones/lookin` and expect it to work without flags.
The reference [`Casks/lookin.rb`](../Casks/lookin.rb) in this repo
exists so the Cask source-of-truth is reviewed alongside the app, but
publishing it should happen via the tap repo.

## Per-release bump

Every signed Lookin release triggers a Cask bump in the tap repo. See
[Docs/release.md](release.md) for the full checklist; the short version:

1. Read the `sha256` from the release notes published by the
   [Release workflow](../.github/workflows/release.yml).
2. Update `version` and `sha256` in `Casks/lookin.rb` in the tap repo.
3. Run `brew style --fix Casks/lookin.rb` locally if you have brew
   installed.
4. Commit `chore: lookin <version>` and push.

`brew livecheck` will catch missed bumps on the next run, but the
deterministic path is to bump the tap immediately after each Lookin
release.
