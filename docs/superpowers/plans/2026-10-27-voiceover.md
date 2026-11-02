# VoiceOver Pass (everything except the chat screen) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Every visible meaningful element on every screen outside the chat screen is exposed to VoiceOver with the
right label, traits, value and activation, in a sensible order, and nothing invisible is exposed.

**Architecture:** First the tooling (an AXe-based capture + audit script and a debug-only "VoiceOver is running"
override), then infrastructure (ASDK container forwarding re-enabled with a rewritten collector, a ComponentFlow
accessibility convention, the tab bar), then a screen-by-screen sweep using one fixed procedure, recorded in an
inventory.

**Tech Stack:** Swift, Objective-C (AsyncDisplayKit), ComponentFlow, Bazel via `Make.py`, AXe 1.8.0, Python 3 for
the audit script, XCTest (`ios_unit_test`).

**Spec:** `docs/superpowers/specs/2026-10-27-voiceover-design.md`

## Global Constraints

- Branch `accessibility`; one PR at the end. Never stage `submodules/WalletContext/Sources/WalletTonConnect.swift`.
- No visual or behavioural change for sighted users; no cost when no accessibility client is active.
- A label is exactly the string the element already shows (same key the UI uses). Only an element with no text of its
  own gets a new key `VoiceOver.<Area>.<Name>` in `Telegram/Telegram-iOS/en.lproj/Localizable.strings`; English only.
- All comparisons are made with the VoiceOver override on (Task 2).
- The chat screen must not get worse; regressions there are fixed by opting chat nodes out of the new collector, not
  by working on the chat screen.
- Logged-in simulator: iPhone 17 Pro `EA95FB21-AE07-4325-B995-943D36E889C6`. Anything may be done on the account;
  **messages are sent only to "John Telegram"**; purchase sheets are opened, never confirmed.
- Logged-out screens: `--ui-test` on iPhone 17 Pro Max `E5E21C20-6660-4019-BC32-D7BE43F2C492` only.
- AXe: `~/.local/opt/axe/axe` (`~/.local/bin/axe`). Build/install: root `CLAUDE.md` (whole-`.app` copy, with the
  UDIDs above instead of K3).

## Review Focus

