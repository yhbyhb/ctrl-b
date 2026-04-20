# In-App Support Menu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "Support ctrl-b" submenu to the status-bar menu, with localized entries for GitHub Sponsors and Ko-fi that open the corresponding URLs in the default browser. Shipping this in Stage 0 lets the UI ride along in dogfooding; URLs are updated (not restructured) at Stage 1 launch.

**Architecture:** A tiny enum `SupportLinks` holds the two URLs as typed constants, isolated from menu code so Stage 1 launch only touches URL strings and Stage 2 adds one more constant plus one more menu item. `StatusBarController.buildMenu(_:)` is extended to insert the submenu between the existing statistics block and the "Launch at Login" item, matching the layout in the business-model spec. All labels go through `NSLocalizedString`, following the existing pattern.

**Tech Stack:** Swift 5.9, Cocoa (`NSMenu`, `NSMenuItem`, `NSWorkspace`), SPM resource localization.

**Reference spec:** `docs/superpowers/specs/2026-04-20-business-model-design.md` ("In-App Support UX" section).

---

## File Structure

- Create: `Sources/CtrlB/SupportLinks.swift` — URL constants.
- Modify: `Sources/CtrlB/StatusBarController.swift` — add submenu + two action selectors.
- Modify: `Sources/CtrlB/Resources/en.lproj/Localizable.strings` — add 3 keys.
- Modify: `Sources/CtrlB/Resources/ko.lproj/Localizable.strings` — add 3 keys.
- Modify: `Sources/CtrlB/Resources/ja.lproj/Localizable.strings` — add 3 keys.
- Modify: `Sources/CtrlB/Resources/zh-Hans.lproj/Localizable.strings` — add 3 keys.

No tests are added. `StatusBarController` is Cocoa-dependent and has no existing test coverage; `SupportLinks` holds three literal URL strings and is verified at runtime.

---

## Task 1: Add `SupportLinks` URL constants

**Files:**
- Create: `Sources/CtrlB/SupportLinks.swift`

- [ ] **Step 1: Create the file**

Write `Sources/CtrlB/SupportLinks.swift`:

```swift
import Foundation

/// Destination URLs for the "Support ctrl-b" menu. URLs go live at Stage 1 launch.
enum SupportLinks {
    static let githubSponsors = URL(string: "https://github.com/sponsors/yhbyhb")!
    static let kofi = URL(string: "https://ko-fi.com/yhbyhb")!
}
```

- [ ] **Step 2: Build to confirm the file compiles**

Run: `swift build -c release`
Expected: Build succeeds with no warnings or errors about `SupportLinks`.

- [ ] **Step 3: Commit**

```bash
git add Sources/CtrlB/SupportLinks.swift
git commit -m "feat: add SupportLinks URL constants for donation channels"
```

---

## Task 2: Add localized strings (English)

**Files:**
- Modify: `Sources/CtrlB/Resources/en.lproj/Localizable.strings`

- [ ] **Step 1: Add 3 keys under a new "Support Menu" section**

Insert these lines between the existing `"menu.quit"` line and the `/* Accessibility Alert */` comment block:

```
/* Support Menu */
"menu.support" = "Support ctrl-b";
"menu.support.sponsors" = "GitHub Sponsors";
"menu.support.kofi" = "Ko-fi";

```

The resulting file should have the following ordering: Menu, Support Menu, Accessibility Alert, Time Formatting.

- [ ] **Step 2: Build to confirm the resource is still valid**

Run: `swift build -c release`
Expected: Build succeeds. No errors about malformed `Localizable.strings`.

- [ ] **Step 3: Commit**

```bash
git add Sources/CtrlB/Resources/en.lproj/Localizable.strings
git commit -m "feat(i18n): add English strings for Support ctrl-b submenu"
```

---

## Task 3: Add localized strings (Korean)

**Files:**
- Modify: `Sources/CtrlB/Resources/ko.lproj/Localizable.strings`

- [ ] **Step 1: Add 3 keys in the same position as Task 2**

Insert between `"menu.quit"` and `/* Accessibility Alert */`:

```
/* Support Menu */
"menu.support" = "ctrl-b 후원";
"menu.support.sponsors" = "GitHub Sponsors";
"menu.support.kofi" = "Ko-fi";

```

"GitHub Sponsors" and "Ko-fi" are product names and stay in English/original form, matching the style used by Maccy, Rectangle, and other macOS utilities.

- [ ] **Step 2: Build to confirm**

Run: `swift build -c release`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/CtrlB/Resources/ko.lproj/Localizable.strings
git commit -m "feat(i18n): add Korean strings for Support ctrl-b submenu"
```

---

## Task 4: Add localized strings (Japanese)

**Files:**
- Modify: `Sources/CtrlB/Resources/ja.lproj/Localizable.strings`

- [ ] **Step 1: Add 3 keys in the same position as Task 2**

Insert between `"menu.quit"` and `/* Accessibility Alert */`:

```
/* Support Menu */
"menu.support" = "ctrl-b を支援";
"menu.support.sponsors" = "GitHub Sponsors";
"menu.support.kofi" = "Ko-fi";

```

- [ ] **Step 2: Build to confirm**

Run: `swift build -c release`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/CtrlB/Resources/ja.lproj/Localizable.strings
git commit -m "feat(i18n): add Japanese strings for Support ctrl-b submenu"
```

---

## Task 5: Add localized strings (Simplified Chinese)

**Files:**
- Modify: `Sources/CtrlB/Resources/zh-Hans.lproj/Localizable.strings`

- [ ] **Step 1: Add 3 keys in the same position as Task 2**

Insert between `"menu.quit"` and `/* Accessibility Alert */`:

