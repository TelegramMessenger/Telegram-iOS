# Rust MTProto engine on iOS

The Rust MTProto engine (`third-party/mtproto-engine`, Swift wrapper `submodules/MTProtoRustEngine`) is linked into
every iOS build and selected at runtime; MtProtoKit stays the iOS default. Debug Settings ▸ `Rust MTProto [Restart App]`
writes `networkEngineSettings` (applies at the next launch); the `Engine:` row under it shows what the account actually
runs, because the factory still declines (extensions, DC address overrides) and the `mtproto_engine_rust_disabled` app
config forces MtProtoKit.

A network without a fetched app config of its own (a login, `UnauthorizedAccount`; a fresh account) follows the
accountManager shared entry `NetworkEngineState` instead: after every successful `help.getAppConfig` each production
account records its own value there (`true` and `false`, per account, OR-ed). A removed or logged-out account's value
stops counting once a live account has a value for the build; until then it stays, so a login after the last logout
still honours a `true`. Networks get it only through `networkEngineInputs(transaction:)`, so none can start without it.
The entry also holds a local crash-loop fallback (two engine crashes within 24 h turn Rust off for 24 h), fed only by
the app through `recordRustEngineCrash` before accounts start. Each part counts only for the build that wrote it.
Wrapper internals and open items: `third-party/mtproto-engine/docs/swift-integration.md`.

Load-bearing, and none of it shows up as a build error:

- **No `-Clto` on the engine's Bazel targets.** Every `rust_static_library` in the app (also wallet-engine and tlottie)
  shares ONE std: the archives embed identical std members and ld64 pulls a member only for an undefined symbol. LTO
  internalizes std into the archive and duplicates it.
- **Hardware crypto is re-applied by hand** in `MODULE.bazel`, because Bazel reads neither `.cargo/config.toml` nor
  target-specific Cargo features: `--cfg aes_armv8` is a `crate.annotation` on `aes`, and sha2's `asm` is in the spec.
  Without them crypto silently runs ~15x slower. The crates holding non-generic hot code (`aes`, `sha1`, `sha2`,
  `flate2`, `miniz_oxide`, `adler2`, `simd-adler32`, `crc32fast`, `num-bigint`, `num-integer`) also carry
  `-Copt-level=3` annotations: rules_rust otherwise builds them at opt-level 0 under `--configuration=debug_*`.
  `third-party/mtproto-engine/scripts/verify-ios-link.sh <unstripped binary>` checks both crypto settings and the
  single std.
- **Repin only the engine's crates:** `CARGO_BAZEL_REPIN=1 CARGO_BAZEL_REPIN_ONLY=mtproto_engine_crates`. A bare
  `CARGO_BAZEL_REPIN=1` also re-resolves the wallet's loosely pinned crates.
- `third-party/mtproto-engine/.gitignore` ignores `/build/`, not `/build`: on a case-insensitive file system the bare
  pattern also ignores the Bazel `BUILD` file, which then exists only locally.
- A main-session `401` on the Rust engine logs out, exactly as MtProtoKit does
  (`rustEngineAuthorizationRequiredAction`). **Never gate it on `MTContext.checkIfLoggedOut`**: the `401` is already
  the server's verdict, while the probe is a key exchange and bind that can only say less. The probe must contact the
  server: its auth action carries `replacesExistingKey` and `probedPermanentKey`, so it always makes a fresh temporary
  key, binds it to the probed permanent key, never stores it and gives up without a verdict after 120 s. Without them
  it completes on the stored `EphemeralMain` key (the main session's own, or a stale copy of an expired engine key) and
  never logs anyone out. MtProtoKit's own action logs out on the bind's `ENCRYPTED_MESSAGE_INVALID`: it is
  MtProtoKit's answer to a `-404` on a session under the permanent key.
- **Refused binds alone never log out.** A server refuses fresh temporary keys for a while for other reasons too, and a
  logout wipes local data. The engine's `PermanentKeyInvalid` on the home datacenter (`handlePermanentKeyInvalid`) is
  made of refused binds only:
  - While MtProtoKit runs the context's key actions (no `RustEngineActions` installed, for example a session still
    draining after a switch to MtProtoKit), it starts nothing and the session keeps binding, because MtProtoKit's probe
    would decide on one refused bind.
  - While the engine's actions run them, it starts `checkIfLoggedOut` on the engine's action. The gate and the check's
    factory read happen in one block on MTContext's queue (`rustEngineStartLogoutCheck`), which needs MTContext to have
    the active engine's own factories, and `activate`/`deactivate` write the factories only on that queue, so a check
    it starts never gets MtProtoKit's action, nor a replaced engine's.
    The engine's check logs out only when all of these hold (`rustEnginePermanentKeyUnknownDenial`):
    - the context registry has the engine's report and a session's refused bind, watched for 10 s;
    - the server has shown no sign of knowing the key in this context within the last day (an answer, an update or an
      accepted bind under it). This is tdlib's immunity: a datacenter incident can hide a known key, -404s included;
    - after that, a call sent under the permanent key itself (`help.test`, no PFS, as tdlib validates its main key)
      gets nothing but `AuthKeyInvalid` (`-404` twice, the second on a fresh connection), and the evidence still holds.

    Any answer to that call, an error included, keeps the account, and no answer gives no verdict.

  A false logout is the worst outcome there is: never loosen any of these.
- **While Rust carries a network, `MTContext`'s permanent keys, its logout check and its authorization transfers run on
  the engine** (`RustEngineActions`, through MtProtoKit's public `MTExternalActions.h` factories), so over HTTP or
  Telegram Web where TCP is blocked. Installed by `NetworkEngine.activate()` (once in `initializedNetwork`, and by
  `SwitchingNetworkEngine` on every live switch, which deactivates the old engine first), never in extensions.
  `MTContext` stays the one coordinator and the only writer: a permanent key is stored through
  `-[MTDatacenterAuthAction completeWithAuthKey:…]`, whose compare-and-set keeps a key that appeared meanwhile; a
  transfer never resends exported bytes after a failure (one fresh export instead) and writes the token only if the
  destination's permanent key is still the one the import ran under. `deactivate()` (a switch to MtProtoKit) ends the
  actions still running on the engine, so MtProtoKit takes their datacenters over after MTContext's backoff (1 s after
  a first failure, at most 60 s). `UnauthorizedAccount` prefetches permanent keys only on Rust, and before login a
  confirmed unknown home key is replaced (`Network.permanentKeyUnknown`) instead of logging out. Details:
  `docs/swift-integration.md` §9b in the engine.
- **On iOS the engine changes only through the Debug switch.** Live switching (`SwitchingNetworkEngine`: the live
  `mtproto_engine_rust_disabled` kill switch and the live WEB-proxy moves) is macOS only (`#if os(macOS)` in
  `initializedNetwork` and `Account`), for Telegram-Mac. On iOS no wrapper exists,
  `Network.switchEngine`/`disableRustEngine` have nothing to act on, and the network runs the engine resolved at
  launch directly, so with the switch off it is exactly a build without the factory. Even on macOS the wrapper exists
  only while Rust is in play.
- `Network.isUserOnline` (from `Account.shouldKeepOnlinePresence`, wired on iOS only) reaches every session through
  `NetworkEngineSession.setOnline`; the Rust engine then uses tdlib's online keepalive timing. macOS, where Rust is the
  default, stays offline-timed until that cadence is measured there.
