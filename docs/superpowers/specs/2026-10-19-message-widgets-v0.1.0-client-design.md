# Message widgets v0.1.0: the iOS client on our own runtime — design

Status: for approval, 2026-10-19. Branch `feature/message-widgets` (one commit on `origin/master`, `6ef682a009`).

## 1. Intent

The user, 2026-10-19: "I picture a working standard compliant widget implementation with real messages." And: "We are
building our own runtime; we should not adopt any other runtime; our runtime must follow the spec."

So the iOS client shows widgets as widget-sandbox v0.1.0 defines them, arriving as real layer-233 `messageMediaWidget`
messages, and runs them on `WidgetRuntime`, which behaves the way the spec says a widget host must. Where the spec says
"use `WidgetHost`", read "our runtime and its facade (`WRSession`, `MessageWidgetCore`, `MessageWidgetInstance`) behave
as `WidgetHost` is specified to". Its implementation is never a reference to port.

**The authority** is widget-sandbox at tag `v0.1.0` (`d895dcb5`, `~/build/widget-sandbox`, read-only):
`docs/client-checklist.md`, `docs/integration.md`, `docs/sdk-v1.md` (§2 the widget-facing API, §4.1 the Swift host,
§5 what the client implements), `docs/tgw-format.md`, `docs/profile-v1.md` with `packages/conformance/catalogue.json`
(profile 1: 255 features, 173 in, 82 out), `packages/conformance/CLIENTS.md`, `channel.json`, `manifest.json` and
`corpus/attacks`. Where this design and those documents disagree, they win, unless a decision below says otherwise.

**The inventory** was a gap analysis of 36 items (#1–#36), each with the spec section it comes from, our code it
touches, a status and a size; it stayed with the development branch, and the bracketed numbers below refer to it. This
design decides what the inventory left open and how the work is cut.

The runtime's own design stays binding except where §4 below supersedes it; its record is
`docs/message-widgets-native-runtime.md`.

## 2. What done looks like

1. **Real messages.** A `messageMediaWidget` in any chat renders as a widget in its own bubble: gunzipped, sized from
   its anchors, captioned, with the "Widget" stub in the chat list and notifications, and as unsupported media with its
   caption when rendering is off. During development the messages are inserted locally into Saved Messages (§5, V1);
   at the end the existing test bot sends them over layer 233 (V6).
2. **The conformance automatic set** (the 38 `auto/*.html`, per CLIENTS.md) runs on our renderer, through the app's own
   path (`MessageWidgetInstance`, its policy and its bubble height), and `report.mjs` judges the run. The target is
   every in-profile ID passing and every out-profile ID behaving as the profile specifies, failures from rendering
   fidelity in the litehtml fork included, not only missing features. *(My call:)* the first report, at the end of V3,
   goes to the user, who sets the bar for V5 then (all-green, a threshold or a time box). An ID still failing at the end
   is listed with its reason for the user; none is dropped silently.
3. **The attack corpus**, all 100 files at v0.1.0: no leaks and no outside requests, checked through the bridge path
   (nothing a file does reaches `onBridge` or the network), not only at the render tree.
4. **The manual pass.** The whole conformance set (`visual/` and `visual/sdk/`), each widget beside its reference
   picture, goes through the checklist's axes: light and dark, rotation, system font size, an RTL locale, reduce motion,
   bubble re-creation on scroll, forward and edit.
5. **A feed bench** on a low-end device: many widgets in a list, scrolling, memory.
6. **The report files** (`<platform>-<renderer>.json`, `summary.md`) and the list of discrepancies, ready for the user
   to send back. Sending them is the user's.

## 3. Goals, non-goals, anti-goals

Goals: the six points of §2, with the user's decisions of §4.

Non-goals: Android, desktop, web; server changes; the test bot itself (it exists); a widget runtime shared between
widgets; a CALayer-tree renderer (native-runtime D11).

Anti-goals (a failure even if it works):
- adopting another runtime, `WidgetHost` or any of widget-sandbox's implementation code;
- a widget causing a network request, or any of `WidgetRuntime` opening a URL, a file or a socket; `openLink` and
  `openTelegramLink` reaching the user without the confirmation;
- a time-based CPU limit (the user keeps work units);
- silently skipping a conformance ID, or a check that passes because it checks nothing.

## 4. Decisions

The user's, 2026-10-19, as decided:

1. **Layer 233, and the News API comes back, on master first.** The user updates the schema
   (`submodules/TelegramApi/swift_scheme.tl`) with the server's layer-233 entries, `messageMediaWidget` /
   `inputMediaWidget` and the News feed's. That change, and News's return (CLAUDE.md, "News feed: parked at layer 232",
   steps 2–4: `TELEGRAM_NEWS_FEED_API` for `TelegramCore` and its tests, `Serialization.currentLayer()` 233,
   `generate-swiftpm.sh`), land on master on their own, so widgets and News ship separately; this branch then rebases
   onto it and adds only the widget media's parsing. Nothing that needs the new TL lands here before that.
2. **Validation in C++: the whole allowlist.** Bring over all of the profile's validation that makes sense for us,
   implemented in C++ inside the runtime. Profile 1 assumes "every client's validator removes what is out before it
   reaches the renderer"; its tables (`packages/core/profile.json` → `tables`) are allowlists, and ours enforces them
   literally: elements kept, dropped or renamed (`unknown` → `span`), the attribute list plus `data-` and `aria-`, the
   CSS properties, functions, units and `display` / `position` values, the pseudo-classes and pseudo-elements, the
   at-rules and media features. The rewrites the profile marks *in* are part of it (an unknown element becomes
   `<span data-tg-tag>`, `a[href]` becomes `#` plus `data-tg-link`), since the conformance set checks them. This
   supersedes native-runtime **D12** ("No validator … never rewritten"), D1's "native clients need neither the sandbox
   nor the validator", and the §10.1 rows kept under D12 (unknown elements rendering as themselves, `a[href^=https]`
   matching). Corpus widgets that use what the profile leaves out render as the profile says.
