# App Store Submission Checklist

Target: week of 2026-04-21

## Prerequisites
- [ ] Apple Developer Program enrollment ($99/year)
- [ ] Make GitHub repo public
- [ ] Privacy Policy URL (GitHub URL or GitHub Pages)

## App Store Connect
- [ ] Create app in App Store Connect
  - App name: CtrlB
  - Bundle ID: com.yhbyhb.CtrlB
  - Category: Utilities (or Productivity)
  - Price: $2.99–$4.99
  - Support URL: https://github.com/yhbyhb/CtrlB/issues
  - Privacy Policy URL: TBD

## Code Signing & Build
- [ ] Create Distribution certificate
- [ ] Create Provisioning Profile
- [ ] Enable App Sandbox (entitlements file already prepared)
- [ ] Enable Hardened Runtime
- [ ] Build via Xcode Archive → Upload (swift build cannot produce signed builds)

## Assets
- [ ] Screenshots (minimum 1, Retina resolution: 2560x1600 or 2880x1800)
- [ ] App icon 1024x1024 PNG (for App Store Connect)

## Metadata (already prepared in `chore/appstore-metadata` branch)
- [x] Description (`appstore/description.txt`)
- [x] Keywords (`appstore/keywords.txt`)
- [x] Review notes (`appstore/review-notes.txt`)
- [x] Release notes (`appstore/whats-new.txt`)
- [x] Entitlements (`Resources/CtrlB.entitlements`)

## Submit
- [ ] Merge `chore/appstore-metadata` branch
- [ ] Upload build to App Store Connect
- [ ] Fill in metadata, screenshots, pricing
- [ ] Submit for review (typically 1–3 days)

## Post-submission
- [ ] CONTRIBUTING.md
- [ ] Release Please setup
- [ ] Homebrew cask registration (when user base grows)
