# TelegramApi: Swift payload structs over table-described storage (table-driven TL)

`Api.X.Cons_y` is a **`@frozen` Swift struct holding one `TLObject`**. `TLObject` is the only Objective-C class in
TelegramApi: a hand-written **non-NSObject root** (MRC, `TelegramApiObjC` module, `ObjC/`) with its own reference
counting, weak support, and table-driven `-dealloc` and description; it has no ivars beyond a 24-byte header. A
payload's fields live in extra bytes allocated by `TLObjectAllocate(info)`, at offsets the generator computes
(`TLSchemaLayout.storageLayout`): `int32` fields first, then every other field 8-aligned (`int256` is 32 bytes), each
group in schema order, then the `uint64_t` presence mask for optional scalars. The Swift accessors
(`@_alwaysEmitIntoClient` + `@inline(__always)`, so no symbols) load at those offsets, the initializers and
`Api.functions` builders store at them, and the engine, `-dealloc` and description read the same offsets from the
schema table.

**The schema is `submodules/TelegramApi/swift_scheme.tl`, and Bazel generates the code from it on every build.** The
`TelegramApiGenerated` genrule runs the host tool `//build-system/SwiftTL:SwiftTL` and declares a fixed file list:
`Api0`…`Api43.swift` (`--swift-file-count`, types spread evenly), `TLApiSchemaData.m`, and the tests'
`SchemaFixtures.swift`/`SchemaAccessorProbes.swift`. Nothing generated is checked in; changing the schema is the whole
change.
- **SwiftPM reads a locally generated, gitignored copy** in `Sources/`, `ObjC/` and `Tests/SwiftPMGenerated`
  (TelegramCore's `Package.swift`, built by Telegram-Mac, depends on it; Telegram-Mac ignores the copy too). Run
  `submodules/TelegramApi/generate-swiftpm.sh` before a SwiftPM build or `swift test`, and again after the schema or
  the generator changes. Bazel's globs are non-recursive so it never compiles that copy; keep them so.
  **Only ever regenerate all three directories together (the script does):** Swift and `TLApiSchemaData.m` from
  different runs disagree on offsets and corrupt memory silently. Nothing checks the pair at run time;
  `SchemaTableTests.testHashesMatch` and `AccessorProbeTests` catch it.
- **No header is generated.** `TLApiTypes.h` and the umbrella header are static; the counts and hash are
  `extern const`s defined in the generated `TLApiSchemaData.m`. A generated public header would be on both Bazel's and
  SwiftPM's include paths, where either copy can shadow the other.

**Parsing, serialization and function calls run in a C engine** (`ObjC/Sources/TLEngine.m`) driven by the table; the
generated Swift has no `parse_*`/`serialize`/`descriptionFields` bodies. `Api.parse` falls through to
`tlParseTopLevel`, `serialize` and `descriptionFields` come from shared `TLObjectBacked` extensions
(`Sources/TLObjectSupport.swift`), and storage access is in `Sources/TLStorage.swift`.

**The schema table is a zlib-compressed, pointer-free image** (blob v3; format documented at the top of
`build-system/SwiftTL/Sources/SwiftTL/SchemaBlob.swift`) holding every field offset and each constructor's size and
presence-mask offset, emitted as a `const` byte array in `TLApiSchemaData.m`. `ObjC/Sources/TLSchemaLoader.m` inflates
it once, validates it (including every field and mask lying inside its object's storage) and builds the
`TLTypeInfo`/`TLConstructorInfo`/`TLFieldInfo`/`TLFunctionInfo` structs on the heap; access goes through
`TLApiTypeAt`, `TLApiConstructorAt` (ascending id), `TLApiFunctionAt`, `TLApiFunctionConstructorAt` and
`TLApiConstructorWithId`. `TLApiSchemaHash` covers the schema and the layout-algorithm version (`SwiftTL-Storage/1`);
at run time it serves only `tlVerifyClientLayout()` (below), and the loader validates the image's structure, not its
hash. **The 24-byte header size is assumed, not checked** (by user decision): adding an ivar to `TLObject` would shift
every field. Don't.

Compiler-invisible rules:
- **Only TelegramCore depends on TelegramApi.** Bazel `visibility` on both TelegramApi targets admits only
  `//submodules/TelegramCore`, and TelegramCore's files use `internal import TelegramApi`, so the compiler rejects any
  public TelegramCore declaration that exposes an `Api` type and importers of TelegramCore do not load TelegramApi.
  Neither stops an explicit `import TelegramApi` elsewhere (rules_swift puts every transitive module on the search
  path), so don't add one outside TelegramCore. Tests of TelegramCore's Api conversions live in
  `//submodules/TelegramCore:TelegramCoreTests`.
- **TelegramApi's symbols are not exported from `TelegramCoreFramework`:** nothing outside TelegramCore uses them, so
  the framework's computed export list ("Framework export lists" in `Telegram/CLAUDE.md`) leaves them out.
- **`tlFunction` must stay unspecialized** (`@_semantics("optimize.sil.specialize.generic.never")`), or each of the
  ~40 result types gets its own closure copy. Check:
  `nm .build/release/TelegramApi.o | xcrun swift-demangle | grep -c "specialization.*tlFunction"` → 0.
- **The schema code generator and engine are trusted; there is no per-constructor wire test.** Don't add golden
  digests of every fixture: every schema change would fail them until re-recorded on a frozen pre-engine generator.
  `GoldenTests` keeps about 15 hand-written fixtures whose bytes and logger output were recorded pre-engine; never
  re-record those on the engine.
- **Unknown constructors are logged with their exact id, even after an earlier field failed.** So the engine stops
  where the pre-engine Swift parser stopped: a primitive's id in an object field consumes the primitive, and a string
  whose length overruns still skips its padding. `Tests/ParseFailureTests.swift` pins the literal log lines, validated
  against the pre-engine parser; don't edit its expectations to match new behaviour.
- **A bytes field's getter returns a new `Buffer` on every access.** Taking a raw pointer from it (`x.field.data`,
  `x.field.size` inside a `memcpy`) is a use-after-free; copy with `makeData()` or bind the `Buffer` inside
  `withExtendedLifetime`.
- **Offsets are baked into Swift and into the table; they must agree.** `AccessorProbeTests` (generated probes) reads
  every field of every fixture through the Swift accessors and compares it with the table-driven description; the
  fixtures are built through the Swift initializers, so this also checks construction. Change `storageLayout` only
  together with the layout version in `main.swift`'s hash string.
- **Accessor offsets are compiled into TelegramCore** (`@_alwaysEmitIntoClient`), so a TelegramApi regeneration needs
  TelegramCore recompiled. Bazel does that; SwiftPM and Xcode incremental builds can fail to recompile a client whose
  inlined accessor changed, so clean-build clients after regenerating outside Bazel. `tlVerifyClientLayout()`, called
  from `initializedNetwork`, carries the hash as an inlined literal and traps on a stale client.
- **`Api` enums print their constructor name only** (`CustomStringConvertible`, from the table), never field values:
  `"\(value)"` bypasses the logger's redaction. Reflection metadata stays on by choice (turning it off for TelegramApi
  saves ~188 KB in release); the logger goldens pass either way.
