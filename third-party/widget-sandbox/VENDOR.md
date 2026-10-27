# widget-sandbox v0.2.3 (vendored)

Taken from `~/build/widget-sandbox` at the tag **`v0.2.3`** (`88285a3b`, 2026-10-27).
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
V=v0.2.3
W=third-party/widget-sandbox
X=$(mktemp -d)
D=packages/desktop/sandbox
git -C ~/build/widget-sandbox archive "$V" corpus packages/conformance packages/core/profile.json \
  packages/core/tests/fixtures/intl-cases.json packages/core/tests/fixtures/gesture-policy.json \
  packages/core/tests/fixtures/sdk-policy.json $D/include/twidget/gesture_policy.h $D/include/twidget/json.h \
  $D/include/twidget/sdk_policy.h $D/src/gesture_policy.cpp $D/src/sdk_policy.cpp | tar -x -C "$X"
rm -rf "$W/corpus" "$W/conformance"
cp -R "$X/corpus" "$W/corpus"
C=$W/conformance; mkdir -p "$C/tools"
for f in auto visual refs channel.json manifest.json catalogue.json run.schema.json CLIENTS.md README.md; do
  cp -R "$X/packages/conformance/$f" "$C/"
done
cp "$X/packages/conformance/tools/"{report,diff,png}.mjs "$C/tools/"
cp "$X/packages/core/profile.json" "$W/profile/profile.json"
cp "$X/packages/core/tests/fixtures/intl-cases.json" "$W/fixtures/intl-cases.json"
cp "$X/packages/core/tests/fixtures/gesture-policy.json" "$W/fixtures/gesture-policy.json"
cp "$X/packages/core/tests/fixtures/sdk-policy.json" "$W/fixtures/sdk-policy.json"
mkdir -p "$W/gesture/twidget"
cp "$X/$D/include/twidget/"{gesture_policy.h,json.h,sdk_policy.h} "$W/gesture/twidget/"
cp "$X/$D/src/"{gesture_policy.cpp,sdk_policy.cpp} "$W/gesture/"
rm -rf "$X"
(cd submodules/TelegramUI/Components/MessageWidget/WidgetRuntime && python3 IDL/generate-profile-tables.py)
```

Then the counts the tests pin (`ChannelTests`, `ConformanceRunnerTests`, `ConformanceSetTests`, `WidgetCorpusTests`, the
folder lists of `WidgetCorpus` and `CorpusTests`), the run file's `framework`/`commit` (`ConformanceRunFile`), and the
ratchet: `conformance_report.sh --record` retires checks a tag renamed (`ConformanceBaseline.compare`).

Taken:
- `corpus/` (all of it):
  - `attacks/`: 105 pages and `mem-cap-probe.js`. v0.2.0 added the five `request-*` pages and v0.2.2
    `haptic-timer-buzz`. TEST FIXTURES ONLY, never in an app bundle.
  - `common/` and `compat/`.
  - `defaults/` (v0.1.1): six widgets with little or no CSS, the examples a widget that should look native starts from.
  - `generated/`.
  - `gestures/` (v0.1.3): games and controls by the touch-action they claim, the `-xy` ones now behaving as their `-x`
    twins.
  - `htmlbubbles-ported/`.
  - `interactive/` (v0.2.0): a poll, tic-tac-toe, a live ticker and a promo code, played against the bot named in
    `<meta name="tw-bot">`.
  - `out-of-profile/`: widgets using what profile 1 leaves out.
  - `resize/` (v0.1.3): one widget per resize anchor.
  - `showcase/` and `README.md`.

  Tests read it through `:WidgetCorpus` and `:CorpusFiles`, the DEBUG app's corpus insertion through
  `:WidgetCorpusBundle` (attacks excluded).
- `conformance/` from `packages/conformance/`:
  - the 51 `auto/` widgets, the 20 `visual/` widgets and the 26 `visual/sdk/` ones, with their README;
  - `refs/`: stage crops and the reference pictures posted beside the visual widgets, drawn on the bubble's colour
    since v0.1.1;
  - `channel.json`: the 102 posts in order, each with its `message` spec, plus the `bot` table (v0.2.1);
  - `manifest.json` (tests carry `message` and `bot` since v0.2.1), `catalogue.json`,
  `run.schema.json`, `CLIENTS.md`, `README.md` and `tools/{report,diff,png}.mjs` (the report; Node ≥ 18, no
  dependencies; it reads `manifest.json`, `catalogue.json` and `refs/` relative to `tools/..`). Tests read it through
  `:WidgetConformance`; the DEBUG app's conformance insertion through `:WidgetConformanceBundle`.

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
      the state, viewer, chat type, request, copy and answer checks.
  - `:SdkPolicyTests` is upstream's `sdk_policy_shared_fixture` over the fixture, plus
    `sdk_request_strings_refuse_surrogates_and_invalid_utf8` (`gesture/SdkPolicyTests.cpp`, ours around them).

Not taken: `packages/conformance/harness/` (inlined into every widget), `results/` (the framework's own reports),
`catalogue.md`, `probe-fixture.json`, `tools/*.d.mts`, and everything else outside `corpus/` and
`packages/conformance/` but the iOS glue's Intl (the framework's renderers, hosts and SDKs: our runtime is our own,
spec §1).

The previous vendoring (the corpus at side-branch commit 1144002 and the old runtime's JS bundles) is gone: its corpus
differed from v0.1.0 in 216 of the files both share, and the bundles (`WidgetJS/`, Chart.js and D3) were used by
nothing once the old runtime was deleted. Profile 1 bundles no libraries (`P1-libs`).

**Divergence: the host limits by work, not time.** widget-sandbox limits a widget by milliseconds (`cpuLimitMs` 500 per
slice, `cpuQuotaMs` 300 per `cpuQuotaWindowMs` 1000). Our runtime budgets deterministic work units instead (parse
400,000,000, boot 48,000,000, each later task 28,000,000; `MessageWidgetCore`), with no rate limit (the user, 2026-10-15,
and again 2026-10-19: "Keep work-unit limits"). A widget the reference throttles may run here, and the reverse. The
observable contract the catalogue's `limit.cpu` covers holds: a looping widget is stopped and keeps its last frame.
