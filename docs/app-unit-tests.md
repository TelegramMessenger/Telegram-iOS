# App-side unit tests

What each app-side test target pins, and what it shows about running app code in a test process. Run one
with `Make.py test --target <label>` (root `CLAUDE.md`, "Running tests").

`//submodules/TextFormat:TextFormatTests` covers the mention/date link codecs.

`//submodules/Postbox:PostboxTests` covers `SqliteValueBox` and individual Postbox tables directly against an in-memory
value box, using `@testable import Postbox`; add new Postbox regression tests under `submodules/Postbox/Tests/`.

`//submodules/TelegramCallsUI:TelegramCallsUITests` drives `SharedCallAudioContext` through a fake
`ManagedAudioSession` (implementable from outside through `ManagedAudioSessionControl`'s public closure initializer).
Creating the context builds a real tgcalls audio device, which is fine in the simulator test process. It also pins
where the group call header puts its "speaking" line (`VideoChatTitleComponent.View.layoutActivityStatusNode`, with a
real `ChatTitleActivityNode`; the component itself needs `PresentationStrings`).

`//submodules/TelegramAudio:TelegramAudioTests` covers pure `ManagedAudioSessionType` helpers such as
`voiceMessageRecording(beginWithTone:pauseMusicOnRecording:)` (the mapping for the Data & Storage "Pause Music While
Recording" toggle), and the **holder-precedence policy of the real `ManagedAudioSessionImpl`**: it is constructible in
the test process; push with `manualActivate` and never touch the control, so the process's `AVAudioSession` is left
alone. The rule pinned there: a `.voiceCall` holder is never displaced, not even temporarily, by a recording that mixes
with other audio, because deactivating it makes `PresentationCall` drop its audio-session control. The recorder
(`ManagedAudioRecorder`) needs a live `MediaManager` and real audio units, so keep session-policy decisions in testable
helpers rather than in it. It also pins how a call classifies the audio route into the outputs of its audio menu
(`audioSessionOutputs(route:hasLoudspeaker:)` and the Headphones selection `audioSessionWiredHeadsetInput(route:)`,
over `AudioSessionRoute` snapshots, since `AVAudioSessionPortDescription` cannot be constructed): a wired headset's
microphone is part of "Headphones", except while a Bluetooth device is the output or the built-in microphone is in use
over wired headphones, where it stays an item of its own.

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

`//submodules/TranslateUI:TranslateUITests` covers how a chat's translation state is keyed. Whether to translate and
into which language (`ChatTranslationPeerChoice`) is the peer's, shared by its own chat and every thread (forum topics,
comment threads), so enabling or disabling it in one topic applies to all; the detected source language stays each
location's own. A monoforum's threads keep their own choice, being conversations with different users. Topics translated
before the choice was shared enable the peer the first time one of them is shown (no API lists a peer's stored topics,
so this is lazy). A topic already in the target language is shown untranslated, offering the base language, so its bar
never disappears; "Do not translate" in one topic keeps the others translating, while in a chat without topics it turns
the chat's translation off as it always did.

`//submodules/TelegramUI/Components/ChatTitleView:ChatTitleViewTests` covers `chatTitleLeadingIconsLayout`, the
placement of the icons before a chat header's title: a secret chat's lock next to the name, and a third-party
verification icon to the left of the lock, never on top of it.

`//submodules/TelegramUI/Components/InteractiveTextComponent:InteractiveTextComponentTests` covers
`InteractiveTextNode`'s layout of a truncated line (a story caption's "Show more", a collapsed quote): custom emoji
past the cut are not laid out, the last one before it keeps its own place, and a link's highlight across the cut starts
at the link. CoreText reports offset 0 for all of them, which put an emoji over the line's first word.

`//submodules/TelegramUI/Components/VideoMessageCameraScreen:VideoMessageCameraScreenTests` covers the round video
message camera's placement helpers (`VideoMessageCameraLayout.swift`): on iPhone Duo the preview kept above the chat's
input panel and the trailing buttons clear of the status corner, and on every phone the touches that reach the panel
above a bot keyboard, which the window does not report as input.

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

`//submodules/UndoUI:UndoUITests` covers `undoOverlayHorizontalLayout`, the undo toast's panel and text widths. A
chat's presentation context carries its history list's side insets (the safe insets, left and right swapped), so the
context's left inset widens the toast's margin less the Duo's side strip; with equal side insets the metrics are the
previous ones.

`//submodules/TelegramUI/Components/ChatControllerInteraction:ChatControllerInteractionTests` covers
`chatIsOpeningMedia`, the window in which a chat ignores further taps on its media (`isOpeningMedia`) after one opened
it. A gallery appears only once its first item is ready (up to 2 s), so it stays blocked until the gallery reports it
is on screen (at most 4 s); an open that reports nothing is released after 1 s, as before. It also covers
`chatHistoryMaxVisibleReadIndex`, the newest message a chat reads from the rows on screen: a row under the top inset
does not count, one starting up to 100 points above it does, and in a thread (a forum topic, a reply or monoforum
thread) a row holding a non-cloud message is left out.

