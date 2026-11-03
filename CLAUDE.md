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
K3=4483DD69-685A-4FE1-89BE-65F992C271F2   # iPhone 18 Pro K3 (use the dedicated K-sims, not the shared default)
# The K-sims were RECREATED by the Xcode 27 update (2026-09-15), which removed every simulator:
# they are iPhone 18 Pro now, on new UDIDs. K1=03A7DA9C-1832-49B8-9858-2F54F2FB5A04, K2=E643A78E-DB62-4DA4-9F54-BD0836F434AF.
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

### Visual features and animations: verify from recorded frames

Any visual change, and always an animated one, is verified by recording the simulator and reading its frames, not by
a green build: [`AGENTS.md`](AGENTS.md), "Visual features and animations" (`simctl io recordVideo`, then
`tools/animation_sheet.py` for labelled frame sheets, per-frame numbers and per-element tracks in points).

### CI builds in tart VMs (and why every download needs a checksum)

GitLab CI (`.gitlab-ci.yml`) builds, uploads to TestFlight and verifies in tart VMs on the runner host:
`Make.py vm-build` / `vm-deploy-testflight` / `vm-ipa-diff` (`build-system/Make/TartBuild.py`), each in an ephemeral
clone of `macos-<macos>-xcode-<xcode>` from `versions.json` (uploads use `deploy_xcode`). One VM runs per host
(an flock at `~/.telegram-build/vm-build.lock`); CI passes `--waitForLock` so a second job queues instead of failing.
gitlab-runner runs as a launchd service whose PATH has no Homebrew, so `tart` is resolved via `TART_PATH`, PATH, then
the Homebrew locations. The bazel cache is bazel-remote on the runner host (`TELEGRAM_BAZEL_CACHE_HOST`); the guest
reaches it through tart's NAT at the host's LAN address or the gateway (`grpc://@auto:9092`).

