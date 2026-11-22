# Message widgets v0.2: the bot's state and requests — design

Status: approved by the user, 2026-10-26 ("Proceed"). Branch `widgets/v0.2` (from `origin/master` `70214ef56d`).

## 1. Intent

widget-sandbox v0.2 makes a widget **fixed code plus changeable state**. The HTML is set when the bot sends the widget
and never changes. The state changes, and only the bot writes it. The widget reads it, learns of changes, and can ask
the bot. The maintainer's notes (2026-10-26) list what a client supports:

- the state passed into the widget;
- live state updates;
- shared state polled for widgets on screen;
- requests to the bot;
- the network marker;
- `copyText`;
- inline results as previews;
- forward headers;
- (0.2.2) haptics only after a touch.

The user, 2026-10-26:
- "There is a bot that sends these, to any chat (private/group/channel)", so the whole list matters.
- "Use 0.2.2."
- "No bot so far; use upstream for now."
- "Do the conformance for now."

**The authority** is widget-sandbox at tag **`v0.2.2`** (`66f4c1f79f`, `~/build/widget-sandbox`, read-only):
- `docs/changes.md` (the v0.2.0–v0.2.2 notes);
- `docs/client-checklist.md` §d;
- `docs/integration.md`: "The widget's state and requests", "Forwarding and state";
- `docs/sdk-v1.md`: §2.6, §2.13–§2.16, §3, §4.1, §5.11;
- `docs/tgw-format.md`: "Who may send…", "The widget's state and requests", with the layer-233 TL;
- `docs/decisions.md`: I1, "Haptics need a touch";
- `packages/conformance/CLIENTS.md` ("The message context") with `manifest.json` / `channel.json`;
- `packages/core/tests/fixtures/sdk-policy.json`.

Where this design and those documents disagree, they win, unless §4 says otherwise.

The v0.1.0 client spec (`2026-10-19-message-widgets-v0.1.0-client-design.md`) and the runtime record
(`docs/message-widgets-native-runtime.md`) stay binding except where §4 supersedes them. The v0.1.0 spec gets a §11 that
points here.

**Already done:** the layer-233 schema with every v0.2 constructor is on master (`893e88a399`). TelegramCore parses it
and today drops the new fields.

## 2. What done looks like

1. **Conformance.** Our harness runs the v0.2.2 automatic set with each case's message context and a mock bot, per
   CLIENTS.md "The message context".
   - The new cases pass: `25-state-api-a`/`-b`, `26-context-{private,group,no-queries,copy,live-copy,preview}`,
     `27-haptics-no-touch`, and `23-gestures-a`/`-b`, which replace `23-gestures`.
   - The ratchet keeps every check that passes today.
   - The new `visual/sdk` cases load.
   - The vendored policy's fixture tests pass, all sections.
   - The new attacks (`request-*`, `haptic-timer-buzz`) hold: no request without a tap, at most 1 s of haptics.
2. **Real messages carry their state.** A `messageMediaWidget` in any chat starts its widget with the message's context
   and state.
   - A state edit reaches the running widget without restarting it. In W1 that means a supergroup's ordinary channel
     edit; private chats and basic groups get theirs through `updateMessageWidgetData` in W2.
   - The network marker shows exactly where the message has `can_query`.
3. **The app's network paths** (§5, W2) are unit-tested, each named in its milestone.
4. **End to end against a real bot** (W2, W3). Since 2026-10-26 the user's "Widget Bot" runs on the test servers. It
   is in the "iPhone 18 Pro" simulator (`3A36B4F5`).
   - Its commands cover the network paths:
     - `/poll` and `/ttt`: chat state and tap requests;
     - `/polllive`, `/ticker_shared` and `/tick`: shared state, polling and forwards;
     - `/promo`: `copyText`;
     - `/live`: background requests;
     - `/duel` in a group: group state;
     - HTML sent to it: any widget.
   - W2 and W3 end with those checks on that simulator. W1 stays conformance-proven.

## 3. Goals, non-goals, anti-goals

Goals: §2, cut into the milestones of §5.

Non-goals:
- running against a real bot in W1 (W2 and W3 do, §2.4);
- a mock bot inside the app;
- the bot-side updates (`updateBotWidgetQuery`, `updateInlineBotWidgetQuery`, `updateBotWidgetCopyQuery`);
- sending widgets (`inputMediaWidget`, `inputMediaWidgetId`, `inputBotInlineMessageWidget*`);
- `editMessageWidgetData` / `editWidgetData`;
- the `agent.*` API;
- Android, desktop, web.

