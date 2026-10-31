# widget-sandbox v0.5.0 (vendored)

Taken from `~/build/widget-sandbox` at the tag **`v0.5.0`** (`3a7acf1`, 2026-10-30).
- **v0.5.0:** the wallet. A widget can pay (`TelegramWidget.wallet.sendTransaction`) or sign (`wallet.signData`)
  through Gram Wallet in TON Connect's formats, and `request(data, { wallet: true })` gives its bot the user's wallet;
  the gate's grant lets one wallet call follow the answer to a tap's call within 10 s. The policy's checks
  (`checkWalletTransaction`, `checkSignDataPayload`, `checkRequestOptions`, `RequestGate::decideWallet`, the grant),
  the fixture's `walletTransactions` and `signDataPayloads`, three `wallet-*` attacks and
  `corpus/interactive/05-wallet.html`. How this client follows it is in the message widgets guide and the runtime
  record.
- **v0.4.0:** the client's time over a widget with no caption below it, the content safe area: `env(safe-area-inset-*)`
  in profile 1 (`P1-safe-area`), the six `--tg-content-safe-area-*` root variables, the UA layer's body padding,
  `TelegramWidget.contentSafeAreaInset` and `contentSafeAreaChanged`; the conformance cases `auto/36-safe-area` and
  `visual/17-time-corner` (posted twice: `withoutCaption`, `captionAbove`), `auto/04`'s `env()` check, and
  `corpus/safe-area`. How this client follows it is in the message widgets guide and the runtime record.
- **v0.3.0:** strict limits from the start (a counted cap stops the widget), the renderer stress kit for the client
  teams (`stress/`, below), the tweb audit's fixes (the finger rule, pointer capture, bitmap caps, `light-dark()`,
  timer ids), held background requests, `openTelegramLink` without a confirmation of its own, and the conformance cases
  `auto/28`–`35`. How this client follows each is in the message widgets guide and the runtime record.
- **v0.2.3:** fixes from the Android beta, with no API change.
  - Canvas arguments convert as a browser's context converts them. Our context is bound from WebIDL and already did;
    `CanvasArgumentTests` pins it.
  - An image a script made loads before it is inserted, and `complete` and `width` follow a browser. Our runtime now
    has a browser's pending state and the rendered width (the message widgets guide).
  - The conformance pictures of `visual/06`, `08-canvas-a`, `08-canvas-b` and `13` now show what profile 1 draws.
    `auto/02-attributes-images-b` gains three checks.
  - The iOS glue builds its locales with `Locale.Components` (below).
- **v0.2.0 and v0.2.1:** a widget is fixed code plus changeable state. It has the bot's `chatData` / `publicData` and
  their events, `request`, `copyText`, `watchPublicData`, previews, and the message's context (`isForward`, `chatType`,
  `viewer`). The server's side is layer 233.
- **v0.2.2:** haptics need a touch.
- **Earlier:** v0.1.3 made the payload zlib, gave vertical drags to the chat (decision G2) and added
  `TelegramWidget.setResizeAnchor` (decision R1).

Profile, SDK and protocol stay version 1. The widgets client spec
(`docs/superpowers/specs/2026-10-19-message-widgets-v0.1.0-client-design.md`) follows v0.1.0, with this client's v0.1.1,
v0.1.2 and v0.1.3 decisions in its later sections. The v0.2 decisions are in
`docs/superpowers/specs/2026-10-26-message-widgets-v0.2-design.md`. The client's rules are in the message widgets guide
(`submodules/TelegramUI/Components/MessageWidget/CLAUDE.md`).

Files come from the tag, never the working tree, and the old copy is removed first. That way files a tag removed do not
linger in the bundles: v0.1.1 split `visual/03, 05, 08, 09` into `-a` and `-b`; v0.2.1 split `auto/23-gestures`, and
replaced `visual/sdk/16-bot-edit` with `16-state-edit`.