**Every external download must carry a checksum.** Make.py points both `--remote_cache` and
`--experimental_remote_downloader` at bazel-remote, so bazel asks bazel-remote to fetch each archive and waits for the
whole download under the 60s `--remote_timeout`. bazel-remote serves an archive from its store only when the request
names its sha256; without one it re-downloads it from the internet on every build (the repository cache needs the
checksum too, and each ephemeral VM starts with an empty one). On the runner's link (~300-400 KB/s from
static.rust-lang.org) a large archive misses the deadline: the build log fills with
`Remote Cache: DEADLINE_EXCEEDED … remote_addr=…:9092`, the guest sits idle, and after the retries
`--experimental_remote_downloader_local_fallback` (`.bazelrc`) downloads it again inside the VM. It reads like the VM
cannot reach the cache; it can (`curl http://<cache>:8080/status` from the guest answers in milliseconds), and the
tell is bazel-remote holding an outbound connection to the archive's host. This happened with the Rust toolchain:
rules_rust 0.74.0 knows checksums only up to Rust 1.98.0, so `MODULE.bazel` supplies 1.98.1's in
`rust.toolchain(sha256s = …)`. **Bumping the Rust version means updating that dict** (each archive's checksum is at
`static.rust-lang.org/dist/<archive>.sha256`), or dropping it once rules_rust's `known_shas.bzl` covers the version.

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
believing it is live.

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
- App-side unit tests are minimal: the first `ios_unit_test` (`//submodules/TextFormat:TextFormatTests`) was added 2026-06-19 (run via `Make.py test --target` — see Build). `//submodules/Postbox:PostboxTests` (added 2026-09-18) covers `SqliteValueBox` and individual Postbox tables directly against an in-memory value box, using `@testable import Postbox`; add new Postbox regression tests under `submodules/Postbox/Tests/`. `//submodules/TelegramCallsUI:TelegramCallsUITests` (added 2026-09-18) drives `SharedCallAudioContext` through a fake `ManagedAudioSession` (the protocol is implementable from outside since `ManagedAudioSessionControl` gained a public closure initializer); creating the context builds a real tgcalls audio device, which is fine in the simulator test process. `//submodules/TelegramAudio:TelegramAudioTests` (added 2026-09-22) covers pure `ManagedAudioSessionType` helpers such as `voiceMessageRecording(beginWithTone:pauseMusicOnRecording:)`, the mapping the voice recorder uses for the Data & Storage "Pause Music While Recording" toggle, and the **holder-precedence policy of the real `ManagedAudioSessionImpl`** (it is constructible in the test process; push with `manualActivate` and never touch the control, so the process's `AVAudioSession` is left alone). The load-bearing rule pinned there: a `.voiceCall` holder is never displaced, not even temporarily, by a recording that mixes with other audio, because deactivating it makes `PresentationCall` drop its audio-session control. The recorder itself (`ManagedAudioRecorder`) needs a live `MediaManager` and real audio units, so keep session-policy decisions in testable helpers rather than in it. `//submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode:ChatTextInputPanelNodeTests` (added 2026-09-22) covers the legacy composer's Text Size metrics (`ChatTextInputFontMetrics.swift`) against a real `ChatInputTextView` measurement; linking the panel into a test bundle needed `MediaPlayer` declared on `LegacyComponents`. `//submodules/TelegramUI/Components/PeerInfo/PeerInfoPaneNode:PeerInfoPaneNodeTests` (added 2026-09-24) covers `peerInfoMessageChatDestination`, the chat that shared-media "View in Chat" opens. It is the chat the media tab *lists* — neither the peer the profile describes (a secret chat's profile describes the user, so use `data.chatPeer`) nor the chat the message is stored in (a supergroup's tab lists its pre-migration basic group's messages, which open in the supergroup). A user's profile opened from a channel's direct messages lists that channel's thread, which is opened directly: `navigateToForumThread` addresses a topic by an Int32 message id and cannot reach a monoforum thread keyed by a user id. `//Telegram/NotificationService:NotificationServiceTests` (added 2026-09-24) covers the notification service extension's naming of the recipient account when several are signed in (`NotificationRecipientAccount.swift`). On iOS 15+ the system draws a communication notification's title from the sender `INPerson`'s `displayName` and hides `content.subtitle` (measured on 18.6 and 27), so anything the title must show goes into the sender's name. `NotificationContent` is private, so keep such decisions in testable helpers. `//submodules/TelegramUI/Components/Chat/EditableTokenListNode:EditableTokenListNodeTests` (added 2026-09-24) covers `EditableTokenListPeerAlias`, the one decision a chat picker's token (e.g. Add Chats for a folder) uses for both its title and its avatar, so a Saved Messages token draws the Saved Messages icon rather than the account's photo; `PresentationStrings` cannot be built in a test process (it asserts without the app bundle's `PresentationStrings.data`), so the alias is strings-free and the title stays in `ContactMultiselectionController`. `//submodules/PeerAvatarGalleryUI:PeerAvatarGalleryUITests` (added 2026-09-25) covers `avatarGalleryUserEntries`, the one builder both user-gallery paths use: slot 0 is drawn from the peer record's current photo, but `photos.getUserPhotos` keeps its order when an older photo is made the main one again (the server swaps a copy under a **new photo id** into that photo's place), so the current photo is looked up in the list and moved to the front (a personal photo moves the contact's current public photo instead, and a current photo the list does not contain gets its own slot) rather than drawn over whatever the list starts with, which showed it twice and hid that photo. Because of the new id, `_internal_updatePeerPhotoExisting` copies the chosen photo's downloaded sizes to the returned photo's files; the returned photo's sizes and its `photo_small`/`photo_big` ("a"/"c") are byte-identical to the chosen photo's (measured in the sim media cache). The result's user list does not carry the new photo for the account itself, so the same transaction also sets `TelegramUser.photo` from the returned photo; without that the record changed only in a later transaction and every avatar downloaded the photo again. `//submodules/MediaPlayer:UniversalMediaPlayerTests` (added 2026-09-26) drives a real `ChunkMediaPlayerV2` (wait for `MediaPlayerNode.videoLayer`, which the node creates asynchronously, before constructing it) from an `.externalParts` promise. With no parts the player stays buffering, so the clock only moves on a seek; a part backed by an empty `TempBox` file lets it run, because buffering is decided from part times alone. It pins the end of playback: the player keeps a 0.1 s end tolerance for HLS chunks that do not line up with the declared duration (`ChunkMediaPlayerV2.endTolerance`; do not remove it), so a video no longer than that is at its end from position 0 and is not played — its clock never moves, even on a later `play()`. Looping one would seek to where the clock already is, and that no-op `seek` re-runs the end check synchronously until the stack overflows. The RichTextEditor SwiftPM package keeps its own suite (`swift test` / `Scripts/iostest.sh`). MtProtoKit's suite (`//submodules/MtProtoKit:MtProtoKitTests`) also runs on macOS: `swift test` in `submodules/MtProtoKit` (the package's test target puts the module's private headers on its search path). Most modules still have no tests.

## RichTextEditor editor & the `ChatInputContent` composer

A from-scratch WYSIWYG rich-text editor (`submodules/TelegramUI/Components/RichTextEditor`) is the native chat-composer backend — by default a **dual-field switch** (the composer uses the legacy input and latches to the native editor only when content becomes legacy-non-representable); the `useInputDecEngine` experimental flag (Debug Settings ▸ "Input V3") forces always-native with the engine editor (iOS 18.4+). "Force Text Field v2" (`forceNewTextInput`, always-native on the legacy editor) was removed 2026-10-15; `ios_rich_input_mode = 1` still gives that. (This inverted the earlier default+`forceLegacyTextInput`-opt-out scheme.) `ChatInputContent` (a TelegramCore-native value model) replaced `NSAttributedString` as the composer currency. The app-side integration — the model and its load-bearing invariants, composer ↔ editor wiring, the formatting-menu / custom-emoji-mention-date / code-block / inline-media round-trips, rich-message send / edit / pending-display, the long-press-Send send-options preview, **media pre-upload** (attached media uploads immediately and is promoted to cloud media, surviving the editor closing and reopening), and draft persistence (local, cross-device media sync, re-login restore) — lives in [`docs/richtext-composer.md`](docs/richtext-composer.md). Editor internals (the TextKit seam, layout) are the editor's own `submodules/TelegramUI/Components/RichTextEditor/CLAUDE.md` — including the **code-block language field + syntax highlighting** (2026-08-25): a code block's language is authored in an always-visible editable line (a second leaf region on the box, so `activeStack` must resolve a box by its PRIMARY region or edits land in the wrong layout), and libprisma highlights code in both editor hosts through a host-provided seam, since the package cannot depend on the highlighter. The renderer half, and the three silent pre-existing defects that had to be fixed before any highlighting was visible, are in [`docs/instantpage-richtext.md`](docs/instantpage-richtext.md). Also **InstantPage V2 layout parity** (2026-08-14): the editor lays text out pixel-identically to the V2 renderer via the host-supplied `RichTextRenderMetrics` contract, and BOTH surfaces (composer + article editor) use the chat-message metrics, so what you type reads like the message sent. Message **rendering** is [`docs/instantpage-richtext.md`](docs/instantpage-richtext.md).

## Composer harness (`Tests/ComposerHarness`)

A standalone, loginless Bazel `ios_application` that hosts the **real** chat composer —
`ChatTextInputPanelNode` → `RichTextEditorChatInputNode` → `RichTextEngineEditorView` — against a
synthetic `AccountContext` whose only non-stubbed part is a genuine `Account` over a disposable
Postbox with networking off. It exists so an agent can drive composer operation on a deterministic
surface and turn each defect into a regression test, without a login and without touching the
logged-in Telegram on K3.

Its own [`CLAUDE.md`](Tests/ComposerHarness/CLAUDE.md) is the operating manual (build/test/run,
the scenario registry, the model-dump contract, which test tier a regression belongs in, and the
simulator-driving hazards).
Two things to know before using it: **height and inset findings are provisional** (the harness has
no `ChatControllerNode` keyboard machinery), and **unprovided app-context members trap and name
themselves** rather than returning a plausible constant.

## Embedded watch app (`Telegram/WatchApp`)

A standalone watchOS Telegram client (developed in the separate `~/build/tgwatch` repo) is vendored into this repo at `Telegram/WatchApp/` and can be embedded into the **device** IPA under `Telegram.app/Watch/`. It is built by `xcodebuild` (not Bazel) and codesigned by the Bazel build.

**Build it:** add `--embedWatchApp` to a Make.py **device** build (`--configuration=debug_arm64` or `release_arm64`) together with `--watchApiId`, `--watchApiHash`, `--watchSigningIdentity`, `--watchProvisioningProfile`. Off by default (it adds a ~4-min xcodebuild step); simulator builds never embed, and the default `debug_sim_arm64` build is unaffected.

**`Telegram/WatchApp/` is a synced snapshot — do not hand-edit it.** The source of truth and dev tooling live in the `tgwatch` repo. To change the watch app, edit it there, then re-sync with `tgwatch/tools/export-sources.sh /abs/path/to/telegram-ios/Telegram/WatchApp` and commit the result. The committed `tgwatch.xcodeproj` is generated (kept via a `!tgwatch.xcodeproj` negation in `Telegram/WatchApp/.gitignore`, since the root `.gitignore` ignores `*.xcodeproj`); `.build`/`.swiftpm`/`xcuserdata` are excluded.

**How it's wired:** `//Telegram:TelegramWatchApp` (rule in `Telegram/prebuilt_watchos.bzl`) runs in **two actions**: `PrebuiltWatchosCompile` (`Telegram/prebuilt_watchos_compile.sh`) runs xcodebuild on the snapshot in a writable temp copy, baking the api credentials and the watch bundle id (as `PRODUCT_BUNDLE_IDENTIFIER`, from which the snapshot's Info.plist derives `WKCompanionAppBundleIdentifier` via `$(PRODUCT_BUNDLE_IDENTIFIER:base)`) but leaving PLACEHOLDER versions, emitting an unsigned `.app`; `PrebuiltWatchosPatchSign` (`Telegram/prebuilt_watchos_patch.sh`) then rewrites the **two** per-build Info.plist version keys (`CFBundleShortVersionString`, `CFBundleVersion`) and codesigns the `.app` + nested `TDLibFramework.framework` (identity + the watchkitapp profile from `--define`s). The result feeds the `Telegram` `ios_application`'s `watch_application` slot (gated by the `//Telegram:embedWatchApp` flag). The rule takes `bundle_id` (set to `"{telegram_bundle_id}.watchkitapp"` in `Telegram/BUILD`).

**The split exists for caching, and the split's whole value is that the version stays out of the compile action.** `--define=buildNumber` changes on every CI pipeline, so with the version baked by xcodebuild the compile key moved every build and the ~4-min xcodebuild ran every time. Deferring only the version keeps the compile action's key stable (verified with `aquery`: the `PrebuiltWatchosCompile` ActionKey is identical across `--define=buildNumber` and `--define=watchSigningIdentity` changes, while the patch key moves). The api id/hash and bundle id stay baked because they are stable per host configuration and xcodebuild must own the bundle id anyway — and none of these reach the compiled binary, they land only in the Info.plist (via `$(...)` substitution and a runtime `Bundle.main.object(forInfoDictionaryKey:)` lookup in `Secrets.swift`), so deferring the version cannot change the compiled output. Consequence to know: the nested `TDLibFramework` keeps the placeholder `0.0`/`0` version — only the watch app's own Info.plist is version-verified against the host.

**Do not add `"local": "1"` to the compile action's `execution_requirements`.** It looks harmless next to `no-remote-exec`, and it silently defeats every cache. Measured against the vendored bazel 8.4.2 with `--execution_log_json_file`: `{no-sandbox, no-remote-exec, local, requires-network}` reports `cacheable=false, remoteCacheable=false` and never takes a `--disk_cache`/`--remote_cache` hit, while the same set *without* `local` reports `cacheable=true, remoteCacheable=true, remotable=false, runner=local` — i.e. `no-remote-exec` + `no-sandbox` already pin execution local and unsandboxed, so `local` buys nothing and costs all caching. This is exactly why the original 2026-05-28 "Enable watch app cache" change (`0be58ef45a`) was inert: it flipped `no-remote` to `no-remote-exec` but left `local` in place. The patch+sign action *does* keep `local` + `no-remote`, deliberately: its provisioning-profile path is machine-specific and the profile's *contents* are not an action input, so a shared cache would serve wrongly-signed bundles rather than merely miss.

**Non-obvious invariants** (also in the `.bzl` comments): `AppleBundleInfo`'s public init is banned — use the internal `new_applebundleinfo`; `watch_application` requires BOTH `AppleBundleInfo` (with a non-None `infoplist` File) AND `WatchosApplicationBundleInfo`; the embedded watch app's `CFBundleShortVersionString`/`CFBundleVersion` must exactly equal the host's (sourced from `versions.json['app']` + `--define=buildNumber`); the host does NOT re-sign the embedded watch app, so the worker must sign it; the watch bundle id `ph.telegra.Telegraph.watchkitapp` must track the host `telegram_bundle_id`.

**Status:** verified with **development** signing on `debug_arm64` only. Open follow-ups before App Store shipping: secure timestamp (drop `codesign --timestamp=none`), distribution profile (`get-task-allow=false`), `release_arm64` + `altool --validate-app`, and committing a `Package.resolved` for hermetic remote-SwiftPM resolution.

## The vendored InputDec engine and kernel — this repo owns them (2026-09-15)

`submodules/TelegramUI/Components/RichTextEditor/Sources/RichTextInputDecObjC/` (the behavior
kernel) and `Sources/RichTextInputDecUpstream/` (the text engine) are **ordinary source: edit them
here.** There is no upstream to change first, no re-port, no hash list to re-record.

This reverses an arrangement that stood until 2026-09-15, and the reversal is not a preference — it
is a repair. `~/Documents/InputDec` was the source of truth for both trees, the kernel re-synced by
`InputDec/Scripts/export-behavior-kernel.sh` and the engine hand-ported under a SHA-256 list. Its
`.git` went missing on this machine between 2026-09-11 and 2026-09-12, so the authority was an
unversioned working tree on one disk while the copy in this repo was versioned and reviewed. Three
engine changes had already had to be recorded as "working tree at ⟨date⟩" because no commit existed
to name. `PORTED-FILES.sha256`, `PORTED-FILES-local.sha256` and `Scripts/verify-ported-files.sh` are
deleted with the workflow they served.

**Still generated, still pinned:** `Vendor/`'s pristine manifest JSON and
`Generated/TGRichTextInputDecContractData.m`. `VendorSnapshotIntegrityTests` (Core) hashes both
against pins recorded independently in `VENDOR.md` and the test file — no longer to forbid an edit,
but so an accidental one is caught and a deliberate one re-records the pin in the same commit. The
generator (`generate-contract-data.py`) has not been brought across yet, so prefer regenerating over
editing once it is.

**No private UIKit name reaches the binary as text (2026-10-12).** Both trees spell every private
name they cross with UIKit through `TGPN_<name>()` (XOR-encoded, generated from
`submodules/TelegramUI/Components/RichTextEditor/Scripts/private-runtime-names.txt`), compile UIKit's
callbacks under neutral `tgpn_` names added under the private ones from `+initialize`, and store the
embedded contract tables encoded. `PrivateRuntimeNamesTests` guards the sources and
`Scripts/scan-private-runtime-names.py` checks a release binary. The rules, and the one known
residual (the legacy canvas's text-checking client), are in the package `CLAUDE.md`, "Private UIKit
names are not in the binary".

**The open half is the PROOF.** Upstream also holds the engine's tests — 1,078 unit and 196 UI
cases, a stock-`UITextView` oracle host and their fixtures — and those are not here yet. Until they
are, this repo owns the engine without owning what shows it works, and `~/Documents/InputDec` must
not be deleted. That import is the next step, and it has a natural home: `Host/project.yml` already
carries an app, a unit-test bundle and a UI-test bundle.

The directory is a **sibling** of `Sources/RichTextEditorUIKit/`, deliberately: `BUILD`'s
`RichTextEditorUIKit` `swift_library` globs `Sources/RichTextEditorUIKit/**/*.swift` only, so an
`.m`/`.h` placed under that tree would compile fine under SwiftPM (whose package target picks up the
whole directory) and simply vanish from the Bazel/app build with no error.

**The kernel's real consumer is `Sources/RichTextInputDecUpstream/`.** That directory is InputDec's
actual text engine — 78 files / 16,492 lines, brought across 2026-08-26 and owned here since
2026-09-15. Its `PROVENANCE.md` is now an ORIGIN record rather than a diff against a live upstream:
it carries the revision each file was last taken at, the thirteen that were uncommitted upstream when
they were first read, and all six ways this copy differs from the tree it came from. Read it before
touching anything in there — those six are facts about the code you are editing, not paperwork. Two
are worth knowing without opening the file: every file carries a `#if TARGET_OS_IOS` wrapper (which
the export script used to add and which is now simply part of the source — it is what makes the
module compile to nothing on macOS, so a `swift build` can never be evidence about this code), and
`IDPrivateUIKit.m`'s `IDInteractionABISpec` carries an `objc_runtime_name` attribute because the
vendored carve `Host/TGRichTextInputDecHostPreflight.m` defines a class of the same name — it was
carved out of that very file — and the two would otherwise collide at link.

**The port IS on the app graph now** (2026-09-01), reached as
`//Telegram:Telegram → … → ChatRichTextEditorComposer → RichTextEngineEditor → RichTextInputDecUpstream`.
Verify with `bazel query 'somepath(//Telegram:Telegram, //…:RichTextInputDecUpstream)'`.

This paragraph previously said the opposite, and said it was load-bearing: `IDBlockTextView` had a
`+load` that resolved the private `UIKeyboardInput` protocol by name and `@throw`ed an **uncaught**
`NSException` before `main()`, which nothing could guard and no flag could disable. That hazard is
GONE, not tolerated — upstream `442f395` moved the installation into the initializer, where a failure
lands in an existing `@catch` and becomes a failed CONSTRUCTION the host can gate on. There is no
`+load` left anywhere under `Sources/RichTextInputDecUpstream/`; check with
`grep -rn "^+ (void)load" Sources/RichTextInputDecUpstream/` before trusting this sentence, because
its predecessor was true when written and silently stopped being true.

It is also driven by a real editor now. `Sources/RichTextEngineEditor/` maps Telegram's `Document`
onto the engine and is selected by Debug Settings ▸ **"Input V3"**
(`ExperimentalUISettings.useInputDecEngine`). As of R9-inline it does links, inline code, spoilers
(hidden text plus dust) and custom emoji, and it owns the composer's edit menu.

R7 then added containers: `.code`, `.pullQuote` and `.blockQuote` round-trip through
`EngineDocumentBridge`, are drawn by real per-block decoration views, and all three Format-menu
commands (`makeCodeBlock`, `makePullQuote`, `wrapInBlockQuote`) perform. `.table` landed 2026-09-04
and `.media` 2026-09-05
(see the package `CLAUDE.md`, "R7 tables" and "R7 media" — media is an attachment atom plus a caption
line, and Backspace on it is two-step by product decision). R7-nesting (2026-09-05) made the block
quote recursive — any block at any depth, roles carrying an ancestry — see the package `CLAUDE.md`,
"R7 nesting". R7-details (2026-09-08) added the second container kind — a title line that is a
secondary region above a body a fold hides, and an indent each container contributes rather than a
depth every container is charged; see the package `CLAUDE.md`, "R7 details". R9-buttons (2026-09-09)
discharged the LAST trap, `.buttonRow` — which was never a container: it holds no child blocks, so
`EngineAncestor` gained nothing. It is a fifth `EngineBlockShape`, one attachment character for the
whole row whatever its pill count, with the pills packed by the V2-pinned packer inside a hosted
view. The same rung gave inline `textButton` pills their hosted views: they had been laying out and
drawing NOTHING, so an inline button rendered as a blank gap of exactly the right size. See the
package `CLAUDE.md`, "R9 buttons". R9-formulas (2026-09-09) wired the host's formula renderer,
which the engine had stored and never handed to its mapper — so formulas rendered as their own
LaTeX source — gave a standalone formula paragraph block rhythm, and made `insertFormula` produce a
block rather than legacy's inline atom; see "R9 formulas". R10-undo (2026-09-17) wired the article
editor's toolbar Undo/Redo, which were two constants and two traps, to the engine's own undo manager;
see the package `CLAUDE.md`, "The toolbar's undo and redo are the engine's own stack" — including the
measured open item that undo is one step per CHARACTER where legacy coalesces typing into runs.

**Exactly TWO traps are left, both `Block.<case>` in `EngineDocumentBridge` naming R7**, and neither
is reachable by any case the bridge models today. Verify with
`grep -rn richTextEngineUnimplemented submodules/TelegramUI/Components/RichTextEditor/Sources/`
before trusting this sentence: its predecessors named `insertEmoji` at R9-emoji-insertion (answered
for real in `+CustomEmoji.swift`), `R7-paste` (discharged 2026-09-17 by the global-position work) and
`R10-undo`, and each was true when written.

**The block quote is the one that shaped the design.** Every other container is 1:1 with an engine
block, so its kind is a tag in the identity table; `BlockQuote` has `children: [Block]`, so one model
block becomes N engine blocks. The view's cache is therefore `currentRoles: [EngineBlockRole]`, one
per ENGINE block, and the `Document` is DERIVED from it by a stack walk over each role's ancestry —
keyed on the quote's IDENTITY, so two adjacent quotes stay two. `currentBlocks` survives as a
computed engine-parallel projection, which is what left every consumer that indexes the cache by
engine block index untouched. Mutators must write back through `applyEngineParallelBlocks(_:)`:
assigning `Document(blocks:)` directly dissolves every quote into loose paragraphs. **A role is structure only, by type**: it holds
shapes (`EngineBlockShape`, `QuoteShape`, `TableShape`, `EngineContainerShape`), which have no field
for text. The engine's storage is the one copy of the text; `currentBlocks` and `document` are
materialised from the roles and `engine.attributedBlocks` on every read
(`EngineDocumentBridge.block(for:from:)`), and flat geometry sums the ENGINE's block lengths
(`flatOffset(ofRoleAt:)`, `flatLength(ofRoleAt:)`), which is also the axis a formula run's single
attachment character lives on. Before this held, roles carried a second copy of the text refreshed by
convention, and three device defects in one day (2026-09-04) were that copy going stale.

**Structure is decided at the surface gate and settled after the edit (2026-09).** Text reaching the
host view's UITextInput surface (`TGIDObservingBlockTextView`'s `insertText:` and
`replaceRange:withText:`, the same shape as its backspace veto) goes through `tgid_textInputGate`
BEFORE the controller edits: `RichTextEngineEditorView+SurfaceGate.swift` forwards it (the same, or
transformed — a newline inside a cell or a pull-quote/code body becomes `U+2028`, inside a language or
author line it is dropped) or vetoes it after issuing its own top-level edits (a Return in a cell or a
language line is a caret move that registers no undo step; legacy's double-Return exits and
un-makes; a replacement across cells re-issued per cell; a replacement across BLOCKS decided by
legacy's one rule, `applyReplaceOutcome` ported: a container wholly inside the range — code,
pull quote, block quote, table — is dropped with its second lines, blocks between the endpoints are
dropped, the survivor is the start block's role, else the end's, else a fresh body paragraph, a
leaf covered in part keeps its remainder as its own block, a block quote's endpoint child merges
like a paragraph, and a range with an endpoint inside a table it covers only in part is refused). Selection
deletions (`deleteBackward` with a selection, `cut:`) are issued by the host view as
`replaceRange:withText:` with empty text so they reach the gate — before that they went to the
controller, which merged by identity with no rule deciding the survivor, and every container kind
needed its own after-the-fact patch. Consequences settle at the controller's
post-edit callback (`+Settle.swift` from `engineDidFinishEdit`): blocks the edit minted are declared
by rule (a quote child, an author tail restyled to body, a split a dictation made rejoined), a
second line whose container lost its primary region becomes a body paragraph (select all and
Backspace over a code block leaves the language line's identity as the survivor), author-line
presence is fixed, a code body without its language line gets one, and the PRESENTATION of every
block the edit touched or whose role changed is re-derived from its role through the bridge
(`normalisePresentation`: presentation is a function of role and model, never carried by text —
text merged into a cell takes the cell's face, an author tail takes body, stale typing attributes
heal; ambient bold and italic are told from the user's by the engine's base-font key, which the
bridge stamps on header cells and author lines), the replay snapshot registered, typing attributes re-adopted. The
change notification only rebuilds roles by identity — unless the edit carried its plan: a structural
edit goes through `replaceFlat(_:with:adopting:)` and the funnel adopts that plan, by position, in the
edit's own notification, so there is no state in which the roles are a by-identity guess and no
plan can be built from post-edit roles (settle's rejoin once captured its plan after its own merge
and removed a role past the end: device crash, 2026-09-04). `adoptRolePlan` is for structure changes
without an edit; a count mismatch asserts. Measured facts behind this: UIKit's private
should-change delegates are never consulted; every edit issued in one run-loop cycle lands in one
undo group; the controller re-inserts its newline when a NESTED correction leaves a line separator at
its insertion point, moves its caret past nested insertions, delivers nested edits' notifications on
the next processing pass, and spins the run loop inside its own insert — none of which can happen to
an edit issued before or after its own. The host's own edits reach the gated surface too and pass
untouched (the gate and settle each know when they are the ones editing); settle never runs during a
replay. The host never edits inside the change notification. Document sets diff by model id and
replace only the differing span; empty-block typing attributes are pulled by identity from the
bridge.
Document sets diff by model id and rendered text and replace only the differing span
(`tgid_replaceBlocksInRange:withAttributedBlocks:`), attaching to the preceding block so identities
survive; empty-block typing attributes are pulled by identity from the bridge
(`installEmptyLineProviders`, positional while a set is landing). Host commands (insert table, wrap in
quote, …) keep snapshot undo and still clear history (`prepareUndoForStructuralRepair`). A host
COMMAND that issues structural edits from outside the gate frames them with
`performHostStructuralEdit`, which captures the pre-edit roles, tells the gate not to decide them and
settles once at the end — the gate decides KEYSTROKES, and an edit a rule issues already carries its
plan. Tab out of the last cell of a trailing table did not, so the gate read its `"\n"` as a Return in
a cell, ran the command again one level down and vetoed the outer edit, dropping its plan; it produced
the right document only because both plans came from the same roles a moment apart.

**`onChange` fires exactly once per edit, and two paths lost that silently.** Every paragraph mutator
(`setParagraphStyle`, `setList`, `setAlignment`, `indent`, `outdent`) and the list-continuation
reconciliation ends by putting the caret back, and a caret restore reaches `engineDidChangeSelection`
like any other selection change — so each delivered a SECOND `onChange` a run-loop turn behind its
own, because `scheduleSelectionDrivenOnChange` declines only when a notification is already owed and
these marked theirs at the end. `deliveringOneChangeNotification` marks it owed BEFORE the mutation, so
the restore joins it. Separately, while a reconciliation is pending the funnel suppresses each edit's
notification by returning BEFORE marking one owed, so a caret move in that window read the same guard
as false and scheduled a delivery the reconciliation's release could not absorb; that schedule now
defers to a pending reconciliation. Neither fix subsumes the other — reverting either alone brings its
own double delivery back. **The tests that pin this contract could not see it:** they wait for the
FIRST `onChange` and return, so the second lands after the test has finished, and the two cases that
DID notice crashed on a repeat `XCTestExpectation.fulfill` and had the whole class
(`EngineListContinuationTests`) skipped from every run rather than read.
`EngineChangeNotificationCountTests` counts deliveries over a window instead — and had to drain what
its own setup schedules first, or every case reads as 2 whatever the code does. The composer runs a
full layout pass from `onChange`.

**Where presentation goes in that editor is counter-intuitive and cost three wrong designs**: the
canvas renders each block from `block.attributedText`, so there is no render-time attribute hook.
Styling that may be SENT is written into the document and stripped on read-back; styling that must
not be sent, or must change without an edit (a spoiler's hide), goes through
`IDBlockLayout.displayDecorator`; anything font-shaped uses `IDInlineTextBaseFontAttributeName`, the
face the trait pass derives from. Views over text (emoji, dust) are positioned by the host from
`id_rectsForCanonicalRange:` — NOT through `NSTextAttachmentViewProvider`, which cannot be made to
fire at all.

The module is also still reachable from the SwiftPM test target. One suite,
`Tests/RichTextEditorUIKitTests/InputDecUpstreamHostSmokeTests.swift`, stands the host up, makes it
first responder, types into it, and pins the runtime contract gate (140 preflighted contracts — it
was 0 until the port started feeding it the pristine manifest, so it passed by checking nothing).
(`Scripts/verify-ported-files.sh` used to pin the 78 copies by SHA-256 beside it; it is gone with
the port workflow.) The smoke suite does not run automatically.

**There IS an adapter now** — `Sources/RichTextEditorUIKit/InputBackend/InputDec/Upstream/`,
`IDUpstreamInputBackend`, which drives the ported engine through Telegram's own
`RichTextInputBackend` family (this sentence read *"there is no adapter"* until phase 3b; it had been
false since phase 2, and it is exactly the kind of stale claim that reads as freshly verified). It is
**still outside the app build**: the Bazel `srcs` glob excludes that directory, `Package.swift`
compiles it for the test target only, and
`Tests/RichTextEditorCoreTests/SourceBoundary/InputDecUpstreamAdapterBoundaryTests.swift` pins both
halves of that arrangement plus the derived implemented/unimplemented partition. Every requirement
the adapter does not implement reports a NAMED contract violation rather than returning a plausible
value, and a test drives every one of them. There is still **no debug screen and no production call
site**; `RichTextEditorView` stays `.legacy` and `ExperimentalUISettings.inputDecTextBackend` stays
`false`. The older `IDTextEditorBackendModuleProbe.swift` remains what it was: a compile-and-link
probe that imports `RichTextInputDecObjC` and calls one contract-manifest function.

**Phase 3b is the first change in the port that touches production**, and it is a small one:
`RichTextInputBackend` gained `acquireFirstResponder()` / `relinquishFirstResponder()` (answering
`RichTextInputResponderTransition`), because the ported engine's editing surface is a separate view
inside the host and UIKit raises no keyboard for a host that holds the first-responder role itself.
The shipping `LegacyRichTextInputBackend` answers `.hostOwnsTheRole` and touches the responder chain
**not at all** — which is both behaviour-preserving and what makes the pair recursion-proof for a
host that routes its overrides through it. **Nothing in `Sources/` calls either member yet**;
`DocumentCanvasView`'s responder overrides are unchanged, pinned by
`InputBackendSourceBoundaryTests.test_theResponderHandOffHasNoProductionCallSiteYet_R23` (a rule the
phase that wires the canvas is expected to DELETE, not edit around).

**The kernel compiles at the iOS 13 floor and is invisible to the macOS build**, which is what makes a
green `swift build` worthless as evidence about it on its own. Every vendored `.h` and `.m` except
`Host/TGRichTextInputDecModuleAnchor.m` (deliberately left unguarded, so the module has at least one
real symbol to anchor it on macOS) opens with `#if TARGET_OS_IOS`; three kernel headers
(`IDUIKitBehaviorKernel.h`, `IDUIKitInputControllerCapability.h`, `IDUIKitInteractionCapability.h`)
import `<UIKit/UIKit.h>` immediately once that guard opens, and nothing in the kernel uses
`API_AVAILABLE` or `@available` (grep returns zero hits). The consequence, verified directly in this
worktree: a macOS SwiftPM build of this target compiles eleven ~2.4 KB objects with zero defined
symbols and zero Objective-C classes (`nm -g` on all eleven is empty; none carries an
`__objc_classlist` section), while the iOS-simulator build of those same eleven `.m` files defines
**15 Objective-C classes** — confirmed two ways here: the SwiftPM iOS-simulator object files (this
worktree's own DerivedData) and Bazel's `libRichTextInputDecObjC.a` (680,856 bytes, already built
under `bazel-bin`) list the identical 15 class names, from `IDInteractionABISpec` through
`TGRichTextInputDecSelectionRect`. A broken import spelling stays green under `swift build` for
exactly this reason — see the verification traps in the package `CLAUDE.md`.

**Certified build vs. selection floor is a decision already made, not yet code.** The kernel is
*certified* against exactly one OS build (iOS 26.5 / 23F73 — the only combination it has ever run
against upstream, per `Vendor/VENDOR.md`). The backend-introduction plan committed (its decision 2,
dated 2026-08-17; the plan left the tree on 2026-10-12 and is in git history) to eventually *selecting* the ID
backend on a **floor** of iOS 17.0 rather than gating on that exact certified build — but no code
enforces this yet: there is no `IDTextEditorBackend`, no `isSupported()`, nothing beyond the probe
described above. Treat the decision as the constraint later stages must satisfy, not as a description
of anything currently running. The differential-corpus baseline
(`submodules/TelegramUI/Components/RichTextEditor/docs/input-backend-differential-baseline.md`) exists
today only for the legacy backend; the plan calls for re-running that same corpus against the ID
backend, on more than one OS build, before any wider enablement — a matching manifest type encoding
does not prove matching semantics on an OS the kernel was never certified against, and the differential
run is the only instrument that would catch a drift the manifest check cannot see.

**Upstream had no CI either** (no `.github`, `.circleci`, `Jenkinsfile` in `~/Documents/InputDec`):
its enforcement was a standing manual discipline plus the export script's own shape assertions on
every export (clean-tree scope, the host-ABI carve, no leaked canvas-shaped selectors, `VENDOR.md`
provenance). **Those assertions are gone with the export**, and three of the four were real rules
about what this code may contain rather than about how it travelled — in particular "no leaked
canvas-shaped selectors", which upstream also enforced from the other side with `IDProjectSmokeTests`
grepping its own source. Nothing in this repo enforces it today; importing that suite is part of
bringing the proof across. The one *automated* guard that remains is
`VendorSnapshotIntegrityTests`, and it covers the two generated artifacts only.

**The kernel still raises `NSException` on a contract mismatch.** Only the two manifest-resource
lookups were converted to nil-returning; seven raise sites survive (`IDUIKitBehaviorReport.m:83`,
`IDUIKitInteractionCapability.m:119,132,237`, `IDUIKitInputControllerCapability.m:134,231,534` — see
`Vendor/VENDOR.md`), including the `activeController` accessor, which raises on *any* call after
`detach()`. Swift cannot catch an `NSException`, so `TGRichTextInputDecPerform` /
`TGRichTextInputDecPerformReturningObject` (`TGRichTextInputDecExceptionGuard.h`, telegram-ios-authored,
NOT part of the vendored snapshot) are the only sanctioned crossing point. Today that rule is recorded
only as a doc comment next to the probe (`IDTextEditorBackendKernelCallPolicy` in
`IDTextEditorBackendModuleProbe.swift`); the plan assigns an automated grep-based guard
(`IDBackendCallGuardTests`) to a later stage (Task C0) to enforce it mechanically.

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

## iPhone Duo layout (reserved corners)

`ContainerViewLayout.reservedCorners` carries iPhone Duo's corner blocks (the status corner: clock, camera) from a
per-posture table, because the system's own regions are transitional for up to 0.6s after every rotation and fold;
`safeInsets` stay exactly the system's. The rules, the layout API and how to check a screen are in
[`docs/iphone-duo-layout.md`](docs/iphone-duo-layout.md); the all-screens audit is
[`docs/superpowers/duo-screen-audit-2026-10.md`](docs/superpowers/duo-screen-audit-2026-10.md). None of this shows up
as a build error:

- **Folded portrait has a side inset** (right 84, the camera block only at the top). Code that assumes "portrait has
  no side insets" is the main hazard. `UIScreen.main` is the cover screen while unfolded (use
  `mainWindowScreenBounds`), and unfolded landscape is a regular-width phone, not an iPad.
- **Content keeps to the band; bottom buttons and panels span the strip** with `bottomEdgeSideInsets()`, keeping
  clear only of folded landscape-left's bottom block. Exceptions keep the band: small centred controls on the axis of
  band-centred content, tall sheets that scroll up to the top, panels that grow upward, draggable captions.
- **Every Duo fix must reduce to the old expression** with equal side insets and no reserved corners, which is also
  why every bug shape is invisible on other devices. Verify on the Duo simulator (deep links + lldb rotation), not by
  build and review alone: a fix once changed a legacy node while the visible button was another.

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

## Swift 6.4: SimplifyCFG crash in release builds only

`BorrowUtils.swift:551: Fatal error: cannot get borrow introducers for unknown guaranteed value`,
in pass `SimplifyCFG` (jump threading), crashes `swift-frontend` at `-Osize` while debug builds of the
same source compile, so it first shows up on CI. Seen 2026-10-15 in `QrStudioCodePaths.init`: a
nested function called from loops, with the cross-module-inlined `QrCodeMatrix.isEye(x:y:)` (an
`&&`/`||` chain reading `self.size` of the borrowed matrix, a struct holding an array). Calling a
static `QrCodeMatrix.isEye(x:y:size:)` with a local `size` avoids it; removing any other construct of
the function on its own did not.

To reproduce, replay the frontend command from the CI log in the bazel execroot. A single file only
reproduces with a caller added, because WMO deletes an internal function nothing calls before
optimizing it. Give the replay its own `-module-cache-path`: the default relative
`bazel-out/…/_swift_module_cache`, run from the workspace instead of the execroot, writes pcms into
bazel's shared cache under a second path (the `bazel-out` symlink), and the next build fails with
"module '_DarwinFoundation1' is defined in both". Delete the hash directory it wrote to recover.
Also, `Make.py build --target` on a bare `swift_library` builds it for the host (`no such module
'UIKit'`); a library gets its iOS configuration only through the app's transition.

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

## Framework export lists (computed by the build)

`TelegramUIFramework` and `TelegramCoreFramework` export only the symbols their clients use.
- **`TelegramUIFramework`:** its clients are the app binary and the Share, Notification Content,
  Broadcast Upload and Notification Service extensions. It exports 194 of 161,496 public
  symbols in release (214 in debug), which cut it by 13.6 MB (−11.9%).
- **`TelegramCoreFramework`:** its clients are TelegramUI, the app binary and all six extensions.
  It exports 5,279 of 39,436 in release, which cut it by 1.4 MB (−9.2%).

Together, `.ipa` −5.4 MB. The symbol tables went, and so did the unused public code they kept alive.

**Release builds only** (`select` on `:debug`): debug builds export everything, so the per-archive
scans don't run there. A client symbol missing from a list therefore shows up only as a *release*
link error. The list is computed, never checked in. `framework_exported_symbols` (`Telegram/framework_exported_symbols.bzl`)
intersects the undefined symbols of the clients' compiled archives with the symbols the
framework's own archives define. It is then passed through `ios_framework`'s `exported_symbols_lists`.
Each archive is scanned by its own cached action, so an edit rescans only the archives it
changed; a full scan of TelegramUI's debug archives takes ~8.5 s.
There is no cycle: clients *compile* against module interfaces, so the order is client
compile → list → framework link → client link.

- **A new client of either framework** (an extension, or a library of the app binary) must be
  added to that rule's `clients`. A missing one fails that client's link with undefined symbols;
  it never fails at runtime.
- **A new framework under either framework** (a new entry in its `frameworks`) must be added to
  that rule's `provided_by_frameworks`. Otherwise its symbols would be listed as exports the framework
  doesn't define, and `ld` rejects that.
- **Nothing may look up the app's own symbols by name at runtime** (`dlsym`); there is none today.
  `NSClassFromString` and Swift type and conformance lookup use runtime metadata, not exports.
- Count a binary's imports with `xcrun dyld_info -imports`. `nm -u` shows nothing for these
  chained-fixup binaries.

## TelegramApi: Swift payload structs over table-described storage (table-driven TL, steps 1–5)

`Api.X.Cons_y` is a **`@frozen` Swift struct holding one `TLObject`**. `TLObject` is the only
Objective-C class in TelegramApi: a hand-written **non-NSObject root** (MRC, `TelegramApiObjC`
module, `submodules/TelegramApi/ObjC`) with its own reference counting, weak support, and
table-driven `-dealloc` and description. It carries no ivars of its own beyond a 24-byte header.
Each payload's fields live in extra bytes allocated by `TLObjectAllocate(info)`, at offsets the
generator computes (`TLSchemaLayout.storageLayout`):
- `int32` fields first, then every other field 8-aligned (`int256` is 32 bytes), each group in
  schema order;
- then the `uint64_t` presence mask for optional scalars.

The Swift accessors (`@_alwaysEmitIntoClient` + `@inline(__always)`, so they have no symbols)
load at those offsets, and the initializers and `Api.functions` builders store at them. The
engine, `-dealloc` and description read the same offsets from the schema table. **No class,
ivar or runtime name lookup remains.** The blob's image format is documented at the top of
`build-system/SwiftTL/Sources/SwiftTL/SchemaBlob.swift`.

**The schema is `submodules/TelegramApi/swift_scheme.tl`, and Bazel generates the code from it on
every build.** The `TelegramApiGenerated` genrule runs the host tool `//build-system/SwiftTL:SwiftTL`
and declares a fixed file list: `Api0`…`Api43.swift` (`--swift-file-count`, types spread evenly),
`TLApiSchemaData.m`, and the tests' `SchemaFixtures.swift`/`SchemaAccessorProbes.swift`. Nothing
generated is checked in for Bazel; changing the schema is the whole change.
- **SwiftPM reads a locally generated copy** in `Sources/`, `ObjC/` and `Tests/SwiftPMGenerated`
  (TelegramCore's `Package.swift`, which Telegram-Mac builds, depends on TelegramApi's). It is
  gitignored (since 2026-10-15; Telegram-Mac ignores it too): `swift_scheme.tl` is the source of
  truth, so run `submodules/TelegramApi/generate-swiftpm.sh` before a SwiftPM build or
  `swift test`, and again after the schema or the generator changes. Bazel's globs are
  non-recursive so it never compiles that copy; keep them so. **Only ever regenerate all three
  directories together (the script does):** Swift and `TLApiSchemaData.m` from different runs
  disagree on offsets and corrupt memory silently. Nothing checks the pair at run time (one genrule
  action or one script run always writes both); `SchemaTableTests.testHashesMatch` and
  `AccessorProbeTests` catch it in the tests.
- **No header is generated.** `TLApiTypes.h` and the umbrella header are static, and the counts
  and hash are `extern const`s defined in the generated `TLApiSchemaData.m`. A generated public
  header would be on both Bazel's and SwiftPM's include paths, where either copy can shadow the
  other.

**Parsing, serialization and function calls run in a C engine** (`ObjC/Sources/TLEngine.m`)
driven by the table. The generated Swift has no `parse_*`/`serialize`/`descriptionFields`
bodies:
- `Api.parse` falls through to `tlParseTopLevel`;
- `serialize` and `descriptionFields` come from shared `TLObjectBacked` extensions
  (`Sources/TLObjectSupport.swift`);
- storage access lives in `Sources/TLStorage.swift`.

**The schema table is a zlib-compressed image** (blob v3):
- `SwiftTL` (`SchemaBlob.swift`) serializes the layout, including every field offset and each
  constructor's size and presence-mask offset, into a pointer-free image. It is emitted as a
  `const` byte array in the generated `TLApiSchemaData.m`.
- `ObjC/Sources/TLSchemaLoader.m` inflates it once, validates it, and builds the
  `TLTypeInfo`/`TLConstructorInfo`/`TLFieldInfo`/`TLFunctionInfo` structs on the heap. The
  validation covers every field and mask lying inside its object's storage.
- Access goes through `TLApiTypeAt`/`TLApiConstructorAt` (ascending id)/`TLApiFunctionAt`/
  `TLApiFunctionConstructorAt`/`TLApiConstructorWithId`.
- `TLApiSchemaHash` covers the schema and the layout-algorithm version (`SwiftTL-Storage/1`).
  At run time it serves only `tlVerifyClientLayout()` (below); the loader validates the image's
  structure, not its hash. **The 24-byte header size is assumed, not checked** (a user decision): adding an
  ivar to `TLObject` would shift every field. Don't.

Compiler-invisible rules:
- **Only TelegramCore depends on TelegramApi.** Bazel `visibility` on both TelegramApi targets
  admits only `//submodules/TelegramCore`, and TelegramCore's public interface exposes no `Api`
  types. Tests of TelegramCore's Api conversions live in `//submodules/TelegramCore:TelegramCoreTests`.
  TelegramCore's 340 files use `internal import TelegramApi`, so the compiler rejects any public
  TelegramCore declaration that exposes an `Api` type, and importers of TelegramCore no longer load
  TelegramApi implicitly. Neither guard stops an explicit `import TelegramApi` elsewhere: rules_swift
  puts every transitive module on the search path (verified: a probe file in TextFormat's tests
  compiled). So do not add one outside TelegramCore.
- **TelegramApi's symbols are not exported from `TelegramCoreFramework`.** Nothing outside
  TelegramCore uses them, so the framework's computed export list (see "Framework export lists")
  leaves them out. That once took `-unexported_symbol` patterns and cut 1.74 MB, of which 470 KB was
  dead-stripped code.
- **`tlFunction` must stay unspecialized** (`@_semantics("optimize.sil.specialize.generic.never")`).
  Otherwise each of the ~40 result types gets its own closure copy. Check:
  `nm .build/release/TelegramApi.o | xcrun swift-demangle | grep -c "specialization.*tlFunction"` → 0.
- **The schema code generator and engine are trusted; there is no per-constructor wire test.**
  `SchemaGoldenTests` (digests of every fixture recorded from the pre-engine Swift) was removed on
  2026-10-15: every schema change failed it until the new entries were recorded on a frozen
  pre-engine generator. `GoldenTests` keeps about 15 hand-written fixtures whose bytes and logger
  output were recorded pre-engine; never re-record those on the engine.
- **Unknown constructors are logged with their exact id, even after an earlier field failed.**
  That requires the engine to stop where the old Swift parser stopped: a primitive's id in an
  object field consumes the primitive, and a string whose length overruns still skips its
  padding. `Tests/ParseFailureTests.swift` pins the literal log lines; it was validated against
  the pre-engine parser, so do not edit its expectations to match new behaviour.
- **A bytes field's getter returns a new `Buffer` on every access.** Never take a raw pointer
  from it (`x.field.data`, `x.field.size` inside a `memcpy`); copy with `makeData()` or
  bind the `Buffer` inside `withExtendedLifetime`. This was a real use-after-free
  (inline callback button data).
- **Offsets are baked into Swift and into the table; they must agree.** `AccessorProbeTests`
  (generated probes) reads every field of every fixture through the Swift accessors and compares
  it with the table-driven description; since the fixtures are built through the Swift
  initializers, that also checks construction (Swift offsets) against the table. Change
  `storageLayout` only together with the layout version in
  `main.swift`'s hash string.
- **Accessor offsets are part of TelegramCore's compiled code.** They are
  `@_alwaysEmitIntoClient`, so a TelegramApi regeneration needs TelegramCore recompiled. Bazel
  does that. SwiftPM and Xcode incremental builds were seen NOT to recompile a client whose
  inlined accessor changed. `tlVerifyClientLayout()`, called from `initializedNetwork`, carries the
  hash as an inlined literal and traps on a stale client. Clean-build clients after regenerating
  outside Bazel.
- **`Api` enums print their constructor name only** (`CustomStringConvertible`, from the table),
  never field values: `"\(value)"` bypasses the logger's redaction. Reflection metadata stays on.
  Turning it off for TelegramApi in release was measured at −188 KB and kept on by choice. The
  logger goldens pass either way.
- **Generated locals are `_tl`-prefixed** (`_tlObject`, `_tlPresent`, `_tlValue`). `tlStore` is
  generic, so a TL field shadowing an unprefixed local would compile and store the wrong value.
- **Not NSObject on purpose.** `TLObject` inherits nothing Swift can see, and the payload structs
  inherit nothing at all, so a TL field named `hash` or `description` is always the field.
- **Payload fields are read-only.** To change one, construct a new `Cons_y`.
- **The module is MRC.** SwiftPM compiles ObjC *with* ARC by default, so the SwiftPM targets pass
  `-fno-objc-arc` (`unsafeFlags`); Bazel uses `copts = ["-fno-objc-arc"]`. `TLObject.m` `#error`s
  under ARC. `-autorelease` uses `+[NSAutoreleasePool addObject:]`, because `CFAutorelease`
  recurses and crashes. References stored in payload storage are +1; Swift stores them through
  `tlStoreReference`.
- **Logger redaction depends on nested values being Swift enums**
  (`tlDescriptionFields` maps through `tlTypeRegistry`). `GoldenTests` pins the logger
  output with redaction on; `Tests/LoggerDescription.swift` is a verbatim copy of
  `TelegramCore/Sources/State/Serialization.swift` — re-copy it when that file changes.
- **Foreign reference types (C structs) were tried and rejected**: they need iOS 16.4
  (metadata kind 0x204), and multi-payload enums leak them on Swift 6.4.
- Tests: `swift test --package-path submodules/TelegramApi` after `generate-swiftpm.sh` (and
  `-c release -Xswiftc -enable-testing`), `swift test --package-path build-system/SwiftTL`;
  Bazel: `Make.py test --target //submodules/TelegramApi:TelegramApiTests`.

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

## Message send transition (`ChatMessageTransitionNode`)

The send animation (`submodules/TelegramUI/Sources/ChatMessageTransitionNode.swift`) takes its timing from one `ChatMessageTransitionNodeImpl.AnimationParameters` preset per chat, picked when the chat's node is created. **The default is `.bezier`**: 0.3 s on two cubic beziers, no scale. The spring version (2026-10-09) was rolled back to it on 2026-10-16 and is now `.spring`, behind Debug Settings ▸ "Chat: spring send animation" (`ExperimentalUISettings.springSendAnimation`; reopen the chat after toggling). Under `.spring` the vertical axis, the horizontal axis and the bubble scale (a text message squashes from 100% to `scaleDipScale` on one spring, then returns to 100% on another, as additive `transform.scale` phases paired with anchor-keeping position offsets, all four removed together on completion or the bubble blinks at 90% for a frame) each run their own `ContainedViewLayoutTransitionCurve.customSpring`, tuned through the `SpringParameters` constants on `ChatMessageTransitionNodeImpl`. Springs are time-scaled by `CALayer.makeAnimation` to settle within the duration they run with, so only the damping ratio shapes a curve; the preset's `duration` is the single knob for overall speed, and a text message's horizontal spring runs for `textHorizontalDuration` (half of it). When animating a layer directly with these curves, pass `timingFunction: curve.timingFunction` as well as `mediaTimingFunction` — the latter is `nil` for springs, and the default silently falls back to ease-in-out (the mic button's sent-message decoration is one such consumer). For a bezier the non-nil `mediaTimingFunction` wins, so the same call serves both presets.

**Invariant: the history list must scroll with the same vertical curve as the bubble**, or the new bubble drifts relative to its neighbours. `ChatControllerLoadDisplayNode` passes the preset's `verticalListCurve` to `ListViewScrollToItem` (`.Custom` with the bubble's control points under `.bezier`, `ListViewAnimationCurve.CustomSpring` under `.spring`); `listViewAnimationDurationAndCurve` maps `.customSpring` to it (not to the system `.Spring`), and `ListViewImpl` builds the scroll through `CALayer.makeAnimation` so it is configured exactly like the content springs. `ContainedViewLayoutTransitionCurve.solve(at:)` samples the real spring for `.customSpring` (one cached `CASpringAnimation` per parameter set), so display-link consumers follow it too; the animated gradient wallpaper clamps the overshoot. **CoreList, the default backend, holds it too:** `CoreListChatHistoryBackend` maps both `ListViewAnimationCurve.CustomSpring` (scroll and size/inset passes) and `ContainedViewLayoutTransitionCurve.customSpring` (item transitions) to `CoreListTransition.Curve.customSpring`, which emits the same `CASpringAnimation` Display builds — Float-quantized parameters, `duration = settlingDuration`, linear timing, settle mapped onto the pass as `speed` — and whose model `solve(at:)` is the closed-form oscillator, pinned against CA's own solver in `CustomSpringParityTests`. That closed form has **no overdamped branch** on purpose: Display never sets `allowsOverdamping`, and at its default `false` CA renders any damping ratio above 1 as critically damped. The reverse bridge (CoreList curve → ComponentFlow `Curve`, for item internals) still degrades `.customSpring` to `.spring`, since ComponentFlow has no custom spring.

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

**Rich reply quotes** — a reply quoting a selection of a rich message sends `quote_rich`, one
`RichText` per covered text node (`EngineMessageReplyQuote.richText`; `text`/`entities` are its
derived flat form, so every quote consumer reads those unchanged). The pure core (node table,
builder, the server's validation rule) is `TelegramCore/Sources/Utils/RichReplyQuote.swift`; the
renderer stamps each laid-out run with its node and flat range so a selection maps to nodes. The
node-id scheme is shared by the enumerator and the V2 layout and nothing checks the pair. Details
in [`docs/instantpage-richtext.md`](docs/instantpage-richtext.md) under "Rich reply quotes".

## Rust MTProto engine on iOS

The Rust MTProto engine (`third-party/mtproto-engine`, Swift wrapper `submodules/MTProtoRustEngine`)
is linked into every iOS build and selected at runtime: Debug Settings ▸ `Rust MTProto [Restart App]`
writes `networkEngineSettings` (applies at the next launch), and the `Engine:` row under it shows what
the account actually runs — the factory still declines (extensions, DC address overrides)
and the `mtproto_engine_rust_disabled` app config forces MtProtoKit. MtProtoKit stays the iOS default.
A network without a fetched app config of its own (a login, `UnauthorizedAccount`; a fresh account)
follows the accountManager shared entry `NetworkEngineState` instead: after every successful
`help.getAppConfig` each production account records its own value there (`true` and `false`, per
account, OR-ed). A removed or logged-out account's value stops counting once a live account has a
value for the build; until then it stays, so a login after the last logout still honours a `true`.
Networks get it only through `networkEngineInputs(transaction:)`, so none can start without it. The entry also
holds a
local crash-loop fallback (two engine crashes within 24 h turn Rust off for 24 h), fed only by the
app through `recordRustEngineCrash` before accounts start. Each part counts only for the build that
wrote it.
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
  (`rustEngineAuthorizationRequiredAction`). **Never gate it on `MTContext.checkIfLoggedOut`**: the
  `401` is already the server's verdict, while the probe is a key exchange and bind that can only say
  less. The probe must contact the server: its auth action carries `replacesExistingKey` and
  `probedPermanentKey`, so it always makes a fresh temporary key, binds it to the probed permanent key,
  never stores it and gives up without a verdict after 120 s. Without them it completed on the stored
  `EphemeralMain` key (the main session's own, or a stale copy of an expired engine key) and never
  logged anyone out. MtProtoKit's own action logs out on the bind's `ENCRYPTED_MESSAGE_INVALID`: it is
  MtProtoKit's answer to a `-404` on a session under the permanent key.
- **Refused binds alone never log out.** A server refuses fresh temporary keys for a while for other
  reasons too, and a logout wipes local data. The engine's `PermanentKeyInvalid` on the home
  datacenter (`handlePermanentKeyInvalid`) is made of refused binds only:
  - While MtProtoKit runs the context's key actions (no `RustEngineActions` installed, for example a
    session still draining after a switch to MtProtoKit), it starts nothing and the session keeps
    binding, because MtProtoKit's probe would decide on one refused bind.
  - While the engine's actions run them, it starts `checkIfLoggedOut` on the engine's action. The gate
    and the check's factory read happen in one block on MTContext's queue
    (`rustEngineStartLogoutCheck`), which needs MTContext to have the active engine's own factories, and
    `activate`/`deactivate` write the factories only on that queue, so a check it starts never gets
    MtProtoKit's action, nor a replaced engine's.
    The engine's check logs out only when all of these hold (`rustEnginePermanentKeyUnknownDenial`):
    - the context registry has the engine's report and a session's refused bind, watched for 10 s;
    - the server has shown no sign of knowing the key in this context within the last day (an
      answer, an update or an accepted bind under it). This is tdlib's immunity: a datacenter
      incident can hide a known key, -404s included;
    - after that, a call sent under the permanent key itself (`help.test`, no PFS, as tdlib validates
      its main key) gets nothing but `AuthKeyInvalid` (`-404` twice, the second on a fresh
      connection), and the evidence still holds.

    Any answer to that call, an error included, keeps the account, and no answer gives no verdict.

  A false logout is the worst outcome there is: never loosen any of these.
- **While Rust carries a network, `MTContext`'s permanent keys, its logout check and its
  authorization transfers run on the engine** (`RustEngineActions`, through MtProtoKit's public
  `MTExternalActions.h` factories), so over HTTP or Telegram Web where TCP is blocked. Installed by
  `NetworkEngine.activate()` (once in `initializedNetwork`, and by `SwitchingNetworkEngine` on every
  live switch, which deactivates the old engine first), never in extensions. `MTContext` stays the one
  coordinator and the only writer: a permanent key is stored through
  `-[MTDatacenterAuthAction completeWithAuthKey:…]`, whose compare-and-set keeps a key that appeared
  meanwhile; a transfer never resends exported bytes after a failure (one fresh export instead) and
  writes the token only if the destination's permanent key is still the one the import ran under.
  `deactivate()` (a switch to MtProtoKit) ends the actions still running on the engine, so MtProtoKit
  takes their datacenters over after MTContext's backoff (1 s after a first failure, at most 60 s). `UnauthorizedAccount` prefetches permanent keys
  only on Rust, and before login a confirmed unknown home key is replaced (`Network.permanentKeyUnknown`)
  instead of logging out. Details: `docs/swift-integration.md` §9b in the engine.
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

## Opening a channel at a post (history fill and the poll gate)

Measured 2026-10-13:
the Postbox `MessageHistoryView` issues no request; the round trips before a chat shows messages all
come from TelegramCore around it. Four facts keep the critical path at one `messages.getHistory`:

- **A history fill stores before it resolves.** `fetchMessageHistoryHole` stores the messages and
  closes the hole in its first transaction; reply targets, custom emoji files and stories follow, and
  the follow-up re-adds the messages whose reply targets arrived so a view (which watches its own
  chat only) re-renders them. Forums and monoforums keep thread resolution before storage.
- **The around fill learns the top from the server.** `offset_id_offset` is the 1-based position of
  the anchor from the newest message and the server does not fill downward, so the hole closes to the
  top exactly when the newer ids returned number one less than it (`aroundHoleFillRange`, tested in
  `AroundHoleFillRangeTests`). `inexact` vetoes it; the bottom is never inferred.
- **Plain channels request no forum topics.** Every channel post is stored with `threadId = 1`;
  `resolveForumThreads` skips peers that are neither forum nor monoforum (`peerCanHaveForumThreads`).
- **An unjoined channel's view does not wait for the poll.** `wrappedMessageHistorySignal` still
  resets the read state and adds the full hole first, and `keepPollingChannel` still runs (with its
  1.0 s start delay), but the Postbox view is created at once. The profile warmup
  (`keepPeerInfoScreenDataHot`, eight tag views) starts after the first loaded history view.
  The full hole is added once per unpolled period (a flag on the channel's polling context), and a
  fill that closes the hole to the top advances the channel state's `synchronizedUntilMessageId`, so
  the chat's re-subscription after a fill does not wipe it and the poll does not seed a gap hole over it.

## News feed: parked at layer 232 (`TELEGRAM_NEWS_FEED_API`)

Since 2026-10-16 the news feed is parked server-side and the app talks layer 232, whose schema has no feed API:
no `feed.*` types or methods, no `updateReadFeed`, no `channels.editChannelNews`, `channels.joinChannel` without
`for_news`, and a `channel` constructor without `in_news`. That constructor keeps `pinned_msg_id` and is still
`#7ad15240`: a TL constructor id ignores `?true` fields. All News code stays in the app, so the feature comes back
by defining one compile-time condition, not by restoring code. None of this shows up as a build error:

- **`TELEGRAM_NEWS_FEED_API` is defined nowhere.** TelegramCore wraps only the lines that use a removed API symbol,
  or read the removed `in_news` bit, in `#if TELEGRAM_NEWS_FEED_API`. Each `#else` sends nothing and answers with an
  empty success (an empty For you batch, an empty Added page, a read mark kept local, interests left unchanged), so
  no context retries. The feed models, contexts, page storage, grouping, caches and read state stay compiled. Code
  inside an inactive `#if` is not type-checked, which is why the blocks are kept that small.
- **One gate hides News.** TelegramCore exports `newsFeedApiIsAvailable` (Swift defines are per module, so the app
  cannot test the condition itself), and `isNewsFeedEnabled(appConfiguration:apiIsAvailable:)` in `NewsFeedSupport`
  returns false while it is false, before the `dev` flag and the `news_feed_enabled` kill switch. Every News surface
  outside the News modules reads that gate: the tab (`ApplicationContext` → `TelegramRootController`), the channel
  bar (Join or Mute/Unmute instead of the island, also for a channel a 233 build stored with `in_news`) and the
  title's mute badge. `NewsScreen` is still created, like the hidden Calls tab, but never loads, so no feed context
  starts. There is no `#if` on the app side: a new News entry point must go through the gate.
- **A raw bit read compiles silently.** The parse of a channel's `flags2` bit 21 is a bit test, not an accessor, so
  nothing would have caught it; `ParkedNewsFeedApiTests` pins that the parked build ignores it.
- **Stays on:** the pinned-message skeleton (fed by the constructor's `pinned_msg_id` and by `channelFull`'s), no
  read state for unjoined channels (below), and the history-open request chain (above).

To bring the feed back:

1. restore its entries in `swift_scheme.tl`, with `in_news`, `for_news` and `editChannelNews` as the server has them;
2. define the condition for **both** TelegramCore and its tests: `"-DTELEGRAM_NEWS_FEED_API"` in the `copts` of
   `TelegramCore` and `TelegramCoreTestsLib` in `submodules/TelegramCore/BUILD`, and
   `.define("TELEGRAM_NEWS_FEED_API")` in the `swiftSettings` of both the `TelegramCore` and `TelegramCoreTests`
   targets in its `Package.swift`. The tests are their own module. Without the define there, the parked tests
   (`FeedApiConversionTests`, the `in_news` cases of `ChannelInNewsFlagTests` and `ChannelInNewsLocalChangeTests`)
   stay compiled out, `ParkedNewsFeedApiTests` skips itself, and bit 21 is tested by nothing;
3. set `Serialization.currentLayer()` to the server's layer;
4. run `submodules/TelegramApi/generate-swiftpm.sh`.

## Opening a post from the News feed: the cached post first

Reachable only while the feed is on (see "News feed: parked at layer 232" above).
The feed stores every post it shows into the channel's history (inside the hole). Opening a post
from the feed passes `cachedAnchor: true` in `ChatControllerSubject.message`, which the history
view turns into `includeAnchorWhileLoading`: a Postbox view opened around a message that is stored
but still inside a hole then carries that message and its album as entries while it reports
`isLoading` (`MessageHistoryView.isAnchorOnlyWhileLoading`, `PostboxTests`
`MessageHistoryViewAnchorWhileLoadingTests`). Views without the flag keep no entries while loading.
The chat applies the partial view scrolled with the post at the bottom (top edge at the top when
taller). Both measure the post without its date header's space
(`ChatMessageItemView.attachedDateHeaderInset`, `ListViewScrollToItem.excludesAttachedHeaderSpace`):
alone in the view the post carries its day's header, which moves to an older post of the same day once
those load, and a tall post held by its top edge moved with it. The chat also reports the partial
view as loading earlier so the existing placeholder stacks its skeleton bubbles above it, and applies
the loaded view in place (`ChatHistoryViewScrollPosition.pinnedAnchor` /
`.keepInPlace`, resolved in the history node from the post's relative offset). The partial view
reports the history as still loading (`historyState`), so the profile warmup and the pinned-message
view start after the fill as for any other open, and it makes no read claim (`maxReadIndex` is nil,
so no unread separator lands above the post). While the post is pinned and its surroundings have not
loaded, the view reports no hole-fill restart, so a hole operation on the channel (the poll's, or any
other) cannot restart the history around a post that is still inside the hole.

**A channel the account is not a member of has no read state** (For You channels, and channels added only
to News, which stay `.left`): the server keeps none, so the client keeps none either
(`TelegramCore/Sources/State/NonMemberChannelReadState.swift`). Opening one installs a fixed state with
nothing unread and nothing counted (`maxKnownId: Int32.max - 1`), interactive reads do nothing, the
server's read-state operations for it are skipped in replay, and the synchronizer confirms anything queued
for it without sending; dialogs fetched for chat folders store no read state for it either. The state's
`maxIncomingReadId` is 0 on purpose: replaying `.ResetReadState` and validation both keep a local mark that
is ahead of the server's while it reports unread (`localReadMarkIsAheadOfServer`), so a higher one would block
the state a join brings in, which can itself be 0. **A join does
not reliably fetch the dialog:** `initialStateWithPeerIds` judges the stored, still non-member channel and
builds its chat info from stored notification settings, which opening the chat has fetched, so
`resolveMissingPeerChatInfos` asks for nothing. A stored channel that becomes a member therefore queues a
read-state validation itself (`channelJoinNeedsServerReadState` in `updatePeersCustom`). Monoforums (a
user's direct messages with a channel) keep their read state whatever the participation status. A chat
opened from News also shows no unread badge on its back button
(`NavigateToChatControllerParams.showsUnreadChatsBackBadge`).

## A non-contact's chat before it is accepted (suspicious peer)

While a user's chat shows the report/block panel (`PeerStatusSettings` `canReport`/`canBlock`; the one
predicate is `CachedUserData.isSuspiciousPeer`), their incoming messages are untrusted until the panel is
dismissed or the account sends them a message:

- Links, mentions, hashtags and cashtags, emails, bank cards and TON addresses show as plain text
  (`MessageTextEntity.isShownFromSuspiciousPeer`, also in a link preview's text; `instantPageForSuspiciousSender`
  for rich messages). A link preview opens nothing and has no button.
- Buttons are not shown: reply-markup rows, rich inline pills and button rows. A link-styled rich button keeps
  its label as plain text.
- Their emoji status is hidden in the chat title, in the panel's "is a mark for Premium" note and in the
  profile header, including the cover and colours of a collectible status.
- Nothing is marked read (`ChatHistoryListNode.holdsReadsForSender`). Reads also wait while a non-contact's
  settings are still unknown, as on the first open of a chat they started: a read cannot be taken back.

Non-obvious:

- **Sending clears the flags locally.** `enqueueMessages(transaction:)` drops `canReport`/`canBlock` for a
  non-scheduled send; Add Contact stays. `users.getFullUser` rewrites the settings on every refresh, so if the
  server keeps those flags after a reply, the state returns on the next refresh. Unverified as of 2026-10-21
  (no second account to test with); the fallback is `hidePeerSettingsBar` on send, which also drops Add Contact.
- **The rich transform keeps every block's index.** A button row stays with no buttons, which lays out to
  nothing and adds no spacing. Block paths are rich-quote node ids, and quotes are built from the stored page.
  Removing an inline pill drops its label from its node's text, so such a message cannot be partially quoted
  while the state lasts.
- Private chats only. Chat list rows, search, and groups or channels with a report panel are unchanged.

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
6. Full project build per wave (`Make.py build --continueOnError`). When a wave touches a module that has an `ios_unit_test` target, run it too (`Make.py test --target <label>`).
7. **TelegramCore never imports UIKit/Display.** `TelegramCore` is shared with the Telegram-Mac codebase; its Bazel `deps` and source files must not reference UIKit, Display, or any Apple-UI framework. UIKit-needing helpers (image scaling, rendering, etc.) stay in consumer-side submodules.
8. **Never substitute Postbox protocols (`Media`, `Peer`, `Message`) with `Any` / `AnyObject`** in code that previously used them. Type erasure throws away the domain semantics that the next reader expects. Use the matching engine wrapper (`EngineMedia`, `EnginePeer`, `EngineMessage`) — extending it as needed (e.g. add a missing case-init or convenience). If neither typealias nor wrapper covers the use site, restore the original Postbox import + type for now and flag the case for a future facade. Existing `Any`/`AnyObject` parameters predating the refactor are not in scope for this rule.
9. **Functionality must not change.** Converting between types is allowed (wrap/unwrap, typealias swaps, retyping to a wrapper); behaviour is not. A green build is not proof: review the diff for equality and identity (`EngineMessage` is a class with field-wise `==`; two wrappers of one message are not `===`), hashing, overload resolution after an import is dropped, signal emission (optional vs `.never()`), default arguments and lifetimes. Record how equivalence was checked in the wave's log entry.
10. **TelegramCore's public API changes in place**, model types included: no additive accessor, init or overload is kept beside the raw one, and nothing is kept for Telegram-Mac (it follows the same refactor). Persisted encodings (PostboxCoding, FlatBuffers) stay byte-identical; keeping raw storage internal behind a retyped public surface is the default shape for model types.
11. Every wave appends its outcome to `docs/superpowers/postbox-refactor-log.md` in its own commit.
12. **The guard only shrinks.** `build-system/Make/PostboxImportCheck.py` runs before every `Make.py build`/`test` and fails when an in-scope Swift file imports Postbox without being listed in `submodules/Postbox/AllowedImporters.txt`, or a listed file no longer does. Bazel `visibility` on `//submodules/Postbox:Postbox` (`clients`, `test_clients` in its BUILD) fails a dep from any other package. A wave that frees files or packages removes them from both lists in the same commit; adding to either is a deliberate exception, made in review. The same check guards `.postbox` access:
    - An in-scope file whose code contains `.postbox` must be listed in `submodules/Postbox/AllowedPostboxAccess.txt`, and every listed file must still use it. Comments and strings don't count; code inside string interpolation does.
    - A wave that removes a file's last `.postbox` use deletes its line in the same commit.
    - `python3 build-system/Make/PostboxImportCheck.py --report` prints the access measures each wave records.

    Tests: `python3 -m unittest discover -s build-system/Make/tests`.

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

The list above is not exhaustive: `grep -rh 'public typealias Engine' submodules/TelegramCore/Sources` lists every alias. Prefer non-`EngineRaw*` ones.

### Engine wrapper cheat sheet

Postbox types that have an engine wrapper. Prefer these to `EngineRaw*` aliases; the full table, with unwrap methods, is in the log's "Engine wrapper inventory". Not all of them are value types: `EngineMessage`, `EngineRenderedPeer` and `EngineMediaResource` are classes, so two wrappers of one raw object are not `===` (rule 9).

```
Peer → EnginePeer (_asPeer())             RenderedPeer → EngineRenderedPeer
Message → EngineMessage (_asMessage())     Media → EngineMedia (_asMedia())
MediaResource → EngineMediaResource (_asResource()); .Id, .ResourceData, .FetchStatus for its id/data/status
PeerPresence → EnginePeer.Presence         CombinedPeerReadState → EnginePeerReadCounters
ChatListTotalUnreadState → EngineTotalReadCounters   PeerGroupId → EngineChatList.Group
```

`EngineMedia.init(_:)` has a `preconditionFailure()` for any `Media` class outside its cases. Each TelegramCore media class has a case. An app-side pseudo-media class must conform to `EngineCustomMedia`, and wraps as `.custom`; today that is the three link-preview placeholders in `WallpaperPreviewMedia`. `build-system/Make/PostboxImportCheck.py` enforces this on every `Make.py build`/`test`. It fails on any in-scope class, struct, enum, protocol or extension whose inheritance list names `Media` (or `EngineRawMedia`) anywhere without also naming `EngineCustomMedia`. A grep had missed `: EngineRawMedia` conformers, and that gap let waves 455 and 458 trap on wallpaper, theme and gift link previews.

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