- **Generated locals are `_tl`-prefixed** (`_tlObject`, `_tlPresent`, `_tlValue`): `tlStore` is generic, so a TL field
  shadowing an unprefixed local would compile and store the wrong value.
- **Not NSObject on purpose.** `TLObject` inherits nothing Swift can see and the payload structs inherit nothing, so a
  TL field named `hash` or `description` is always the field.
- **Payload fields are read-only.** To change one, construct a new `Cons_y`.
- **The module is MRC.** SwiftPM compiles ObjC with ARC by default, so the SwiftPM targets pass `-fno-objc-arc`
  (`unsafeFlags`); Bazel uses `copts = ["-fno-objc-arc"]`; `TLObject.m` `#error`s under ARC. `-autorelease` uses
  `+[NSAutoreleasePool addObject:]` because `CFAutorelease` recurses and crashes. References stored in payload storage
  are +1; Swift stores them through `tlStoreReference`.
- **Logger redaction depends on nested values being Swift enums** (`tlDescriptionFields` maps through
  `tlTypeRegistry`). `GoldenTests` pins the logger output with redaction on; `Tests/LoggerDescription.swift` is a
  verbatim copy of `TelegramCore/Sources/State/Serialization.swift`: re-copy it when that file changes.
- **Don't replace `TLObject` with foreign reference types (C structs):** they need iOS 16.4 (metadata kind 0x204), and
  multi-payload enums leak them on Swift 6.4.
