# Business Model Design

Date: 2026-04-20
Status: Draft

## Context

ctrl-b is a menu-bar macOS utility that works around a CJK IME bug affecting
Ctrl+letter shortcuts in terminals. The project has been developed privately
with the intent to eventually distribute it publicly. Before any distribution
work begins, this document defines:

- Whether the Mac App Store is a viable distribution channel
- How the app will be distributed (free vs. paid, channels)
- The license under which it will be offered
- The staged rollout from current private state to public launch, and
  potentially to a paid offering
- What signals would justify moving between stages

This spec supersedes the earlier `docs/distribution-plan.md` sketch; the
useful content from that file (Homebrew Formula policy quote, channel
matrix, Homebrew-cask official-tap threshold) is integrated below.

## Decision Summary

1. **Mac App Store is excluded from the roadmap.** Both technical (App Sandbox
   blocks `CGEvent.tapCreate` with `.defaultTap`) and policy (Apple rejects
   apps that use Accessibility features for non-accessibility purposes since
   2026-02) reasons make MAS infeasible with the current architecture.
2. **Direct distribution only.** GitHub Releases (notarized `.dmg`) and
   Homebrew Cask, following the Karabiner-Elements / BetterTouchTool pattern.
3. **License: MIT, unchanged.** Matches the Maccy/UTM precedent of free
   open-source core with an optional paid channel. MIT allows third parties
   to fork and resell; in the indie macOS ecosystem this is a theoretical
   risk rather than observed behavior, and we accept it.
4. **Three-stage rollout:** private dogfooding → public launch → optional paid
   tier. Each stage has explicit entry/exit criteria.
5. **$2.99 flat price if and when a paid tier is added.** Sold via Gumroad or
   Paddle; platform choice deferred to the time the paid tier is activated.
6. **In-app donations:** GitHub Sponsors and Ko-fi, surfaced as a "Support
   ctrl-b" submenu in the status bar menu.

## Why the Mac App Store Is Not Viable

### Technical block: App Sandbox and `.defaultTap`

ctrl-b's event tap is created with `options: .defaultTap`, which allows the
callback to drop the original event (by returning `nil`) and inject a
synthesized replacement. This capability requires Accessibility permission,
which the App Sandbox blocks.

The alternative, `options: .listenOnly`, requires only Input Monitoring
permission — which works in sandbox — but cannot drop events. Without the
ability to drop the IME-corrupted original, the user would receive both the
broken original and our synthetic replacement, defeating the purpose.

Apple's public guidance (Developer Forums thread 789896) confirms that
CGEventTap monitoring works in sandbox via Input Monitoring, and event
posting works via the PostEvent privilege. Active event modification with
`.defaultTap` is not addressed as sandbox-compatible, and no precedent of a
CGEventTap-based remapper on the Mac App Store was found during this
investigation. Comparable apps (Karabiner-Elements, BetterTouchTool,
Hyperkey, Hammerspoon, Keyboard Maestro) all distribute outside the App
Store.

### Policy block: Accessibility-for-non-accessibility

As of February 2026, Apple App Review rejects apps that use Accessibility
features for purposes other than supporting users with disabilities. The
Whisper Notes Mac app, which used the same category of API to insert
transcribed text, was rejected with:

> "The app uses Accessibility features to insert transcribed text.
> Accessibility features are intended to help users with different
> capabilities interact with their devices and app. Apps may not use
> features designed to increase accessibility for other purposes."

ctrl-b uses Accessibility for the same kind of non-accessibility purpose (IME
workaround), so the same rejection rationale applies.

### Re-evaluation conditions

Move MAS out of exclusion only if *both* blocks are lifted:

- Apple publicly supports `CGEventTap` with `.defaultTap` (active event
  modification) inside the App Sandbox without needing the Accessibility
  entitlement, **and**
- Apple relaxes its policy on Accessibility-for-non-accessibility purposes,
  or introduces a distinct non-accessibility entitlement for keyboard event
  remapping.

Until both conditions hold, perform only a lightweight annual check. No
active preparation work (entitlements, review notes, MAS assets) is done.

## Distribution Channels

### Homebrew Cask, not Homebrew Formula

Homebrew Formula is intended for CLI tools. Homebrew's own Formula Cookbook
forbids shipping `.app` bundles through Formulae:

> "Don't make your formula build an `.app` (native macOS Application); we
> don't want those things in Homebrew."