1. **Lists longer than the screen**: VoiceOver must still reach row N+1 by swiping past the last visible row
   (ListView's `accessibilityScroll`/focus code at `ListView.swift:5434-5510`) after off-screen rows leave the tree.
   Pinned in Task 3 (`testListViewExposesOnlyVisibleRows`, `testListViewAccessibilityScrollStillForwarded`).
2. **Pagers** (chat list folders, peer-info media tabs, story viewer): only the current page is exposed, also mid-swipe
   and right after switching. Pinned in Task 3 (`testOffscreenPagerPageIsExcluded`) and checked in Tasks 9, 13, 15.
3. **Elements that appear later** (banners, badges, search results, loading → loaded): the tree updates without a
   stale cached list. Pinned in Task 3 (`testCacheInvalidatesNextRunLoopTurn`).
4. **Light/dark theme and RTL language**: labels and order do not depend on theme; in an RTL language the order runs
   trailing to leading like the screen. Checked once in Task 9 (Hebrew/Arabic and dark theme on the chat list).
5. **Edit / selection modes** (chat list edit, contacts selection, member pickers): selected state is a value or the
   `.selected` trait, not only a checkmark image. Checked in Tasks 9, 10, 15.

---

## Screen sweep procedure (used by Tasks 9–17)

For each screen of the task's group:

1. Navigate there on the right simulator (taps by coordinate, deep links via `xcrun simctl openurl`), app launched
   with the VoiceOver override.
2. `tools/accessibility/capture.sh <udid> <screen-id>` → `build/accessibility/<screen-id>/{screen.png,tree.json,report.txt}`.
3. Compare `report.txt` and `screen.png` against the spec's Goals: every visible meaningful element present, label,
   traits, value, order; nothing invisible; mechanical flags from the audit all resolved or justified.
4. Fix in code (prefer the component level — Tasks 5–8 — over per-screen fixes when the same component is wrong in
   several places), rebuild, reinstall, capture again until clean.
5. Record the screen in `docs/accessibility/voiceover-inventory.md`: screen id, how to reach it, status
   (`clean` / `justified: <reason>`), files changed.
6. Commit per screen group: `fix(a11y): <group> — VoiceOver labels, traits and order`.

`build/accessibility/` is git-ignored output.

---

### Task 1: Capture and audit tooling, inventory skeleton

**Files:**
- Create: `tools/accessibility/axaudit.py`, `tools/accessibility/capture.sh`, `tools/accessibility/tests/test_axaudit.py`,
  `tools/accessibility/tests/fixtures/chatlist-before.json` (copy of today's chat list dump),
  `docs/accessibility/voiceover-inventory.md`
- Modify: `.gitignore` (add `build/accessibility/`)

**Interfaces:**
- Produces: `python3 tools/accessibility/axaudit.py <tree.json> [--screen WxH]` printing one line per meaningful
  element (`type | label | value | traits | frame`) and then `FLAG <kind> <element>` lines; exit code 0 always.
  Flag kinds: `unlabelled-interactive`, `offscreen`, `zero-size`, `duplicate`, `bare-image`, `bare-text-in-control`.
  `capture.sh <udid> <screen-id>` writes `screen.png` (via `xcrun simctl io <udid> screenshot`), `tree.json` (AXe
  `describe-ui`) and `report.txt` (audit output) under `build/accessibility/<screen-id>/`.

- [ ] **Step 1: Write failing tests** in `test_axaudit.py` against the fixture:
  - `test_flags_unlabelled_buttons`: the Button at frame `16,64 55x44` and at `75,57 207x44` are flagged `unlabelled-interactive`.
  - `test_flags_offscreen_rows`: the row labelled `Test Channel 3` at y=1455 and the row at x=402 are `offscreen` for screen `402x874`.
  - `test_flags_duplicates`: the tab bar images at y=791 (same type+label+frame twice) are `duplicate`.
  - `test_ignores_scroll_bars`: no output line mentions `scroll bar`.
  - `test_labelled_row_not_flagged`: `John Telegram` produces no FLAG.
- [ ] **Step 2:** `python3 -m unittest discover -s tools/accessibility/tests` → FAIL (module missing).
- [ ] **Step 3:** Implement `axaudit.py` (default screen size read from the root Application frame) and `capture.sh`.
- [ ] **Step 4:** Tests pass; run `capture.sh EA95FB21-AE07-4325-B995-943D36E889C6 chatlist` on the live app, report
  lists the flags above.
- [ ] **Step 5:** Inventory skeleton: one section per screen group of Tasks 9–17 with the screen list from the spec's
  Scope, every screen `pending`; a "Borderline (chat-adjacent)" section.
- [ ] **Step 6:** Commit `chore(a11y): AXe capture and audit tooling, VoiceOver inventory`.

### Task 2: Debug-only VoiceOver override

**Files:**
- Modify: `submodules/Display/Source/Accessibility.swift`, `submodules/Display/Source/WindowContent.swift:504,840-842`,
  `submodules/Display/Source/NativeWindowHostView.swift:190`,
  `submodules/LegacyComponents/Sources/TGMediaAssetsPickerController.m:401`

**Interfaces:**
- Produces: `public var isVoiceOverRunningForLayout: Bool` (Display, free function-style global computed var):
  `UIAccessibility.isVoiceOverRunning || forced`, where `forced` is
  `CommandLine.arguments.contains("--force-voiceover-layout")` inside `#if DEBUG` and `false` otherwise.
  Every former `UIAccessibility.isVoiceOverRunning` read in Display uses it. The ObjC site uses the same argument
  under `#ifdef DEBUG` via `NSProcessInfo.processInfo.arguments`.
- Launch: `xcrun simctl launch <udid> ph.telegra.Telegraph --force-voiceover-layout`.

- [ ] **Step 1:** Before the change: capture `contacts` with a plain launch (baseline).
- [ ] **Step 2:** Implement; confirm `-DDEBUG` reaches both Swift (`-c dbg`) and ObjC targets in `debug_sim_arm64`
  (if ObjC lacks it, gate on a `#if DEBUG`-only Swift helper exported to ObjC, never on a runtime-only check).
- [ ] **Step 3:** Build (`Make.py build`, `debug_sim_arm64`), install, launch with the argument, capture `contacts`
  again: the sort control/order differs per `ContactsController.swift:269-271`. Launch without it: identical to
  Step 1.
- [ ] **Step 4:** `release_sim_arm64` build: `nm` / `strings` of `TelegramUIFramework` and the app binary do not
  contain `--force-voiceover-layout`.
- [ ] **Step 5:** Commit `feat(a11y): debug-only VoiceOver layout override for automated checks`.

### Task 3: Rewritten ASDK accessibility collector

**Files:**
- Modify: `submodules/AsyncDisplayKit/Source/_ASDisplayViewAccessiblity.mm`,
  `submodules/AsyncDisplayKit/Source/ASDisplayNode.h` (+ its accessibility category / ivar storage)
- Create: `submodules/Display/Tests/AccessibilityCollectorTests.swift`; test targets in `submodules/Display/BUILD`
  (`DisplayAccessibilityTests`, runner `iPhone 17` / `26.5`, pattern from `submodules/TextFormat/BUILD:47-60`)

**Interfaces:**
- Produces: `@property (nonatomic) BOOL accessibilityUsesViewElements;` on `ASDisplayNode` (default `NO`). When `YES`,
  that node's view returns `[super accessibilityElements]` (today's behaviour) for itself and its subtree.
- `-[_ASDisplayView accessibilityElements]` forwards to the node again (node overrides are used as-is, unsorted).
- The default collector (`CollectAccessibilityElementsForView` and friends) keeps its frame sort for auto-collected
  elements and adds:
  - exclusion of nodes/views that are hidden, `alpha < 0.01`, zero-size, or whose frame does not intersect the
    visible bounds of the nearest clipping ancestor (`clipsToBounds` view or scroll view) and the window;
  - a cache per view, valid for one main run loop turn (a global generation counter bumped by a
    `kCFRunLoopBeforeWaiting` observer installed on first use), so `accessibilityElementCount` /
    `accessibilityElementAtIndex:` / `indexOfAccessibilityElement:` and nested queries reuse one walk.
- `setAccessibilityElements:` stores and returns an explicitly set array again.

- [ ] **Step 1: Chat baseline.** Before any change, capture five chats (text, media, stickers + service message,
  channel post, a group with the input panel open) as `chat-baseline-<n>`; keep them under
  `build/accessibility/` for Task 4. Time `axe describe-ui` on the chat list three times.
- [ ] **Step 2: Failing tests** (`AccessibilityCollectorTests`), each building a small node tree in a window:
  - `testNodeOverrideIsForwarded`: a node overriding `accessibilityElements` with `[b, a]` → its view returns `[b, a]`.
  - `testHiddenAndTransparentSubnodesExcluded`: labelled subnodes with `isHidden`, `alpha = 0`, zero size → absent.
  - `testOffscreenPagerPageIsExcluded`: a clipping container 400 wide with pages at x=0 and x=400 → only page 0 labels.
  - `testListViewExposesOnlyVisibleRows`: a `ListView` 400x300 with 20 rows of 76 → exposed rows are exactly those
    intersecting the visible bounds.
  - `testLayerBackedLabelledNodeBecomesElement`: layer-backed node with a label → one `UIAccessibilityElement` with
    its label and screen frame.
  - `testCacheInvalidatesNextRunLoopTurn`: add a labelled subnode after a query; same turn → old list; after one
    run loop spin → includes it.
  - `testOptOutKeepsViewElements`: `accessibilityUsesViewElements = YES` → equals `UIView`'s default for the view.
  - `testListViewAccessibilityScrollStillForwarded`: after the change, `accessibilityScroll(.down)` on the ListView's
    view still scrolls by a page (Review Focus 1: the next rows become visible and enter the tree).
  - `testPlainUIViewChildrenKept`: a plain `UIButton` with a label inside a node → present.
- [ ] **Step 3:** `Make.py test --target //submodules/Display:DisplayAccessibilityTests` → FAIL.
- [ ] **Step 4:** Implement.
- [ ] **Step 5:** Tests pass.
- [ ] **Step 6:** Build, install; capture `chatlist`: rows beyond y=874 and the x=402 row are gone; Edit/title
  still flagged (fixed later). Time `describe-ui` three times: not slower than Step 1 by more than 20%.
  XCUITest (spec anti-goal): if `iOSAppUITestSuite` runs per `docs/ui-testing.md`, run it before (Step 1) and after,
  compare duration and results; if it cannot run in this environment, record that in the inventory.
- [ ] **Step 7:** Commit `fix(a11y): re-enable ASDK accessibility forwarding with a bounded, visibility-aware collector`.

### Task 4: Chat screen non-regression

**Files:**
- Modify (only if needed): the chat screen's root node(s), e.g. `submodules/TelegramUI/Sources/ChatControllerNode.swift`,
  setting `accessibilityUsesViewElements = true` on the narrowest subtree that regressed.

- [ ] **Step 1:** Capture the five chats from Task 3 Step 1 again as `chat-after-<n>`.
- [ ] **Step 2:** Diff each pair (labels, values, traits, order, count). Regression = an element lost, a label lost,
  order changed for the worse, duplicates added. Improvements (fewer off-screen elements) are fine.
- [ ] **Step 3:** For each regression, opt the narrowest subtree out; recapture until no regression remains.
- [ ] **Step 4:** Record the comparison (what changed, what was opted out) in the inventory's "Chat non-regression"
  section. Commit `fix(a11y): keep the chat screen's accessibility tree unchanged`.

### Task 5: ComponentFlow accessibility convention

**Files:**
- Create: `submodules/ComponentFlow/Source/Base/ComponentAccessibility.swift`
- Modify: `submodules/ComponentFlow/Source/Components/Button.swift`,
  `submodules/TelegramUI/Components/PlainButtonComponent/Sources/PlainButtonComponent.swift`,
  `submodules/TelegramUI/Components/ButtonComponent/Sources/ButtonComponent.swift`,
  `submodules/TelegramUI/Components/GlassBarButtonComponent/Sources/GlassBarButtonComponent.swift`
- Test: `submodules/ComponentFlow/Tests/ComponentAccessibilityTests.swift` (+ `ComponentFlowTests` target in its BUILD)

**Interfaces:**
- Produces:
  ```swift
  public struct ComponentAccessibility: Equatable {
      public var label: String?
      public var value: String?
      public var hint: String?
      public var traits: UIAccessibilityTraits
      public var isHidden: Bool   // true: not an element, children hidden too
      public init(label: String? = nil, value: String? = nil, hint: String? = nil, traits: UIAccessibilityTraits = [], isHidden: Bool = false)
  }
  extension UIView { public func apply(accessibility: ComponentAccessibility?, defaultTraits: UIAccessibilityTraits) }
  ```
  Each of the four button components gains `accessibility: ComponentAccessibility? = nil` as the last init parameter
  (part of `==`). With `nil`: `ButtonComponent` derives the label from its title content's text; the others stay
  unlabelled (the audit flags them; call sites fix them). Always `.button` (+ `.notEnabled` when disabled).
  Decorative content inside a labelled button is not separately exposed.

- [ ] **Step 1: Failing tests:** `testButtonAppliesLabelAndButtonTrait`, `testDisabledButtonHasNotEnabledTrait`,
  `testHiddenAccessibilityRemovesElement`, `testButtonComponentDerivesLabelFromTitle`,
  `testLabelledButtonHidesInnerTextElements`.
- [ ] **Step 2:** Run target → FAIL. **Step 3:** Implement. **Step 4:** PASS.
- [ ] **Step 5:** Full build (`--continueOnError`): the new defaulted parameter must not break call sites.
- [ ] **Step 6:** Commit `feat(a11y): ComponentAccessibility for ComponentFlow buttons`.

### Task 6: List components (ListActionItem / ListSection / ListSwitchItem and kin)

**Files:**
- Modify: `submodules/TelegramUI/Components/ListActionItemComponent`, `ListSectionComponent`,
  `ListSwitchItemComponent` (and other `List*ItemComponent` modules the sweep shows on in-scope screens)
- Test: add cases to `ComponentAccessibilityTests` or a per-module test target if the module pulls in strings

**Interfaces:**
- Consumes: `ComponentAccessibility` (Task 5).
- Produces: a list row is one element: label = title (+ subtitle), value = trailing value/switch state, traits
  `.button` when it has an action, switches expose on/off via `VoiceOver_Common_On/Off` and activate toggles.
  Section headers/footers get `.header` / static text.

- [ ] Steps: failing tests `testActionRowIsSingleButtonElement`, `testSwitchRowValueAndActivate`,
  `testSectionHeaderTrait` → implement → pass → build → capture one ListAction-based settings screen → commit
  `feat(a11y): list item components expose one element per row`.

### Task 7: Selectors and tabs (TabSelector / HorizontalTabs / segmented)

**Files:** `submodules/TelegramUI/Components/TabSelectorComponent`, `HorizontalTabsComponent` (and the chat list
folder tabs' component found by the sweep)

**Interfaces:** each tab is a button element with its title as label, `.selected` on the current one, badge as
value (e.g. "267 unread" via an existing unread-count string; new key only if none exists); container trait
`.tabBar` on the strip.

- [ ] Steps: failing test `testTabsExposeSelectedTrait` → implement → pass → build → capture `chatlist` (All / Forums /
  Unread present, Unread value carries 267) → commit `feat(a11y): tab selectors`.

### Task 8: Tab bar

**Files:** `submodules/TelegramUI/Components/TabBarComponent/Sources/TabBarComponent.swift` (`View`, `ItemComponent.View`,
`TabBarBadgeView`)

**Interfaces:** bar view `accessibilityTraits = .tabBar`, exposed once; each item a button with the tab title,
`.selected` on the current; badge as value (count → existing unread string; `!` → new key
`VoiceOver.TabBar.AttentionRequired` only if no existing string fits); activation selects the tab (same path as
the tap gesture); the search item labelled with its existing string.

- [ ] Steps: capture `chatlist` (baseline flags) → implement → build → capture: five tab buttons, no duplicate,
  Chats `.selected` with value, Settings value for `!` → commit `fix(a11y): tab bar items are labelled tabs`.

### Task 9: Sweep — Chats tab root

Screens: chat list (all folders), folder tabs, banners (premium, suggestions) and their close buttons, stories strip,
search (empty, typing, results by category), edit mode and selection, archive, header buttons (Edit, title/status,
Add Story, New Message), proxy/connection status in the title. Procedure above. Also run the Review Focus checks:
dark theme and an RTL language (Hebrew) on the chat list.

### Task 10: Sweep — Contacts and Calls

Contacts list (sort, invite, add contact, search, selection), add-contact screen, Calls list (all/missed, edit,
call info, delete action as a custom action).

### Task 11: Sweep — Settings root and first level

Settings root (header, avatar, name, account switcher, every row), Edit profile, Saved Messages entry point,
Recent Calls, Devices, Chat Folders, Notifications, Privacy and Security, Data and Storage, Appearance, Power
Saving, Language, Stickers and Emoji, Ask a Question / FAQ / Features.

### Task 12: Sweep — Settings deep levels

Every sub-screen under the Task 11 screens (privacy rule editors with exception lists, passcode settings, 2FA
settings, blocked users, active sessions detail, auto-download, storage usage with its chart, proxy settings and
add proxy, theme editor and accent picker, text size, app icon, folder editor, notification exceptions, sound
picker, language list).

### Task 13: Sweep — Premium, Stars, Business, Wallet

Premium intro and feature pages (pager — Review Focus 2), gift Premium, Stars balance/transactions/top-up sheet
(opened, never confirmed), Business settings and their sub-screens, wallet screens.

### Task 14: Sweep — Peer profiles

User, bot, group, channel, forum profiles: header (avatar, name, status, action buttons), info rows, shared media
tabs (pager), members list, admins, permissions, edit screens, invite links. Any profile opened from a chat counts.

### Task 15: Sweep — Creation flows, pickers, share, QR

New message/compose, new group (member picker with selection state — Review Focus 5), new channel, new secret chat,
contact/peer pickers, share sheet, QR code screens, global search outside the chat list if separate.
Messages sent while exercising these flows go only to John Telegram.

### Task 16: Sweep — Stories

Stories strip states, the story viewer (pager between peers and stories — Review Focus 2; progress, author header,
reply field, reactions, more menu), own story viewers list, the posting camera/editor entry screens.

### Task 17: Sweep — Logged-out flows and passcode (iPhone 17 Pro Max, `--ui-test`)

Install the same build on `E5E21C20-6660-4019-BC32-D7BE43F2C492`; launch with `--ui-test --force-voiceover-layout`.
Welcome/intro pager, phone entry with country picker, code entry, 2FA password, sign-up name/photo, terms.
Passcode setup and the lock screen (set a passcode on the logged-in simulator, check, remove).

### Task 18: Final verification and PR

- [ ] `Make.py build --continueOnError` (`debug_sim_arm64`) and a `release_sim_arm64` build both succeed.
- [ ] `Make.py test --target //submodules/Display:DisplayAccessibilityTests`, the ComponentFlow tests, and the
  unit-test targets of touched modules (root `CLAUDE.md` list) pass.
- [ ] `python3 -m unittest discover -s tools/accessibility/tests` and `python3 -m unittest discover -s build-system/Make/tests` pass.
- [ ] Recapture the five chats once more: still no regression against the baseline.
- [ ] Inventory: no `pending` screens; every `justified` has a reason.
- [ ] `docs/accessibility/voiceover-inventory.md` gets a short "How to check a screen" section (capture script, override
  flag, simulators); add a pointer line to the root `CLAUDE.md` "Smaller ones" guide list.
- [ ] Push `accessibility`, open one PR against `master` summarising infrastructure, components and the inventory.