Anti-goals (a failure even if it works):
- `WidgetRuntime` opening a URL, a file or a socket (unchanged);
- any network request for a widget other than the two §4.A names, or either of them outside its gate;
- deriving the server's flags (`is_copy`, `can_query`, `background_query`) instead of passing them as they are;
- a state change restarting a widget;
- polling a widget that is off screen or not watching;
- a request left without exactly one outcome (the widget could never ask again);
- the state decoded leniently, so that `data-rejected` / `INVALID_ANSWER` can never fire;
- silently skipping a conformance check, or a check that passes because it checks nothing.

## 4. Decisions

### The user's

1. **v0.2.2 is the target** ("Use 0.2.2").
2. **The whole list is in scope**: the bot sends to private chats, groups and channels.
3. **Conformance is the verification for now**, with upstream's case tables standing in for the bot. There is no bot
   yet, and no mock bot in the app ("Do the conformance for now").
4. The shape played back on 2026-10-26 was accepted ("Yes, looks good"):
   - the runtime learns the new SDK;
   - the app wires it to the server;
   - done means real chats plus conformance, the real-chat half waiting for a bot.
5. **All three milestones, W1 to W3** ("Do all W1/W2/W3").
6. **The app makes network requests on a widget's behalf** ("Yes, the app can obviously make network requests on
   widget's behalf. This is part of the new upstream spec"), as A below sets out.

**A. Network requests on a widget's behalf** (the user's decision 6). This supersedes:
- v0.1.0 §3's anti-goal "a widget causing a network request";
- §6's "a widget can never cause a network request from the device";
- the guide's "No network, ever / One way out".

v0.2 requires the client to ask the server for a widget. Proposed:
- `WidgetRuntime` still opens nothing (`:WidgetRuntimeNoIOScanTests` and `testAttackCorpusRequestsNothing` stay).
- The **app** sends exactly two requests for a widget, both only to Telegram's server, carrying only the bot's data,
  never a URL:
  1. **`messages.getBotWidgetQueryAnswer`**, only when the runtime's request gate admits a widget's `request(data)`.
     - It needs a tap in a message whose server flags say `can_query`.
     - Or, without a tap, in the bot's private chat when the server sets `background_query`: **one when the widget
       appears on screen, then at most one per 5 s while it stays visible.** A widget there can make requests with no
       user action, as Mini Apps can.
     - The server allows 5 per 5 s per user and bot.
  2. **`messages.getWidgetPublicData`**, only for a widget on screen that has a `widget_id` and has called
     `watchPublicData()`: one message per `widget_id`, at the period the server returns (5–3600 s).
- `openLink` keeps its prompt. A request shows nothing of its own: its `result` is the widget's to show.

### My calls

1. **The vendored policy decides.**
   - `twidget::sdk` from `third-party/widget-sandbox/gesture/` runs inside the runtime: `RequestGate`, `HapticGate`
     with `press`/`release`, `checkWidgetData`, `checkViewer`, `checkChatType`, `checkRequestData`, `checkCopyText`,
     `checkRequestAnswer`, `allowedInPreview` and `PRIVILEGED_METHODS`.
   - The runtime's own haptic bucket (`HostState::admitHaptic`) goes.
   - Precedent: v0.1.2 took `gesture_policy` and v0.1.3 `checkResizeAnchor`, both shared decision tables pinned by
     upstream's fixtures. "Never a reference to port" still holds for the rest of widget-sandbox.
   - The gates read the step's `now`, handed in by the host as `admitHaptic` does today (§6).