```
/* Support Menu */
"menu.support" = "支持 ctrl-b";
"menu.support.sponsors" = "GitHub Sponsors";
"menu.support.kofi" = "Ko-fi";

```

- [ ] **Step 2: Build to confirm**

Run: `swift build -c release`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/CtrlB/Resources/zh-Hans.lproj/Localizable.strings
git commit -m "feat(i18n): add Simplified Chinese strings for Support ctrl-b submenu"
```

---

## Task 6: Add the "Support ctrl-b" submenu to `StatusBarController`

**Files:**
- Modify: `Sources/CtrlB/StatusBarController.swift`

The menu layout after this task:

```
Ctrl+key remapping           ← disabled header
────────
✓ Enabled                    ← toggle
────────
Today: N times · T saved     ← disabled stats
Total: N times · T saved     ← disabled stats
────────
Reset Statistics
────────
Support ctrl-b ▸    GitHub Sponsors   ← NEW submenu
                   Ko-fi
────────
✓ Launch at Login
────────
Quit
```

- [ ] **Step 1: Add submenu construction inside `buildMenu(_:)`**

In `Sources/CtrlB/StatusBarController.swift`, locate this block (lines 55-57 in the current file):

```swift
        // Reset
        menu.addItem(action(localized("menu.reset"), #selector(resetStats)))
        menu.addItem(.separator())
```

Immediately after it (before the "Launch at login" block), insert:

```swift
        // Support submenu
        let supportItem = NSMenuItem(title: localized("menu.support"), action: nil, keyEquivalent: "")
        let supportSubmenu = NSMenu()
        supportSubmenu.addItem(action(localized("menu.support.sponsors"), #selector(openSponsors)))
        supportSubmenu.addItem(action(localized("menu.support.kofi"), #selector(openKofi)))
        supportItem.submenu = supportSubmenu
        menu.addItem(supportItem)
        menu.addItem(.separator())
```

- [ ] **Step 2: Add the two action selectors**

In the same file, locate the `// MARK: - Actions` section (around line 69). Immediately after `toggleLaunchAtLogin()` (around line 81), add:

```swift
    @objc private func openSponsors() {
        NSWorkspace.shared.open(SupportLinks.githubSponsors)
    }

    @objc private func openKofi() {
        NSWorkspace.shared.open(SupportLinks.kofi)
    }
```

- [ ] **Step 3: Build to confirm the app compiles**

Run: `swift build -c release`
Expected: Build succeeds. No warnings about unused selectors or missing resources.

- [ ] **Step 4: Commit**

```bash
git add Sources/CtrlB/StatusBarController.swift
git commit -m "feat: add Support ctrl-b submenu to status bar"
```

---

## Task 7: Manual verification

No automated tests exist for `StatusBarController` (Cocoa-dependent, per project convention). Verify the behavior end-to-end on the developer's machine.

- [ ] **Step 1: Build and package the `.app` bundle**

Run: `make app`
Expected: `ctrl-b.app` is recreated under the repo root with the new binary.

- [ ] **Step 2: Quit any running ctrl-b instance and launch the fresh build**

The executable inside the bundle is still named `CtrlB` (Swift module naming constraint), so `pkill CtrlB` is correct even though the app is `ctrl-b.app`.

Run:
```bash
pkill CtrlB 2>/dev/null; sleep 1; open ./ctrl-b.app
```
Expected: The menu bar shows `⌃b`.

- [ ] **Step 3: Inspect the menu**

Click the `⌃b` status item.
Expected:
- "Support ctrl-b" appears between "Reset Statistics" and "Launch at Login".
- Hovering "Support ctrl-b" expands the submenu with two items: "GitHub Sponsors" and "Ko-fi".

- [ ] **Step 4: Verify the links open**

Click "GitHub Sponsors".
Expected: Default browser opens `https://github.com/sponsors/yhbyhb`. The page may show a 404 or an empty-profile state during Stage 0; that is acceptable. What must work is that the URL is launched by the app.

Click the status item again, hover "Support ctrl-b", click "Ko-fi".
Expected: Default browser opens `https://ko-fi.com/yhbyhb`. Same Stage-0 caveat about the destination page.

- [ ] **Step 5: Verify localization**

Open System Settings → General → Language & Region. Temporarily set the "Preferred Languages" top entry to Korean, Japanese, then Simplified Chinese, quitting and re-launching ctrl-b.app each time.
Expected:
- Korean build shows "ctrl-b 후원" as the submenu parent; submenu children remain "GitHub Sponsors" and "Ko-fi".
- Japanese build shows "ctrl-b を支援".
- Simplified Chinese build shows "支持 ctrl-b".

Restore the preferred language after verification.

- [ ] **Step 6: Record the verification result in the commit message of the next change**

No commit here. This task is a manual gate before marking the plan complete.

---

## Done criteria

All of the following hold:
- `swift build -c release` succeeds.
- `make app` produces a `ctrl-b.app` that shows the new submenu with correct localized labels in all four supported languages.
- Clicking each submenu item opens the corresponding URL in the default browser.
- Six commits on `main` (or current working branch) corresponding to Tasks 1–6.

## Stage 1 / Stage 2 follow-ups (out of scope for this plan)

- Stage 1 launch: activate GitHub Sponsors, create Ko-fi account, confirm both URLs resolve to real profiles. Update `SupportLinks` only if handles differ.
- Stage 2 activation: add `Sources/CtrlB/SupportLinks.swift` constant `gumroadListing` (or Paddle equivalent), add a third submenu entry in `StatusBarController`, add the three localized strings for the "Buy" label. The structure established in this plan is expected to absorb that change in a single small commit per locale.
