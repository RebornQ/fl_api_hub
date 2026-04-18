# macOS Signing — Local Dev Without an Apple Team

> How to make `flutter build macos` and `flutter run -d macos` succeed on a
> developer machine that does **not** have an Apple Developer Team enrolled in
> Xcode, and how to keep Xcode's "Signing & Capabilities" panel showing
> `Provisioning Profile: None Required`.

---

## Overview

This repo historically had its macOS Runner target configured for real Apple
Team signing (`CODE_SIGN_IDENTITY = "Apple Development"`, `ProvisioningStyle =
Manual`). On machines without an enrolled Team, Xcode fails the build with:

```
error: Signing for "Runner" requires a development team.
       Select a development team in the Signing & Capabilities editor.
```

The accepted local-dev configuration is **adhoc signing** (`CODE_SIGN_IDENTITY
= "-"`, also called "Sign to Run Locally"). This is what a freshly created
Flutter macOS project ships with.

Adhoc is sufficient to run/debug the app locally. It is **not** acceptable for
App Store distribution or notarized redistribution.

---

## Historical Note: Why This Project Dropped `flutter_secure_storage`

The first attempt was adhoc signing + stripped `keychain-access-groups` from
entitlements. Build succeeded, but `flutter_secure_storage_darwin` 10.0 still
threw `PlatformException(Code: -34018, errSecMissingEntitlement)` at runtime
the moment any write was attempted.

Root cause (confirmed by reading
`~/.pub-cache/.../flutter_secure_storage_darwin-0.2.0/.../FlutterSecureStorage.swift`):
the plugin hard-codes `kSecUseDataProtectionKeychain = true` on macOS. Under
that backend, the calling process must carry either:

1. an `application-identifier` derived from a real Apple Team signature, or
2. an explicit `keychain-access-groups` entitlement.

Adhoc signing provides neither. `keychain-access-groups` is an Apple-defined
**restricted entitlement** — adhoc / self-signed certificates are not allowed
to embed it; Xcode refuses with `"requires signing with a development
certificate"`. `$(AppIdentifierPrefix)` would also expand to an empty string
under adhoc because there is no provisioning profile.

**Resolution**: the project removed `flutter_secure_storage` entirely (see
commit after `04-19-storage-flatten-secrets`). Sensitive fields (`accessToken`
on `Account`, `keyValue` on `ApiKey`) are now plaintext strings stored on the
entity itself, serialized via `AccountMapper` / `ApiKeyMapper` into the
existing Hive boxes. Threat model: local machine is trusted; anyone with file
access to `~/Library/Application Support/...` can read the tokens. Consistent
with other single-user local tools.

---

## Required Build Settings (`macos/Runner.xcodeproj/project.pbxproj`)

The Runner target's three XCBuildConfiguration blocks (Debug / Release /
Profile) must all carry the same four fields:

```
"CODE_SIGN_IDENTITY[sdk=macosx*]" = "-";
CODE_SIGN_STYLE = Automatic;
DEVELOPMENT_TEAM = "";
PROVISIONING_PROFILE_SPECIFIER = "";
```

`attributes → TargetAttributes` must pair with them:

```
33CC10EC2044A3C60003C045 = {    // Runner
    ProvisioningStyle = Automatic;
};
33CC111A2044C6BA0003C045 = {    // Flutter Assemble (aggregate)
    ProvisioningStyle = Automatic;
};
```

### Xcode UI Expected Result

Open `macos/Runner.xcworkspace`, select Target **Runner** → **Signing &
Capabilities**, switch between Debug / Release / Profile:

| Field                 | Expected Value           |
| --------------------- | ------------------------ |
| Team                  | None                     |
| Bundle Identifier     | (current app id)         |
| Provisioning Profile  | **None Required**        |
| Signing Certificate   | **Sign to Run Locally**  |

---

## Required Entitlements (`macos/Runner/*.entitlements`)

Both `DebugProfile.entitlements` and `Release.entitlements` **must not**
contain `keychain-access-groups` (or any other restricted entitlement) under
adhoc signing.

```xml
<!-- FORBIDDEN under adhoc signing -->
<key>keychain-access-groups</key>
<array>
    <string>$(AppIdentifierPrefix)com.example.app</string>
</array>
```

### Why

`keychain-access-groups` is a **restricted entitlement** that Apple's codesign
tooling refuses to embed unless the signing identity is a real Apple
Development / Distribution certificate. Adhoc (`-`) signing triggers:

```
error: "Runner" has entitlements that require signing with a development
       certificate. Enable development signing in the Signing & Capabilities
       editor.
```

Removing `keychain-access-groups` makes the build pass, but any plugin
requiring Data Protection Keychain will still fail at runtime with
`-34018 errSecMissingEntitlement` (see Historical Note above).

### Baseline entitlements contents kept by this repo

```xml
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0">
<dict>
  <key>com.apple.security.app-sandbox</key>
  <false/>
  <key>com.apple.security.cs.allow-jit</key>
  <true/>
  <key>com.apple.security.network.server</key>
  <true/>
  <key>com.apple.security.network.client</key>
  <true/>
</dict>
</plist>
```

Sandbox is **disabled** on purpose (unrestricted local file / network access
during dev). This repo does not ship any Keychain-backed plugin — secrets
live in Hive boxes, not the system Keychain.

---

## Forbidden Patterns

