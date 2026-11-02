# web-platform-tests (vendored subset)

From https://github.com/web-platform-tests/wpt at d2727a54348e2af3f8fc7cbdfd4956d75927c938 (2026-10-15), BSD 3-Clause
(`LICENSE.md`), copied verbatim. `FILES.txt` lists every file with its git blob id, and every id is upstream's at
that commit (checked when vendoring). Only what the message-widget native runtime uses is here:

- `interfaces/{dom,html,SVG}.idl`: the source of `submodules/TelegramUI/Components/MessageWidget/WidgetRuntime/IDL/`
  (that directory's README lists every change made there). `interfaces/{webidl,hr-time}.idl`: the source of
  `Function`, `VoidFunction` and `DOMHighResTimeStamp` there, and `interfaces/{pointerevents,touch-events}.idl` of the
  `GlobalEventHandlers` partials for the pointer and touch handlers. (Upstream's file is `webidl.idl`, lower case.)
  `interfaces/web-animations{,-2}.idl` (2026-10-21, at the same pin): the source of `WidgetRuntime/IDL/web-animations.webidl`
  (Level 1, with Level 2's time attributes and `iterationComposite`). `interfaces/css-{animations,transitions}{,-2}.idl`
  (2026-10-21, at the same pin, each blob id checked against upstream's `contents` API): the source of
  `WidgetRuntime/IDL/css-animations.webidl` (the events and handlers, `CSSAnimation` and `CSSTransition`).
- `resources/testharness.js`; `common/{gc,utils,subset-tests-by-key,reftest-wait}.js`: the harness and the helpers the
  tests load. `resources/testharnessreport.js` is deliberately absent: the runner serves its own
  (`WidgetRuntime/Tests/WPT/wpt-report.js`).
- The tests WidgetRuntime's headless runner (`:WidgetRuntimeWPTTests`) runs, with their support files:
  - `dom/nodes/` without `Document-contentType/` (iframes and XHR) and `moveBefore/` (outside the profile);
  - `dom/events/` without `scrolling/` and `non-cancelable-when-passive/` (testdriver and layout);
  - `dom/collections/`, `dom/lists/`, and `dom/{common,constants}.js`;
  - `html/webappapis/{timers,microtask-queuing,animation-frames}/` and `html/webappapis/scripting/event-loops/`.
  - from `css/cssom/`, the inline style declaration block's tests (2026-10-19, at the same pin): `CSSStyleDeclaration-*`,
    `cssstyledeclaration-{csstext,csstext-final-delimiter,csstext-important,custom-properties,mutability,properties,
    removeProperty-all,setter-attr,setter-declarations}.html`, `css-style-attr-decl-block.html`,
    `css-style-attribute-modifications.html`, `cssom-cssstyledeclaration-set.html`, `cssom-cssText-serialize.html`,
    `setproperty-null-undefined.html`, `style-attr-update-across-documents.html`, `style-cssText-mutations.html` and
    `style-set-cssText.html`; and `interfaces/cssom.idl`, the source of `WidgetRuntime/IDL/cssom.webidl`.
- `web-animations/` (2026-10-21, at the same pin, each blob id checked against `HEAD:<path>`): `testcommon.js`,
  `resources/` and the `interfaces/` and `timing-model/` tests, which `:WidgetRuntimeWPTTests` runs (V5e plan, Task 5).
- `css/css-animations/animationevent-interface.{html,js}` and `css/css-transitions/transitionevent-interface.html`
  (2026-10-21, at the same pin, each blob id checked against `HEAD:<path>`): the event interfaces' tests. The other
  pages of those directories need a CSS animation to run, which needs a render tree the runner does not install; the
  conformance harness and `WidgetRuntimeTests` (`CSSAnimation*Tests.cpp`) cover them instead (V5f plan, Task 8).
- `url/resources/{urltestdata,toascii}.json` (2026-10-20, at the same pin, each blob id checked against upstream's
  `contents` API): the URL Standard's parsing and "domain to ASCII" cases, which `:WidgetRuntimeURLDataTests` drives
  through `URL` (the WPT pages that use them fetch them, and the runner has no fetch).

Not vendored, inside those directories: `*.py` and `*.headers` (wptserve handlers, no server here).

Referenced by the vendored tests and not vendored: `resources/testharnessreport.js` (the runner's own),
`resources/testdriver.js`, `resources/testdriver-actions.js` and `resources/testdriver-vendor.js` (no testdriver).

## How it was fetched

    D=$(mktemp -d)
    git init -q "$D"; git -C "$D" config core.symlinks false
    git -C "$D" remote add origin https://github.com/web-platform-tests/wpt.git
    git -C "$D" sparse-checkout set --no-cone <the paths above, with the excluded directories negated>
    git -C "$D" fetch -q --depth 1 --filter=blob:none origin d2727a54348e2af3f8fc7cbdfd4956d75927c938
    git -C "$D" checkout -q FETCH_HEAD
    (cd "$D" && rsync -r -t -R --exclude='*.py' --exclude='*.headers' <the paths> <this directory>/)
    # then: directories 755, files 644 (macOS's rsync has no --chmod)

Fetch by SHA, never a branch: a `--depth 1` clone of master drifts from the pin. Use the paths' exact case
(`webidl.idl`): a case-insensitive file system hides a wrong one, and only the blob check against `HEAD:<path>` shows it.

To update: fetch one new commit the same way, re-copy every file, regenerate `FILES.txt`, re-check
`WidgetRuntime/IDL/` against the new IDL, and re-run `:WidgetRuntimeWPTTests` with `--update` (its ratchet then
shows every result the new tests changed).