Every macOS menu-bar / GUI app in the official Homebrew taps uses Cask
(pre-built, code-signed binary). A personal tap could technically bend this
rule with a Formula that builds from source, but the resulting UX and
maintainability are inferior to a signed Cask, so ctrl-b follows the Cask
path once signing is in place.

### Channel matrix

| Channel | Fixed cost | Gatekeeper | Stage it becomes available |
|---|---|---|---|
| GitHub Releases (notarized `.dmg`) | $99/yr | Passes | Stage 1 |
| Personal tap Cask (`yhbyhb/ctrl-b`) | $99/yr | Passes | Stage 1 |
| homebrew-cask official tap | $99/yr + ~75 stars | Passes | Optional Stage 1 follow-up |
| GitHub Sponsors | $0 | n/a | Stage 1 |
| Ko-fi | $0 | n/a | Stage 1 |
| Gumroad / Paddle | Platform fees | n/a | Stage 2 only |

homebrew-cask's official tap has an unwritten expectation of reasonably
established projects (community rule of thumb is around 75 GitHub stars).
The personal tap works from Stage 1 without this bar; submitting to the
official tap is an optional later move, not a launch-day requirement.

## Distribution Strategy

### Stage 0: Private dogfooding (repo private)

Purpose: validate usability and find bugs before any public exposure.
The early portion of this stage costs nothing; the Apple Developer Program
enrollment ($99/year) is made only in the late-stage parallel work below,
once public launch feels close.

Activities:
- Daily personal use (terminal + Korean IME scenarios that exercise the
  prefix-follow-up remap path)
- Bugs and usability issues recorded in internal GitHub Issues
- Optional: direct binary share with 1-2 trusted people for additional
  signal, with manual Gatekeeper-bypass instructions
- Revise README and CONTRIBUTING to reflect current behavior

Not done in Stage 0:
- Apple Developer Program enrollment
- Homebrew tap publication
- Sponsors / Ko-fi account activation
- Sparkle integration
- Any public communication about the project

Exit criteria (all must hold):
1. At least 2 consecutive weeks of daily personal use with no critical bugs
   found.
2. Self-assessed confidence: "I would recommend this to a friend who has
   this problem."
3. All known issues either resolved or consciously documented as
   "won't fix."
4. README and CONTRIBUTING accurately reflect the current product.

Late-Stage-0 parallel work (once the above feel close, typically 2-3 weeks
before public launch):
- Enroll in Apple Developer Program ($99/year).
- Issue a Developer ID Application certificate.
- Build and test the notarization pipeline (`xcrun notarytool`) end-to-end
  against the private build.
- Integrate Sparkle with a placeholder feed URL.
- Create the Homebrew tap repo (`homebrew-ctrl-b`), kept private until
  launch.
- Prepare GitHub Sponsors tier configuration (without activating).
- Create a Ko-fi account.

### Stage 1: Public launch (repo visibility flip, $99 already spent)

Single trigger event: the ctrl-b repo visibility changes from private to
public. Everything else is prepared in advance so that the moment of
exposure gives a complete experience.

Coordinated at the flip:
- First notarized `.dmg` published on GitHub Releases.
- Homebrew tap repo made public.
- GitHub Sponsors page activated.
- Ko-fi link live.
- README shows normal install instructions (`brew install --cask yhbyhb/ctrl-b/ctrl-b`
  and direct download), with no Gatekeeper workarounds needed.
- Status-bar "Support ctrl-b" submenu points to working URLs.

Optional launch communication (planned in `docs/ROADMAP.md`, not this spec):
Product Hunt, Hacker News, relevant CJK developer communities, a short
"why this exists" blog post.

Signals that begin to accumulate at this point: GitHub Stars, Homebrew
install counts, Sponsors sign-ups, Ko-fi tips, issue and PR traffic,
explicit user feedback about paying.

### Stage 2: Optional paid tier (triggered by demand, not timeline)

Trigger: all three of the following hold. Both quantitative buckets are
required because usage alone does not prove willingness to pay, and
sponsorship alone does not prove there is an audience large enough to
sustain a paid tier.

- **Usage signal (at least one):**
  - 500+ GitHub Stars
  - 50+ Homebrew installs per week, sustained across 3+ months

- **Willingness-to-pay signal (at least one):**
  - 5+ currently-subscribed GitHub Sponsors, or $25+/month in recurring
    sponsorship income
  - 10+ explicit requests to pay