- Tests: `swift test --package-path submodules/TelegramApi` after `generate-swiftpm.sh` (and
  `-c release -Xswiftc -enable-testing`), `swift test --package-path build-system/SwiftTL`; Bazel:
  `Make.py test --target //submodules/TelegramApi:TelegramApiTests`.

## Parked APIs: the news feed and the agent (layer 233)

Layer 233 as the server serves it (the schema of 2026-10-30) has no news feed API (`feed.*`, `feedPosition`,
`updateReadFeed`, `channels.editChannelNews`, `channels.joinChannel`'s `for_news`) and no agent API (`agent.*`,
`updateAgentSettings`). Their code is parked, not deleted: TelegramCore wraps only the lines that name a removed symbol
in `#if TELEGRAM_NEWS_FEED_API` or `#if TELEGRAM_AGENT_API`, and nothing defines either. None of this shows up as a
build error:

- **Each `#else` sends nothing.** The feed answers with empty successes (an empty For you batch or Added page, a read
  mark kept local, the interests unchanged, a vote dropped), so no context retries; a join is always the plain one and
  asserts that nothing asked for a News-only one. The agent's requests fail with `.notAvailable` and its provider
  refresh completes. Both features' models, contexts, caches and read state stay compiled. Code in an inactive `#if`
  is not type-checked, which is why the blocks are kept small.
- **The agent settings travel as `EngineAgentSettings`** through the state pipeline (the operation, the final state's
  events, the event hub), not as the Api type: a parameter of `AccountFinalStateEvents`' initializer cannot be inside
  an `#if`. Only the interpreter's decode is parked.
- **One gate per feature hides it in the app.** TelegramCore exports `newsFeedApiIsAvailable` and
  `agentApiIsAvailable` (Swift defines are per module, so the app cannot test the conditions itself).
  `isNewsFeedEnabled` and `isNewsFeedServerAvailable` (NewsFeedSupport) are false while the first is: News is off for
  every account, the device-built Added feed included (`submodules/TelegramUI/Components/News/CLAUDE.md`).
  An agent bot's profile shows no provider rows while the second is false (`peerInfoScreenData` checks it beside
  `isAgentBotPeer`, which stays ungated: the agent chat's composer does not use the API). A new entry point to either
  feature's API must go through its gate.
- **`in_news` is not parked:** layer 233's `channel` keeps `flags2.21`. With News off a channel stored with it shows
  Join or Mute/Unmute, as before News (`NewsChannelBarAction`).

To bring one back:

1. restore its entries in `swift_scheme.tl` as the server has them;
2. define its condition for both TelegramCore and its tests: `"-DTELEGRAM_NEWS_FEED_API"` (or
   `"-DTELEGRAM_AGENT_API"`) in the `copts` of `TelegramCore` and `TelegramCoreTestsLib` in
   `submodules/TelegramCore/BUILD`, and `.define(...)` in the `swiftSettings` of the `TelegramCore` and
   `TelegramCoreTests` targets in its `Package.swift`. The tests are their own module: `ParkedApiTests` fails when
   only TelegramCore has the condition, which would leave the parked tests (`FeedApiConversionTests`' Api cases)
   compiled out;
3. run `generate-swiftpm.sh`.
