# CLAUDE.md

This file provides guidance to AI assistants when working with code in this repository.

## Build

The app is built using Bazel via the `Make.py` wrapper. There is no selective per-module build — the only supported invocation builds the full `Telegram/Telegram` target.

**Command:**

```sh
python3 build-system/Make/Make.py --overrideXcodeVersion \
 --cacheDir ~/telegram-bazel-cache \
 build \
 --configurationPath build-system/appstore-configuration.json \
 --gitCodesigningRepository git@gitlab.com:peter-iakovlev/fastlanematch.git \
 --gitCodesigningType development --gitCodesigningUseCurrent --buildNumber=1 --configuration=debug_sim_arm64
```

Add `--continueOnError` after `build` (forwards to bazel's `--keep_going`) when verifying changes that may surface errors in many files at once — it lets the full set of errors land in one pass instead of stopping at the first failing target.

The build needs `TELEGRAM_CODESIGNING_GIT_PASSWORD` in the environment. It is set in `~/.zshrc` but Claude Code's bash tool does NOT source shell config by default. Prefix build commands with `source ~/.zshrc 2>/dev/null;` to pick it up.

**Running tests.** `Make.py test` runs Bazel test targets (same config + codesigning as `build`, forced `debug_sim_arm64`). It accepts `--target <label>` (added 2026-06-19; default `Tests/AllTests`) so a single `ios_unit_test` can run in isolation, e.g.:

```sh
source ~/.zshrc 2>/dev/null; python3 build-system/Make/Make.py --overrideXcodeVersion --cacheDir ~/telegram-bazel-cache \
 test --configurationPath build-system/appstore-configuration.json \
 --gitCodesigningRepository git@gitlab.com:peter-iakovlev/fastlanematch.git \
 --gitCodesigningType development --gitCodesigningUseCurrent --target //submodules/TextFormat:TextFormatTests
```

The first app-side `ios_unit_test` is `//submodules/TextFormat:TextFormatTests` (the mention/date link codecs). An `ios_unit_test` here needs an `ios_test_runner` pinned to a real device/OS (e.g. `iPhone 17` / `26.5`) — the default runner picks an invalid device and the test process exits 15. **Run new targets via `--target`, not the default suite:** `Tests/AllTests` currently references a dangling `//submodules/TgVoipWebrtc:TgCallsTests`, so the default would fail to build until that suite is repaired.

Pure C++ units have host `cc_test`s that bypass Make.py entirely (macOS build, no codesigning):
`./build-input/bazel-9.2.0-darwin-arm64 test //submodules/TgVoipWebrtc:streaming_audio_renderer_test --test_output=all`
(likewise `:mtproto_ice_transport_test`). `//third-party/libprisma:SyntaxHighlighterTests` (added
2026-09-25) is the same kind of target outside tgcalls: it compiles only libprisma's pure-C++ core
(not `Syntaxer.mm`, which needs UIKit) plus header-only `boost_regex`, loads the real shipped
`grammars.dat` (passed via the target's `args = ["$(location Resources/grammars.dat)"]`), and pins the
**code-block highlighter recursion bound** — highlighting a `brightscript` block whose grammar has a
token cycle used to recurse `tokenize()`/`matchGrammar()` without limit and kill the process with a
stack overflow (a remote DoS: the block is highlighted on receipt). `SyntaxHighlighter::kMaxTokenizeDepth`
(128; ~1.1 KiB of stack per level, measured) caps it and degrades gracefully to plain text at the cap.
Upstream `TelegramMessenger/libprisma` does **not** fix this (checked at HEAD 07ff1fcc, 2026-09-21):
the recursion has no bound there and the regenerated `grammars.dat` still ships the cycle, so pulling
upstream is not a substitute for the cap. They follow a plain `CHECK_TRUE` + `main()` pattern, are listed
explicitly in `submodules/TgVoipWebrtc/BUILD` (group sources are not globbed), and must be added to the
`exclude:` list in `tgcalls/Package.swift` so SwiftPM does not compile their `main()`. The first run compiles
WebRTC for the host (~2.5 min); later runs take seconds. Note the binary is version-stamped and
arch-suffixed (`bazel-9.2.0-darwin-arm64` since 2026-09-14, was `bazel-8.4.2-darwin-arm64`), not the
bare `bazel-8.4.2` the tgcalls CLAUDE.md names; `versions.json` is the single pin.

`//submodules/MetalEngine:MetalPipelineCacheTests` (added 2026-10-01) is the first host `swift_test`, run
the same way (`… bazel-9.2.0-darwin-arm64 test //submodules/MetalEngine:MetalPipelineCacheTests`; one test
via `--test_filter=MetalPipelineCacheTests/<name>`, comma lists are not supported). It compiles only
`MetalPipelineCache.swift` + `MetalBinaryArchiveSerialization.swift` and runs on the Mac's GPU, because
the simulator has no binary archives (serializing fails an assertion there). It pins an **Apple bug**: a
`MTLBinaryArchive.serialize(to:)` whose final file move fails does not throw — Metal frees the error on
the compiler's reply thread and the caller crashes retaining it (device crash on iOS 26.3, reproduced on
macOS 27). `MetalBinaryArchiveSerialization` hooks that one `NSFileManager` call to keep the error alive;
the target sets `NSZombieEnabled` so a regression fails deterministically.

`//submodules/UrlWhitelist:UrlWhitelistTests` (added 2026-10-06) is a host `swift_test` like
`MTProtoRustEngineMappingTests`, run the same way. It pins `externalUrlWithLoginPart`, the check that
makes opening a link with a login part in front of its host ask first: in
`https://telegram.org∕test∕@evil.org` the `∕` (U+2215) is not a slash, so `telegram.org∕test∕` is a user
name and the link opens evil.org. The check runs in the external-URL opener (`openExternalUrlImpl`),
which every external link leaves through, including the openers that never ask about anything (admin
log, Instant View), and its parse is the opener's own (`canonicalExternalUrl`, now in `UrlWhitelist`).
The prompts in `openUserGeneratedUrl` and `TextLinkHandling` also flag such links. Every prompt, and
the title of every long-press link menu (`displayUrlRevealingLoginPart`; Copy still copies the link as
written), shows the address without the login part, and accepting a prompt records the address
(`noteLoginPartConfirmed`) so the opener does not ask a second time. The check stays out of `parseUrl`,
whose `concealed` flag also makes the shared-links list title a link with its whole address instead of
its host.

### Updating the running simulator after a rebuild (whole-`.app` copy)

`simctl install` will NOT replace an already-installed app when the build number is unchanged (installd keeps a hard-link cache), so a rebuilt binary silently doesn't take effect. **Preferred fix: copy the whole freshly-built `.app` over the installed bundle in place.** This is more robust than swapping only the `Frameworks/TelegramUIFramework` binary (no risk of app↔framework version skew), and it preserves the account/login because the **data container is a separate path** (`.../data/Containers/Data/Application/<uuid>/`, keyed by bundle id) — only the **bundle** container is replaced, and the install-DB entry stays valid since the path + bundle id are unchanged.

```sh
K3=FA6F7462-AA97-42FE-9E57-8DA0593CE756   # iPhone 17 Pro K3 (use the dedicated K-sims, not the shared default)
BUNDLE=ph.telegra.Telegraph
# Fresh build output. Go through `bazel-bin`, which bazel repoints at
# the LAST BUILD's configuration. Do NOT `find` under `bazel-out`: it keeps one directory per
# configuration you have ever built, so `… | head -1` can hand you a stale *device* archive. That copies
# fine and then refuses to launch ("request was denied by service delegate (SBMainWorkspace)"), which
# reads like a crash rather than an arch mismatch — and `lipo -archs` does not disambiguate, since device
# and simulator arm64 slices both report plain `arm64`.
# SOURCE THE .ipa, NOT `Telegram_archive-root/`. The archive-root directory is only rewritten when
# the packaging step actually re-runs; on a cache-hit incremental build it is left behind holding a
# PREVIOUS build's binaries, and nothing about it looks stale (see the note below). The .ipa is
# rewritten every build and carries a real mtime.
STAGE=$(mktemp -d)
unzip -q -o bazel-bin/Telegram/Telegram.ipa -d "$STAGE"
SRC="$STAGE/Payload/Telegram.app"
DEST="$(xcrun simctl get_app_container "$K3" "$BUNDLE" app)"   # installed bundle path
# GUARD before the destructive rm: never rm the installed app unless SRC actually resolved,
# or a failed cp leaves the sim with NO app installed (relaunch then fails).
[ -x "$SRC/Telegram" ] || { echo "no fresh bundle at SRC=$SRC — aborting"; exit 1; }
xcrun simctl terminate "$K3" "$BUNDLE" 2>/dev/null            # terminate before replacing the running binary
rm -rf "$DEST" && cp -Rp "$SRC" "$DEST"                        # replace bundle in place; data container untouched
xcrun simctl launch "$K3" "$BUNDLE"
```

The sim ignores code signing, so the unsigned bundle runs fine.

**`Telegram_archive-root/` goes stale silently — do not install from it.** It is written by the
Make.py wrapper's post-build packaging, which only re-runs when the packaging action itself is not a
cache hit. After an incremental build (`Build completed successfully, 21 total actions`, ~30s) the
directory is simply left as it was, still holding a PREVIOUS build's binaries, while
`bazel-bin/Telegram/Telegram.ipa` *is* rewritten. Demonstrated 2026-08-20: one build produced an
archive-root framework and an .ipa framework with different md5s, the archive-root one still
containing symbols from source that had already been reverted.

There is no cheap way to eyeball the staleness, which is what makes it dangerous:
- **mtime cannot detect it.** Bazel stamps a reproducible `Jan 1 1980` on everything under
  archive-root, so the stale copy and a fresh one look identical.
- The stale bundle launches and behaves normally — it is simply *older code*. The failure mode is
  "I am debugging behaviour that is not in the source I am reading", which can burn an entire
  investigation before anyone suspects the bundle. It did exactly that once already.

So the recipe above unzips the `.ipa` instead. If you ever do copy from archive-root, verify first:
`md5 -q .../Telegram_archive-root/Payload/Telegram.app/Frameworks/TelegramUIFramework.framework/TelegramUIFramework`
against the same path unzipped out of the `.ipa`, and treat a mismatch as stale.

(The older framework-only `cp` of `TelegramUIFramework` still works and is faster, but prefer the
whole-`.app` copy to avoid version skew.)

### Driving the simulator UI: use the Xcode MCP server

**XcodeBuildMCP is configured for this project** (`~/.claude.json` → `projects["…/telegram-ios"].mcpServers.XcodeBuildMCP`, run as `npx -y xcodebuildmcp@latest mcp`). Its tools appear as `mcp__XcodeBuildMCP__*` and are the way to **interact with** a running simulator — screenshots, `describe_ui` accessibility dumps, taps/swipes/typing, log capture. Reach for it whenever a change needs verification that a build alone can't give: flipping a Debug Settings flag, opening a chat, scrolling a list, checking that something rendered.

Do **not** fall back to `cliclick` / `osascript` / `screencapture -R` for this. Those need macOS Accessibility and Screen Recording privileges that the terminal running Claude Code does not have (`cliclick` reports "Accessibility privileges not enabled"; `screencapture -R` fails with "could not create image from rect"), and with several K-sims booted at once there is no way to identify the right Simulator window anyway. `xcrun simctl io <udid> screenshot` **does** work without extra privileges and is fine for a passive look, but it cannot drive anything.

If the `mcp__XcodeBuildMCP__*` tools are absent from a session's tool list (it has happened — the server is configured but its tools weren't exposed), say so and hand the interactive checks to the user rather than attempting the privilege-blocked fallbacks.