```sh
V=v0.5.0
W=third-party/widget-sandbox
X=$(mktemp -d)
D=packages/desktop/sandbox
git -C ~/build/widget-sandbox archive "$V" corpus packages/conformance packages/stress packages/core/profile.json \
  packages/core/tests/fixtures/intl-cases.json packages/core/tests/fixtures/gesture-policy.json \
  packages/core/tests/fixtures/sdk-policy.json packages/core/tests/fixtures/cpu-budget.json \
  $D/include/twidget/gesture_policy.h $D/include/twidget/json.h $D/include/twidget/sdk_policy.h \
  $D/include/twidget/cpu_budget.h $D/src/gesture_policy.cpp $D/src/sdk_policy.cpp $D/src/cpu_budget.cpp | tar -x -C "$X"
rm -rf "$W/corpus" "$W/conformance" "$W/stress"
cp -R "$X/corpus" "$W/corpus"
C=$W/conformance; mkdir -p "$C/tools"
for f in auto visual refs channel.json manifest.json catalogue.json run.schema.json CLIENTS.md README.md; do
  cp -R "$X/packages/conformance/$f" "$C/"
done
cp "$X/packages/conformance/tools/"{report,diff,png}.mjs "$C/tools/"
S=$W/stress; mkdir -p "$S/tools"
for f in widgets manifest.json run.schema.json CLIENTS.md README.md; do cp -R "$X/packages/stress/$f" "$S/"; done
cp "$X/packages/stress/tools/report.mjs" "$S/tools/"
cp "$X/packages/core/profile.json" "$W/profile/profile.json"
cp "$X/packages/core/tests/fixtures/intl-cases.json" "$W/fixtures/intl-cases.json"
cp "$X/packages/core/tests/fixtures/gesture-policy.json" "$W/fixtures/gesture-policy.json"
cp "$X/packages/core/tests/fixtures/sdk-policy.json" "$W/fixtures/sdk-policy.json"
cp "$X/packages/core/tests/fixtures/cpu-budget.json" "$W/fixtures/cpu-budget.json"
mkdir -p "$W/gesture/twidget"
cp "$X/$D/include/twidget/"{gesture_policy.h,json.h,sdk_policy.h,cpu_budget.h} "$W/gesture/twidget/"
cp "$X/$D/src/"{gesture_policy.cpp,sdk_policy.cpp,cpu_budget.cpp} "$W/gesture/"
rm -rf "$X"
(cd submodules/TelegramUI/Components/MessageWidget/WidgetRuntime && python3 IDL/generate-profile-tables.py)
```

Then the counts the tests pin (`ChannelTests`, `ConformanceRunnerTests`, `ConformanceSetTests`, `WidgetCorpusTests`, the
folder lists of `WidgetCorpus` and `CorpusTests`), the run file's `framework`/`commit` (`ConformanceRunFile`), and the
ratchet: `conformance_report.sh --record` retires checks a tag renamed (`ConformanceBaseline.compare`).

Taken:
- `corpus/` (all of it):
  - `attacks/`: 113 pages and `mem-cap-probe.js`. v0.2.0 added the five `request-*` pages, v0.2.2
    `haptic-timer-buzz`, v0.3.0 five from the tweb audit (`activation-pointer-capture`, `activation-touch-swipe`,
    `css-light-dark-url`, `mem-huge-bitmaps`, `timer-id-reuse`), and v0.5.0 three on the wallet (`wallet-no-activation`,
    `wallet-forged-wire`, `wallet-grant-reuse`). TEST FIXTURES ONLY, never in an app bundle.
  - `bot-demos/` (v0.3.0): an order, a poll, an RSVP, tic-tac-toe, a ticker and a reaction, built as bots build them;
    `auto/28`–`30` reproduce their renderer patterns.
  - `common/` and `compat/`.
  - `defaults/` (v0.1.1): six widgets with little or no CSS, the examples a widget that should look native starts from.
  - `generated/`.
  - `gestures/` (v0.1.3): games and controls by the touch-action they claim, the `-xy` ones now behaving as their `-x`
    twins.
  - `htmlbubbles-ported/`.
  - `interactive/` (v0.2.0): a poll, tic-tac-toe, a live ticker and a promo code, played against the bot named in
    `<meta name="tw-bot">`; v0.5.0's `05-wallet` pays and signs against the `shop` bot.
  - `out-of-profile/`: widgets using what profile 1 leaves out.
  - `resize/` (v0.1.3): one widget per resize anchor.
  - `safe-area/` (v0.4.0): seven widgets that show what the client passed as its content safe area (a diagnostic,
    full-bleed cards, one right-to-left, an unstyled note, CSS as models write it, a canvas chart, a widget posted
    without a caption, with one below and with one above) and their README.
  - `showcase/` (`3d/` since v0.3.0: six CSS 3D scenes) and `README.md`.

  Tests read it through `:WidgetCorpus` and `:CorpusFiles`, the DEBUG app's corpus insertion through
  `:WidgetCorpusBundle` (attacks excluded).
