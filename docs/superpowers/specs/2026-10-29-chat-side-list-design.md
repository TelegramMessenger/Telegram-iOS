# Chat side list — design

Date: 2026-10-29. Status: approved in conversation, pending plan.

## What it is

A chat that belongs to a parent list (a Saved Messages sub-chat, a channel's direct-messages thread, a bot thread)
gets a sidebar button in the right slot of its navigation bar. Tapping it slides the parent list in from the right over
the chat: the real chat list for that parent, with its own header ("•••", title + subtitle, avatar), search field and
rows. The chat moves left and stays visible as a strip about 75pt wide (the sidebar button, bubble tails/timestamps,
the input panel's left edge). Picking a row switches the chat in place and closes the list.

Reference screenshots (8, from the design): Dubai Runners forum topic ↔ topic list; Agent bot thread "Kyoto Trip" ↔
"Agent / Claude" thread list with "New Topic"; Saved Messages ▸ All Messages ↔ "Saved Messages / 8 chats"; Durger King
channel DMs (Emma Carter) ↔ "Durger King / Direct messages". The forum pair is out of scope (below) and is only the
visual reference.

## Scope

In (v1):

| Chat | Parent list shown | Today |
|---|---|---|
| Saved Messages sub-chat (and "All Messages", the account's own chat) | `ChatListControllerLocation.savedMessagesChats(peerId:)`; "All Messages" row first | sub-chat list is a separate pushed screen; no strip |
| Channel direct messages, admin view (`channel.isMonoForum`, linked channel has `.manageDirect`) | monoforum list (`.savedMessagesChats(peerId:)` of the monoforum, as `ChatSideTopicsPanel.swift` subscribes today); no extra row for the channel itself | `ChatSideTopicsPanel` / `ChatFloatingTopicsPanel` |
| Bot with threads (`botInfo.flags.contains(.hasForum)`), the Agent bot (`isAgentBotPeer`) included | the bot's thread list (`.forum(peerId:)` of the bot) | `ChatSideTopicsPanel` / `ChatFloatingTopicsPanel` |

Out (v1):

- **Forums** (`channel.isForum`). Behaviour unclear; they keep today's strip/tabs unchanged.
- iPad / regular-width layouts and iPhone Duo unfolded: keep current behaviour (my call; confirm with the user if the
  plan wants otherwise).

## Behaviour

- **Saved Messages entry point changes**: with the feature on, opening Saved Messages in "view as chats" mode no
  longer pushes the sub-chat list screen; it opens "All Messages" (the account's own chat) directly, and the sub-chat
  list exists only in the side panel. Back from any Saved Messages chat goes to where Saved Messages was opened from.
  With the killswitch on, the list screen is pushed as today. (The places that push that screen must all be found.)
- **Initial state**: the panel is always closed when a chat opens, including a parent opened without a thread (a bot
  at its root, the monoforum's "All" view). It opens only on the user's action.

- **Entry**: the sidebar button in the right navigation slot (replaces the avatar/`moreInfoNavigationButton` there for
  in-scope chats). Also a left swipe over the history (my guess from the design; the plan may cut it if it fights the
  existing swipe-to-reply / back gestures).
- **Open state**: list on the right, chat strip on the left. The current chat's row is highlighted (grey rounded fill,
  as in the screenshots).
- **Exit**: tap the strip, swipe right, or the sidebar button shown on the strip.
- **Picking a row**: the chat switches in place, the list closes. Back and the "‹ 23" badge keep pointing where they
  pointed before (the list is not pushed on the navigation stack).
- **"New Topic"** floating button at the bottom: bot threads only. Saved Messages and channel DMs have none.
- Everything else in the list (row swipe actions, context menus, typing, unread badges, search) behaves as in the
  same chat list opened as a standalone screen.
- **Search in the list** (my call): a hit inside the same parent switches in place (to the message, via
  `updateChatLocationThread(threadId:subject:)`); a hit outside the parent pushes as the standalone list does.
- **Peer info** (my call): the chat's title tap opens info as today; the avatar in the list header opens the parent's
  profile.
- **`topicListPanelLocation` toggle** (my call): with the feature on, the panel-location menu item is hidden for
  channel DMs and bot threads (it would do nothing); the stored value is kept for the killswitch.

## Killswitch

- App-config key `ios_killswitch_disable_chat_side_list` (name provisional) **or** Debug Settings toggle
  "Chat side list: legacy strip" turns the feature off.
- Off means: channel DMs and bot threads get `ChatSideTopicsPanel` / `ChatFloatingTopicsPanel` exactly as today
  (`ChatInterfaceTitlePanelNodes.swift`, `topicListPanelLocation` `.top`/`.side`/`.bottom`); Saved Messages has no
  sidebar button.
- Follow the existing pattern: `ios_killswitch_disable_media_grid_v2` in `AccountContext/Sources/MediaPickerGridV2.swift`
  with its toggle in `DebugSettingsUI/Sources/DebugController.swift` and a flag test.

## Constraints and anchors in the code

- Today's strip is chosen in `ChatInterfaceTitlePanelNodes.swift` (`titleTopicsPanelForChatPresentationInterfaceState…`
  and `floatingTopicsPanelForChatPresentationInterfaceState`, branches for monoforum / forum / bot forum). With the
  feature on, the monoforum and bot-forum branches return nil; the forum branch is untouched.
- The right navigation slot is decided in `ChatInterfaceStateNavigationButtons.swift` (the `isForumOrMonoForum` and
  `hasForum` branches return `moreInfoNavigationButton`).
- In-place switching already exists: `ChatControllerImpl.updateChatLocationThread(threadId:animationDirection:…)`
  (`ChatController.swift`), used by today's strip via `interfaceInteraction.updateChatLocationThread`. Prefer it over
  replacing the controller (my call): it keeps the navigation stack, draft saving and the inline-switch animation.
  It currently builds `ChatReplyThreadMessage(isForumPost: true, isMonoforumPost: …)`; Saved Messages sub-chats must be
  checked to go through it correctly (peerId = account peer, threadId = sub-chat peer).
- The list content is `ChatListControllerImpl` (`ChatListUI`) with the location above, embedded as a child controller,
  not a new renderer. `ChatListItem` already renders bot-thread and monoforum rows; whether the whole controller works
  for a bot's `.forum(peerId:)` (`ForumChannelTopics` is channel-named) must be verified first.
- The list's own row tap must be intercepted to call the in-place switch instead of pushing a new chat.
- Layout rules from the root `CLAUDE.md`: the chat node does not set its own frame; the container positions it.
  Duo reserved corners / side insets apply to the strip if the plan touches Duo.
- New strings go to `Telegram/Telegram-iOS/en.lproj/Localizable.strings`.
- Visual verification from recorded simulator frames (`AGENTS.md`, "Visual features and animations").

## Left to the builder

- Where the container lives (inside `ChatControllerNode` vs. a wrapper controller), the open/close animation curve and
  the exact strip width, as long as it matches the screenshots.
- Gesture conflict resolution for the swipe entry.
- Whether the list controller is kept alive between openings or recreated.
- Tests: the killswitch flag decision as a unit test (like `MediaPickerGridFlagTests`); the rest is checked on the
  simulator.
