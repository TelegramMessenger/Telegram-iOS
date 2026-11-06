# Group-wide mentions: client proposal

This is an offline client prototype for https://bugs.telegram.org/c/11, not a released Telegram API feature. The suggestion and permission are available only in an isolated Debug demo account and its fictional groups. No collective mention is exposed in ordinary cloud groups.

## User behavior

A new group starts with **Mention All Members** disabled. The switch applies to everyone, including administrators. Its disabled state removes **All members** from @ suggestions. A previously selected atom or manually typed @all becomes ordinary text if the permission is off at the send boundary.

When enabled, **All members** appears first in suggestions with an @ icon and member count. Selecting it inserts a semantic atom. The mock send boundary also recognizes a standalone literal @all outside protected formatting. Usernames, emails, explicit personal mentions, URLs, code and quotes are not promoted to collective calls.

The limit is group-wide: three calls in one series, then five minutes from the third call before another is allowed. If five minutes pass without a call, a partial series also resets. For example, calls at minute 0 and minute 3 belong to one series; a call at minute 8 starts a new one. Switching the permission or editing/deleting a message does not reset the quota. The UI shows a generic wait message and preserves the draft when the quota is exhausted.

## Delivery and reuse

Silent delivery retains the existing silent attribute. Queueing a scheduled message neither reserves quota nor plays an effect. Delivery rechecks collective permission, quota, membership, write access and topic availability in the same local transaction as recording the send. Failed scheduled groups remain in the queue with an explanation and require a manual retry or reschedule.

A forum call refers to all group members; its topic controls the message destination and notification navigation. Permission and quota are shared across topics, while unread/read state remains per topic. Existing topic-management exceptions are used for closed topics.

An edit of a sent ordinary message cannot become a new collective call. An existing call may keep or lose its atom without another reservation or effect. Forwarding copies text and normal formatting without collective intent, read state or the automatic effect. A queued call can be explicitly edited before delivery, when the normal checks still apply.

## Effect and recipient

A new eligible call without an explicitly chosen effect gets one megaphone near its message. It flies in, compresses and recoils without rotating, emits fast @ glyphs and particles, then leaves. Explicit message effects take precedence. The decoration does not receive touches or reflow messages, and is removed on cancellation, navigation, backgrounding or reduced motion. Historical messages do not replay the effect.

The local recipient path uses the native in-app banner, unread-mention tag and chat/topic navigation. Viewing a call marks it read locally and consumes its one-time effect. Muted senders and silent attributes flow through the existing notification path. This is not APNs or real remote delivery.

## Code map

- `TextFormat` and `TelegramCore/ChatInputContent`: semantic atom, validation, UTF-16 ranges, formatting and draft bridges.
- `AllMentionGroupPermission`, `AllMentionScheduledDelivery`, `AllMentionIncomingMessage`: local state and transaction policies.
- `MentionChatInputContextPanelNode`, `AllMembersMentionChatInputPanelItem`, `ChannelPermissionsController`: native suggestion and permission UI.
- `ChatControllerNode`, `AllMentionSendEffectNode`: exact-message attachment, receiver placement and effect lifecycle.
- `AllMentionDemo*`, `ChatAllMentionDemoContents`, account/application hooks: offline fixture backend, scheduling, recipient and forum demonstration.
- Existing localization generation and bundled locales: new-string fallbacks below both remote language components.

## Demo and persistence

The default showcase is **Weekend Trip**, eight fictional friends and eight seeded travel messages. The first launch is an ordinary sender group with permission off. Showcase and legacy QA sessions have separate persistent manifests and preferences. Restarting does not reseed history, reset quota, drop queued messages or resurrect read mentions. An invalid saved manifest fails instead of silently selecting a new account.

For a Debug build of the dedicated `org.allmention.TelegramClient` bundle, launch with:

```
--all-mention-demo --all-mention-demo-showcase --all-mention-demo-sender --all-mention-demo-regular
```

Use `--all-mention-demo-recipient` for the recipient mode and `--all-mention-demo-incoming` for an explicit mock delivery, still subject to permission and quota. Add `--all-mention-demo-showcase --all-mention-demo-forum --all-mention-demo-topic 100` for the Plans topic. `--all-mention-demo-qa` selects the preserved legacy QA dataset. The selected dataset/mode persists for icon launches. None of these modes opens a normal account store or uses real API credentials.

## Readiness

The client proposal needs Telegram product/API decisions and server support described in `all-mentions-server.md`. The private custom entity and local preferences are not a wire protocol. The upstream port uses private preference namespace 26; the tested historical prototype used 24. Neither is a published migration contract for production data.