`//submodules/ReactionSelectionNode:ReactionContextGeometryTests` covers the reaction bar's pure geometry (`Geometry/`,
linked without AccountContext), among it `reactionContextBackgroundContentBounds`, what the reaction panel's background
(the glass) covers. Its tail's circles widen it only when the tail is shown: a hidden tail can point well past the panel
(a story's input row, wider than iPhone Duo's landscape card), and the glass reached out to it. Circles under the panel
give the same bounds as before.

`//submodules/ContactsPeerItem:ContactsPeerItemTests` covers `ContactItemHighlighting`, the Contacts list's highlight of
the chat a split view's detail pane shows. When the split goes away (folding iPhone Duo) it clears the selection with no
chat and progress 0; a progress without a chat must count as no selection in progress, or every row on screen takes
`1 - 0` as its highlight and stays gray, and a pressed row shows none.

`//submodules/TelegramUI/Components/EntityKeyboard:EntityKeyboardTests` covers `EntityKeyboardSideInsets.swift`, the
emoji / stickers / GIFs keyboard's placement beside the Duo's side strip: the grid and the centred controls (group
headers, the GIFs / Stickers / Emoji switcher) centre on the band between the side insets, and the side strips the pack
rows are clipped by; with equal side insets the old expressions come out exactly. The clipping itself is checked on
the Duo simulator.

`//submodules/PasswordSetupUI:PasswordSetupUITests` covers `twoFactorDataInputHorizontalLayout`, the bands of the
2FA data input screen per Duo posture: content, bottom button, and the text actions that take the hidden button's place
(in the fields' row in Settings, in the button's frame in the login flow); with equal side insets all are the previous
ones.

`//submodules/ItemListUI:ItemListUITests` covers `itemListDisclosureLabelConstrainedWidth`, the room an
`ItemListDisclosureItem` row leaves its trailing value after the title: the legacy reserve by default, or the
`minimumLabelSpacing` a row names (Data and Storage's usage rows use 6pt, so «Использование трафика» and a compact
size share a 390pt line; on 375pt and narrower the value truncates). Titles are never shortened for the value.

`//submodules/LegacyMediaPickerUI:LegacyMediaPickerUITests` covers `DocumentPickerPresentation`, which tells when the
system document picker of `legacyICloudFilePicker` ("Select from Files") is gone without a word to its delegate. The
picker is presented over an invisible full-screen host that leaves only through the picker's callbacks. UIKit holds the
picker's presentation back for up to 3 s, and a dismissal on the root controller meanwhile cancels it silently: the app
lock does that when the app goes inactive with passcode auto-lock on, as for the Face ID prompt of a Files app locked with
Face ID (#40, read from the code, not reproduced). The host then stayed and took every touch. A picker not on screen
counts as lost only past that limit (or at once when UIKit released it), so one still held back is never cancelled. A
`UIWindow` cannot be used in this hostless test process: it traps at exit, when UIKit invalidates its screen-based scene,
so the picker-on-screen case has no test.

`//submodules/TelegramUI/Components/RichTextEditorMediaView:RichTextEditorMediaViewTests` covers
`MediaChromeLayout`, where the article editor's glass media buttons go: a tile's "…" keeps clear of the
container's "+" and layout toggle (#28), checked over the real album layouts (`MosaicCellFrames`).

`//submodules/TelegramPresentationData:TelegramPresentationDataTests` covers the theme settings' storage and the
bubble-free mode's themes. With bubbles on, the stored bytes are master's (captured before the bubble-free fields
existed). No builtin raw value an older build does not know reaches `"t"` or `"theme_v2"`, which older builds and both
extensions force-unwrap at launch. The bubble-free theme is built and recoloured as the app does. Building a
`PresentationTheme` works in the test process (`makePresentationTheme` takes a `MediaBox` on a temporary directory);
`PresentationStrings` does not, so no `PresentationData` and no theme names in these tests.
It also covers `dataSizeString`'s `compact` format ("48 МБ", "131 МБ", "27,2 ГБ", "1 ГБ" for 1000 MB), with a
`DataSizeStringFormatting` built from plain `FormattedString`s instead of the app's strings.

The RichTextEditor SwiftPM package keeps its own suite (`swift test` / `Scripts/iostest.sh`). MtProtoKit's suite
(`//submodules/MtProtoKit:MtProtoKitTests`) also runs on macOS: `swift test` in `submodules/MtProtoKit` (the package's
test target puts the module's private headers on its search path).

Most modules still have no tests.