2. **State is stored as bytes.**
   - `chat_data` and `public_data` stay `Data` from the TL to the runtime.
   - The runtime decodes them strictly (the policy's `wellFormed`), so text that is not UTF-8 is `data-rejected`.
   - Never `String(decoding:)`, which would swap in U+FFFD and hide the rejection.
3. **Polled shared state is kept with the messages it reached.**
   - When a poll brings a new hash, each on-screen message with that `widget_id` gets the new `public_data` written
     into its stored media, the way `updateMessageWidgetData` writes it. That satisfies sdk-v1 §5.11's "keep the state
     with the message", and the widgets get it through the same no-restart path.
   - An in-memory table per account keeps, per `widget_id`, the last hash, period and next poll.
   - The widget media gets no `MediaId`.
4. **The first poll is immediate.**
   - A `widget_id` starts polling as soon as one of its widgets watches while on screen, with the last hash or 0.
   - After that it polls after each answer's period (30 s until the first answer).
   - One visible, watching carrier per id; another takes over when it leaves; polling stops when none is left.
   - Upstream does not say (discrepancy list, §8).
5. **Server errors follow the tag**:
   - `WIDGET_RESPONSE_TIMEOUT` → timeout;
   - `FLOOD_WAIT_*` → rate limited;
   - everything else → failed, `WIDGET_QUERY_NOT_ALLOWED` included (sdk-v1 §5.11; the policy has no "not allowed"
     failure). The maintainer's notes map it to `NOT_ALLOWED` (§8).
   - A request still without an outcome after 30 s completes as failed. The server's own limit is 15 s; ours keeps a
     lost connection from leaving the gate busy forever.
6. **`copyText` honours copy protection**, as the widget's text selection does. Where the chat forbids copying, nothing
   is copied and the chat's usual "copying is restricted" toast shows. Elsewhere the text goes to the pasteboard and the
   `.copy(text:)` toast shows it (`UndoOverlayController`).
7. **The network marker** is a small glyph in the bubble's date/status area, beside the time, as the edited and
   views marks sit. Tapping it shows a tooltip such as "This widget can send data to @bot when you tap it". The exact
   look and wording are for the user to check against `visual/sdk/21-network-marker`.
8. **Forwards keep their header.**
   - A widget message keeps its forward header in the local echo and in the forward preview when "hide sender names"
     is on, as dice already do (`ChatControllerNode`'s `hasDice`, `EnqueueMessage`'s hide-names path).
   - The toggle stays for the rest of a mixed selection.
9. **Debug insertion carries state.**
   - The DEBUG conformance insertion gives local messages their post's `message` spec (flags and state), so they render
     with it.
   - Their requests complete as failed (a local id means nothing to the server), and nothing polls them.
10. **A context change is a new widget; a state change is not.** The registry key gains the context: the three flags,
    whether the message is a forward or a preview, the chat type and the viewer. The state stays out of the key.
    - Upstream fixes a host's context at creation, and a sent inline result is a new host (sdk-v1 §2.16).
    - A forward's local echo starts conservatively: a copy with no `can_query`, no `background_query` and no chat
      state. A live copy's `can_query` depends on `fwd_allow_queries`, which the client cannot see.
    - When the server's message replaces the echo with other flags, the widget restarts once.
    - A W3 inline result's echo is a preview-free widget with the result's state and no queries, restarted the same
      way.
    - This replaces "the echo copies the source's media unchanged" (`EnqueueMessage`) for widgets only. Their
      storage still follows the message's id, as the guide describes.

## 5. The work, in milestones

Each milestone gets its own plan and is executed test-first. It ends with a whole-branch review on the most capable
model and a review of that review's fix wave, and leaves a carry-over file (v0.1.0 spec §5).

**W1 — What conformance can prove.**
- **Re-vendor `v0.2.2`** per `third-party/widget-sandbox/VENDOR.md`.
  - New: `corpus/interactive/`, the six new attacks, the conformance cases and READMEs, the new `sdk-policy.json`, and
    `sdk_policy.{h,cpp}`. The gesture policy, `json.h`, the Intl fixture and glue are byte-identical.
  - Regenerate the profile tables. `tables` is unchanged, so the output should be too; confirm it.
  - Update every pinned count: auto 41→51, `visual/sdk` 18→26, posts 82→102, features 257→267, attacks 100→106;
    verify each at vendoring.
  - Update VENDOR.md, the folder lists, and `ConformanceRunFile`'s framework/commit.
  - Port `gesture/SdkPolicyTests.cpp` to the new fixture. Today L97's resize-only assertion and the `hapticGate` loop
    fail on it. Upstream's `packages/desktop/tests/test_main.cpp` covers every section.
- **The runtime's SDK** (`TelegramWidget`, `HostState`, the IDL):
  - The new members:
    - `chatData`, `publicData`: frozen, cached per data generation;
    - `isForward`, `chatType`, `viewer` (frozen), `isPreview`;
    - events `chatDataChanged` then `publicDataChanged`, only for what changed, in one task;
    - `request(data)` → a promise;
    - `copyText(text)`;
    - `watchPublicData()` / `unwatchPublicData()`.
  - **Context and state at boot**, through pre-boot setters, as locale and storage are passed today.
  - **`setData` after boot** follows the theme's path: store, bump a generation, queue the event task.
  - **Requests settle later:**
    - a pending promise per id (1…2^31−1);
    - a bridge call `request [id, data]` once the gate admits it;
    - a new `WRSession` entry that completes an id with a result or a failure, queuing the task that settles it;
    - `checkRequestAnswer` decides `INVALID_ANSWER`.
    - The gate's `show()` runs on every hidden → visible change, and `finish()` when an outcome reaches the widget.
  - **`copyText`** joins the one-tap privileged calls.
  - **`watchPublicData [on]`** goes out on changes only.
  - **Preview mode:**
    - no input;
    - every bridge call but `ready` and `setResizeAnchor` refused with `preview-blocked`;
    - no storage preload or commits;
    - no haptics, viewer or chat type.
  - **The haptic gate's press and release** come from the trusted touch path: the primary press's begin
    (`TapState::runDown`) and its end or cancel (`runUp`, `runCancel`).
  - **Diagnostics:** `request-blocked`, `answer-rejected`, `data-rejected`, `preview-blocked`, `haptic-limit`, each
    capped as upstream caps it.
  - **Check one more v0.2.0 note:** the element-scope fix ("Element members stay their element's": an inline
    `onclick="reset()"` must not resolve to the form's `reset`).
- **The facade** (`MessageWidgetCore`, `MessageWidgetInstance`, `MessageWidgetRegistry`):
  - Context and data go in at creation. `setData` and `answerRequest(id, outcome)` are added.
  - `BridgeCall` gains `.request(id, data)`, `.copyText(text)` and `.watchPublicData(on)`.
  - The instance exposes whether it is effectively visible and whether it watches.
  - **The context joins the registry key; the state never does** (§4, call 10), so a state change never restarts a
    widget.
- **TelegramCore's model.** `TelegramMediaWidget` gains:
  - `isCopy`, `canQuery`, `backgroundQuery`;
  - `chatData`, `publicData` as `Data?`;
  - `widgetId`.

  It also needs new Postbox keys (old messages decode with none set), equality over every field, and the parse in
  `StoreMessage_Telegram`.
- **The bubble:**
  - Builds the context from the message:
    - the flags as they are;
    - `chatType` from the chat peer: user → private, basic group → group, megagroup → supergroup, broadcast → channel;
    - `viewer` from the account's own `TelegramUser` (id, names, username, premium), passed for every message (the
      runtime strips it where it does not apply);
    - the state from the media.
  - Turns an update that changes only a widget's state into `setData`.
  - Shows the network marker (§4, call 7) and handles `copyText` (§4, call 6).
  - Until W2, a request completes as failed and nothing polls.
- **The conformance runner** (`Tests/WidgetHarness`):
  - Reads each test's `message` and `bot`.
  - Starts the instance with the first spec's kind flags (`WIDGET_MESSAGE_KINDS`), its state and a fixed test viewer.
    Tests without `message` run as a private chat with no state.
  - Answers requests from the `bot` table by exact `data` (`result`, `edit`, `editShared`, `repeat`, the `{n}` /
    `{from}` / `{time}` templates).
  - Records accepted haptics in `observed.bridge` (case 27).
  - Moves the baseline per the ratchet.
- **Docs in the same milestone:**
  - the guide's "No network, ever" rewritten to §4.A;
  - the runtime record;
  - the harness guide;
  - the v0.1.0 spec's §11 pointer.
- **Unit tests besides conformance:**
  - TelegramCore: the media's coding and equality with old data;
  - the registry: no restart on a state-only edit;
  - the context from each kind of chat and message.

**W2 — The network.**
- **Requests:**
  - `engine.messages` gains the `getBotWidgetQueryAnswer` call (the peer, the message id in the user's coordinates,
    `data` as bytes) with §4's error mapping; unit tests on the mapping.
  - The bubble sends each request with its own disposable: one per request id, as `AccountViewTracker`'s
    `DisposableDict` does. This avoids `ChatController`'s single callback-query disposable and its swallowed errors.
  - The 30 s guard; the request is cancelled when its widget goes away.
- **State updates:**
  - `updateMessageWidgetData` in the common pts box (`apiUpdatePtsRange`, the interpreter, a mutation and its replay,
    `StateReplayBatching`). An absent field is unchanged and an empty one clears it.
  - Supergroups' state edits come as ordinary channel edits and already land through W1's model.
  - State/CLAUDE.md's obligations: `docs/state-sync.md` in the same commit, `Tests/StateSync` cases, and the
    truth-server runs it names.
- **The shared-state poller** (§4, calls 3 and 4):
  - widgets register while visible and watching;
  - one carrier per `widget_id`;
  - a not-modified answer changes only the timing;
  - the period is clamped to 5–3600 s;
  - nothing polls off screen.
  - Unit tests for carrier hand-over, visibility, the period and a not-modified answer.
- **Forwards** (§4, call 8), unit-tested on the local echo.

**W3 — Inline previews.**
- `ChatContextResultMessage` gains a widget case. It is a persisted enum, so it also needs its coding. The case replaces
  today's placeholder mapping to an empty `.auto`.
- The results lists draw such a result as a widget in preview mode, which runs the vendored preview filter; a tap
  selects the result.
- The outgoing local echo carries the widget (§4, call 10), so the pending message shows it until the server's
  replaces it.
- Upstream says the server's shape for a widget inline result is untested.
- **Our TL's field order is the server's.** `botInlineMessageWidget#f1851c7e` puts `reply_markup` (flag 2) before
  `widget_id` (flag 3). Its constructor id checks out by CRC32; upstream's `tgw-format.md` order would be `3983e831`
  (§8).

**All three milestones are in scope** (the user's decision 5). *(My call:)* nothing is merged before W2 is done. Alone,
W1 would show the marker on messages whose every request fails, and private chats and basic groups would get no live
state edits. W1 and W2 go to master together, W3 after them or with them, each merge asked for as usual.

## 6. Constraints

- **Security:** see the anti-goals and §4.A. A widget's text never reaches a URL, and `request` data and `copyText` text
  are bounded by the policy (64 bytes, 256 UTF-16 units).
- **Determinism:** every limit on a widget's JS is still a budget of work (the guide's "no rate limits" means none on
  CPU). The request and haptic gates are bridge-call policies over the step's host-given `now`, as `admitHaptic` is;
  no new clock enters the runtime.
- **Widgets exist only where the bubble lays out on main.** The inline results panels are `ListViewImpl` lists, which
  lay out off main except in a `.Synchronous` transaction. W3's preview cell therefore needs:
  - a main-thread point to boot and query the widget;
  - a placeholder height from the anchors until then.
- **TelegramCore:**
  - no UIKit;
  - only TelegramCore imports TelegramApi;
  - new consumer code reaches the model through engine types (the Postbox refactor's rules);
  - state sync never gives up on an error (State/CLAUDE.md).
- **widget-sandbox is read-only.** Files are vendored from the tag, never the working tree.
- **Process:**
  - the controller runs every Bazel build; subagents never build;
  - commit locally, never push or merge without asking;
  - the standing simulator rules apply: harness work on K1, never K3.
- **Coordination:** `widgets/v9` (rendering, another session) is in flight. The code is disjoint, but
  `MessageWidget/CLAUDE.md` and the runtime record will conflict. Rebase onto master when it lands.

## 7. Left to the builder

- Type, member and Postbox key names; where the context is derived (bubble or a helper); the test viewer's values.
- How the runtime holds pending requests (`PromiseSlot` or its own table).
- The runner's internals within CLIENTS.md, including how `editShared` and `repeat` are timed in a Tier 1 run.
- Where the poller lives (a TelegramCore tracker beside `AccountViewTracker`, or app-side), within §4's rules.
- The order inside each milestone.

## 8. Discrepancies to send upstream

1. `WIDGET_QUERY_NOT_ALLOWED`: sdk-v1 §5.11 maps it to `failed`; the maintainer's notes to `NOT_ALLOWED`.
2. The first poll's timing is unspecified (`integration.md`, `tgw-format.md`).
3. `protocol.md` is stale in three places:
   - `onRequest({data, background})`: the hosts pass `data` only;
   - its config table lacks `backgroundQuery` and `isPreview`;
   - its touch section predates v0.1.2.
4. `client-checklist.md` still says v0.1.0, and its §d calls the viewer "the account's user id" where §2.13 and I1
   require the full `WebAppUser`.
5. `integration.md` leaves `channel` out of `chatType` and has stale case counts.
6. TL `bytes` against "text": the docs should say a client must decode strictly.
7. The Intl glue's trap on a locale with a unicode extension is still there (VENDOR.md).
8. `tgw-format.md` line 24 swaps `botInlineMessageWidget`'s last two fields. The server's `#f1851c7e` is
   `reply_markup:flags.2?ReplyMarkup widget_id:flags.3?long`.
9. `auto/26-context-*`'s check "TelegramWidget exists" is published only when the SDK is missing (`if (!TW) return
   T.ok(…, false, …)`), while the manifest expects it. A conforming client therefore always reports it `missing`.
