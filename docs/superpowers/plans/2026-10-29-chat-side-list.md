# Chat Side List Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A sidebar button in Saved Messages, channel-DM (admin) and bot-thread chats slides the parent chat list in
from the right over the chat; picking a row switches the chat in place.

**Architecture:** A new `ChatSideListPanel` module hosts a real `ChatListControllerImpl` as a child controller of
`ChatControllerImpl`, shifting the chat (navigation bar included) left to a ~75pt strip. Row taps are routed through a
new hook on `ChatListControllerImpl` to the existing `ChatControllerImpl.updateChatLocationThread`. A pure flag function
plus app-config killswitch / Debug toggle restores today's `ChatSideTopicsPanel` strip.

**Tech Stack:** Swift, AsyncDisplayKit/Display, ComponentFlow, SwiftSignalKit, Bazel (`Make.py`).

**Spec:** `docs/superpowers/specs/2026-10-29-chat-side-list-design.md`

## Global Constraints

- Forums (`channel.isForum`) are untouched in every task: today's strip/tabs stay.
- In scope: Saved Messages (account peer, sub-chats), monoforum with linked channel `.manageDirect`, bots with
  `botInfo.flags.contains(.hasForum)`.
- Killswitch key `ios_killswitch_disable_chat_side_list`; Debug Settings toggle "Chat side list: legacy strip".
  Either one = feature off = today's behaviour exactly.
- Monoforum list location is `.savedMessagesChats(peerId: monoforumPeerId)`; bot list `.forum(peerId: botPeerId)`;
  Saved Messages list `.savedMessagesChats(peerId: accountPeerId)` with "All Messages" first. No extra channel row.
- Panel is closed whenever a chat opens; it opens only on user action.
- "New Topic" button: bot threads only.
- iPhone compact width only; `.regular` width class keeps today's behaviour.
- Chat views never set their own `frame`; the container positions them (root `CLAUDE.md`, "View frame ownership").
- New strings in `Telegram/Telegram-iOS/en.lproj/Localizable.strings`.
- Build: `source ~/.zshrc 2>/dev/null; python3 build-system/Make/Make.py --overrideXcodeVersion --cacheDir ~/telegram-bazel-cache build --continueOnError --configurationPath build-system/appstore-configuration.json --gitCodesigningRepository git@gitlab.com:peter-iakovlev/fastlanematch.git --gitCodesigningType development --gitCodesigningUseCurrent --buildNumber=1 --configuration=debug_sim_arm64`
- Visual changes are verified from recorded simulator frames (`AGENTS.md`, "Visual features and animations"), on K3.

## Review Focus

1. **Draft in the composer when switching threads from the list**: it must be saved to the old thread and the new
   thread's draft restored (today's `updateChatLocationThread` does this; the hook must not bypass it). → Task 4, sim check.
2. **Tapping the row of the chat that is already open**: closes the panel, no reload/flash. → Task 4 test.
3. **Killswitch flipped while a chat is open**: the next layout must not show both the strip and the button. → Task 2
   (decision is read from the same flag in both places; sim check with the Debug toggle).
4. **Search hit for a peer outside the parent** (Saved Messages search finds a regular chat): pushes normally, does
   not try an in-place switch with a foreign peerId. → Task 4 test.
5. **Agent bot with zero threads**: the button still opens a list (empty) with "New Topic"; today's strip hides for
   non-user-managed bots without topics (`hasTopics`). → Task 2 test.

---

### Task 1: Feature flag and decision function

**Files:**
- Create: `submodules/AccountContext/Sources/ChatSideList.swift`
- Modify: `submodules/TelegramUIPreferences/Sources/ExperimentalUISettings.swift` (add `chatSideListLegacy: Bool`,
  default `false`, coded as `"chatSideListLegacy"`, next to `mediaGridLegacy` in all six places)
- Modify: `submodules/DebugSettingsUI/Sources/DebugController.swift` (entry `case chatSideListLegacy(Bool)` mirroring
  `.mediaGridLegacy` in all four places; title "Chat side list: legacy strip")
- Test: `submodules/TelegramUI/Components/ChatMediaEditorScreen/Tests/ChatSideListFlagTests.swift` (the existing
  `ChatMediaEditorScreenTests` target already hosts `MediaPickerGridFlagTests` and depends on AccountContext)

