# VoiceOver pass over the app (everything except the chat screen)

## Intent

VoiceOver support in the app was once reasonable and has decayed: many elements are unlabelled, whole controls are
missing from the accessibility tree, and invisible content leaks into it. The goal is a complete, systematic pass over
every screen outside the chat screen, comparing what is visible with what VoiceOver exposes, and fixing every
difference. Infrastructure is fixed first so that most screens improve at once; then each screen is checked and fixed
individually.

The verification is automated: a screenshot of the screen against an accessibility-tree dump of the same screen
(AXe, see "Verification"). Nobody listens with a real VoiceOver on a device as part of this work.

## What is wrong today (recon, 2026-10-27)

- **ASDK container forwarding is off.** `bb30f5c1ea` "Disable ASDK accessibility" (Feb 2026) made
  `-[_ASDisplayView accessibilityElements]` return `super` and turned `setAccessibilityElements:` into a no-op
  (`submodules/AsyncDisplayKit/Source/_ASDisplayViewAccessiblity.mm:314-331`). Simple properties (label, value,
  traits, `isAccessibilityElement`) still reach VoiceOver for view-backed nodes; node-level `accessibilityElements`
  overrides (e.g. `NavigationBarNode`'s ordered back/title/trailing list) and layer-backed accessible nodes are dead.
  The author does not remember why. The likely reason (inferred, not established) is XCUITest work started three
  days later (`9988158f83`, `docs/ui-testing.md`): the collector `CollectAccessibilityElementsForView` re-walks the
  whole subtree on every call with no caching, calls `accessibilityElementCount` recursively per child (quadratic),
  does not skip hidden/alpha-0/off-screen nodes, and re-sorts elements by frame (`SortAccessibilityElements`),
  overriding any authored order.
- **ComponentFlow and the "glass" components expose nothing.** No accessibility code in `ComponentFlow`,
  `ButtonComponent`, `PlainButtonComponent` (focusable, unlabelled), `GlassBarButtonComponent`,
  `ListActionItemComponent`, `ListSectionComponent`, `ListSwitchItemComponent`, `HorizontalTabsComponent`,
  `TabSelectorComponent`, `StoryPeerListComponent`, `ChatListHeaderComponent`, … The live tab bar is now
  `TabBarComponent` (`TabBarContollerNode.swift:287`), which has no accessibility; the labelled `TabBarNode` is no
  longer what renders. `NavigationBarComponent` (Oct 2026) is the one well-annotated modern component and is the
  model to follow.
- **Older hand-annotated code mostly works**: ItemListUI rows, `ChatListItem`, `CallListCallItem`, `ContactsPeerItem`.
  Spot gaps: unlocalized `"Selected"` in `ItemListCheckboxItem.swift:291`, missing `.button` on PeerInfo settings
  rows, several ItemList/PeerInfo item types with no accessibility at all.
- **Chat list dump (iPhone 17 Pro, AXe)** as a concrete baseline: Edit and the title are unlabelled buttons; the
  folder tabs (All / Forums / Unread 267) and the premium banner with its close button are absent; the tab bar is five
  unlabelled images plus bare "1" and "!" texts, duplicated twice, with no tab traits; rows far below the screen
  (y up to 1455) and a row from the neighbouring folder page (x = 402) are exposed; chat rows themselves are labelled
  well.

## Goals

1. On every in-scope screen, every visible meaningful element is in the accessibility tree with:
   - a label a user understands, in the interface language;
   - the right traits (button, header, tab/selected, adjustable, static text, image only when the image means
     something) and value/state (selected, on/off, badge counts, progress);
   - working activation (and increment/decrement, custom actions where the sighted UI offers a gesture-only action
     such as swipe-to-delete or long press);
   - a sensible reading order (top to bottom, leading to trailing, navigation bar first, tab bar last).
2. Nothing invisible is in the tree: hidden or alpha-0 views, off-screen list rows beyond what the list's own
   accessibility scrolling needs, neighbouring pages of pagers, decorative images, duplicated subtrees.
3. Infrastructure that makes this the default rather than per-screen work: ASDK forwarding back on (rewritten),
   and an accessibility convention for ComponentFlow / glass components so a component annotated once is right on
   every screen.

## Non-goals

- The chat screen and everything opened from it (see Scope).
- Listening with a real VoiceOver on a device; Voice Control, Switch Control and Full Keyboard Access as separate
  targets (they benefit from the same tree but are not checked).
- Dynamic Type, contrast, reduce-motion work.
- Translating new strings into other languages (the translation platform does that).

## Anti-goals (a failure even if the tree looks right)

- Any visual or behavioural change for sighted users.
- Measurable cost when no accessibility client is active. The rewritten ASDK collector runs only when the
  accessibility system asks for elements.
- Making XCUITest (`docs/ui-testing.md`, `Telegram/Tests/Sources/`) slower or broken: it reads the same tree.
- Inventing a new string when the element already shows a text of its own.

## Scope

In scope, by screen (the screen itself decides, not how it was reached):

- Tab bar and the four/five tab roots: Contacts, Calls, Chats (chat list incl. folder tabs, banners, stories strip,
  search, edit mode, archive), News, Settings.
- The whole Settings tree, every level deep (PeerInfo settings mode, privacy, notifications, data and storage,
  appearance, language, devices, folders, stickers and emoji settings, Premium, Stars, Business, wallet, etc.).
- Contacts flows: add contact, invite, sort, search, nearby/QR.
- Calls list, call info.
- Peer profiles (users, groups, channels, bots) and their sub-screens (members, admins, edit, shared media tabs).
- Creating a group / channel / secret chat, compose (new message) flow.
- Login and onboarding (welcome, phone entry, code, 2FA, sign-up), passcode setup and lock screen.
- Stories: the strip and the story viewer (including its reply/reaction panel), and story-posting camera/editor
  entry points.
- Global search, contact/peer pickers, share sheet, QR screens, proxy settings.

Out of scope: the chat screen (history, input panel, attach menu, message context menus, in-chat search, pinned/top
panels, reactions, gallery opened from a message, sticker/emoji input, polls/todo composition from chat, chat-only
settings sheets). A screen reachable both from chat and from elsewhere (a peer profile, the media gallery from a
profile) is in scope. *(My call: classification by screen; the builder lists borderline screens in the inventory.)*

## Strings

- If the element shows a text of its own (button title, header, label next to it), its accessibility label is
  exactly that string — reuse the key the UI uses, not a similar one.
- Only when the element has no text of its own (icon-only button, badge, meaningful image, state indicator) add a
  new key `VoiceOver.<Area>.<Name>` to `Telegram/Telegram-iOS/en.lproj/Localizable.strings` and regenerate
  `PresentationStrings` the way the project already does. English only; other languages come from the translation
  platform.
- Replace hardcoded English (e.g. `"Selected"` in `ItemListCheckboxItem`) with keys under the same rule.

## Infrastructure decisions

1. **Re-enable ASDK forwarding** in `_ASDisplayViewAccessiblity.mm`, with a rewritten collector:
   - skip hidden, alpha ≈ 0, zero-size and fully clipped/off-screen subtrees (with an exception for list rows that
     `ListView` scrolling needs — the builder decides how many rows ListView exposes, following UIKit's table
     behaviour);
   - keep the node's authored order: a node's own `accessibilityElements` override is used as-is (it bypasses the
     frame sort, which only applies to auto-collected elements and stays);
   - no quadratic re-walk (compute child counts once per collection, cache per accessibility query or invalidate on
     layout);
   - plain UIViews and ComponentFlow views inside a node keep working (they are in the tree today through `super`).
   The new collector must not make the chat screen worse (see Verification), so it has a per-node/per-subtree
   opt-out that keeps today's `super` behaviour.
   The reason it was disabled is unknown, so the builder measures before/after: tree correctness on several screens,
   time of one `describe-ui` and of scrolling a long list with an accessibility client attached, and XCUITest if it
   can be run.
2. **A ComponentFlow / glass accessibility convention**, modelled on `NavigationBarComponent`
   (`NavigationBarItemContent` label → title fallback, back button traits, header trait on titles): base controls
   (`Button`, `PlainButtonComponent`, `ButtonComponent`, `GlassBarButtonComponent`, tab/segment selectors, list
   item components, switches) accept or derive a label, traits and value, so call sites pass a string instead of
   reaching into views. Exact API shape is the builder's.
3. **Tab bar**: `TabBarComponent` exposes each item as a button with the tab title, `.tabBar` container semantics on
   the bar, `.selected` on the current tab, the badge as value ("1 unread", "!" as a labelled attention state), and
   the bar exposed once.

## Verification

- **Check the VoiceOver-on layout.** The app lays out differently when VoiceOver runs:
  `ContainerViewLayout.inVoiceOver` comes from `UIAccessibility.isVoiceOverRunning` (`WindowContent.swift`), ~90 files
  branch on it (Contacts' sort order, chat list, ItemList screens, Premium, …), and a few call
  `UIAccessibilityIsVoiceOverRunning()` directly (`TGMediaAssetsPickerController.m`). The simulator never runs
  VoiceOver, so add a **debug-only override** (compiled out of release builds; a launch argument or Debug Settings
  flag, builder's choice) that makes the app behave as if VoiceOver is running, including the direct checks, and
  posts the same change notifications. All comparisons are made with it on.
- **The chat screen must not get worse.** The collector change is app-wide. Before the collector lands, dump a few
  representative chats (text, media, stickers, service messages, a channel post, the input panel); after, dump them
  again. Any regression there is fixed by keeping the old behaviour for the chat's nodes (a per-node / per-subtree
  opt-out from the new collector), not by working on the chat screen.
- Logged-in simulator: **iPhone 17 Pro**, `EA95FB21-AE07-4325-B995-943D36E889C6`, the user's account. Build and
  install per the root `CLAUDE.md` (whole-`.app` copy; use this UDID instead of K3). Anything may be done on this
  account — create groups, channels, secret chats, post stories, change settings — with one limit: **send messages
  only to "John Telegram"**, to nobody else. Purchase sheets are opened and checked but never confirmed (no real
  money).
- Logged-out screens (welcome, phone, code, 2FA, sign-up) are checked with the `--ui-test` launch argument (isolated
  data, test servers, wiped each launch) on a **separate simulator**, never on the logged-in one. *(My call: iPhone 17
  Pro Max `E5E21C20-6660-4019-BC32-D7BE43F2C492`.)*
- AXe 1.8.0 is installed at `~/.local/opt/axe/axe` (`~/.local/bin/axe`); `axe describe-ui --udid <UDID>` dumps the
  tree as JSON with frames. Navigation: taps by coordinate (AXe `tap -x -y` or the simulator tool), deep links via
  `xcrun simctl openurl`.
- Per screen: screenshot + dump, compared for the goals above; every difference is fixed or recorded with a reason.
  A screen is done when its comparison is clean. Keep a screen inventory with status (doc in `docs/`, updated as the
  pass goes) so progress is visible and borderline screens are listed.
- A small script that flattens the dump to meaningful elements (label, value, traits, frame) and flags the
  mechanical problems (interactive element without a label, element outside the screen bounds, zero-size element,
  duplicated label+frame) does most of the comparison; the screenshot covers what is missing.
- The full project build (`Make.py build`) passes; touched modules with `ios_unit_test` targets run.

## Delivery

- Branch `accessibility` off `master`, one PR at the end. Commits in parts: ASDK collector, ComponentFlow
  convention, tab bar, then screen groups.
- The uncommitted change in `submodules/WalletContext/Sources/WalletTonConnect.swift` is not part of this work and is
  never staged.

## Left to the builder

- The exact collector algorithm and caching, and how many off-screen list rows to expose.
- The component-level API for labels/traits.
- Screen grouping and order after infrastructure; the inventory format; the flattening script.
- Whether to add XCUITest/unit coverage for the collector and the tab bar.