3. **Work units stay the CPU limit.** The spec's millisecond limits (`cpuLimitMs` 500, `cpuQuotaMs` 300 per second) are
   not emulated; the divergence is documented for the maintainers in the report's discrepancy list. The kill reasons
   take the spec's names (`CPU limit exceeded`, `Layout query limit exceeded`, `Memory limit exceeded (64 MB)`).
4. **Web Animations are implemented** (`Element.animate`, `getAnimations`, `Animation`, `document.timeline`, control of
   CSS animations). This supersedes the native-runtime non-goal "Web Animations API".
5. **Profile 1 is the target.** In particular `P1-libs`: no bundled libraries, so native-runtime **D2**'s "Chart.js and
   D3 stay … installed on demand" and M3's library loader are dropped. Forms, inner scroll, 3D transforms and the other
   out features follow the profile, which supersedes the native-runtime non-goal text that controls "render, take taps
   and have a focus model".
6. **`tgw` is removed: both `.tgw` files and `tgwidget` code blocks**, once the `messageMediaWidget` bubble renders the
   conformance set (V1); `messageMediaWidget` is the only delivery path. The InstantPage V2 widget block goes with
   them (a future page-block widget would bring one back). This overrides `tgw-format.md`'s `.tgw` debug path.
7. **Storage per the v0.1.0 docs**: `sdk-v1.md` §2.8 (D17) and §5.4. The standalone twidget repository's README, which
   says widgets get no storage, predates them. *(The user, 2026-10-20:)* the client keeps it in the message's derived
   attributes (`DerivedDataMessageAttribute`), not in a separate Postbox table or cache.

The user's answers to the builder check, 2026-10-19: the whole allowlist (2), master first (1), K3 for this project
(§6), both `.tgw` and `tgwidget` (6).