- Setting `"CODE_SIGN_IDENTITY[sdk=macosx*]" = "Apple Development"` at the
  target level. It overrides the project-level `"-"` and forces real-team
  signing.
- Mixing `ProvisioningStyle = Manual` in `TargetAttributes` with
  `CODE_SIGN_STYLE = Automatic` in a build configuration. Xcode arbitrates
  between them and reports confusing errors.
- Leaving `CODE_SIGN_STYLE = Manual` on any Runner configuration without also
  providing a `PROVISIONING_PROFILE_SPECIFIER`. Manual signing requires a
  profile.
- Re-introducing `keychain-access-groups` or any other restricted entitlement
  without also restoring real-team signing.
- Re-introducing `flutter_secure_storage` (or any Keychain-backed plugin) on
  macOS without first switching to a real Apple Development signature. See
  Historical Note.
- Relying on `$(AppIdentifierPrefix)` in any adhoc context — it expands to
  empty.

---

## Common Mistakes

| Mistake                                                                                 | Symptom                                                                                                          | Fix                                                                     |
| --------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| Added `keychain-access-groups` in Xcode UI for a feature that needs Keychain            | `entitlements that require signing with a development certificate` at build time                                 | Remove it for local dev; re-add only when real-team signing is restored |
| Toggled Xcode "Automatically manage signing" on/off                                     | pbxproj ends up with `DEVELOPMENT_TEAM` removed AND `CODE_SIGN_STYLE = Manual`; Release build fails              | Reset the four fields back to the Required Build Settings above        |
| Set a personal Apple ID team in Xcode once, then removed the account                    | `CODE_SIGN_IDENTITY = "Apple Development"` persists in pbxproj even though the team no longer exists             | Manually restore `"-"` per this doc                                     |
| Re-added `flutter_secure_storage` thinking adhoc + removed `keychain-access-groups` is enough | Build passes, runtime throws `-34018 errSecMissingEntitlement` on first write                                    | Use Hive plaintext storage instead; Keychain needs a real Apple Team    |

---

## Verification

### Pre-commit (required)

```bash
flutter clean
flutter pub get
flutter build macos --debug --no-pub
```

Expected: exit 0, no `requires a development team` and no `require signing
with a development certificate` errors.

### Signing check (required)

```bash
codesign -dvv build/macos/Build/Products/Debug/all_api_hub_flutter.app 2>&1
```

Expected output contains:

```
Signature=adhoc
Identifier=<bundle id>
TeamIdentifier=not set
```

### Runtime smoke (recommended)

```bash
flutter run -d macos
```

Exercise the Hive-backed entity read/write path (add an account, set an
access token, restart the app, confirm the token is recovered from the
`accounts` Hive box). Expect **no** `-34018` exception now that the Keychain
path is gone.

### Xcode UI spot check (recommended)

Open `macos/Runner.xcworkspace`, Target **Runner** → **Signing &
Capabilities**. Cycle Build Configuration through Debug / Release / Profile
and confirm the table in [Xcode UI Expected Result](#xcode-ui-expected-result).

---

## Migration Back to Real Apple Team Signing

When a developer is ready to ship or notarize:

1. In Xcode → Settings → Accounts, add an Apple ID (paid Developer Program or
   free Personal Team).
2. Target **Runner** → **Signing & Capabilities** → check **Automatically
   manage signing**, then pick the Team from the dropdown.
3. Xcode rewrites `DEVELOPMENT_TEAM` and switches
   `"CODE_SIGN_IDENTITY[sdk=macosx*]"` back to `"Apple Development"`
   automatically in the three Runner configurations.
4. Only after real-team signing is in place: consider whether to revive
   Keychain-backed secret storage. If yes, re-introduce `flutter_secure_storage`
   and add `keychain-access-groups` back to both entitlements files. Otherwise
   keep the Hive plaintext scheme — it works everywhere.
5. If targeting Mac App Store, flip `com.apple.security.app-sandbox` to
   `true` in `Release.entitlements` and audit remaining entitlements against
   App Sandbox requirements.

---

## Checklist Before Commit

- [ ] `flutter build macos --debug --no-pub` succeeds
- [ ] `codesign -dvv` reports `Signature=adhoc`
- [ ] `flutter analyze` has no new issues
- [ ] No `keychain-access-groups` re-introduced in either entitlements file
- [ ] No `"Apple Development"` value re-introduced in any Runner
      `CODE_SIGN_IDENTITY[sdk=macosx*]`
- [ ] Runner `ProvisioningStyle` in `TargetAttributes` stays `Automatic`
- [ ] `flutter_secure_storage` (or any other Keychain-backed plugin) NOT in
      `pubspec.yaml`

---

## Reference

- Incident (round 1 — signing only): Trellis task
  `.trellis/tasks/archive/2026-04/04-19-macos-signing-adhoc/`, captures the
  adhoc signing switch and the first-attempt entitlements cleanup.
- Incident (round 2 — secure storage removal): Trellis task
  `.trellis/tasks/04-19-storage-flatten-secrets/`, captures the decision to
  drop `flutter_secure_storage` and flatten secrets onto entity fields.
- Apple documentation: `codesign(1)` man page, section on ad-hoc signing.
- Plugin behavior source: `flutter_secure_storage_darwin-0.2.0/.../FlutterSecureStorage.swift`
  (`kSecUseDataProtectionKeychain = true` is hard-coded).
