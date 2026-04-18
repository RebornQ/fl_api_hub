# Platform Development Guidelines

> Platform-specific (iOS / macOS / Android / Web / Desktop) build, signing, and
> configuration conventions for this Flutter project.

---

## Overview

This directory documents non-Dart, platform-layer knowledge that is easy to get
wrong and expensive to rediscover — Xcode project settings, entitlements,
Gradle / Podfile details, native bootstrap, etc.

Dart / Flutter domain rules live in `../backend/` and `../frontend/`. Cross-layer
(Dart ↔ native) design guidance lives in `../guides/`.

---

## Guidelines Index

| Guide                                 | Description                                                          | Status   |
| ------------------------------------- | -------------------------------------------------------------------- | -------- |
| [macOS Signing](./macos-signing.md)   | Xcode signing for local dev without an Apple Team (adhoc / `"-"`)    | Authored |

---

## How to Fill These Guidelines

For each new file:

1. Start from a **real incident** or a real configuration choice this repo made.
2. Include the **exact Xcode / Gradle / Podfile field names and values**, not
   prose-only advice.
3. Capture **what broke**, why it broke, and the **minimal fix** that was
   accepted.
4. Record the **migration path back** if the local workaround has to be undone
   when entering a different environment (e.g. "switch back before shipping to
   App Store").

---

**Language**: All documentation should be written in **English**.
