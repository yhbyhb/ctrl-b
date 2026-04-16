# Privacy Policy

Last updated: 2026-04-16

## Overview

CtrlB is a macOS menu bar utility that fixes Ctrl+key shortcuts when a non-ASCII input method (e.g., Korean IME) is active. Your privacy is important to us, and this policy explains how CtrlB handles your data.

## Data Collection

**CtrlB does not collect, store, or transmit any personal data.**

Specifically:

- **No network access**: CtrlB does not connect to the internet. It has no analytics, telemetry, crash reporting, or update checking functionality.
- **No keylogging**: CtrlB intercepts keyboard events solely to remap Ctrl+key combinations. Keystrokes are processed in memory and never recorded or stored.
- **No user tracking**: CtrlB does not use any tracking, advertising, or fingerprinting technologies.

## Local Data

CtrlB stores the following data **locally on your Mac only**, using macOS UserDefaults:

- Remap count (how many times a key was remapped)
- Estimated time saved
- Launch-at-login preference

This data never leaves your device and can be reset from the menu bar menu at any time.

## Accessibility Permission

CtrlB requires macOS Accessibility permission to intercept and remap keyboard events via CGEventTap. This permission is used exclusively for the app's core functionality. No keystroke data is collected, logged, or transmitted.

## Third-Party Services

CtrlB does not use any third-party services, SDKs, or frameworks that collect data.

## Changes to This Policy

If this policy changes, the updated version will be posted in this repository with a new "Last updated" date.

## Contact

If you have questions about this privacy policy, please open an issue at:
https://github.com/yhbyhb/CtrlB/issues