Also the user's, 2026-10-19:
- **Real messages may be inserted locally into Saved Messages** for testing ("for simplicity you may insert conforming
  messages into saved messages locally"). A test bot that sends layer-233 widgets exists.
- The milestone cut and the order in §5 were played back and accepted ("looks good").

## 5. The work, in milestones

Each milestone gets its own plan, is executed with tests written first and watched failing,
ends with a whole-branch review on the most capable model, and **a review of that review's fix wave** before it is
called done (the user's standing rule; M1d's fix wave had three holes). Each leaves a carry-over file. Gap-analysis item
numbers in brackets.

**V1 — Real widget messages.** Independent of the schema except its last step.
- A TelegramCore media class for the widget (width and height anchors in CSS px, `0` = auto; the gzip payload), with
  its Postbox coding, an `EngineMedia` case, and handling in forward, edit, search and the chat-list, notification and
  search text helpers (caption, else the localized "Widget" stub) [#1, #4, #26].
- Its own bubble content node: gunzip, the registry, the caption under the widget; the unsupported fallback with the
  caption when rendering is off [#2]. An enable flag, off by default, in the app's debug/experimental settings, as the
  spec asks for a client flag rather than app config [#3]; the app-config kill switch may stay as an extra.
- Bubble sizing from the anchors: width 0 = the bubble's width, W = fixed in [200, max]; height 0 = a placeholder, then
  the content height in [50, 600], cached per message; H = clamp(H, 50, 600); a hard clip at the bubble's height, no
  fullscreen [#7, #8, #9]. The runtime's own 256 KiB source cap does not apply to this path (the spec adds no limit of
  the client's own; the server bounds the HTML at 32 KB) [#6].
- The host CSS follows the spec: no `body { padding: 4px 9px }`; the spec's root CSS [#30].
- Re-vendor widget-sandbox at `v0.1.0` into `third-party/widget-sandbox` (corpus, conformance set, refs, report tool) [#35].
- **A debug action inserts the conformance set into Saved Messages as local widget messages**, in `channel.json` order,
  each visual widget with its reference picture beside it as the channel posts it. It replaces the `.tgw` corpus sender.
- Then `tgw` goes: `.tgw` files and `tgwidget` code blocks as delivery paths, with the InstantPage V2 widget block and
  its tests [#5].
- **Once layer 233 is on master (§4.1):** rebase, then `messageMediaWidget` parsing from the TL.

**V2 — SDK v1.** The widget-facing API and what the client implements (sdk-v1 §2, §5) [#13–#24]:
- the v1 bridge object (`profile`, `isProfileAtLeast`, `colorScheme`, `themeParams`, `isActive`, `onEvent` /
  `offEvent`, `onTheme` calling back at once; `on` and host→widget bridge events removed; **`sendMessage` removed**);
- the removed and inert APIs (`alert` / `confirm` / `prompt`, clipboard, share, the network globals throwing
  `NetworkDisabledError`) and the spec's diagnostic names;
- links: the URL rules, `openTelegramLink`, `<a href>` and `window.open` routing, one call per press shared by both
  methods over pointerdown…click, the full URL in the confirmation, one dialog at a time;
- theme (`themeParams` from the chat's palette, `--tg-theme-*`, the button tokens, the profile's UA sheet), locale;
- haptics with the rate limit;
- storage, runtime and client (§2.8 / §5.4), including deletion with the message, the chat, the account and "Clear
  cache", and forward (own, empty storage) and bot edit (same storage) semantics. *(The user's decision, 2026-10-20,
  replacing my call of a Postbox table:)* the client half lives in the message's derived attributes
  (`DerivedDataMessageAttribute`, written through `engine.messages.updateLocallyDerivedData`), not in a separate
  Postbox table or cache, so removing a message, a chat or an account removes its widgets' storage with it; how "Clear
  cache", forward and a bot's edit treat that attribute is checked against §5.4 in V2b. Widget storage is not listed in
  Storage Usage. The per-message height cache is a separate, rebuildable cache;
- gestures: taps only reach the widget; double tap and long press stay with the bubble; drag claims (`touch-action`,
  `preventDefault`) against swipe-to-reply and the list scroll; no focus move, no touch events;
- the restart policy (rebuild once; stopped after 2 crashes in a row).

**V3 — Layout queries and the conformance runner.** The harness cannot publish tap targets without
`getBoundingClientRect`, and uses `getComputedStyle`, so these come first: the layout-query bindings
(`getBoundingClientRect`, `getClientRects`, `offset*` / `client*` / `scroll*`, `getComputedStyle`, `matchMedia`,
`ResizeObserver`, `IntersectionObserver`, `elementFromPoint`) with the layout-query budget behind "Layout query limit
exceeded" [#28 part]. Then the runner [#31], driving `MessageWidgetInstance` on the simulator per CLIENTS.md (width
390, the scripted actions with real input, crops at 2× through `WRTree`, the run file per `run.schema.json`), and
`report.mjs` run from the vendored v0.1.0 copy with `--out` outside widget-sandbox. *(My call:)* the runner is hosted
where a check needs the app, in a test host application like `Tests/ComposerHarness`: a bare `ios_unit_test` has no
`UIApplication` or window, so a stand-in field could never hold first responder (`chatFocused`) and double tap and
right click could not go through the bubble's gesture handling. A check the runner cannot perform for real is reported
as not performed, never as passed. The first
report is the work list for V4 and V5. The attack test through the bridge path, all 100 files [#33], lands here too.

**V4 — Profile enforcement.** The C++ validation of §4.2: profile 1's tables compiled in and enforced as allowlists,
the profile's rewrites included, for content scripts create as well as the initial markup; `CSS.supports`, `@supports` and
`TelegramWidget.profile` from the same tables; the strict limits (64 KB text values, the text budgets, the 300 KB
attribute rule, 50,000 nodes, 16 handlers per event type, the URL length) [#27, #29].

**V5 — Profile in-features**, ordered by the report's failure counts [#28 rest]: CSS transitions and animations, Web
Animations, canvas 2D, `Intl`, the built-ins (`crypto.getRandomValues` / `randomUUID`, `TextEncoder` / `TextDecoder`,
`URL`, `URLSearchParams`, `structuredClone`, `AbortController`, `atob` / `btoa`), `MutationObserver`.

**V6 — Release checks** [#32, #34, #36]: the bot's real layer-233 messages end to end (forwarded into the test
channel), the manual pass of §2.4, the feed bench on a low-end device, the final report and discrepancy list.

The native-runtime milestones still open (M1e's WPT rendering, corpus gates and goldens; Task 10c, the incremental render
subtree) are not dropped: they are taken up where a V milestone needs them (the feed bench may need Task 10c), and
otherwise after V6.

## 6. Constraints

- **Security, unchanged:** a widget can never cause a network request from the device; `openLink` (and now
  `openTelegramLink`) always prompts; nothing in `WidgetRuntime` opens a URL, a file or a socket.
- **widget-sandbox is read-only**; the app vendors its v0.1.0 files into `third-party/widget-sandbox`.
- **Determinism:** every runtime limit counts work, never time (§4.3).
- **TelegramCore** stays free of UIKit and Display; the gunzip and the model may live there, the bubble does not.
  The Postbox refactor rules apply (CLAUDE.md, "Postbox → TelegramEngine refactor"): a new media class needs its
  `EngineMedia` case, and new consumer code reaches it through engine types, not `import Postbox`.
- **TL:** only from the user's schema; `swift_scheme.tl` is the source, Bazel regenerates, SwiftPM's copy via
  `generate-swiftpm.sh`.
- **Process:** the controller runs every Bazel build; subagents never build. Commit locally; never push; never merge
  without asking.
- **Simulators:** K3 (`4483DD69-685A-4FE1-89BE-65F992C271F2`, logged in) is approved for this project (the user,
  2026-10-19), for installs, the Saved Messages insertion and the manual checks, with the standing rules: never open a
  chat with unread messages, a fresh screenshot before every tap, no account switching. Visual and animated changes are
  verified from recorded frames (AGENTS.md). The low-end device for V6's feed bench is asked for at V6.

## 7. Left to the builder

- The media class's name and coding, and whether gunzip happens in TelegramCore or at the bubble.
- Where the enable flag lives (Debug Settings or experimental settings) and its name.
- How the debug insertion is triggered and how the reference pictures are stored as local media.
- How the C++ validation is structured (a pass over the tree, checks at the existing decision points such as the
  builder's not-rendered list, the CSS and selector parsers and the image MIME check, or both), provided it holds for
  script-created content and reads the profile's tables.
- The runner's internals (reading `data-conformance`, the virtual clock for `wait`), within CLIENTS.md.
- The order inside each milestone, and V5's order (by the report).
