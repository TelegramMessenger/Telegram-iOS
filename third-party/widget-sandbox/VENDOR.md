# widget-sandbox v0.1.0 (vendored)

Taken from `~/build/widget-sandbox` at the tag **`v0.1.0`** (`d895dcb50e47129277164f84afd1f1951e3479b0`, 2026-10-17),
the release the widgets client spec (`docs/superpowers/specs/2026-10-19-message-widgets-v0.1.0-client-design.md`)
follows. Files come from the tag, never the working tree:

```sh
X=$(mktemp -d)
git -C ~/build/widget-sandbox archive v0.1.0 corpus packages/conformance | tar -x -C "$X"
cp -R "$X/corpus" third-party/widget-sandbox/corpus
C=third-party/widget-sandbox/conformance; mkdir -p "$C/tools"
for f in auto visual refs channel.json manifest.json catalogue.json run.schema.json CLIENTS.md README.md; do
  cp -R "$X/packages/conformance/$f" "$C/"
done
cp "$X/packages/conformance/tools/"{report,diff,png}.mjs "$C/tools/"
```

Taken:
- `corpus/` (all of it): `attacks/` (99 pages and `mem-cap-probe.js`; TEST FIXTURES ONLY, never in an app bundle),
  `common/`, `compat/`, `generated/`, `htmlbubbles-ported/`, `out-of-profile/` (widgets using what profile 1 leaves
  out), `showcase/` and `README.md`. Tests read it through `:WidgetCorpus` and `:CorpusFiles`; the DEBUG app's corpus
  insertion through `:WidgetCorpusBundle` (attacks excluded).
- `conformance/` from `packages/conformance/`: the 38 `auto/` widgets, the 13 `visual/` widgets and the 17
  `visual/sdk/` ones, `refs/` (stage crops and the reference pictures posted beside the visual widgets),
  `channel.json` (the posts, in order), `manifest.json`, `catalogue.json`, `run.schema.json`, `CLIENTS.md`, `README.md`
  and `tools/{report,diff,png}.mjs` (the report; Node ≥ 18, no dependencies; it reads `manifest.json`,
  `catalogue.json` and `refs/` relative to `tools/..`). Tests read it through `:WidgetConformance`; the DEBUG app's
  conformance insertion through `:WidgetConformanceBundle`.

- `profile/profile.json` from `packages/core/profile.json` (2026-10-20, V5c): profile 1's definition, the data its
  tables come from (`git -C ~/build/widget-sandbox show v0.1.0:packages/core/profile.json`). Data, as the conformance
  widgets are: WidgetRuntime's `IDL/generate-profile-tables.py` writes the tables its `CSS.supports` uses (and V4's
  validator will use) into `Sources/Host/ProfileTables.inc`; its tests read the file through `:ProfileJSON`.

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
