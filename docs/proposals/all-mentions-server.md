# Required server support for collective mentions

These are proposed behavioral requirements, not names or numeric IDs for existing Telegram APIs. This client patch contains no server implementation and defines no TL constructors. Telegram must choose the actual capability, rights, entities, errors and rollout contract.

## Capability and group permission

A server capability must gate presentation of the collective suggestion and setting. Persist a per-group permission, off by default, and validate updates against the appropriate group-management right. The chosen rule applies equally to administrators and members. A client-local preference cannot authorize a cloud-group send.

## Entity and normalization

Define an unambiguous collective-mention entity and its compatibility behavior for older clients. Keep normal @all usernames/text distinct from collective intent. Preserve UTF-16 ranges and protected formatting. Validate at the server boundary instead of trusting a client flag. Editing a sent message and forwarding it must not produce a new collective notification.

## Atomic group quota

Enforce up to three calls per group in a series, shared by all senders and topics. Every accepted call moves the reset deadline to five minutes after that call. The third starts the five-minute break; five minutes of inactivity also clears a partial series. Validate the permission and reserve quota atomically with accepting the message batch. Use the normal send idempotency mechanism so retries do not consume another call. Permission changes, edits, deletions and client restarts must not reset a group’s quota.

## Scheduling and destinations

A queued call stores intent, target topic, silence and explicit effect. It reserves nothing until actual execution. The server scheduler must work while the client is closed and recheck membership, write access, topic existence/closure, collective permission and quota at delivery. Preserve ordinary closed-topic management exceptions.

Reject a failed batch as a whole. Retain a failed scheduled message with a structured reason and a manual retry/reschedule path; do not automatically retry a call once access returns. A token queued as ordinary text must not become a collective call because the permission was enabled later.

## Fan-out, read state and effects

Resolve recipients from authorized group membership at delivery. The proposed forum scope is the whole group; preserve the exact topic/message for navigation. Specify how that interacts with topic subscription and existing personal-mention notification rules. Suppression for a muted sender, silent delivery and read state must remain consistent with Telegram’s notification model.

Deliver and synchronize unread-mention/read state across devices. Avoid notifying the sender about their own call. One recipient viewing a call must not clear another device/user’s unrelated topic state.

Effects are presentation metadata, not delivery authority. An explicitly chosen effect takes priority over the automatic megaphone. History, edit, forward and duplicate delivery must not trigger a second effect or reservation.

## Work remaining before production

Implement the approved server/API contract, capability rollout, server scheduling and synchronized state; replace the mock provider and private entity bridge; then validate concurrent senders, duplicate sends, cross-device read state, permission changes while offline and actual push delivery. The included local tests exercise the proposed client policy but cannot establish those server guarantees.