### Upgrading the vendored FFmpeg

FFmpeg is built from source by the `libffmpeg_build` genrule in `submodules/ffmpeg/BUILD`. Dropping in
a new `Sources/FFMpeg/ffmpeg-<ver>/` tree needs exactly two edits, both in that file (7.1.1 → 8.1.2,
done 2026-08-01, was a two-line change):

1. **`FFMPEG_VERSION`** — the only place the version is pinned. `build-ffmpeg-bazel.sh` takes it as
   `$5` and derives `$SOURCE_DIR/ffmpeg-$FF_VERSION`.
2. **Prune `ffmpeg_header_paths`** of headers the new release removed. That list doubles as the
   genrule's declared `outs`, each `cp`'d twice (to `Public/` and `Public/third_party/ffmpeg/`), so a
   header that no longer exists **hard-fails the build**. 8.x dropped `libavcodec/avfft.h`
   (deprecated lavc 60.25.100, removed in FFmpeg 8); nothing here uses the avfft API.

Two non-obvious things when surveying for breakage:

- **App consumers are guarded lower-bound only** (`#if LIBAVFORMAT_VERSION_MAJOR >= 59`, and its
  `< 59` complement), so removed APIs sit in dead branches and majors can climb freely — 8.1.2 is
  lavc/lavf 62, lavu 60, swr 6. That is why `avcodec_close`, `swr_alloc_set_opts` and
  `av_get_default_channel_layout` still appear in `FFMpegBinding/Sources/*.m` and
  `tgcalls/group/{AudioStreamingPart*,VideoStreamingPart}.*` despite being gone from FFmpeg 8.
- **Don't validate configure component names by grepping `configure`** — it derives them at runtime
  from `libavformat/allformats.c` and `libavcodec/{allcodecs,parsers,bitstream_filters}.c` /
  `hwaccels.h` (`extern const FFOutputFormat ff_<name>_muxer;`). Always control-diff the result
  against the outgoing version, because several names in the flags (`libopus` demuxer/parser, `mp3`
  parser, `libvpx_vp9` encoder) have always been inert and otherwise read as a fresh regression.

The `pkg-config` shim in `Sources/FFMpeg/` strips version qualifiers and always answers `--exists`,
so `require_pkg_config "dav1d >= 1.0.0"` cannot fail on version — only the wrapper's compile against
the vendored headers can. Verification is the full `Make.py build` (there is no isolated smoke
build); afterwards confirm `bazel-bin/submodules/ffmpeg/Public/libavutil/ffversion.h` actually reports
the new version rather than trusting a cache hit. Note that a header dropped from the list lingers
under `bazel-bin/.../Public/` — bazel does not delete undeclared outputs, so check its mtime before
believing it is live. `spm-files/` and `xcode-files/` likewise keep stale copies; both are gitignored
and regenerated by `Make.py generateProject` / `spm`.

### Upgrading the vendored SQLCipher

`submodules/sqlcipher` is the SQLCipher **amalgamation** (one `Sources/sqlite3.c` plus the three
public headers), not the source tree. Upgraded 4.4.2/SQLite 3.33.0 -> 4.19.0/SQLite 3.53.4 on
2026-09-22, which picked up the upstream WAL-reset corruption fix (SQLite 3.51.3) that matters
because the app and the notification extension write and checkpoint the same WAL database.

A SQLCipher release archive does not ship the amalgamation; generate it from the tree:

```sh
./configure --with-tempstore=yes --enable-fts5 \
  CFLAGS="-DSQLITE_HAS_CODEC -DSQLITE_EXTRA_INIT=sqlcipher_extra_init -DSQLITE_EXTRA_SHUTDOWN=sqlcipher_extra_shutdown -DSQLCIPHER_CRYPTO_CC" \
  LDFLAGS="-framework Security -framework Foundation"
make sqlite3.c sqlite3.h     # also copies sqlite3ext.h and ext/session/sqlite3session.h to the root
```

(needs `/usr/bin/tclsh`; the configure flags do not bake into the amalgamation, every feature is
still selected by the `-D`s in `BUILD`). Copy `sqlite3.c` to `Sources/` and the three headers to
`PublicHeaders/sqlcipher/`. Then check `sqlite3.c` for `#define SQLITE_VERSION` and
`CIPHER_VERSION_NUMBER` rather than trusting the archive name.

Non-obvious points:

- **Since SQLCipher 4.6 `sqlcipher.c` `#error`s** unless `SQLITE_EXTRA_INIT=sqlcipher_extra_init`,
  `SQLITE_EXTRA_SHUTDOWN=sqlcipher_extra_shutdown`, `SQLITE_THREADSAFE` in {1,2} and
  `SQLITE_TEMP_STORE` in {2,3} are all defined. `BUILD` and `Package.swift` carry them; keep the two
  in sync.
- **Keep the amalgamation pristine.** The 2021 copy carried a hand edit that normalised SQLite's
  `MIN`/`MAX` macros to the `<sys/param.h>` spelling so clang's `-Wambiguous-macro` stayed quiet
  under `enable_modules`. That is now `-Wno-ambiguous-macro` in `BUILD` instead; do not re-patch.
- **Behaviour changes that touch `SqliteValueBox`:** `PRAGMA cipher_memory_security = OFF` is a
  no-op (memory security can only be turned on); `PRAGMA key` on a connection that has already
  decrypted a page is ignored with a log line, so re-keying means opening a new connection (which
  the value box already does); a keyless `PRAGMA cipher_plaintext_header_size` is still a silent
  no-op and only `cipher_default_plaintext_header_size` applies before `PRAGMA key`.
- The `-W#warnings` suppression is for `"gethostuuid() is disabled."`, which the amalgamation
  emits on iOS. A `clang -fsyntax-only` pass with the `BUILD` defines is a 1-second smoke check.

**Self-heal policy in `SqliteValueBox`** (2026-09-22, tested in
`Postbox/Tests/SqliteValueBoxRecoveryPolicyTests.swift`): the app and its extensions share one
WAL database, so deleting it to recover is only ever done by the owning read-write connection
(`removeDatabaseOnError` is folded with `!isReadOnly && !isTemporary` in `init`), always as the
whole `db_sqlite` + `-wal` + `-shm` set (`removeDatabaseFiles`), and never on a transient result.
`SQLITE_BUSY`/`LOCKED`/`IOERR`/`CANTOPEN`/… from the schema probe are not a verdict about the
file: the probe returns `.unavailable`, lock contention (`BUSY`/`LOCKED`/`PROTOCOL`) is retried
exactly once (each attempt already waits the 5 s busy timeout), and then the owner crashes
without touching files while a non-owner reports no database. The crash is deliberate: the owner's
`.error` result is mapped to a permanent `.upgrading(0.0)` by `accountWithId`, so returning nil
would hang the launch screen. Probe results (busy, disk full, I/O) never
feed a deletion fallback: those clear on relaunch or when space is freed, and deleting the account
database is not a recovery. The one valve is on a failed `sqlite3_open_v2` (`Database.open`): the
owner records the failure in `db_sqlite-open-failures` and wipes on the third consecutive one, but
only for errnos deleting could fix (EISDIR, EIO, unknown); EPERM and EACCES (data protection
before first unlock), descriptor exhaustion, out of memory and disk full never advance it, and a
successful open resets it. The same fold gates in-place reencryption
(`forceEncryptionIfNoSet`): a non-owner never rewrites the live file. Deleting `db_sqlite` alone
was the mechanism behind repeated "Corrupted DB at step, dropping": the relaunched app shared the
extension's still-mapped `-shm` with a different WAL file. `.tempkey` creation in `BuildConfig.m`
is serialized across processes with `flock` on `.tempkey.lock` for the same reason (two generators
would each key a database with material only one of them persisted).

## Code Style Guidelines
- **Naming**: PascalCase for types, camelCase for variables/methods
- **Imports**: Group and sort imports at the top of files
- **Error Handling**: Properly handle errors with appropriate redaction of sensitive data
- **Formatting**: Use standard Swift/Objective-C formatting and spacing
- **Types**: Prefer strong typing and explicit type annotations where needed
- **Documentation**: Document public APIs with comments

