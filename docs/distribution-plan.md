# Distribution Plan

## Overview

ctrl-b is distributed as open source (MIT) with a free-tier GitHub Release and a paid convenience channel via Homebrew Cask once the app is code-signed and notarized.

## Why Not the App Store

ctrl-b uses `AXIsProcessTrustedWithOptions()` + `CGEvent.tapCreate(.cgSessionEventTap)` to intercept, discard, and replace keyboard events. This combination is blocked by App Sandbox:

- Accessibility APIs always return false in sandboxed apps
- Input Monitoring cannot replace this: it is read-only and cannot discard or synthesize events
- Apple has explicitly rejected apps using Accessibility permission for non-accessibility purposes since February 2026 (see: Whisper Notes rejection)
- All comparable apps (Keyboard Maestro, Karabiner-Elements, Alfred) distribute outside the App Store for the same reason

**App Store distribution is not possible — technically or by policy.**

## Why Not Homebrew Formula (Source Build)

Homebrew's official policy explicitly prohibits building `.app` bundles in Formulae:

> "Don't make your formula build an `.app` (native macOS Application); we don't want those things in Homebrew."

All macOS menu bar and GUI apps in Homebrew use Cask (pre-built binary), not Formula (source build). There are no exceptions in homebrew-core.

## Distribution Channels

| Channel | Cost | Gatekeeper | Notes |
|---------|------|------------|-------|
| GitHub Releases (unsigned) | Free | Requires workaround | Initial release, developer audience |
| Personal tap Cask (`yhbyhb/ctrl-b`) | $99/yr | Passes | `brew tap yhbyhb/ctrl-b && brew install --cask ctrl-b` |
| homebrew-cask official | $99/yr | Passes | `brew install --cask ctrl-b`, requires ~75 stars |
| GitHub Sponsors / Buy Me a Coffee | Voluntary | — | Monetization |

## Roadmap

### Phase 1 — Open Source Launch (Free)
- Clean up temp files (`debug_simulate.swift`, `spike_followup.swift`)
- Add `.claude/` to `.gitignore`
- Improve README (screenshot, install instructions, why Accessibility permission is needed)
- Make GitHub repo public

### Phase 2 — First Release (Free, Unsigned)
- Build `ctrl-b.app.zip` via `make app`
- Upload as GitHub Release `v1.0.0`
- Include unsigned app workaround in release notes:
  - Option A: Right-click → Open
  - Option B: `xattr -cr ctrl-b.app && open ctrl-b.app`
- Set up GitHub Sponsors or Buy Me a Coffee
- Add `.github/FUNDING.yml`

### Phase 3 — Code Signing & Notarization ($99/yr)
*Trigger: enough interest (stars, issues, sponsors)*

- Join Apple Developer Program
- Set up Developer ID Application certificate
- Add `codesign` step to `Makefile`
- Write `make notarize` script (`xcrun notarytool submit` + `staple`)
- Upload signed build as `v1.1.0`

### Phase 4 — Homebrew Cask (after Phase 3)

**4-A: Personal tap (first)**
1. Create `yhbyhb/homebrew-ctrl-b` repo on GitHub
2. Write Cask file (`Casks/ctrl-b.rb`):
   ```ruby
   cask "ctrl-b" do
     version "1.1.0"
     sha256 "<sha256>"
     url "https://github.com/yhbyhb/ctrl-b/releases/download/v#{version}/ctrl-b.app.zip"
     name "ctrl-b"
     desc "Fix Ctrl+key shortcuts under CJK IME"
     homepage "https://github.com/yhbyhb/ctrl-b"
     app "ctrl-b.app"
     uninstall quit: "com.yhbyhb.ctrl-b"
     zap trash: [
       "~/Library/Preferences/com.yhbyhb.ctrl-b.plist",
     ]
   end
   ```
3. Install via:
   ```
   brew tap yhbyhb/ctrl-b
   brew install --cask ctrl-b
   ```

**4-B: homebrew-cask official (after ~75 stars)**
- Submit PR to `homebrew/homebrew-cask`
- Enables: `brew install --cask ctrl-b` (no tap needed)

### Phase 5 — Sparkle Auto-Update (after Phase 3)
- Add Sparkle 2 dependency to `Package.swift`
- Create `appcast.xml` at repo root
- Add `SUFeedURL` to `Info.plist`
- Extend `make release` script: build → sign → notarize → zip → update appcast → upload GitHub Release

## Cost Summary

| Item | Cost | When |
|------|------|------|
| GitHub public repo | Free | Now |
| GitHub Sponsors / Buy Me a Coffee | Free to set up | Phase 2 |
| Apple Developer Program | $99/yr | Phase 3 (defer until traction) |
| Homebrew Cask (personal tap) | Free | Phase 4 |
| homebrew-cask official submission | Free | Phase 4-B |
