# widget-sandbox v0.1.1 (vendored)

Taken from `~/build/widget-sandbox` at the tag **`v0.1.1`** (`e9654cab644145521e754004de220aa4ed0f3ad1`, 2026-10-21),
a clarification of profile 1 (profile, SDK and protocol stay version 1; every v0.1.0 widget stays valid). The widgets
client spec (`docs/superpowers/specs/2026-10-19-message-widgets-v0.1.0-client-design.md`) follows v0.1.0; what v0.1.1
changes for the client is in the root `CLAUDE.md`'s "Message widgets" section. Files come from the tag, never the
working tree, and the old copy is removed first, so files a tag removed (v0.1.1 split `visual/03, 05, 08, 09` into `-a`
and `-b`) do not linger in the bundles:

```sh
V=v0.1.1
W=third-party/widget-sandbox
X=$(mktemp -d)
git -C ~/build/widget-sandbox archive "$V" corpus packages/conformance packages/core/profile.json \
  packages/core/tests/fixtures/intl-cases.json | tar -x -C "$X"
rm -rf "$W/corpus" "$W/conformance"
cp -R "$X/corpus" "$W/corpus"
C=$W/conformance; mkdir -p "$C/tools"
for f in auto visual refs channel.json manifest.json catalogue.json run.schema.json CLIENTS.md README.md; do
  cp -R "$X/packages/conformance/$f" "$C/"
done
cp "$X/packages/conformance/tools/"{report,diff,png}.mjs "$C/tools/"
cp "$X/packages/core/profile.json" "$W/profile/profile.json"
cp "$X/packages/core/tests/fixtures/intl-cases.json" "$W/fixtures/intl-cases.json"
rm -rf "$X"
(cd submodules/TelegramUI/Components/MessageWidget/WidgetRuntime && python3 IDL/generate-profile-tables.py)
```

Then the counts the tests pin (`ChannelTests`, `ConformanceRunnerTests`, `ConformanceSetTests`, `WidgetCorpusTests`, the
folder lists of `WidgetCorpus` and `CorpusTests`), the run file's `framework`/`commit` (`ConformanceRunFile`), and the
ratchet: `conformance_report.sh --record` retires checks a tag renamed (`ConformanceBaseline.compare`).

Taken:
- `corpus/` (all of it): `attacks/` (99 pages and `mem-cap-probe.js`; TEST FIXTURES ONLY, never in an app bundle),
  `common/`, `compat/`, `defaults/` (v0.1.1: six widgets with little or no CSS, the examples a widget that should look
  native starts from), `generated/`, `htmlbubbles-ported/`, `out-of-profile/` (widgets using what profile 1 leaves
  out), `showcase/` and `README.md`. Tests read it through `:WidgetCorpus` and `:CorpusFiles`; the DEBUG app's corpus
  insertion through `:WidgetCorpusBundle` (attacks excluded).
- `conformance/` from `packages/conformance/`: the 39 `auto/` widgets, the 20 `visual/` widgets and the 17
  `visual/sdk/` ones, `refs/` (stage crops and the reference pictures posted beside the visual widgets, drawn on the
  bubble's colour since v0.1.1), `channel.json` (the 79 posts, in order), `manifest.json`, `catalogue.json`,
  `run.schema.json`, `CLIENTS.md`, `README.md` and `tools/{report,diff,png}.mjs` (the report; Node ≥ 18, no
  dependencies; it reads `manifest.json`, `catalogue.json` and `refs/` relative to `tools/..`). Tests read it through
  `:WidgetConformance`; the DEBUG app's conformance insertion through `:WidgetConformanceBundle`.

- `profile/profile.json` from `packages/core/profile.json`: profile 1's definition, the data its tables come from. Data,
  as the conformance widgets are: WidgetRuntime's `IDL/generate-profile-tables.py` writes the tables its `CSS.supports`
  and policies use, and the renderer's UA layer (`tables.uaStylesheet`, each `:where(X)` written as X, the `@layer`
  kept: an origin of its own in the master, twidget edit 41), into `Sources/Host/ProfileTables.inc`; its tests read the
  file through `:ProfileJSON`.
- `fixtures/intl-cases.json` from `packages/core/tests/fixtures/intl-cases.json` (v0.1.1): 166 Intl requests as the
  shim sends them, with V8's answers. WidgetRuntime's `IntlCasesTests` (host, the system ICU) and `WRIntlCasesTests`
  (iOS) run each as the call a widget would make (`Tests/IntlCases.js`), with an explicit drift list
  (`Tests/intl-cases-expected-failures.txt`); they read it through `:IntlCases`.

Not taken: `packages/conformance/harness/` (inlined into every widget), `results/` (the framework's own reports),
`catalogue.md`, `probe-fixture.json`, `tools/*.d.mts`, and everything else outside `corpus/` and
`packages/conformance/` (the framework's renderers, hosts and SDKs: our runtime is our own, spec §1).

The previous vendoring (the corpus at side-branch commit 1144002 and the old runtime's JS bundles) is gone: its corpus
differed from v0.1.0 in 216 of the files both share, and the bundles (`WidgetJS/`, Chart.js and D3) were used by
nothing once the old runtime was deleted. Profile 1 bundles no libraries (`P1-libs`).

**Divergence: the host limits by work, not time.** widget-sandbox limits a widget by milliseconds (`cpuLimitMs` 500 per
slice, `cpuQuotaMs` 300 per `cpuQuotaWindowMs` 1000). Our runtime budgets deterministic work units instead (parse
400,000,000, boot 48,000,000, each later task 28,000,000; `MessageWidgetCore`), with no rate limit (the user, 2026-10-15,
and again 2026-10-19: "Keep work-unit limits"). A widget the reference throttles may run here, and the reverse. The
observable contract the catalogue's `limit.cpu` covers holds: a looping widget is stopped and keeps its last frame.
