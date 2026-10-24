# widget-sandbox v0.1.3 (vendored)

Taken from `~/build/widget-sandbox` at the tag **`v0.1.3`** (`11aacec5fbdc24e2419ce53c8c0ae3c91279e38f`, 2026-10-24):
the payload is zlib, vertical drags are always the chat's (decision G2, the gesture policy's `claimOf` never claims
`y`), and `TelegramWidget.setResizeAnchor` (decision R1, the SDK policy's `checkResizeAnchor`); profile, SDK and protocol
stay version 1. The widgets client spec (`docs/superpowers/specs/2026-10-19-message-widgets-v0.1.0-client-design.md`)
follows v0.1.0, with this client's v0.1.1, v0.1.2 and v0.1.3 decisions in its later sections; the client's rules are in the message widgets guide
(`submodules/TelegramUI/Components/MessageWidget/CLAUDE.md`). Files come from the tag, never the
working tree, and the old copy is removed first, so files a tag removed (v0.1.1 split `visual/03, 05, 08, 09` into `-a`
and `-b`) do not linger in the bundles:

```sh
V=v0.1.3
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
- `corpus/` (all of it): `attacks/` (99 pages and `mem-cap-probe.js`; TEST FIXTURES ONLY, never in an app bundle),
  `common/`, `compat/`, `defaults/` (v0.1.1: six widgets with little or no CSS, the examples a widget that should look
  native starts from), `generated/`, `gestures/` (v0.1.3: games and controls by the touch-action they claim, the
  `-xy` ones now behaving as their `-x` twins), `htmlbubbles-ported/`, `out-of-profile/` (widgets using what profile 1
  leaves out), `resize/` (v0.1.3: one widget per resize anchor), `showcase/` and `README.md`. Tests read it through `:WidgetCorpus` and `:CorpusFiles`; the DEBUG app's corpus
  insertion through `:WidgetCorpusBundle` (attacks excluded).
- `conformance/` from `packages/conformance/`: the 41 `auto/` widgets, the 20 `visual/` widgets and the 18
  `visual/sdk/` ones, `refs/` (stage crops and the reference pictures posted beside the visual widgets, drawn on the
  bubble's colour since v0.1.1), `channel.json` (the 82 posts, in order), `manifest.json`, `catalogue.json`,
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

  **Upstream's glue traps on a locale tag with a unicode extension** (still so at v0.1.3, whose Intl section is the
  same as v0.1.1's). Upstream's shim passes tags as written, so on upstream's own client one widget line crashes the
  app. The glue's `Locale(identifier:)` turns `ar-EG-u-nu-arab` into `ar_EG@numbers=yes`. The glue force-unwraps the
  resulting nil `dateFormat` (`plainConnector(formatter.dateFormat, …)`) and `NumberFormatter` symbols (`numberParts`),
  and `RelativeDateTimeFormatter` traps inside Foundation itself. WidgetRuntime never sends a unicode extension
  (`intl::resolveLocale`).

  The fix is upstream's to make: build the locale with `Locale(components: Locale.Components(identifier:))` (iOS 16+).
  With it, the crashing requests format with their extensions applied, and `intl-cases.json` still passes on macOS 27,
  iOS 26.5 and iOS 27.0. When a vendored version has it, `resolveLocale` may keep extensions on iOS 16 and later.
  The runtime record's Intl section has the details.

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
  `packages/core/src/shared/sdk-policy.ts`) and `fixtures/sdk-policy.json` (its four copies' fixture). `:SdkPolicy` is
  what WidgetRuntime's `TelegramWidget.setResizeAnchor` checks its edge with (`checkResizeAnchor`); `:SdkPolicyTests`
  is upstream's `sdk_policy_shared_fixture` over the fixture (`gesture/SdkPolicyTests.cpp`, ours around it).

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
