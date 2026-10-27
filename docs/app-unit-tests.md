# App-side unit tests

What each app-side test target pins, and what it shows about running app code in a test process. Run one
with `Make.py test --target <label>` (root `CLAUDE.md`, "Running tests").

`//submodules/TextFormat:TextFormatTests` covers the mention/date link codecs.

`//submodules/Postbox:PostboxTests` covers `SqliteValueBox` and individual Postbox tables directly against an in-memory
value box, using `@testable import Postbox`; add new Postbox regression tests under `submodules/Postbox/Tests/`.

`//submodules/TelegramCallsUI:TelegramCallsUITests` drives `SharedCallAudioContext` through a fake
`ManagedAudioSession` (implementable from outside through `ManagedAudioSessionControl`'s public closure initializer).
Creating the context builds a real tgcalls audio device, which is fine in the simulator test process.

`//submodules/TelegramAudio:TelegramAudioTests` covers pure `ManagedAudioSessionType` helpers such as
`voiceMessageRecording(beginWithTone:pauseMusicOnRecording:)` (the mapping for the Data & Storage "Pause Music While
Recording" toggle), and the **holder-precedence policy of the real `ManagedAudioSessionImpl`**: it is constructible in
the test process; push with `manualActivate` and never touch the control, so the process's `AVAudioSession` is left
alone. The rule pinned there: a `.voiceCall` holder is never displaced, not even temporarily, by a recording that mixes
with other audio, because deactivating it makes `PresentationCall` drop its audio-session control. The recorder
(`ManagedAudioRecorder`) needs a live `MediaManager` and real audio units, so keep session-policy decisions in testable
helpers rather than in it.

`//submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode:ChatTextInputPanelNodeTests` covers the legacy
composer's Text Size metrics (`ChatTextInputFontMetrics.swift`) against a real `ChatInputTextView` measurement. The
panel links into a test bundle only because `LegacyComponents` declares `MediaPlayer`.

`//submodules/TelegramUI/Components/PeerInfo/PeerInfoPaneNode:PeerInfoPaneNodeTests` covers
`peerInfoMessageChatDestination`, the chat that shared-media "View in Chat" opens. It is the chat the media tab
*lists* — neither the peer the profile describes (a secret chat's profile describes the user, so use `data.chatPeer`)
nor the chat the message is stored in (a supergroup's tab lists its pre-migration basic group's messages, which open in
the supergroup). A user's profile opened from a channel's direct messages lists that channel's thread, which is opened
directly: `navigateToForumThread` addresses a topic by an Int32 message id and cannot reach a monoforum thread keyed by
a user id.

`//Telegram/NotificationService:NotificationServiceTests` covers the notification service extension's naming of the
recipient account when several are signed in (`NotificationRecipientAccount.swift`); with "Show Notifications From All
Accounts" off only the current account notifies, so its notifications are not named. On iOS 15+ the system draws a
communication notification's title from the sender `INPerson`'s `displayName` and hides `content.subtitle`, so anything
the title must show goes into the sender's name. `NotificationContent` is private, so keep such decisions in testable
helpers.

`//submodules/TelegramUI/Components/Chat/EditableTokenListNode:EditableTokenListNodeTests` covers
`EditableTokenListPeerAlias`, the one decision a chat picker's token (e.g. Add Chats for a folder) uses for both its
title and its avatar, so a Saved Messages token draws the Saved Messages icon rather than the account's photo.
`PresentationStrings` cannot be built in a test process (it asserts without the app bundle's
`PresentationStrings.data`), so the alias is strings-free and the title stays in `ContactMultiselectionController`.

`//submodules/PeerAvatarGalleryUI:PeerAvatarGalleryUITests` covers `avatarGalleryUserEntries`, the one builder both
user-gallery paths use. Slot 0 is the peer record's current photo, but `photos.getUserPhotos` keeps its order when an
older photo is made the main one again (the server swaps a copy under a **new photo id** into that photo's place), so
the builder looks the current photo up in the list and moves it to the front (a personal photo moves the contact's
current public photo instead; a current photo the list does not contain gets its own slot). Drawing it over whatever
the list starts with shows it twice and hides that photo. Because of the new id, `_internal_updatePeerPhotoExisting`
copies the chosen photo's downloaded sizes to the returned photo's files (the returned photo's sizes and its
`photo_small`/`photo_big` ("a"/"c") are byte-identical to the chosen photo's), and the same transaction sets
`TelegramUser.photo` from the returned photo, because the result's user list does not carry it for the account itself;
otherwise every avatar downloads the photo again.

`//submodules/TelegramUI/Components/Chat/ChatSendStarsScreen:ChatSendStarsScreenTests` covers
`chatSendStarsShownTopPeers`, the paid-reaction sheet's "Top Senders": the message's top reactors, most Stars first, cut
to three only after dropping a sender whose peer is not stored locally (it has no name or avatar to draw); an anonymous
sender needs no stored peer. The server sends only the top three plus the account's own entry, so a dropped sender
leaves the sheet with two: what keeps three is the reactions poll (`AccountViewTracker.updateReactionsForMessageIds`)
storing the users and chats it returns, since a sender who reached the leaderboard after the message was stored is known
only from that response. No test covers that networked path.

`//submodules/MediaPlayer:UniversalMediaPlayerTests` drives a real `ChunkMediaPlayerV2` (wait for
`MediaPlayerNode.videoLayer`, which the node creates asynchronously, before constructing it) from an `.externalParts`
promise. With no parts the player stays buffering, so the clock only moves on a seek; a part backed by an empty
`TempBox` file lets it run, because buffering is decided from part times alone. It pins the end of playback: the player
keeps a 0.1 s end tolerance for HLS chunks that do not line up with the declared duration
(`ChunkMediaPlayerV2.endTolerance`; do not remove it), so a video no longer than that is at its end from position 0 and
is not played — its clock never moves, even on a later `play()`. Looping one would seek to where the clock already is,
and that no-op `seek` re-runs the end check synchronously until the stack overflows.

The RichTextEditor SwiftPM package keeps its own suite (`swift test` / `Scripts/iostest.sh`). MtProtoKit's suite
(`//submodules/MtProtoKit:MtProtoKitTests`) also runs on macOS: `swift test` in `submodules/MtProtoKit` (the package's
test target puts the module's private headers on its search path).

Most modules still have no tests.
