# Telegram/ — agent notes

The app target, its extensions and the frameworks they link are declared in `Telegram/BUILD`.

## Framework export lists (computed by the build)

`TelegramUIFramework` and `TelegramCoreFramework` export only the symbols their clients use, which drops their unused
public code along with the symbol tables (~5 MB of the `.ipa`).
- **`TelegramUIFramework`:** clients are the app binary and the Share, Notification Content, Broadcast Upload and
  Notification Service extensions.
- **`TelegramCoreFramework`:** clients are TelegramUI, the app binary and all six extensions.

**Release builds only** (`select` on `:debug`): debug builds export everything, so a client symbol missing from a list
shows up only as a *release* link error. The list is computed, never checked in: `framework_exported_symbols`
(`Telegram/framework_exported_symbols.bzl`) intersects the undefined symbols of the clients' compiled archives with the
symbols the framework's own archives define, and passes the result through `ios_framework`'s `exported_symbols_lists`.
Each archive is scanned by its own cached action, so an edit rescans only the archives it changed. There is no cycle:
clients *compile* against module interfaces, so the order is client compile → list → framework link → client link.

- **A new client of either framework** (an extension, or a library of the app binary) must be added to that rule's
  `clients`. A missing one fails that client's link with undefined symbols; it never fails at runtime.
- **A new framework under either framework** (a new entry in its `frameworks`) must be added to that rule's
  `provided_by_frameworks`. Otherwise its symbols are listed as exports the framework doesn't define, and `ld` rejects
  that.
- **Nothing may look up the app's own symbols by name at runtime** (`dlsym`); there is none today. `NSClassFromString`
  and Swift type and conformance lookup use runtime metadata, not exports.
- Count a binary's imports with `xcrun dyld_info -imports`; `nm -u` shows nothing for these chained-fixup binaries.

## Embedded watch app (`Telegram/WatchApp`)

A standalone watchOS Telegram client, developed in the separate `~/build/tgwatch` repo, is vendored at
`Telegram/WatchApp/` and can be embedded into the **device** IPA under `Telegram.app/Watch/`. `xcodebuild` builds it
(not Bazel); the Bazel build codesigns it.

**Build it:** add `--embedWatchApp` to a Make.py **device** build (`--configuration=debug_arm64` or `release_arm64`)
with `--watchApiId`, `--watchApiHash`, `--watchSigningIdentity`, `--watchProvisioningProfile`. Off by default (it adds a
~4-min xcodebuild step); simulator builds never embed.

**`Telegram/WatchApp/` is a synced snapshot — do not hand-edit it.** Edit the `tgwatch` repo, re-sync with
`tgwatch/tools/export-sources.sh /abs/path/to/telegram-ios/Telegram/WatchApp`, and commit the result. The committed
`tgwatch.xcodeproj` is generated and kept by a `!tgwatch.xcodeproj` negation in `Telegram/WatchApp/.gitignore` (the root
`.gitignore` ignores `*.xcodeproj`); `.build`/`.swiftpm`/`xcuserdata` are excluded.

**How it's wired:** `//Telegram:TelegramWatchApp` (rule in `Telegram/prebuilt_watchos.bzl`) runs **two actions**:
- `PrebuiltWatchosCompile` (`Telegram/prebuilt_watchos_compile.sh`) runs xcodebuild on a writable temp copy of the
  snapshot, baking the api credentials and the watch bundle id (as `PRODUCT_BUNDLE_IDENTIFIER`, from which the
  Info.plist derives `WKCompanionAppBundleIdentifier` via `$(PRODUCT_BUNDLE_IDENTIFIER:base)`) but leaving placeholder
  versions, and emits an unsigned `.app`.
- `PrebuiltWatchosPatchSign` (`Telegram/prebuilt_watchos_patch.sh`) rewrites the two per-build Info.plist version keys
  (`CFBundleShortVersionString`, `CFBundleVersion`) and codesigns the `.app` and the nested `TDLibFramework.framework`
  (identity and the watchkitapp profile from `--define`s).

The result feeds the `Telegram` `ios_application`'s `watch_application` slot (gated by the `//Telegram:embedWatchApp`
flag). The rule's `bundle_id` is `"{telegram_bundle_id}.watchkitapp"` in `Telegram/BUILD`.

**Keep the version out of the compile action; that is the split's whole value.** `--define=buildNumber` changes on
every CI pipeline, so a version baked by xcodebuild would rerun the ~4-min compile every build. Check with `aquery`
that the `PrebuiltWatchosCompile` ActionKey stays identical across `--define=buildNumber` and
`--define=watchSigningIdentity` changes. The api id/hash and bundle id stay baked (stable per host configuration, and
xcodebuild must own the bundle id); none of them reach the compiled binary, only the Info.plist (`$(...)` substitution,
read at runtime by `Bundle.main.object(forInfoDictionaryKey:)` in `Secrets.swift`), so deferring the version cannot
change the compiled output. The nested `TDLibFramework` keeps the placeholder `0.0`/`0` version; only the watch app's own
Info.plist is version-verified against the host.

**Do not add `"local": "1"` to the compile action's `execution_requirements`.** It makes the action uncacheable (no
`--disk_cache`/`--remote_cache` hit; `--execution_log_json_file` shows `cacheable=false`), and buys nothing:
`no-remote-exec` + `no-sandbox` already pin execution local and unsandboxed. The patch+sign action *does* keep `local` +
`no-remote`, deliberately: its provisioning-profile path is machine-specific and the profile's contents are not an
action input, so a shared cache would serve wrongly signed bundles.

**Non-obvious invariants** (also in the `.bzl` comments): `AppleBundleInfo`'s public init is banned — use the internal
`new_applebundleinfo`; `watch_application` requires BOTH `AppleBundleInfo` (with a non-None `infoplist` File) AND
`WatchosApplicationBundleInfo`; the embedded watch app's `CFBundleShortVersionString`/`CFBundleVersion` must exactly
equal the host's (from `versions.json['app']` + `--define=buildNumber`); the host does NOT re-sign the embedded watch
app, so the worker must sign it; the watch bundle id `ph.telegra.Telegraph.watchkitapp` must track the host
`telegram_bundle_id`.

**Status:** verified only with **development** signing on `debug_arm64`. Open before App Store shipping: secure timestamp
(drop `codesign --timestamp=none`), distribution profile (`get-task-allow=false`), `release_arm64` +
`altool --validate-app`, and a committed `Package.resolved` for hermetic remote-SwiftPM resolution.