- **Qualitative readiness (AND condition):**
  - Maintenance burden feels larger than the enjoyment of working on the
    project
  - Willingness to run a paid product: handle purchases, provide support,
    process refunds, manage taxes via the chosen platform

When triggered:
- Create a Gumroad or Paddle listing at $2.99 (platform chosen at the time
  based on current fee structure and Merchant-of-Record treatment).
- Add a "Buy on Gumroad" (or equivalent) item to the "Support ctrl-b"
  submenu.
- The purchase is a trust-based contribution, not a license gate: the app
  remains fully functional when installed from GitHub or Homebrew. This
  mirrors the Maccy model.

### Fallback: stay free indefinitely (Stage 1 → never Stage 2)

If Stage 1 has been live for 12+ months and the trigger is not met, or if
the qualitative readiness never holds, Stage 2 is not activated. GitHub
Sponsors and Ko-fi remain the only support channels. No code or
infrastructure change is required for this path.

## In-App Support UX

Location: status-bar menu, below the existing statistics lines. The
placement co-locates the "this app saved me N minutes" moment with the
support prompt, which is the natural point of willingness.

Layout:

```
…
27 remaps · ~5.4 min saved
──────
Support ctrl-b ▸   GitHub Sponsors
                   Ko-fi
                   (Buy on Gumroad — added in Stage 2)
──────
Launch at Login
Quit
```

Implementation notes:
- Each submenu item opens a URL via `NSWorkspace.shared.open(_:)`.
- URLs live in a single config struct to keep them trivially updateable.
- Localized labels added to all four `Localizable.strings` files (en, ko,
  ja, zh-Hans).

This UI code ships in Stage 1. The "Buy" item is added in Stage 2 without
further structural change.

## Pricing

- **Free:** GitHub source, Homebrew, GitHub Releases `.dmg`.
- **Paid (Stage 2 only):** $2.99, one-time. Chosen as a "coffee-level"
  contribution that signals intent without creating a meaningful barrier.
  The free channel always exists alongside, so the paid tier is effectively
  opt-in support.

## Non-Goals

This spec does *not* decide:

- The app's minimum supported macOS version, Swift toolchain version, or
  runtime dependencies.
- App icon, naming, or branding changes.
- Feature roadmap (belongs in `docs/ROADMAP.md`).
- Product spec: problem description, interaction model, settings model
  (belongs in a future `docs/SPEC.md`).
- Marketing or launch-day communication plan (belongs in
  `docs/ROADMAP.md`).
- Legal review of the Homebrew tap, Gumroad/Paddle terms, or cross-border
  sales tax obligations. These are handled at the time the relevant stage
  is activated.
- Handling of third-party contributions (CLA, DCO, etc.). Deferred until
  contributions start to arrive.

## Note on naming

The user-facing app name and bundle are `ctrl-b` (see commit 420c5dc).
Swift Package Manager target directories and module names remain `CtrlB`
because Swift module names cannot contain hyphens. When this spec refers
to the product in prose, "ctrl-b" is used; when it refers to source
directories or Swift types, the module name appears unchanged.

## References

- Apple Developer Forums thread 789896 — "Accessibility Permission In
  Sandbox For Keyboard"
  <https://developer.apple.com/forums/thread/789896>
- Apple Developer Forums thread 668975 — "CGEventTap and App Store"
  <https://developer.apple.com/forums/thread/668975>
- Whisper Notes — "Why Whisper Notes for Mac Left the App Store"
  <https://whispernotes.app/blog/why-whisper-notes-left-mac-app-store>
- Homebrew — "Acceptable Casks"
  <https://docs.brew.sh/Acceptable-Casks>
- Homebrew — "Formula Cookbook"
  <https://docs.brew.sh/Formula-Cookbook>
- Workbrew — "What Homebrew 5.0.0 means for your Mac fleet"
  <https://workbrew.com/blog/homebrew-5-0-0>
- Maccy <https://github.com/p0deje/Maccy> — MIT + MAS $10, precedent for
  free-open-source-plus-paid-channel.
- Rectangle <https://github.com/rxhanson/Rectangle> and Rectangle Pro
  <https://rectangleapp.com/pro/> — open-core precedent.
- UTM <https://github.com/utmapp/UTM> — free GitHub / paid MAS precedent
  for Apache-2.0.