- `conformance/` from `packages/conformance/`:
  - the 60 `auto/` widgets (v0.3.0 added `28`–`35`: three renderer patterns and five stop tests, which name the stop's
    reason in the manifest's `stops`; v0.4.0 `36-safe-area`, whose manifest entry carries the `safeArea` its runner
    passes), the 21 `visual/` widgets (v0.4.0: `17-time-corner`, with its `safeArea`) and the 26 `visual/sdk/` ones,
    with their README;
  - `refs/`: stage crops and the reference pictures posted beside the visual widgets, drawn on the bubble's colour
    since v0.1.1;
  - `channel.json`: the 114 posts in order, each with its `message` spec, plus the `bot` table (v0.2.1); since v0.4.0
    a widget the client draws its time over is posted twice, `withoutCaption` and `captionAbove`;
  - `manifest.json` (tests carry `message` and `bot` since v0.2.1), `catalogue.json`,
  `run.schema.json`, `CLIENTS.md`, `README.md` and `tools/{report,diff,png}.mjs` (the report; Node ≥ 18, no
  dependencies; it reads `manifest.json`, `catalogue.json` and `refs/` relative to `tools/..`). Tests read it through
  `:WidgetConformance`; the DEBUG app's conformance insertion through `:WidgetConformanceBundle`.

- `stress/` from `packages/stress/` (v0.3.0): the renderer stress kit, 127 widgets in 19 loads, each a ladder of levels
  (`widgets/<load>/<value>.html`), with `manifest.json` (run order, warm-up and measuring window, width),
  `run.schema.json`, `CLIENTS.md` (how a client runs it and what it reports), `README.md` and `tools/report.mjs`. The
  client's runner is `MessageWidgetStress` (the message widgets guide); the harness and DEBUG app bundle it through
  `:WidgetStressBundle`.

- `gesture/twidget/cpu_budget.h`, `gesture/cpu_budget.cpp` from `packages/desktop/sandbox` and
  `fixtures/cpu-budget.json` from `packages/core/tests/fixtures`: the CPU quota policy (a sliding window of ten
  buckets, the slice, the floor, the layout-query budget, the modelled op cost), one of four line-for-line copies
  checked against the shared fixture. WidgetRuntime's event loop decides every step with it, for the JS quota and the
  main-thread window; `CpuBudgetTests` runs the fixture.

- `profile/profile.json` from `packages/core/profile.json`: profile 1's definition, the data its tables come from. Data,
  as the conformance widgets are: WidgetRuntime's `IDL/generate-profile-tables.py` writes the tables its `CSS.supports`
  and policies use, and the renderer's UA layer (`tables.uaStylesheet`, each `:where(X)` written as X, the `@layer`
  kept: an origin of its own in the master, twidget edit 41), into `Sources/Host/ProfileTables.inc`; its tests read the
  file through `:ProfileJSON`.
- `fixtures/intl-cases.json` from `packages/core/tests/fixtures/intl-cases.json` (v0.1.1): 166 Intl requests as the
  shim sends them, with V8's answers. `:WidgetSandboxIntlTests` runs the glue below on it alone; WidgetRuntime's
  `IntlCasesTests` (host) checks that the runtime sends exactly those requests, and `WRIntlCasesTests` (iOS) runs each
  as the call a widget would make (`Tests/IntlCases.js`) through the glue, with an explicit drift list
  (`Tests/intl-cases-expected-failures.txt`); they read it through `:IntlCases`.
- `ios/IntlBridge.swift` and `ios/PluralRules.swift`, unedited: the iOS glue's `intl` capability (the "Intl
  delegation" section of `packages/ios/Sources/WidgetSandbox/SandboxEngine.swift`, after an `import Foundation`, and
  `PluralRules.swift`), which answers WidgetRuntime's Intl requests in the app (`:WidgetSandboxIntl`). Foundation only:
  ICU's formatting API is not public on iOS, which is why upstream delegates Intl to the host. `ios/WidgetSandboxIntl.swift`
  is ours: the public entry, and the one member of upstream's `SandboxEngine` the section reads.

  **A locale tag with a unicode extension.** Until v0.2.2 the glue trapped on one: its `Locale(identifier:)` turned
  `ar-EG-u-nu-arab` into `ar_EG@numbers=yes`, it force-unwrapped the resulting nil `dateFormat` and `NumberFormatter`
  symbols, and `RelativeDateTimeFormatter` trapped inside Foundation itself.
  - **v0.2.3 has the fix:** `IntlBridge.bcp47Locale` builds the locale with `Locale(components:
    Locale.Components(identifier:))` on iOS 16 and later and drops the extension before that. Its tags come from
    `identifier(.bcp47)`. `intl-cases.json` still passes (`:WidgetSandboxIntlTests`).
  - **WidgetRuntime sends a tag's unicode extension reduced as ECMA-402's ResolveLocale reduces it**
    (`intl::resolveLocale`): only the keywords the constructor reads, each with a value from a conservative table.
    The keys are NumberFormat and RelativeTimeFormat `nu`, DateTimeFormat `ca`/`hc`/`nu`, Collator `co`/`kf`/`kn`,
    and none for PluralRules or ListFormat. Upstream's shim sends the tag whole. Two reasons not to do the same, both
    in this glue (`WRIntlExtensionTests` pins them):
    - a numbering system name Foundation does not know (`en-u-nu-bogus`, a bare `-u-nu`, `yes`) makes
      `RelativeDateTimeFormatter` trap in `IntlBridge.relative`, crashing the app;
    - `PluralRules.languageKey` splits the locale identifier on `-` and `_` but not `@`. So `ar-u-nu-arab` becomes
      `ar@numbers=arab`, matches no rules, and selects `other` for everything; `IntlBridge.relative`'s English
      quarter check misreads `en-u-nu-thai` the same way.

    Both are upstream bugs to report. On iOS 16 and later the glue applies what is kept; before that it drops it.
    `resolvedOptions()` reports `numberingSystem: "latn"` and `calendar: "gregory"` whatever the glue applied, as
    upstream's glue answers it.
  - The runtime record's Intl section has the details.

  ```sh
  git -C ~/build/widget-sandbox show "$V":packages/ios/Sources/WidgetSandbox/SandboxEngine.swift \
    | awk '/^\/\/ MARK: - Intl delegation/,0' | { printf 'import Foundation\n\n'; cat; } > "$W/ios/IntlBridge.swift"
  git -C ~/build/widget-sandbox show "$V":packages/ios/Sources/WidgetSandbox/PluralRules.swift > "$W/ios/PluralRules.swift"
  ```

