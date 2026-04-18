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
contain `keychain-access-groups` under adhoc signing.

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

Additionally, `$(AppIdentifierPrefix)` is populated from the provisioning
profile's `ApplicationIdentifierPrefix`. Adhoc has no profile, so the variable
expands to an empty string, silently producing an invalid group id even if the
entitlement check were somehow bypassed.

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

Both files currently have sandbox **disabled** on purpose (unrestricted local
file / network access during dev). `flutter_secure_storage_darwin` still works
because it falls back to the app's default keychain access group when no group
is explicitly declared.

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
- Keeping `keychain-access-groups` in entitlements while signing adhoc.
- Relying on `$(AppIdentifierPrefix)` in any adhoc context — it expands to
  empty.

---

## Common Mistakes

| Mistake                                                                                 | Symptom                                                                                                          | Fix                                                                     |
| --------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| Added `keychain-access-groups` in Xcode UI for a feature that needs Keychain            | `entitlements that require signing with a development certificate` at build time                                 | Remove it for local dev; re-add only when real-team signing is restored |
| Toggled Xcode "Automatically manage signing" on/off                                     | pbxproj ends up with `DEVELOPMENT_TEAM` removed AND `CODE_SIGN_STYLE = Manual`; Release build fails              | Reset the four fields back to the Required Build Settings above        |
| Set a personal Apple ID team in Xcode once, then removed the account                    | `CODE_SIGN_IDENTITY = "Apple Development"` persists in pbxproj even though the team no longer exists             | Manually restore `"-"` per this doc                                     |
| Copy-pasted `keychain-access-groups` from an iOS project into the macOS entitlements    | Build error above; or runtime `errSecMissingEntitlement` / `-34018` from `flutter_secure_storage`                | macOS baseline does not need this entitlement; leave it out            |

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

If the app exercises `flutter_secure_storage`, write + read + delete at least
one entry to confirm default-keychain access works.

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
4. If the project needs Keychain sharing or runs in an App Group, re-add:

   ```xml
   <key>keychain-access-groups</key>
   <array>
       <string>$(AppIdentifierPrefix)com.mallotec.reb.flallapihub</string>
   </array>
   ```

   in whichever of `DebugProfile.entitlements` / `Release.entitlements` is in
   scope.
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

---

## Reference

- Incident: Trellis task `.trellis/tasks/04-19-macos-signing-adhoc/` captures
  the full investigation, including the two-step fix (pbxproj first, then
  entitlements) and the SubAgent verification loop.
- Apple documentation: `codesign(1)` man page, section on ad-hoc signing.