## Project Structure
- Core launch and application extensions code is in `Telegram/` directory
- Most code is organized into libraries in `submodules/`
- External code is located in `third-party/`
- App-side unit tests are minimal: the first `ios_unit_test` (`//submodules/TextFormat:TextFormatTests`) was added 2026-06-19 (run via `Make.py test --target` — see Build). `//submodules/Postbox:PostboxTests` (added 2026-09-18) covers `SqliteValueBox` and individual Postbox tables directly against an in-memory value box, using `@testable import Postbox`; add new Postbox regression tests under `submodules/Postbox/Tests/`. `//submodules/TelegramCallsUI:TelegramCallsUITests` (added 2026-09-18) drives `SharedCallAudioContext` through a fake `ManagedAudioSession` (the protocol is implementable from outside since `ManagedAudioSessionControl` gained a public closure initializer); creating the context builds a real tgcalls audio device, which is fine in the simulator test process. `//submodules/TelegramAudio:TelegramAudioTests` (added 2026-09-22) covers pure `ManagedAudioSessionType` helpers such as `voiceMessageRecording(beginWithTone:pauseMusicOnRecording:)`, the mapping the voice recorder uses for the Data & Storage "Pause Music While Recording" toggle, and the **holder-precedence policy of the real `ManagedAudioSessionImpl`** (it is constructible in the test process; push with `manualActivate` and never touch the control, so the process's `AVAudioSession` is left alone). The load-bearing rule pinned there: a `.voiceCall` holder is never displaced, not even temporarily, by a recording that mixes with other audio, because deactivating it makes `PresentationCall` drop its audio-session control. The recorder itself (`ManagedAudioRecorder`) needs a live `MediaManager` and real audio units, so keep session-policy decisions in testable helpers rather than in it. `//submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode:ChatTextInputPanelNodeTests` (added 2026-09-22) covers the legacy composer's Text Size metrics (`ChatTextInputFontMetrics.swift`) against a real `ChatInputTextView` measurement; linking the panel into a test bundle needed `MediaPlayer` declared on `LegacyComponents`. `//submodules/TelegramUI/Components/PeerInfo/PeerInfoPaneNode:PeerInfoPaneNodeTests` (added 2026-09-24) covers `peerInfoMessageChatDestination`, the chat that shared-media "View in Chat" opens. It is the chat the media tab *lists* — neither the peer the profile describes (a secret chat's profile describes the user, so use `data.chatPeer`) nor the chat the message is stored in (a supergroup's tab lists its pre-migration basic group's messages, which open in the supergroup). A user's profile opened from a channel's direct messages lists that channel's thread, which is opened directly: `navigateToForumThread` addresses a topic by an Int32 message id and cannot reach a monoforum thread keyed by a user id. `//Telegram/NotificationService:NotificationServiceTests` (added 2026-09-24) covers the notification service extension's naming of the recipient account when several are signed in (`NotificationRecipientAccount.swift`). On iOS 15+ the system draws a communication notification's title from the sender `INPerson`'s `displayName` and hides `content.subtitle` (measured on 18.6 and 27), so anything the title must show goes into the sender's name. `NotificationContent` is private, so keep such decisions in testable helpers. `//submodules/TelegramUI/Components/Chat/EditableTokenListNode:EditableTokenListNodeTests` (added 2026-09-24) covers `EditableTokenListPeerAlias`, the one decision a chat picker's token (e.g. Add Chats for a folder) uses for both its title and its avatar, so a Saved Messages token draws the Saved Messages icon rather than the account's photo; `PresentationStrings` cannot be built in a test process (it asserts without the app bundle's `PresentationStrings.data`), so the alias is strings-free and the title stays in `ContactMultiselectionController`. `//submodules/PeerAvatarGalleryUI:PeerAvatarGalleryUITests` (added 2026-09-25) covers `avatarGalleryUserEntries`, the one builder both user-gallery paths use: slot 0 is drawn from the peer record's current photo, but `photos.getUserPhotos` keeps its order when an older photo is made the main one again (the server swaps a copy under a **new photo id** into that photo's place), so the current photo is looked up in the list and moved to the front (a personal photo moves the contact's current public photo instead, and a current photo the list does not contain gets its own slot) rather than drawn over whatever the list starts with, which showed it twice and hid that photo. Because of the new id, `_internal_updatePeerPhotoExisting` copies the chosen photo's downloaded sizes to the returned photo's files; the returned photo's sizes and its `photo_small`/`photo_big` ("a"/"c") are byte-identical to the chosen photo's (measured in the sim media cache). The result's user list does not carry the new photo for the account itself, so the same transaction also sets `TelegramUser.photo` from the returned photo; without that the record changed only in a later transaction and every avatar downloaded the photo again. `//submodules/MediaPlayer:UniversalMediaPlayerTests` (added 2026-09-26) drives a real `ChunkMediaPlayerV2` (wait for `MediaPlayerNode.videoLayer`, which the node creates asynchronously, before constructing it) from an `.externalParts` promise. With no parts the player stays buffering, so the clock only moves on a seek; a part backed by an empty `TempBox` file lets it run, because buffering is decided from part times alone. It pins the end of playback: the player keeps a 0.1 s end tolerance for HLS chunks that do not line up with the declared duration (`ChunkMediaPlayerV2.endTolerance`; do not remove it), so a video no longer than that is at its end from position 0 and is not played — its clock never moves, even on a later `play()`. Looping one would seek to where the clock already is, and that no-op `seek` re-runs the end check synchronously until the stack overflows. The RichTextEditor SwiftPM package keeps its own suite (`swift test` / `Scripts/iostest.sh`). Most modules still have no tests.

## RichTextEditor editor & the `ChatInputContent` composer

A from-scratch WYSIWYG rich-text editor (`submodules/TelegramUI/Components/RichTextEditor`) is the native chat-composer backend — by default a **dual-field switch** (the composer uses the legacy input and latches to the native editor only when content becomes legacy-non-representable); the `forceNewTextInput` experimental flag (Debug Settings ▸ "Force Text Field v2") forces always-native. (This inverted the earlier default+`forceLegacyTextInput`-opt-out scheme.) `ChatInputContent` (a TelegramCore-native value model) replaced `NSAttributedString` as the composer currency. The app-side integration — the model and its load-bearing invariants, composer ↔ editor wiring, the formatting-menu / custom-emoji-mention-date / code-block / inline-media round-trips, rich-message send / edit / pending-display, the long-press-Send send-options preview, **media pre-upload** (attached media uploads immediately and is promoted to cloud media, surviving the editor closing and reopening), and draft persistence (local, cross-device media sync, re-login restore) — lives in [`docs/richtext-composer.md`](docs/richtext-composer.md). Editor internals (the TextKit seam, layout) are the editor's own `submodules/TelegramUI/Components/RichTextEditor/CLAUDE.md` — including the **code-block language field + syntax highlighting** (2026-08-25): a code block's language is authored in an always-visible editable line (a second leaf region on the box, so `activeStack` must resolve a box by its PRIMARY region or edits land in the wrong layout), and libprisma highlights code in both editor hosts through a host-provided seam, since the package cannot depend on the highlighter. The renderer half, and the three silent pre-existing defects that had to be fixed before any highlighting was visible, are in [`docs/instantpage-richtext.md`](docs/instantpage-richtext.md). Also **InstantPage V2 layout parity** (2026-08-14): the editor lays text out pixel-identically to the V2 renderer via the host-supplied `RichTextRenderMetrics` contract, and BOTH surfaces (composer + article editor) use the chat-message metrics, so what you type reads like the message sent. Message **rendering** is [`docs/instantpage-richtext.md`](docs/instantpage-richtext.md).

## Embedded watch app (`Telegram/WatchApp`)

A standalone watchOS Telegram client (developed in the separate `~/build/tgwatch` repo) is vendored into this repo at `Telegram/WatchApp/` and can be embedded into the **device** IPA under `Telegram.app/Watch/`. It is built by `xcodebuild` (not Bazel) and codesigned by the Bazel build.

**Build it:** add `--embedWatchApp` to a Make.py **device** build (`--configuration=debug_arm64` or `release_arm64`) together with `--watchApiId`, `--watchApiHash`, `--watchSigningIdentity`, `--watchProvisioningProfile`. Off by default (it adds a ~4-min xcodebuild step); simulator builds never embed, and the default `debug_sim_arm64` build is unaffected.

**`Telegram/WatchApp/` is a synced snapshot — do not hand-edit it.** The source of truth and dev tooling live in the `tgwatch` repo. To change the watch app, edit it there, then re-sync with `tgwatch/tools/export-sources.sh /abs/path/to/telegram-ios/Telegram/WatchApp` and commit the result. The committed `tgwatch.xcodeproj` is generated (kept via a `!tgwatch.xcodeproj` negation in `Telegram/WatchApp/.gitignore`, since the root `.gitignore` ignores `*.xcodeproj`); `.build`/`.swiftpm`/`xcuserdata` are excluded.

**How it's wired:** `//Telegram:TelegramWatchApp` (rule in `Telegram/prebuilt_watchos.bzl`) runs in **two actions**: `PrebuiltWatchosCompile` (`Telegram/prebuilt_watchos_compile.sh`) runs xcodebuild on the snapshot in a writable temp copy, baking the api credentials and the watch bundle id (as `PRODUCT_BUNDLE_IDENTIFIER`, from which the snapshot's Info.plist derives `WKCompanionAppBundleIdentifier` via `$(PRODUCT_BUNDLE_IDENTIFIER:base)`) but leaving PLACEHOLDER versions, emitting an unsigned `.app`; `PrebuiltWatchosPatchSign` (`Telegram/prebuilt_watchos_patch.sh`) then rewrites the **two** per-build Info.plist version keys (`CFBundleShortVersionString`, `CFBundleVersion`) and codesigns the `.app` + nested `TDLibFramework.framework` (identity + the watchkitapp profile from `--define`s). The result feeds the `Telegram` `ios_application`'s `watch_application` slot (gated by the `//Telegram:embedWatchApp` flag). The rule takes `bundle_id` (set to `"{telegram_bundle_id}.watchkitapp"` in `Telegram/BUILD`).

**The split exists for caching, and the split's whole value is that the version stays out of the compile action.** `--define=buildNumber` changes on every CI pipeline, so with the version baked by xcodebuild the compile key moved every build and the ~4-min xcodebuild ran every time. Deferring only the version keeps the compile action's key stable (verified with `aquery`: the `PrebuiltWatchosCompile` ActionKey is identical across `--define=buildNumber` and `--define=watchSigningIdentity` changes, while the patch key moves). The api id/hash and bundle id stay baked because they are stable per host configuration and xcodebuild must own the bundle id anyway — and none of these reach the compiled binary, they land only in the Info.plist (via `$(...)` substitution and a runtime `Bundle.main.object(forInfoDictionaryKey:)` lookup in `Secrets.swift`), so deferring the version cannot change the compiled output. Consequence to know: the nested `TDLibFramework` keeps the placeholder `0.0`/`0` version — only the watch app's own Info.plist is version-verified against the host.

**Do not add `"local": "1"` to the compile action's `execution_requirements`.** It looks harmless next to `no-remote-exec`, and it silently defeats every cache. Measured against the vendored bazel 8.4.2 with `--execution_log_json_file`: `{no-sandbox, no-remote-exec, local, requires-network}` reports `cacheable=false, remoteCacheable=false` and never takes a `--disk_cache`/`--remote_cache` hit, while the same set *without* `local` reports `cacheable=true, remoteCacheable=true, remotable=false, runner=local` — i.e. `no-remote-exec` + `no-sandbox` already pin execution local and unsandboxed, so `local` buys nothing and costs all caching. This is exactly why the original 2026-05-28 "Enable watch app cache" change (`0be58ef45a`) was inert: it flipped `no-remote` to `no-remote-exec` but left `local` in place. The patch+sign action *does* keep `local` + `no-remote`, deliberately: its provisioning-profile path is machine-specific and the profile's *contents* are not an action input, so a shared cache would serve wrongly-signed bundles rather than merely miss.

**Non-obvious invariants** (also in the `.bzl` comments): `AppleBundleInfo`'s public init is banned — use the internal `new_applebundleinfo`; `watch_application` requires BOTH `AppleBundleInfo` (with a non-None `infoplist` File) AND `WatchosApplicationBundleInfo`; the embedded watch app's `CFBundleShortVersionString`/`CFBundleVersion` must exactly equal the host's (sourced from `versions.json['app']` + `--define=buildNumber`); the host does NOT re-sign the embedded watch app, so the worker must sign it; the watch bundle id `ph.telegra.Telegraph.watchkitapp` must track the host `telegram_bundle_id`.

**Status:** verified with **development** signing on `debug_arm64` only. Open follow-ups before App Store shipping: secure timestamp (drop `codesign --timestamp=none`), distribution profile (`get-task-allow=false`), `release_arm64` + `altool --validate-app`, and committing a `Package.resolved` for hermetic remote-SwiftPM resolution.

## iOS 26/27 windows and touch delivery

Three measured facts that are invisible from the code and each cost an investigation
([`docs/ios27-windows-and-touches.md`](docs/ios27-windows-and-touches.md) has the evidence):

- **Never call `+[UIRemoteKeyboardWindow remoteKeyboardWindowForScreen:create:]`** — it traps
  (`brk #0`) when the binary is linked against the iOS 27 SDK, which this project is. Get the keyboard
  window via `-[UIApplication internalGetKeyboardForScene:]`, which goes through the window scene's
  `keyboardSceneDelegate`. It legitimately returns nil (keyboard never created, or keyboard UI hosted
  out of process), so nil must mean "no keyboard surface", never a missing window.
- **An app can never place a window above the keyboard.** `UIRemoteKeyboardWindow` is at level
  `1e7 + 1` and `-[UIWindow _adjustedWindowLevelFromLevel:]` clamps app windows to `1e7`. Content that
  must appear over the keyboard has to be parented *into* the keyboard window — which is what
  `NavigationController`'s `globalOverlayContainerParent` and `GlobalOverlayPresentationContext` do.
- **A layer that renders nothing receives no real touches**, although `-hitTest:` still returns it:
  `backgroundColor` unassigned (`layer.backgroundColor == nil`) and no `contents` means taps never
  arrive. Transparent `layer.contents` fixes it; a near-zero background alpha only works above an
  undocumented threshold. Watch for `NavigationBackgroundNode(color: .clear)`, whose `updateColor`
  early-return means the colour is never assigned even once.

## Swift 6.4: `[weak]` in a local closure that also captures a `var`

Swift 6.4 (Xcode 27) miscompiles this shape, at `-Onone` as well as `-O`: a closure literal stored in
a local `let`, with a `[weak x]`/`[unowned x]` capture list, that **also captures a mutable local** and
never escapes (only called directly). `MandatoryAllocBoxToStack` moves the capture box to the stack and
destroys it right after the closure is formed, before the closure is ever called. For an NSObject-derived
`x` the load then reads a dead slot (on device it had been reused as a `swift_beginAccess` record and
crashed in `objc_msgSend`; macOS 27 traps "not in the weak references table"); for a native Swift class
it silently returns nil, so `guard let x else { return }` skips the work. Closures passed straight to a
non-escaping parameter, or a declared `weak var w = x` captured instead, are compiled correctly.

Write such a closure with a strong capture (`{ [self] i in`), which cannot cycle because it never
escapes. It has bitten twice: `processPollOptionItem` (ComposePollScreen, 2026-09-25) and the
identical `processTodoItemItem` (ComposeTodoScreen, 2026-10-02, App Store crash on 12.10/35210).
In a binary the fingerprint is a weak/unowned `…Init` whose stack slot gets `…Destroy`ed before the
first call to a closure specialized as `Arg[n] = Stack Promoted from Box`; a scan of every binary in
the 2026-10-02 debug build found no other site.

## Per-module `-O` and pixel loops

Almost every submodule builds `-Onone` under `--configuration=debug_*`. Exactly **two** override it with
`copts = ["-O"]`: `submodules/GradientBackground` and `submodules/AnimatedStickerNode`. Nothing about a
call site reveals which side of that line it is on.

This matters whenever per-pixel work is written in Swift. Measured over 1.41 Mpx, the wallpaper
soft-light blend runs **3.4 ms at `-O` and 1083 ms at `-Onone`** — the same source, a factor of ~300,
no build error, no symptom but a hitch. A hand-written loop that replaces a CoreGraphics call can
therefore be *much* faster in release and *much* slower in debug, which is the one direction a
release-only benchmark cannot show you.

Consequences:

- **Benchmark at the optimization level the module actually builds at.** `swiftc -O` numbers are
  meaningless for an `-Onone` module.
- `composeSoftLightOverBackground` lives in `GradientBackground` **only** because of that copt, and is
  called from `WallpaperBackgroundNode` (which is `-Onone`). Moving it "back where it belongs" for
  tidiness silently reintroduces the 1083 ms. The function comment says so; keep it.
- Swift's wide-SIMD lowering is poor at `-Onone` — `SIMD4`/`SIMD16` arithmetic there is *slower* than
  scalar (measured 1083 ms vs 448 ms for the same blend). SIMD only pays inside an `-O` module.
- Bulk `SIMD` conversions (`loadUnaligned` into `SIMD4<UInt8>`, `SIMD16<UInt8>(floatVector)`) lower
  badly even at `-O`: per-lane element access beat a 32-bit word load 3.3 ms vs 28.6 ms on the same
  kernel. Measure the load shape; do not assume the "vectorized-looking" one wins.

Two things about reimplementing a CoreGraphics operation, both learned the hard way here:

- **CoreGraphics' `.softLight` is not the PDF/CSS soft light.** It omits the `D(Cb)` highlight branch,
  so it is linear in the source with no kink at 0.5 (verified against a full 256x256 grid). A
  spec-faithful reimplementation is visibly wrong. `±1/255` is the achievable floor against CG's
  internal fixed-point rounding — float, double, integer and two-step formulations all cap there.
- **`vImageScale_ARGB8888` is not CoreGraphics' resampler.** It is ~5.5x faster for the wallpaper's
  36x80 -> full-screen stretch but moves the composed result by up to 5/255, so that stretch stays on
  `CGContext.draw`.

And the trap that produced a shipped-and-reverted wrong image: **the wallpaper pattern is transparent.**
`WallpaperResources.swift` builds it with `DrawingContext(..., clear: true)` and no `opaque:`, over a
`.clear` background, so its alpha decides which pixels blend at all. Compositing it into an opaque
buffer silently discards that and leaves untouched regions reading uninitialised memory. Any fixture
used to validate the compose must use a transparent, premultiplied, **two-colour** pattern — the symbol
image is tinted white while `customPatternColor` may be black, so "the pattern is monochrome" is false.

## Neighbor descriptors

A `ListViewItem` does not see its neighbors. It sees `ListViewItemNeighbors` — two `AnyEquatable`
descriptors that the adjacent items published via `neighborDescriptor`, read through facet protocols
(`ItemListNeighborFacet`, `HeaderNeighborFacet`, and module-local ones). `previousItem:`/`nextItem:`
no longer exist on `nodeConfiguredForParams`, `updateNode`, or `ListViewItemNode.layoutForParams`.

**A descriptor must encode everything a neighbor reads.** `ListViewImpl` relayouts a row exactly
when its `ListViewItemNeighbors` value changes (`ListViewItemNode.appliedNeighbors` vs
`ListView.neighbors(at:)`), so a fact omitted from a descriptor goes stale on screen. When adding a
neighbor-dependent behavior, add the fact to the neighbor's payload — never widen the API back to
passing items.

`neighborDescriptor` has **no default implementation**, deliberately. A conservative default would
compile everywhere while making un-migrated items force a relayout on every transaction — worse
than the policy it replaced, and silent. `AnyEquatable.noNeighborInfluence` is the one-line answer
for items whose neighbors read nothing about them.

`nil` on a side means *no neighbor*; a non-nil descriptor whose facet does not resolve means *a
neighbor that publishes nothing relevant*. Several items depend on that distinction
(`ContactsPeerItem` renders `first` and `firstWithHeader` differently).

**Header families.** Most bespoke neighbor logic was a concrete-type cast asking "does this
neighbor participate in my header runs". That is a `ListViewItemHeaderFamily` tag on
`HeaderNeighborFacet`; consumers that group with any header-bearing neighbor ignore it, narrow ones
compare it. This also removes cross-module type coupling — `ContactListActionItem` checks
`.contactList` rather than importing `ContactsPeerItem`.

**When migrating a new item, grep for more than `previousItem as?`.** The original sweep found eight
neighbor reads only after the parameters were deleted, because they used `is <Type>`, helper
parameters named `(top:bottom:)`, or bare `== nil` presence checks. Note also that `previousItem` is
an overloaded name in this codebase: `let previousItem = self.item` inside a node's `asyncLayout`
means the node's *previous item state*, nothing to do with neighbors.

Types: `Display/AnyEquatable.swift`, `Display/ListViewItemNeighbors.swift`,
`ItemListUI/ItemListNeighborFacet.swift`,
`ChatMessageItemCommon/{ChatHistoryItemNeighbors,ChatMessageMergeFingerprint}.swift`.

## View frame ownership

A view does not control its own `frame`. The parent (or a layout system) sets the frame; the view positions its own subviews against `self.bounds` in response.

This matters in two places specifically:

- **Reusable components (`UIView`/`ASDisplayNode` subclasses).** Public methods like `update(...)` / `apply(...)` rebuild internal state, mutate child frames, and read `self.bounds` to lay them out — but they do not write `self.frame`. The caller has already chosen the frame; mutating it from inside the component overrides that choice and fights the parent's next layout pass.
- **`asyncLayout`-style content nodes.** The measure pass runs off-main and returns a size; the apply step runs on main and the chat layout system positions the node. A child view that writes `self.frame` from `update()` corrupts the size the parent just measured.

Rare exceptions: top-level view-controller views integrating with the system's first-responder/inset model. If you find yourself wanting `self.frame = …` from inside a child view, refactor so the parent positions it instead.

## ChatHistoryListNode composition

`ChatHistoryListNodeImpl` (`submodules/TelegramUI/Sources/ChatHistoryListNode.swift`) **composes** rather than inherits `ListViewImpl` (`submodules/Display/Source/ListView.swift`): it is an `ASDisplayNode` wrapper holding `private let listView: ChatHistoryListViewBackend` and exposes a deliberately narrowed surface (the `ChatHistoryListNode` protocol in `AccountContext` + curated concrete forwarders) instead of the full `ListView` API. `ListViewImpl` gained a `getCustomItemDeleteAnimationDuration` closure hook so the one former `override` works via composition.

`ChatHistoryListViewBackend` (`submodules/TelegramUI/Sources/ChatHistoryListViewBackend.swift`) is a **chat-specific protocol** abstracting the list backend: it declares exactly the members `ChatHistoryListNodeImpl` touches on its list view (nothing more), toward an alternative backend. That alternative is `CoreListChatHistoryBackend` (`submodules/TelegramUI/Sources/CoreListChatHistoryBackend.swift`), built on the from-scratch UIKit virtualized list `CoreVirtualListView` in `submodules/TelegramUI/Components/CoreList/` — its own [`CLAUDE.md`](submodules/TelegramUI/Components/CoreList/CLAUDE.md) documents the engine, animation model, and (vendored, K2-testable) demo/test project. It is keyed on message `stableId` and is the **default for the rotated history** (`makeListView(rotated:useCoreListBackend:)`); the `rotated: false` lists that share the initializer keep `ListViewImpl`, the `coreListChatBackend` Debug Settings switch still forces CoreList on, and `ios_killswitch_disable_corelist_chat_backend` rolls the whole thing back from the server. Read the chosen backend off `ChatHistoryListNodeImpl.usesCoreListBackend` rather than re-deriving that policy. The backend's own architecture, the load-bearing identity-rotation invariant, and its deferred items (still open: per-item animation selectivity, `stationaryItemRange` bounds; topic-header stacking is implemented but not yet runtime-verified) live in [`docs/chat/corelist-chat-history-backend.md`](docs/chat/corelist-chat-history-backend.md). `ChatHistoryListViewBackend` is standalone by design — it does **not** refine the shared `Display` `ListView` protocol even though most members overlap (deliberate; the chat surface owns its own contract). `ListViewImpl` satisfies it via a retroactive `extension ListViewImpl: ChatHistoryListViewBackend {}` in the same file, keeping the generic `Display` module free of chat concepts. When adding a `self.listView.<member>` access, add the matching member to this protocol (its build is the check). Construction-only config (`rotated`) is set on the concrete `ListViewImpl` inside the private `makeListView(rotated:)` factory before upcast, so it need not appear on the protocol — the pattern for anything set once at construction.

These invariants are **compiler-invisible** — getting them wrong silently breaks the app's primary scroll surface:

- **The π rotation stays on the wrapper** (chat is bottom-up). The wrapper keeps `transform = π` + a `rotated` flag; the child `listView` gets only `rotated = true` (identity transform). So `historyNode.view`/`.layer` remain the rotated surface, and rotation-coupled code — hitTest coordinate conversions, the blur `drawHierarchy` flip, the dust/delete layer, `.layer` animations, and the overscroll-overlay + snapshot-slide reparenting — **stays on `self` (the wrapper)** unchanged.
- **Only genuine scroll-surface concerns route to the child:** gesture recognizers (selection pan; external taps via `addContentGestureRecognizer`) attach to `self.listView.view` to share the scroll pan's simultaneity environment, and scroll-view access goes through the backend's narrow accessors (`bounces` / `contentHeight` / `setTopContentInset(_:)`), not a raw `scroller` (the `ListViewScroller` concrete type is no longer on the backend contract).
- **`let _ = self.view` in `init` is load-bearing.** The old inherited node was view-loaded eagerly (so `self.isNodeLoaded` was always true); `enqueueHistoryViewTransition` gates the history dequeue on it. The wrapper must force-load its view in init or off-screen nodes (created during thread switches) never become ready and `reloadChatLocation`'s completion never fires.
- **Item nodes are one level deeper.** Any `.supernode` chain / hierarchy-depth assumption passing through the history node gained one level (item → child `listView` → wrapper). E.g. `ChatMessageTransitionNode` converts item rects up `supernode?.supernode?.supernode?.view` (was 2 hops) so the wrapper's rotation is applied as an intermediate transform; a missing hop reflects effect-burst overlays ~180°.
- Child geometry is driven inside `updateLayout` via `transition.updateFrame(node: self.listView, …)` — the project never relies on ASDisplayNode's automatic `layout()`.

The public surface is being narrowed incrementally (e.g. `scroller` is fully removed from the backend, replaced by `bounces`/`contentHeight`/`setTopContentInset(_:)`; the `trackingOffset`/`beganTrackingAtTopOrigin` pair → `didInteractivelyDragFromTopOrigin`, now the only spelling anywhere: the pair is private to `ListViewImpl` and gone from both the `ListView` and backend protocols). Prefer intent-named accessors over re-exposing raw `ListView` state — **a pair of raw members is a pair a backend can half-implement.** The same lesson recurred with `enableUnreadAlignment`: the chat layer re-pinned the unread separator itself, gated on `itemNode.index`, which is `public internal(set)` to `Display` and so is *always nil* for a hosted node — the behavior was dead under the CoreList backend with no build error. It is now one `maintainsUnreadItemAlignment` parameter rather than the measure-then-reapply pair it decomposes into, because the two halves straddle the pass's inset change. Its sibling `itemNodeFrame(_:)` exists for the same reason: `ListViewItemNode.frame` is list-space only on `ListViewImpl`, so every chat-layer geometry read now goes through the backend. Those two were stubbed to `0.0`/`false` in `CoreListChatHistoryBackend`, which type-checked, read as plausible state, and silently disabled the chat's keyboard-dismissal snap-back; one combined member cannot be half-stubbed. `settledContentOffsets()` is the third instance and sharpens the rule: `visibleContentOffset()`/`visibleBottomContentOffset()` were separate members, and their one consumer *compares* them, so under a backend whose model and presented geometry diverge the two reads could describe different moments of the same animation — **a pair of raw members is also a pair a backend can half-sample.** The bottom offset is now off the contract entirely (it has no per-frame consumer at all), and the combined member returns both in the settled geometry, leaving the thresholds in the chat layer. `scrollGestureHostView` is the fourth instance and extends the rule past *members* to the node itself — **`listView.view` is a view a backend can host differently.** Three call sites wanted "the view the scroll pan is attached to" and spelled it `self.listView.view`, which is only `ListViewImpl`'s answer; under CoreList the pan sits two levels lower, on the scroll engine's content host. UIKit collects a touch's recognizers from the hit view UPWARD and both backends' `gestureRecognizerShouldBegin` enumerates `pan.view.gestureRecognizers`, so an ancestor is wrong in both directions and wrong silently: `ChatControllerNode`'s previewing-mode `hitTest` fallback could not scroll at all, and the two-touch selection pan lost its deferral so a selection drag scrolled the chat instead. Note the shape of the near-miss — the accessor was ADDED by the composition refactor to fix exactly this bug one level up, then re-encoded the same assumption in its body. (Note: most config knobs like `preloadPages`/`experimentalSnapScrollToItem` are set at deferred/lifecycle points — `viewDidAppear`, post-snapshot animation completions — not at construction, so they can't be hoisted into `makeListView` without changing behavior; and `transaction(stationaryItemRange:)` is load-bearing (`.Reload`/`.HoleReload` pass `(0, Int.max)`; the send-animation-v2 insertion path passes `(maxInsertedItem+1, Int.max)`).)

## InstantPage V2 & rich-text messages

Typed markdown with structure the regular message-entity set can't represent (headings, lists, tables, formulas, nested blockquotes) is sent as a **rich message** — a `RichTextMessageAttribute` carrying an `InstantPage`, drawn by `ChatMessageRichDataBubbleContentNode` via the **InstantPage V2** renderer (with AI-streaming progressive reveal, inline custom emoji, and entity cases). The detailed architecture and non-obvious invariants — streaming reveal, V2 table/text-box layout, custom-emoji & entity round-trips, task-list checkboxes, nested blockquotes, thinking blocks, the markdown send / edit / copy / paste paths, and surfacing rich-message media through the shared-media/gallery/preview pipelines via `Message.effectiveMedia` — live in [`docs/instantpage-richtext.md`](docs/instantpage-richtext.md).

**Inline buttons & document blocks** — `textButton` (inline, inside `RichText`),
`pageBlockButtonRow`, and `pageBlockDocument`, from the TL change that reshaped
`keyboardButton`/`keyboardInlineButton` (first unifying the 16 per-behaviour constructors into two,
then splitting `keyboardInlineButton` into its own `KeyboardInlineButton` type with a matching
`keyboardInlineButtonRow` that `replyInlineMarkup.rows` carries). All three are modelled losslessly (Postbox + FlatBuffers +
both Api directions) **and rendered in V2**; V1 Instant View still skips them. The server emits all
three. `pageBlockDocument` is also produced client-side — the
**RichText article editor produces it**: attaching a file (Files tab) makes a `MediaKind.document`
block that sends as `InstantPageBlock.document`, and tapping a downloaded one in the bubble opens it
via `openMessage(…, mediaSubject: .richTextMedia(fileId))`.

The load-bearing invariants are in [`docs/instantpage-richtext.md`](docs/instantpage-richtext.md)
under "Inline buttons & document blocks". The ones that bite hardest: `textButton` follows the inline
**formula** attachment path (real run-delegate ascent/descent, top-level item) and *not* the
inline-image path; the attachment must carry its own measurements because the line-breaker cannot
re-measure; interactive V2 items route taps through a **pageView closure** (`buttonTapped`, mirroring
`checkboxTapped`) rather than `tapActionAtPoint`, and that closure carries a `Promise<Bool>` the
tapped pill subscribes to for its loading shimmer; `InstantPageTheme.withUpdatedFontStyles`
reconstructs field-by-field so omitting a colour there silently reverts it; the `InstantPageButton`
FlatBuffers tables must live in `RichText.fbs` (include cycle); `ReplyMarkupButtonAction` is reused
and therefore wider than the schema permits; two media sites fail *silently* for `.document`; and
`InstantPageAnchorPath` must NOT recurse into `.buttonRow`. On the rendering side: a pill needs
`clipsToBounds` or `cornerRadius` is drawn and then covered by the `draw(_:)` background bitmap
(it renders as a rect); an inline pill's **type icon trails the label** rather than sitting in the
corner (the pill is ~20pt tall, so a badge would be shaved by the capsule) and the pill is measured
14pt wider to hold it — unconditional width, so it moves line breaks and the editor must reserve the
identical amount; `attachment.ascent` is a *full* font ascent and must not be compared directly
against `lineAscent`, which is the *reduced* `floor(ascender + descender)` box; and a width cap must
travel as `inlineButtonMaxWidth`, forwarded through all 31 recursive
`attributedStringForRichText` calls — `boundingWidth` is nil on the paragraph path and also drives
the inline-image clamp. Deferred: markdown-edit data loss, tapping an already-downloaded document,
and `checkboxFill`/`checkboxForeground` being misnamed (they are the `.primary` button colours).

**Text Size** — a rich bubble follows Settings ▸ Appearance ▸ Text Size through ONE `contentScale`
(`baseDisplaySize / 17`) passed to `layoutInstantPageV2`, applied once to the unscaled theme's fonts
(whole-point floor) and once to `InstantPageMetrics` (pixel snap) — never to an already-scaled theme.
Code, table and quote body stay equal at every step, so `codeBlockFontSize` is a whole-point floor, not
a pixel snap. Tests pin the grid to 3x because the test process reports a 1x screen. Details in
[`docs/instantpage-richtext.md`](docs/instantpage-richtext.md) under "Text Size / content scale".

**Unsupported blocks** — every block this build cannot decode arrives as
`InstantPageBlock.unsupported`, and V2 now renders it as the shared "please update" pill from
`submodules/TelegramUI/Components/UnsupportedContentPill`, which the chat's standalone
unsupported-media bubble also draws (its constants are load-bearing for that bubble's appearance).
A run of adjacent unsupported blocks collapses to one pill, and the chat wallpaper reaches the
renderer through `InstantPageV2RenderContext.wallpaperBackgroundNode`. Details in
[`docs/instantpage-richtext.md`](docs/instantpage-richtext.md) under "Unsupported blocks".

## Rust MTProto engine on iOS

The Rust MTProto engine (`third-party/mtproto-engine`, Swift wrapper `submodules/MTProtoRustEngine`)
is linked into every iOS build and selected at runtime: Debug Settings ▸ `Rust MTProto [Restart App]`
writes `networkEngineSettings` (applies at the next launch), and the `Engine:` row under it shows what
the account actually runs — the factory still declines (extensions, WEB proxy, DC address overrides)
and the `mtproto_engine_rust_disabled` app config forces MtProtoKit. MtProtoKit stays the iOS default.
Wrapper internals, measured results and open items: `third-party/mtproto-engine/docs/swift-integration.md`.

Load-bearing, and none of it shows up as a build error:

- **No `-Clto` on the engine's Bazel targets.** Every `rust_static_library` in the app shares ONE std:
  the archives embed identical std members and ld64 pulls a member only for an undefined symbol
  (measured: one `core`/`alloc`/`std` alongside wallet-engine and tlottie). LTO internalizes std into
  the archive and duplicates it.
- **Hardware crypto is re-applied by hand** in `MODULE.bazel`: Bazel reads neither
  `.cargo/config.toml` (`--cfg aes_armv8`, now a `crate.annotation` on `aes`) nor target-specific
  Cargo features (sha2's `asm`, now in the spec). Without them crypto silently runs ~15x slower.
  `third-party/mtproto-engine/scripts/verify-ios-link.sh <unstripped binary>` checks both and the
  single std. The crates holding non-generic hot code (`aes`, `sha1`, `sha2`, `flate2`, `miniz_oxide`,
  `adler2`, `simd-adler32`, `crc32fast`, `num-bigint`, `num-integer`) also carry `-Copt-level=3`
  annotations: rules_rust otherwise builds them at opt-level 0 under `--configuration=debug_*`.
- **Repin only the engine's crates:** `CARGO_BAZEL_REPIN=1 CARGO_BAZEL_REPIN_ONLY=mtproto_engine_crates`.
  A bare `CARGO_BAZEL_REPIN=1` also re-resolves the wallet's loosely pinned crates.
- `third-party/mtproto-engine/.gitignore` ignores `/build/`, not `/build`: on a case-insensitive file
  system the bare pattern also ignores the Bazel `BUILD` file, which then exists only locally.
- A main-session `401` on the Rust engine logs out, exactly as MtProtoKit does
  (`rustEngineAuthorizationRequiredAction`). **Never gate it on `MTContext.checkIfLoggedOut`**: that
  probe's `EphemeralMain` auth action completes without contacting the server whenever the main
  session's own temporary key is stored, so it always answers "not removed" and a session terminated
  from another device would never log out.
- **On iOS the engine changes only through the Debug switch.** Live switching
  (`SwitchingNetworkEngine`: the live `mtproto_engine_rust_disabled` kill switch and the live
  WEB-proxy moves) is macOS only (`#if os(macOS)` in `initializedNetwork` and `Account`); Telegram-Mac
  uses it. On iOS no wrapper exists, `Network.switchEngine`/`disableRustEngine` have nothing to act
  on, and the network runs the engine resolved at launch directly, so with the switch off it is
  exactly a build without the factory. Even on macOS the wrapper exists only while Rust is in play.
- `Network.isUserOnline` (from `Account.shouldKeepOnlinePresence`, wired on iOS only) reaches every
  session through `NetworkEngineSession.setOnline`; the Rust engine then uses tdlib's online
  keepalive timing. macOS, where Rust is the default, stays offline-timed until that cadence is
  measured there.

## Network telemetry (`NetworkTelemetry`)

TelegramCore records every request of an account's network above the engine
(`Network/RecordingNetworkEngine.swift`), so MtProtoKit and the Rust engine are measured by the
same code: per-method counts, retries, failures and latency buckets for a server-driven A/B, and
a `NetworkFailureRecord` for every failed, abandoned, dropped, slow or stalled request with the
context to reproduce it (connection timeline, latency p50/p90, estimated requests in flight,
retries). Records persist in `<account>/network-telemetry/` and are reported through
`help.saveAppLog` (`network_telemetry_summary` / `network_telemetry_failures`) while the app config
sets `network_telemetry_enabled`; `network_telemetry_variant` labels the arm. A period ends when it
is reported and when the variant, app or system version, or layer changes, so a report can carry several
summaries, each with its own labels. Debug builds always record and never report on their own.
`mtproto-bench replay` (engine repo README) turns records back into bench runs against the test
server.

None of this shows up as a build error:

- **Recording off must cost nothing.** The wrapper is installed only when recording, so with it
  off the request path is the pre-telemetry one; every request-path change is A/B'd three ways
  (baseline, off, on) with `mtproto-bench tc --suite torture --only million-clean`. Recording on
  costs ~0.4 µs per request (~13% at the 250k req/s ceiling).
- **Keep per-request work off the engines' serial queues.** A success appends one sample under an
  `os_unfair_lock`; counting happens in batches on a utility queue. Measured: aggregating inline
  cost 33%, a shared list written by the issuing thread 13%, and any extra per-request object that
  outlives `add` and crosses threads ~10%. That is why the state lives inline in
  `NetworkEngineRequest`, the engine's own disposable is returned unchanged, abandonment is noticed
  in the request's `deinit` (engines must release a request once it is cancelled), and only one
  request in eight is watched for stalls.
- **Only active waiting counts.** The main session's pauses mark the app suspended; time spent
  suspended and server flood waits never count toward slow, stalled or abandoned, a stall is
  counted only from when the connection last came up, and requests that waited through a
  suspension or a flood wait stay out of the latency histogram. The clock is `CLOCK_UPTIME_RAW`,
  so device sleep does not count either. `dropped` (an engine returning `EmptyDisposable`) exists
  only where an engine refuses requests, today Rust and the switching wrapper, so leave it out of
  engine comparisons.
- **Anonymization is enforced by tests.** `testReportedFieldsAreAllowlisted` pins every key that
  leaves the device. Method names come from `FunctionDescription.name` only, never from
  `shortMetadata.description`: `upload.getWebFile` passes its full description, URL included, as
  short metadata, and a request's metadata keeps every argument (upload parts too), so nothing
kept for counting may hold it. Error texts must be upper-case server constants (anything else
becomes `OTHER`) and lose numbers and tokens; request sizes are rounded up to a power of two.

## WEB proxy carrier (`tg://webproxy`)

A third proxy kind beside SOCKS5 and MTProxy. MtProtoKit's obfuscated2 transform runs
unchanged; what changes is only where the transformed TCP stream goes — each MTProto
connection becomes a logical stream multiplexed over a hidden `WKWebView` that speaks
HTTPS/WSS to a `tproxy-server` relay, which converts each stream back into one TCP
connection to a stock MTProxy. The relay therefore cannot pick a destination or decrypt
anything. The wire contract is upstream and client-neutral
([`PROTOCOL.md`](https://github.com/telegramdesktop/tproxy-server/blob/master/PROTOCOL.md),
with `IOS.md`, `BASE_PATH.md` and `HARDENING.md` beside it); the client half is
`submodules/WebProxyTransport` plus the `ProxySettings`/`SettingsUI`/`UrlHandling` wiring.

The non-obvious parts:

- **The loopback address never leaves MtProtoKit.** `MTSocksProxySettings.webProxy` is the
  whole hook: `MTTcpConnection` substitutes `127.0.0.1:443` at dial time while `ip` keeps
  the **public** hostname. So proxy identity, sponsored-channel attribution, and
  `ProxyServerPreviewScreen`'s "wait until the account reports online through this address"
  check all keep working, and the loopback endpoint is never displayed or shared.
- **One process-wide carrier**, `WebProxyTransport.shared`. It runs exactly while a
  configuration is present *and* someone holds demand (`setCarrierDemand(_:wanted:)`,
  idempotent per token). Demand rides `shouldKeepConnection`, i.e. the app's existing
  foreground/background/service-task machinery — that is how IOS.md's foreground-only
  lifecycle is met without a background mode or a timer of our own. `Network.swift` also
  refuses the carrier outright when the main bundle ends in `.appex`.
- **The web view must be in a real view hierarchy** or WebKit throttles off-screen work and
  the long poll stalls with no error. The transport cannot reach the hierarchy itself —
  TelegramCore depends on it and is shared with Telegram-Mac, so nothing in the module may
  import UIKit — hence `WebProxyCarrierViewHost`, implemented by
  `TelegramUI/Sources/WebProxyCarrierWindowHost.swift` as a 1pt, noninteractive,
  `alpha = 0.01` view at the bottom of the root container. Zero alpha is *not* equivalent.
- **Base-path relays.** `.web(secret:path:)` encodes as `_t = 3` only when the path is
  non-empty; `_t = 2` stays byte-identical for existing root records. The bridge capability
  binds the path: context `…-v1\nH` at the root, `…-v2\nH\nP` under a prefix, so one
  capability authenticates nothing at another prefix. The path is **case-sensitive** and
  never folded, unlike the host. The editor has one "server" field holding the whole
  `host/base-path` address (`canonicalWebProxyAddress`), and the list row drops the port
  for a WEB entry because 443 is implied.
- **The `0x70` marked secret.** A link that carries a base path *must* encode its secret as
  unpadded base64url of `0x70 || secret`; an unmarked secret there is **rejected**, so no
  link exists that a client without base-path support would silently accept as a pathless
  proxy on an empty host. Never `0xDD` — an older parser reads that as an ordinary padded
  secret. Enforced in `parseWebProxyLinkComponents`, which every link entry point (QR,
  pasteboard, `tg://`/`t.me` handling) goes through; hand entry in the editor stays lenient
  on purpose, because the hazard is specific to a shared link.
- **The carrier's `WKWebView` is hardened on its own and must never share anything** with
  Mini Apps, payments, 3-D Secure, Instant View embeds or the location picker: its own
  configuration, nonpersistent store and user-content controller per carrier lifetime.
  `WebProxyWebViewHardening` installs **two** document-start scripts in order — the
  execution profile, then the bridge shim. The profile goes into **every frame**; the shim
  stays main-frame-only because it is the half that reaches native. That split is measured,
  not assumed (`WebProxyFrameIsolationTests`): under the profile's own CSP a page can still
  append a src-less `about:blank` iframe — `frame-src 'none'` does not stop it, the initial
  about:blank being no fetch — and with a main-frame-only profile that child's
  `navigator.geolocation`, `Worker` and `BroadcastChannel` all came back pristine. The
  shim refuses to expose
  `TelegramWebProxy` unless the profile's flag says it is in place; construction itself
  fails closed if the scripts did not install, so a carrier without the policy never
  navigates. A different operator controls the proxy document, which is why the client
  imposes an independent meta CSP rather than trusting the response's own.
- **The meta CSP creates `document.head` when the parser has not reached it yet.** WebKit
  honours a `<meta>` policy only inside `document.head`, defined as the *first* head child
  of `<html>`, so the injected head becoming that first head is load-bearing — the parser's
  own head then lands after it as a second head element.
- **Geolocation has no public refusal below iOS 27.** `WebPageProxy::requestGeolocationPermissionForFrame`
  falls through `UIDelegate` (which returns with the handler intact when the app implements
  no geolocation method) to `PageClientImpl`, which on iOS *always* consumes it — so the
  `completionHandler(false)` at the end of that function is unreachable there. It lands in
  `WKWebGeolocationPolicyDecider`, which presents a `UIAlertController` on the view's
  **full-screen presentation context**, needs no user gesture, and auto-allows an origin
  after `kGeolocationChallengeThreshold` (2) grants recorded in `GeolocationSitesV2.plist`.
  The public `requestGeolocationPermissionFor` delegate (iOS 27+) denies it; below that the
  all-frames `navigator.geolocation` shim is the block, and the private SPI is deliberately
  not used. Do not describe the shims as the boundary anywhere else — here they are it.
- Calls stay SOCKS5-only (a WEB entry is never offered), and `ProxyServersStatuses` never
  pings an inactive WEB row: it would read "checking…" forever, so the row shows
  "not tested" and only the active one follows the real account connection state.

## Postbox shared-media removal (deferred design: tombstones)

`Transaction.updateMedia(id, update: nil)` is meant to remove a media from every message that
carries it. Today it is used for one thing: the server answers a web-page update with `webPageEmpty`
(no preview exists for that URL) and `AccountStateManagementUtils` turns it into a nil media update
(replayed through `updateMessageMedia(transaction:id:media:)`). The intended end state matches a
fresh store of such a message, which yields no web-page media at all.

It works only for media **embedded** in a single message (the message is rewritten and an
`.UpdateEmbeddedMedia` operation is emitted). For a **shared record** — two or more messages carry
the same media id, which is exactly what pasting or forwarding the same link produces, since web-page
ids are stable per URL — `MessageHistoryTable.updateMedia` merely decrements the record's reference
count and stops: the record stays, every message keeps the preview, and the update is not even
reported to views because `updatedMedia[id] = nil` on a `[MediaId: Media?]` **deletes the key**
instead of storing `.some(nil)`. Each further empty update decrements again, so the record is freed
while messages still reference it (an undercount; 3.1 in the 2026-09-18 audit was the matching leak).

The root cause is that the media table knows only a *count* for a shared record, not which messages
reference it; the only reverse lookup is `enumerateMediaMessages`, a history scan.

**Decided 2026-09-18, deferred:** implement removal of a shared record as a **tombstone** — rewrite
the `Direct` record into a flagged row whose `get` returns no media, leave the reference count
untouched, and record the removal with `updatedMedia.updateValue(nil, forKey: id)` so live views drop
it (the history view's `updateMedia` already handles `.some(nil)`). Every render then omits the
media, the count stays honest so the row is deleted on the final dereference as today, and a later
real update for the same id revives it for every referencing message at once. Do **not** delete the
row immediately: the stale ids left in the messages' reference arrays would corrupt the count of the
record when the same id reappears (old messages would resolve a new message's embedded copy, and
their later removal would decrement a count they never contributed to). The fully correct
alternative is a reverse index (media id → message indices) maintained beside the reference arrays,
which also lets the per-message tag recomputation in `updateMessageMedia` run; it needs a version
bump and a rebuild from the scan, so it is the eventual replacement only if a tag turns out to
derive from the web-page media rather than the URL entity. Tests belong in
`submodules/Postbox/Tests/` on `PostboxFixture` (two messages sharing one media, then an empty update).

## Postbox → TelegramEngine refactor (in progress)

A gradual migration is underway to eliminate direct `import Postbox` from consumer submodules in favor of `TelegramEngine`.

**Historical record:** Wave-by-wave outcomes, the running tally of Postbox-free modules, the full wave-selection guidance, and the `TelegramEngine.Resources` facade inventory (also authoritatively defined in `submodules/TelegramCore/Sources/TelegramEngine/Resources/TelegramEngineResources.swift`) live in [`docs/superpowers/postbox-refactor-log.md`](docs/superpowers/postbox-refactor-log.md). Read that file when you need wave-specific context, a full worked example of a pattern, or the history of a particular module's migration.

See the log for per-wave detail; the current wave count and the list of still-open migration opportunities live in the `project_postbox_refactor_next_wave.md` memory file.

### Rules that apply to every wave

1. `TelegramCore` does **not** `@_exported import Postbox`. Once a consumer drops `import Postbox`, every remaining Postbox-type reference must use an engine-typealiased equivalent.
2. **Never typealias `Postbox`, `Account`, or `MediaBox`.** These umbrella types rename without encapsulating. Narrow utility typealiases (`MemoryBuffer`, `PostboxDecoder`, `PostboxEncoder`, `AdaptedPostboxDecoder`, `MediaResource`, …) remain allowed and expected.
3. No new engine wrapper **structs** unless the wave's spec explicitly allows — only typealiases and thin forwarding methods.
4. **Discovery first:** before adding any new engine wrapper/typealias, grep `submodules/TelegramCore/Sources/TelegramEngine/` for existing equivalents. Record the search result in the commit message.
5. **Abandonment protocol:** if a module can only be refactored by violating rule 2 or by editing a module outside the current wave's list, mark the task Abandoned with a recorded reason. Do NOT substitute a new module mid-wave.
6. Full project build per module. No unit tests exist in this project.
7. **TelegramCore never imports UIKit/Display.** `TelegramCore` is shared with the Telegram-Mac codebase; its Bazel `deps` and source files must not reference UIKit, Display, or any Apple-UI framework. UIKit-needing helpers (image scaling, rendering, etc.) stay in consumer-side submodules.
8. **Never substitute Postbox protocols (`Media`, `Peer`, `Message`) with `Any` / `AnyObject`** in code that previously used them. Type erasure throws away the domain semantics that the next reader expects. Use the matching engine wrapper (`EngineMedia`, `EnginePeer`, `EngineMessage`) — extending it as needed (e.g. add a missing case-init or convenience). If neither typealias nor wrapper covers the use site, restore the original Postbox import + type for now and flag the case for a future facade. Existing `Any`/`AnyObject` parameters predating the refactor are not in scope for this rule.

### Engine typealias cheat sheet (existing aliases)

```
PeerId              → EnginePeer.Id
MessageId           → EngineMessage.Id
MessageIndex        → EngineMessage.Index
MessageTags         → EngineMessage.Tags
MessageAttribute    → EngineMessage.Attribute
MessageFlags        → EngineMessage.Flags
MessageForwardInfo  → EngineMessage.ForwardInfo
MediaId             → EngineMedia.Id
PreferencesEntry    → EnginePreferencesEntry
TempBox             → EngineTempBox
PinnedItemId        → EngineChatList.PinnedItem.Id
MemoryBuffer        → EngineMemoryBuffer           (added 2026-04)
PostboxDecoder      → EnginePostboxDecoder         (added 2026-04)
PostboxEncoder      → EnginePostboxEncoder         (added 2026-04)
AdaptedPostboxDecoder → EngineAdaptedPostboxDecoder (added 2026-04)
ItemCollectionId    → EngineItemCollectionId       (added 2026-04-20)
FetchResourceSourceType → EngineFetchResourceSourceType (added 2026-04-20)
FetchResourceError  → EngineFetchResourceError     (added 2026-04-20)
StoryId             → EngineStoryId                (added 2026-05-02)
ChatListIndex       → EngineChatListIndex          (added 2026-05-03)
TempBoxFile         → EngineTempBoxFile            (added 2026-05-03)
ItemCollectionItemIndex → EngineItemCollectionItemIndex (added 2026-05-03)
ItemCollectionViewEntryIndex → EngineItemCollectionViewEntryIndex (added 2026-05-03)
ValueBoxEncryptionParameters → EngineValueBoxEncryptionParameters (added 2026-05-03)
MessageAndThreadId  → EngineMessageAndThreadId      (added 2026-05-03)
PeerStoryStats      → EnginePeerStoryStats          (added 2026-05-03)
MessageHistoryAnchorIndex → EngineMessageHistoryAnchorIndex (added 2026-05-03)
ChatListTotalUnreadStateCategory → EngineChatListTotalUnreadStateCategory (added 2026-05-03)
ChatListTotalUnreadStateStats → EngineChatListTotalUnreadStateStats (added 2026-05-03)
PeerSummaryCounterTags → EnginePeerSummaryCounterTags (added 2026-05-03)
ChatListTotalUnreadState → EngineChatListTotalUnreadState (added 2026-05-04)
ItemCacheEntryId    → EngineItemCacheEntryId        (added 2026-05-04)
HashFunctions       → EngineHashFunctions           (added 2026-05-04 wave 251)
CachedMediaResourceRepresentationResult → EngineCachedMediaResourceRepresentationResult (added 2026-05-04 wave 265)
MediaResourceDataFetchResult → EngineMediaResourceDataFetchResult (added 2026-05-04 wave 266)
MediaResourceDataFetchError → EngineMediaResourceDataFetchError (added 2026-05-04 wave 266)
MediaResourceStatus → EngineMediaResourceStatus     (added 2026-05-04 wave 272)
```

**Free-function thin forwarders in TelegramCore** (rule 3 allows):
- `engineFileSize(_ path:, useTotalFileAllocatedSize: Bool = false)` — forwards to Postbox's `fileSize(...)` (added 2026-05-04 wave 268)

**TelegramEngineUnauthorized.resources facade**: `UnauthorizedResources.storeResourceData(id: EngineMediaResource.Id, data:, synchronous:)` — bridges to `account.postbox.mediaBox.storeResourceData` (added 2026-05-04 wave 271)

For the `MediaResource` Postbox protocol, prefer the TelegramCore subtype `TelegramMediaResource` when the consumer's usage allows (note: `EngineMediaResource` is a wrapper **class**, not a typealias, so it is not interchangeable with the protocol).

### MediaResource → EngineMediaResource consumer migration

`EngineMediaResource` is a `final class` in `TelegramCore` wrapping a `MediaResource` value. Unlike the typealiases above it is **not** interchangeable with the protocol, but it does provide wrap/unwrap helpers:

- `EngineMediaResource(rawResource)` — wrap a raw `MediaResource`.
- `engineResource._asResource()` — unwrap to the raw `MediaResource`.
- `EngineMediaResource.ResourceData(rawResourceData)` — wrap `MediaResourceData`.
- `EngineMediaResource.Id(rawMediaResourceId)` — wrap `MediaResourceId`.

**Pattern for facade functions:** when a `TelegramEngine.<Area>` method leaks raw `MediaResource` in its public signature, **change the facade signature in place** to `EngineMediaResource` (and change any closure parameter types the same way). Bridge inside the facade body by calling the existing `_internal_*` function with `engineResource._asResource()` / wrapping raw inputs from inner closures with `EngineMediaResource(rawResource)`. Update all call sites in the same commit. The `_internal_*` function stays on raw `MediaResource` — it is the Postbox-facing layer.

Do **not** add opt-in `EngineMediaResource` overloads alongside raw-`MediaResource` overloads. Duplicate signatures fragment the public API and leave the leak in place forever.

For consumer modules, prefer `EngineMediaResource` as the type in properties, locals, generic arguments and function parameters when the usage is a pure type reference. Do **not** try to use `EngineMediaResource` where a class must conform to `TelegramMediaResource` (Postbox protocol) or override `isEqual(to: MediaResource)` — those remain `import Postbox`.

## tgcalls Testbench

This repo includes a tgcalls testbench (CLI tool, Go/Pion SFU, Docker build) layered on top of the iOS source. All testbench code, build instructions, and architecture docs live inside the tgcalls submodule:

- `submodules/TgVoipWebrtc/tgcalls/CLAUDE.md` — top-level testbench overview, build/run commands
- `submodules/TgVoipWebrtc/tgcalls/tools/cli/CLAUDE.md` — CLI test tool architecture
- `submodules/TgVoipWebrtc/tgcalls/tools/go_sfu/CLAUDE.md` — Go SFU internals
- `submodules/TgVoipWebrtc/CLAUDE.md` — tgcalls library internals + macOS/Linux build patches
- `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/CLAUDE.md` — pump-boundary call core: `InstanceV2ReferenceImpl`'s control logic behind a C ABI (since Phase 2.5 a PeerConnection-projection contract: SDP munge point, transceiver/parameter/ICE-restart commands, rich stats, and since Phase 2.6 core-owned signaling framing, N named data channels, and audio/ICE config knobs), runnable natively or as a WASM module in the vendored WAMR interpreter. **Ships as call versions `18.0.0` (native core) and `19.0.0` (the same source as wasm embedded in the binary)** so a server-side A/B can measure the substrate alone; the client advertises both and the server reconciles. `customParameters.wasm_core_path` and the filesystem module loader are compiled out of the app (`TGCALLS_ALLOW_EXTERNAL_WASM_CORE`, CLI target only) — never add that define to the `TgVoipWebrtc` objc_library. A second module `variant-core-abi1.wasm` demonstrates behavior changes (fmtp munge, adaptive bitrate cap, periodic ICE restart) shipped as wasm only, CLI-loaded. Design/validation records in `docs/superpowers/specs/2026-07-*-tgcalls-wasm-*`

Build the test binary from this directory with:

`./build-input/bazel-9.2.0-darwin-arm64 build //submodules/TgVoipWebrtc/tgcalls/tools/cli:tgcalls_cli`