**Interfaces:**
- Produces:
  - `public let chatSideListKillswitchKey = "ios_killswitch_disable_chat_side_list"`
  - `public func chatSideListEnabled(legacyOverride: Bool, killswitchPresent: Bool) -> Bool`
  - `public extension AccountContext { var usesChatSideList: Bool }` (same shape as `usesMediaPickerGridV2`)
  - `public enum ChatSideListKind: Equatable { case savedMessages; case monoforum(peerId: EnginePeer.Id); case botThreads(peerId: EnginePeer.Id) }`
  - `public func chatSideListKind(peer: EnginePeer?, accountPeerId: EnginePeer.Id, isAdminMonoforum: Bool, isRegularWidth: Bool, enabled: Bool) -> ChatSideListKind?`
    — `nil` when `!enabled`, regular width, forum channel, or anything else out of scope. `isAdminMonoforum` is
    computed by the caller exactly as today's condition in `ChatInterfaceTitlePanelNodes.swift` (linked channel
    `hasPermission(.manageDirect)`).
  - `public extension ChatSideListKind { var listLocation: ChatListControllerLocation; var showsNewTopicButton: Bool }`

- [ ] **Step 1: Write the failing tests** — `testOnByDefault`, `testLegacyOverrideDisables`, `testKillswitchDisables`,
  `testKillswitchKey` (as `MediaPickerGridFlagTests`, key `"ios_killswitch_disable_chat_side_list"`), plus:
  - `testSavedMessages`: `peer` = account user → `.savedMessages`; `listLocation == .savedMessagesChats(peerId: accountPeerId)`; `showsNewTopicButton == false`
  - `testAdminMonoforum`: monoforum channel, `isAdminMonoforum: true` → `.monoforum(peerId:)`, location `.savedMessagesChats(peerId: monoforumId)`
  - `testNonAdminMonoforum`: `isAdminMonoforum: false` → `nil`
  - `testBotThreads`: bot user with `.hasForum` → `.botThreads`, location `.forum(peerId: botId)`, `showsNewTopicButton == true`; also with `.hasForum` but no `.forumManagedByUser` (Review Focus 5)
  - `testForumExcluded`: forum channel → `nil`
  - `testRegularWidthExcluded`, `testDisabledReturnsNil`
- [ ] **Step 2: Run and verify they fail** — `Make.py test … --target //submodules/TelegramUI/Components/ChatMediaEditorScreen:ChatMediaEditorScreenTests`. Expected: compile failure, `chatSideListEnabled` not found.
- [ ] **Step 3: Implement** the flag, kind, settings field and Debug toggle.
- [ ] **Step 4: Run tests** — same command. Expected: all pass, `MediaPickerGridFlagTests` still pass.
- [ ] **Step 5: Commit** — `feat(chat-side-list): feature flag, killswitch and kind decision`

### Task 2: Replace the strip and the right navigation button

**Files:**
- Modify: `submodules/TelegramUI/Components/Chat/ChatNavigationButton/Sources/ChatNavigationButton.swift` (add `case toggleSideList`)
- Modify: `submodules/TelegramUI/Sources/ChatInterfaceTitlePanelNodes.swift` (monoforum and bot-forum branches of both
  the title-panel and `floatingTopicsPanelForChatPresentationInterfaceState` functions return `nil` when
  `chatSideListKind(...) != nil`; forum branch untouched)
- Modify: `submodules/TelegramUI/Sources/ChatInterfaceStateNavigationButtons.swift` (when `chatSideListKind(...) != nil`
  and subject is not `.pinnedMessages`/`.messageOptions`, return a sidebar button; this goes before the
  `isForumOrMonoForum` / `hasForum` branches; Saved Messages gets it too)
- Modify: `submodules/TelegramUI/Sources/ChatController.swift` (navigation-button handler: `.toggleSideList` → `self.toggleSideList()`, a stub until Task 3)
- Modify: `submodules/ChatPresentationInterfaceState/Sources/ChatPresentationInterfaceState.swift` only if the
  decision inputs (regular width, feature flag) are not already reachable where the two functions run; prefer
  passing `context.usesChatSideList` and the layout width class from the call sites.

