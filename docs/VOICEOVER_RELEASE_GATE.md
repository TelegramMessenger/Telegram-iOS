# VoiceOver release gate

Accessibility changes are release-ready only after all three layers below pass.

## 1. Source contracts

Run from the repository root:

```sh
python3 -m unittest discover -s Tests/VoiceOverContracts -p "test_*.py" -v
```

These tests prevent known renderer, stable-focus, and modal contracts from being removed. They do not prove runtime accessibility.

The source-contract job runs automatically for pushes to `VoiceOver-fixes` and for pull requests that touch accessibility implementation or gate files.

## 2. Simulator tree audit

Generate the Xcode project using the repository build instructions and run `AccessibilityUITests` from `iOSAppUITestSuite` on an iOS 17 or newer simulator. The suite runs the XCTest accessibility audit and checks stable message identifiers for duplicates.

The default suite launches with `--ui-test` and therefore uses a clean signed-out data directory. To exercise the populated-chat assertions, prepare a dedicated simulator account, leave the required chat open, and run the suite with `VOICEOVER_USE_EXISTING_DATA=1` in the test scheme environment. In this mode the tests retain simulator data and additionally verify message names, unique stable identifiers, non-empty frames, and the input field's expanded hit target and keyboard focus. These tests report `XCTSkip`, rather than a false pass, when the required fixture is absent.

The repository command used by the manually dispatched GitHub gate is:

```sh
python3 build-system/Make/Make.py \
  --bazelUserRoot=/private/var/tmp/_bazel_voiceover \
  test \
  --configurationPath=build-system/appstore-configuration.json \
  --disableProvisioningProfiles \
  --target=Telegram:iOSAppUITestSuite
```

Run the suite in at least these states:

- signed out, welcome screen;
- signed in, chat list populated;
- chat containing text, media, voice, instant video, reply, service, gift, and paid-media messages;
- search results visible;
- a context menu or modal sheet open.

The initial accessibility tree has a regression budget of 500 exposed elements. After one warm-up traversal, the suite takes ten samples and enforces a conservative average budget of 2 seconds and a maximum budget of 5 seconds. It also records XCTest wall-clock time and memory through `XCTClockMetric` and `XCTMemoryMetric`. Tighten the conservative budgets after accepting a stable device-specific baseline. Treat a statistically significant regression against the latest accepted `.xcresult` as release-blocking even when the absolute budgets still pass.

## 3. Manual VoiceOver matrix

Record the device, iOS version, app commit, locale, and result for each scenario:

- history traversal and three-finger scrolling;
- jump to latest and input focus;
- reply, react, options, copy, forward, and delete actions;
- delivery, read, playback, selection, loading, error, and disabled states;
- selection transactions and limit errors;
- Share Extension peers, search, topics, error, Escape, and return focus;
- Peer Info, Gifts, members, contacts, and search transaction focus;
- context, peek, pinch, alert, and action-sheet containment and Escape;
- Dynamic Type accessibility sizes, Reduce Motion, and Voice Control names.

A release is blocked when a P0 chat flow fails, focus moves to an unrelated element, a modal leaks background traversal, or an interactive control has no meaningful name or action.

## Evidence

Attach the source-contract log, XCTest result bundle, tree-size attachment, performance comparison, VoiceOver transcript or recording, and discovered regressions to the release tracking issue. The manually dispatched GitHub workflow retains its `.xcresult` artifact for 30 days. Regressions must link to an atomic fix commit or a documented release-blocking decision.