- The shared gesture policy, unedited: `gesture/twidget/gesture_policy.h` and `gesture/gesture_policy.cpp` (the C++
  copy of `packages/core/src/shared/gesture-policy.ts`, upstream's `packages/desktop/sandbox`), `gesture/twidget/json.h`
  (the desktop glue's JSON value, for the test only) and `fixtures/gesture-policy.json` (the fixture its four copies
  share): who gets a press, the claim from `touch-action` (`claimOf`), the `GestureArbiter` and its thresholds.
  `:GesturePolicy` is what WidgetRuntime's `TapState` runs; `:GesturePolicyTests` is upstream's
  `gesture_policy_shared_fixture` over the fixture (`gesture/GesturePolicyTests.cpp`, ours around it).
- The shared SDK policy, unedited: `gesture/twidget/sdk_policy.h` and `gesture/sdk_policy.cpp` (the C++ copy of
  `packages/core/src/shared/sdk-policy.ts`) and `fixtures/sdk-policy.json` (its four copies' fixture).
  - `:SdkPolicy` is what WidgetRuntime runs:
    - `TelegramWidget.setResizeAnchor` checks its edge with `checkResizeAnchor`;
    - since v0.2.2's vendoring, `HostState` runs the `RequestGate` and the `HapticGate` with its press and release, and
      the state, viewer, chat type, request, copy and answer checks;
    - since v0.5.0's, `TelegramWidget` checks the wallet's calls and the request's options with it, and the gate's
      `decideWallet` and grant run in `HostState`.
  - `:SdkPolicyTests` is upstream's `sdk_policy_shared_fixture` over the fixture, plus
    `sdk_request_strings_refuse_surrogates_and_invalid_utf8` (`gesture/SdkPolicyTests.cpp`, ours around them).

Not taken: `packages/conformance/harness/` (inlined into every widget), `results/` (the framework's own reports),
`catalogue.md`, `probe-fixture.json`, `tools/*.d.mts`, and everything else outside `corpus/` and
`packages/conformance/` but the iOS glue's Intl (the framework's renderers, hosts and SDKs: our runtime is our own,
spec §1).

The previous vendoring (the corpus at side-branch commit 1144002 and the old runtime's JS bundles) is gone: its corpus
differed from v0.1.0 in 216 of the files both share, and the bundles (`WidgetJS/`, Chart.js and D3) were used by
nothing once the old runtime was deleted. Profile 1 bundles no libraries (`P1-libs`).

**The host's limits are upstream's** (since 2026-10-30; the user: "move closer to the upstream", exact parity).
`WidgetRuntime` runs `LIMIT_DEFAULTS` on the widget thread's CPU clock: a 500 ms slice per task, the JS quota of 300 ms
per 1000 ms window and the 100 ms main-thread window through the vendored `CpuBudget`, 100 ms of layout queries per
task, and the wall backstop max(10 × slice, 5 s) (`wr::CpuLimits`, `wr::Runtime`, `wr::EventLoop`). The work units it
ran on from 2026-10-15 are gone. What still differs: our renderer's flushes are measured but charged to no window
(upstream's renderer is the browser's; only the layout queries' time and the modelled op cost reach it); a follow-up
task gets a slice of its own rather than its delivery's, so a chain rooted in a boot, event or visibility step is not
deferred by the quota (a core drain and the boot's loop stop once a slice is spent); and native builtins are not interruptible, as
in every QuickJS client of upstream's.