**Interfaces:**
- Consumes: `chatSideListKind`, `AccountContext.usesChatSideList` (Task 1).
- Produces: `ChatNavigationButtonAction.toggleSideList`; `ChatControllerImpl.toggleSideList()` (filled in Task 3).

The sidebar button's icon is the one in the screenshots' top-right glass button (`Chat/Navigation/SideList` asset; add
it if absent, as a template image).

- [ ] **Step 1: Build** (command in Global Constraints). Expected: green.
- [ ] **Step 2: Sim check (frames)** — on K3, feature on: bot-thread chat and admin channel DMs show no strip/tabs and
  a sidebar button on the right; a forum topic still shows its strip; Saved Messages "All Messages" shows the button.
  Toggle Debug "Chat side list: legacy strip": strip returns, button gone, with the chat left open and reopened (Review Focus 3).
- [ ] **Step 3: Commit** — `feat(chat-side-list): sidebar button replaces topics strip`

### Task 3: The side-list container (open/close, strip, gestures)

**Files:**
- Create: `submodules/TelegramUI/Components/Chat/ChatSideListPanel/BUILD`
- Create: `submodules/TelegramUI/Components/Chat/ChatSideListPanel/Sources/ChatSideListPanelNode.swift`
- Modify: `submodules/TelegramUI/BUILD` (dep)
- Modify: `submodules/TelegramUI/Sources/ChatController.swift` (owns the panel, implements `toggleSideList()`,
  positions chat display node + navigation bar in `containerLayoutUpdated`)

**Interfaces:**
- Consumes: `ChatSideListKind.listLocation` (Task 1); `context.sharedContext.makeChatListController(context:location:controlsHistoryPreload: false, hideNetworkActivityStatus: true, previewing: false, enableDebugActions: false)`.
- Produces:
  - `final class ChatSideListPanelNode: ASDisplayNode` with
    `init(context: AccountContext, kind: ChatSideListKind, listController: ChatListController)`,
    `var isOpen: Bool { get }`, `func setOpen(_ open: Bool, transition: ContainedViewLayoutTransition)`,
    `var openFraction: CGFloat { get }` (0…1, drives the chat offset while dragging),
    `var requestClose: (() -> Void)?`,
    `func updateLayout(layout: ContainerViewLayout, transition: ContainedViewLayoutTransition)`.
  - `static let stripWidth: CGFloat = 75.0`
  - `ChatControllerImpl.toggleSideList()`, `ChatControllerImpl.closeSideList(animated: Bool)`.

Behaviour: closed by default on every chat open; open = list frame `x = stripWidth … layout.size.width`, chat offset
`-(layout.size.width - stripWidth)`; a transparent tap target over the strip calls `requestClose`; pan right on the
list/strip closes interactively (`openFraction`); pan left over the history opens it unless it conflicts with
swipe-to-reply (drop the open-pan if it does, and say so in the commit message). The list controller is created on
first open and kept for the controller's lifetime. Use `stripWidth` + safe insets so Duo folded portrait's right inset
is respected.

- [ ] **Step 1: Build.** Expected: green.
- [ ] **Step 2: Sim check (frames)** — record open/close on K3 in a bot-thread chat; `tools/animation_sheet.py`:
  chat and list move together, no gap, strip is ~75pt, ends match screenshots 3↔4. Tap strip closes; swipe right closes.
- [ ] **Step 3: Commit** — `feat(chat-side-list): side list container and open/close`

### Task 4: Row selection, search and "New Topic"

**Files:**
- Modify: `submodules/ChatListUI/Sources/ChatListController.swift` (hook at the top of `mainContainerNode.peerSelected` at
  line ~1399, and in the search container's open-peer path)
- Modify: `submodules/AccountContext/Sources/ChatListController.swift` (expose the hook on the protocol)
- Modify: `ChatSideListPanelNode.swift` (route selections, "New Topic" button)
- Modify: `submodules/TelegramUI/Sources/ChatController.swift`
- Test: `submodules/TelegramUI/Components/ChatMediaEditorScreen/Tests/ChatSideListFlagTests.swift` (routing decision)

**Interfaces:**
- Consumes: Tasks 1, 3; `ChatControllerImpl.updateChatLocationThread(threadId:animationDirection:replaceInline:transferInputState:subject:completion:)`.
- Produces:
  - On `ChatListController`: `var interceptPeerSelection: ((EnginePeer, Int64?, EngineMessage.Id?) -> Bool)? { get set }` — returning `true` consumes the tap (no push, highlight cleared). Called with the *resolved* `(peer, threadId)` after the existing `forumSourcePeer` mapping, so Saved/monoforum sub-chats arrive as `(parentPeer, threadId)`.
  - In AccountContext `ChatSideList.swift`: `public enum ChatSideListSelection: Equatable { case switchThread(Int64?, messageId: EngineMessage.Id?); case closeOnly; case passThrough }` and
    `public func chatSideListSelection(kind: ChatSideListKind, accountPeerId: EnginePeer.Id, currentThreadId: Int64?, selectedPeerId: EnginePeer.Id, selectedThreadId: Int64?, messageId: EngineMessage.Id?) -> ChatSideListSelection`
    — `.passThrough` when `selectedPeerId` is not the kind's parent peer (Review Focus 4); `.closeOnly` when the
    thread equals `currentThreadId` and there is no `messageId` (Review Focus 2); else `.switchThread`.

"New Topic" (bot threads only): `updateChatLocationThread(threadId: nil, …)` then close — the same target as the
`VerticalAllItemComponent` of today's `.botForum` strip (`ChatSideTopicsPanel.swift:1950`). Verify on the sim that it
lands in the new-thread composer; if not, use what the strip's "all"/new item does.

- [ ] **Step 1: Write failing tests** — `testSelectionOtherThreadSwitches`, `testSelectionSameThreadClosesOnly`,
  `testSelectionSameThreadWithMessageSwitches`, `testSelectionForeignPeerPassesThrough` (Saved Messages kind, a
  regular user's peerId), `testSavedMessagesAllMessagesIsNilThread` (selecting the account peer itself → `.switchThread(nil, …)`).
- [ ] **Step 2: Run, expect failure** (`chatSideListSelection` not found).
- [ ] **Step 3: Implement** the function, the hook, and the panel's routing: `.switchThread` → `updateChatLocationThread(threadId:subject:)` (message hits via `subject: .message(...)`) then `closeSideList(animated: true)`; `.closeOnly` → close; `.passThrough` → return `false`.
- [ ] **Step 4: Run tests.** Expected: pass.
- [ ] **Step 5: Build + sim check (frames)** — switch between two bot threads with a typed draft in each; drafts
  survive (Review Focus 1); current row highlighted; search hit in Saved Messages opens in place; a hit for an outside
  chat pushes.
- [ ] **Step 6: Commit** — `feat(chat-side-list): in-place selection, search and new topic`

### Task 5: Saved Messages opens "All Messages" directly

**Files:**
- Modify: `submodules/TelegramUI/Sources/NavigateToChatController.swift` (~line 138: the
  `!viewForumAsMessages … peer.id == account.peerId` branch that pushes `makePeerInfoController`; skip it when
  `context.usesChatSideList` and compact width, falling through to the normal chat open)
- Modify, only if found: any other entry that pushes the Saved Messages chats screen directly (grep
  `DisplaySavedChatsAsTopics` and `.savedMessagesChats(peerId: context.account.peerId)` callers; record the list in the commit message)

**Interfaces:** Consumes `AccountContext.usesChatSideList` (Task 1).

- [ ] **Step 1: Build.**
- [ ] **Step 2: Sim check** — with "view as chats" on: tapping Saved Messages opens "All Messages" with the sidebar
  button; back returns to the chat list; the panel's list shows "All Messages" first and the sub-chats; picking a
  sub-chat switches in place. Debug legacy toggle on: the profile-style chats screen opens as today.
- [ ] **Step 3: Commit** — `feat(chat-side-list): saved messages opens all messages`

### Task 6: Final verification

- [ ] **Step 1:** Full build with `--continueOnError`; all Task 1/4 tests via `--target …ChatMediaEditorScreenTests`.
- [ ] **Step 2:** Recorded-frame pass on K3 over the four in-scope screenshots (Agent, Saved Messages, Durger King DMs)
  plus one forum topic (unchanged), feature on and off.
- [ ] **Step 3:** Commit any fixes; note in the final message what was not covered (iPad, Duo unfolded: out of scope).
