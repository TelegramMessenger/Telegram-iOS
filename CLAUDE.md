# CLAUDE.md

This file provides guidance to AI assistants when working with code in this repository. It holds what applies
anywhere in the codebase: building, testing, driving the simulators, and the rules any change can trip. Each
subsystem's own notes are in a `CLAUDE.md` beside its code, which Claude Code loads when files under that directory
are read; "Subsystem guides" below lists them. **Put a new subsystem's notes there, not here.**

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

**Running tests.** `Make.py test` runs Bazel test targets (same config + codesigning as `build`, forced `debug_sim_arm64`). It accepts `--target <label>` (default `Tests/AllTests`) so a single `ios_unit_test` can run in isolation, e.g.:

```sh
source ~/.zshrc 2>/dev/null; python3 build-system/Make/Make.py --overrideXcodeVersion --cacheDir ~/telegram-bazel-cache \
 test --configurationPath build-system/appstore-configuration.json \
 --gitCodesigningRepository git@gitlab.com:peter-iakovlev/fastlanematch.git \
 --gitCodesigningType development --gitCodesigningUseCurrent --target //submodules/TextFormat:TextFormatTests
```

An `ios_unit_test` here needs an `ios_test_runner` pinned to a real device/OS (e.g. `iPhone 17` / `26.5`) — the default runner picks an invalid device and the test process exits 15. **Run targets via `--target`, not the default suite:** `Tests/AllTests` references a dangling `//submodules/TgVoipWebrtc:TgCallsTests`, so the default fails to build until that suite is repaired.

**A failing iOS test run must not sit in `simctl diagnose`** for up to 10 minutes after its last test:
`MODULE.bazel` patches xctestrunner so that it does not (why, and what the patch changes:
`build-system/bazel-patches/CLAUDE.md`). **If a failing run still
stalls after its `Test Suite … failed` line:** `pgrep -fl "simctl diagnose"`. A hit means the patch is not in effect;
killing that process is safe (it only collects logs) and the run returns at once with its real result. Scripts that call
xcodebuild themselves pass `-collect-test-diagnostics never`, as two arguments.

Pure C++ units have host `cc_test`s that bypass Make.py entirely (macOS build, no codesigning):
`./build-input/bazel-9.2.0-darwin-arm64 test //submodules/TgVoipWebrtc:streaming_audio_renderer_test --test_output=all`
(likewise `:mtproto_ice_transport_test`, and outside tgcalls `//third-party/libprisma:SyntaxHighlighterTests` and
`//third-party/webrtc:neteq_normal_test`, NetEq in our WebRTC fork, whose header gives the ASan flags it needs). The
tgcalls ones follow a plain `CHECK_TRUE` + `main()` pattern, are listed
explicitly in `submodules/TgVoipWebrtc/BUILD` (group sources are not globbed), and must be added to the
`exclude:` list in `tgcalls/Package.swift` so SwiftPM does not compile their `main()`. The first run compiles
WebRTC for the host (~2.5 min); later runs take seconds. The binary is version-stamped and
arch-suffixed (`bazel-9.2.0-darwin-arm64`), not the bare `bazel-8.4.2` the tgcalls CLAUDE.md names; `versions.json`
is the single pin.

Host `swift_test`s run the same way (`… bazel-9.2.0-darwin-arm64 test //submodules/MetalEngine:MetalPipelineCacheTests`; one test
via `--test_filter=MetalPipelineCacheTests/<name>`, comma lists are not supported): `MetalPipelineCacheTests` (runs
on the Mac's GPU), `//submodules/MTProtoRustEngine:MTProtoRustEngineMappingTests`,
`//submodules/UrlWhitelist:UrlWhitelistTests`, `//third-party/widget-sandbox:WidgetSandboxIntlTests`.

**App-side `ios_unit_test` targets**, each run via `--target` (what each one pins, and what app code can and cannot do
in a test process: [`docs/app-unit-tests.md`](docs/app-unit-tests.md)): `//submodules/TextFormat:TextFormatTests`,
`//submodules/Postbox:PostboxTests` (add new Postbox regression tests under `submodules/Postbox/Tests/`),
`//submodules/TelegramCallsUI:TelegramCallsUITests`, `//submodules/TelegramAudio:TelegramAudioTests`,
`//submodules/TelegramUI/Components/Chat/ChatTextInputPanelNode:ChatTextInputPanelNodeTests`,
`//submodules/TelegramUI/Components/PeerInfo/PeerInfoPaneNode:PeerInfoPaneNodeTests`,
`//Telegram/NotificationService:NotificationServiceTests`,
`//submodules/TelegramUI/Components/Chat/EditableTokenListNode:EditableTokenListNodeTests`,
`//submodules/PeerAvatarGalleryUI:PeerAvatarGalleryUITests`, `//submodules/MediaPlayer:UniversalMediaPlayerTests`,
`//submodules/UndoUI:UndoUITests`, `//submodules/ContactsPeerItem:ContactsPeerItemTests`,
`//submodules/TelegramUI/Components/ChatControllerInteraction:ChatControllerInteractionTests`,
`//submodules/ReactionSelectionNode:ReactionContextGeometryTests`,
`//submodules/PasswordSetupUI:PasswordSetupUITests`,
`//submodules/ItemListUI:ItemListUITests`,
`//submodules/LegacyMediaPickerUI:LegacyMediaPickerUITests`,
`//submodules/TelegramUI/Components/ChatTitleView:ChatTitleViewTests`,
`//submodules/TelegramUI/Components/InteractiveTextComponent:InteractiveTextComponentTests`,
`//submodules/TelegramUI/Components/Chat/ChatSendStarsScreen:ChatSendStarsScreenTests`,
`//submodules/TelegramUI/Components/LegacyMessageInputPanel:LegacyMessageInputPanelTests`,
`//submodules/TelegramUI/Components/VideoMessageCameraScreen:VideoMessageCameraScreenTests`,
`//submodules/TelegramUI/Components/EntityKeyboard:EntityKeyboardTests`,
`//submodules/TelegramPresentationData:TelegramPresentationDataTests`,
`//submodules/TranslateUI:TranslateUITests`,
`//submodules/MtProtoKit:MtProtoKitTests` (also `swift test` in `submodules/MtProtoKit` on macOS), and the targets the
subsystem guides name. `PresentationStrings` cannot be built in a test process (it asserts without the app bundle's
`PresentationStrings.data`), so keep a decision under test strings-free. The RichTextEditor SwiftPM package keeps its
own suite (`swift test` / `Scripts/iostest.sh`). Most modules still have no tests.

### Updating the running simulator after a rebuild (whole-`.app` copy)

`simctl install` will NOT replace an already-installed app when the build number is unchanged (installd keeps a hard-link cache), so a rebuilt binary silently doesn't take effect. **Preferred fix: copy the whole freshly-built `.app` over the installed bundle in place.** This is more robust than swapping only the `Frameworks/TelegramUIFramework` binary (no risk of app↔framework version skew), and it preserves the account/login because the **data container is a separate path** (`.../data/Containers/Data/Application/<uuid>/`, keyed by bundle id) — only the **bundle** container is replaced, and the install-DB entry stays valid since the path + bundle id are unchanged.

```sh
K3=4483DD69-685A-4FE1-89BE-65F992C271F2   # iPhone 18 Pro K3 (use the dedicated K-sims, not the shared default)
# K1=03A7DA9C-1832-49B8-9858-2F54F2FB5A04, K2=E643A78E-DB62-4DA4-9F54-BD0836F434AF (both iPhone 18 Pro).
BUNDLE=ph.telegra.Telegraph
# Fresh build output: go through `bazel-bin`, which bazel repoints at the LAST build's configuration.
# Never `find` under `bazel-out`: it keeps every configuration ever built, so `… | head -1` can return a
# stale *device* archive, which copies fine and then refuses to launch ("request was denied by service
# delegate (SBMainWorkspace)"); `lipo -archs` can't tell device from simulator arm64.
# Source the .ipa, never `Telegram_archive-root/` (see below): the .ipa is rewritten every build.
STAGE=$(mktemp -d)
unzip -q -o bazel-bin/Telegram/Telegram.ipa -d "$STAGE"
SRC="$STAGE/Payload/Telegram.app"
DEST="$(xcrun simctl get_app_container "$K3" "$BUNDLE" app)"   # installed bundle path
# GUARD before the destructive rm: never rm the installed app unless SRC actually resolved,
# or a failed cp leaves the sim with NO app installed (relaunch then fails).
[ -x "$SRC/Telegram" ] || { echo "no fresh bundle at SRC=$SRC — aborting"; exit 1; }
xcrun simctl terminate "$K3" "$BUNDLE" 2>/dev/null            # terminate before replacing the running binary
rm -rf "$DEST" && cp -Rp "$SRC" "$DEST"                        # replace bundle in place; data container untouched
rm -rf "$STAGE"   # every staging left behind keeps ~580 MB in $TMPDIR
xcrun simctl launch "$K3" "$BUNDLE"
```

The sim ignores code signing, so the unsigned bundle runs fine.

**`Telegram_archive-root/` goes stale silently — do not install from it.** It is written by the
Make.py wrapper's post-build packaging, which re-runs only when the packaging action is not a cache hit, so after an
incremental build it still holds a PREVIOUS build's binaries while `bazel-bin/Telegram/Telegram.ipa` is rewritten.
Nothing shows it: bazel stamps `Jan 1 1980` on everything there (mtime is useless), and the stale bundle launches and
behaves normally, as older code than the source you are reading. If you ever do copy from archive-root, verify first:
`md5 -q .../Telegram_archive-root/Payload/Telegram.app/Frameworks/TelegramUIFramework.framework/TelegramUIFramework`
against the same path unzipped out of the `.ipa`, and treat a mismatch as stale.

(The older framework-only `cp` of `TelegramUIFramework` still works and is faster, but prefer the
whole-`.app` copy to avoid version skew.)

### Driving the simulator UI: use the Xcode MCP server

**XcodeBuildMCP is configured for this project** (`~/.claude.json` → `projects["…/telegram-ios"].mcpServers.XcodeBuildMCP`, run as `npx -y xcodebuildmcp@latest mcp`). Its tools appear as `mcp__XcodeBuildMCP__*` and are the way to **interact with** a running simulator — screenshots, `describe_ui` accessibility dumps, taps/swipes/typing, log capture. Reach for it whenever a change needs verification that a build alone can't give: flipping a Debug Settings flag, opening a chat, scrolling a list, checking that something rendered.

Do **not** fall back to `cliclick` / `osascript` / `screencapture -R` for this. Those need macOS Accessibility and Screen Recording privileges that the terminal running Claude Code does not have (`cliclick` reports "Accessibility privileges not enabled"; `screencapture -R` fails with "could not create image from rect"), and with several K-sims booted at once there is no way to identify the right Simulator window anyway. `xcrun simctl io <udid> screenshot` **does** work without extra privileges and is fine for a passive look, but it cannot drive anything.

If the `mcp__XcodeBuildMCP__*` tools are absent from a session's tool list (the server can be configured without its tools being exposed), say so and hand the interactive checks to the user rather than attempting the privilege-blocked fallbacks.

### Visual features and animations: verify from recorded frames

Any visual change, and always an animated one, is verified by recording the simulator and reading its frames, not by
a green build: [`AGENTS.md`](AGENTS.md), "Visual features and animations" (`simctl io recordVideo`, then
`tools/animation_sheet.py` for labelled frame sheets, per-frame numbers and per-element tracks in points).

### CI builds and external downloads

GitLab CI (`.gitlab-ci.yml`) builds, uploads to TestFlight and verifies in tart VMs on the runner host; how they run,
lock and reach the bazel cache is `build-system/Make/CLAUDE.md`. **Every external download must carry a checksum.**
bazel-remote serves an archive from its store only when the request names its sha256; without one every ephemeral VM
downloads it again from the internet and misses the 60s `--remote_timeout` (the build log fills with
`Remote Cache: DEADLINE_EXCEEDED`, which reads like the VM cannot reach the cache). rules_rust 0.74.0 knows checksums
only up to Rust 1.98.0, so `MODULE.bazel` supplies 1.98.1's in
`rust.toolchain(sha256s = …)`. **Bumping the Rust version means updating that dict** (each archive's checksum is at
`static.rust-lang.org/dist/<archive>.sha256`), or dropping it once rules_rust's `known_shas.bzl` covers the version.

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
- App-side tests: "Running tests" above

## RichTextEditor editor & the `ChatInputContent` composer

The from-scratch WYSIWYG rich-text editor (`submodules/TelegramUI/Components/RichTextEditor`, with its own guides) is
the native chat-composer backend. By default the composer is a **dual-field switch**: the legacy input, latching to the
native editor only when content becomes legacy-non-representable. `ios_rich_input_mode = 1` makes it always native on
the legacy editor; Debug Settings ▸ "Input V3" (`useInputDecEngine`, iOS 18.4+) always native on the engine editor.
`ChatInputContent` (a TelegramCore value model), not `NSAttributedString`, is the composer currency. The app-side
integration is [`docs/richtext-composer.md`](docs/richtext-composer.md): the model and its invariants, composer ↔ editor
wiring, the formatting / custom-emoji / mention / date / code-block / inline-media round-trips, rich-message send / edit
/ pending display, the long-press-Send preview, **media pre-upload** (attached media uploads at once and is promoted to
cloud media, surviving the editor closing and reopening) and draft persistence (local, cross-device media sync,
re-login restore). Both editor hosts (composer, article editor) lay text out pixel-identically to the InstantPage V2
renderer with the chat-message metrics (`RichTextRenderMetrics`), and libprisma highlights code blocks in both through a
host seam (the package cannot depend on the highlighter). Message rendering:
[`docs/instantpage-richtext.md`](docs/instantpage-richtext.md).

## Subsystem guides

A nested guide loads by itself once a file under its directory is read; read it first when planning a change to that
subsystem from elsewhere.

- **Embedded watch app** (`--embedWatchApp`): `Telegram/CLAUDE.md`. `Telegram/WatchApp/` is a synced snapshot of
  `~/build/tgwatch`: never hand-edit it.
- **InputDec engine and kernel**: this repo owns `RichTextEditor/Sources/RichTextInputDecUpstream/` and
  `RichTextInputDecObjC/` (edit them here; their own tests are in `RichTextEditor/Host/Engine/`). Guides there and in
  `Sources/RichTextEngineEditor/` (the "Input V3" editor) and `Sources/RichTextEditorUIKit/InputBackend/`.
- **TelegramApi** (generated from `swift_scheme.tl`): `submodules/TelegramApi/CLAUDE.md`. Only TelegramCore may
  `import TelegramApi`; elsewhere it would still compile. The news feed and agent APIs are parked behind `#if` there
  ("Parked APIs"); News and an agent bot's provider rows are off while they are.
- **Chat history list, send animation, a non-contact's unaccepted chat**: `submodules/TelegramUI/Sources/CLAUDE.md`;
  the CoreList backend: `submodules/TelegramUI/Components/CoreList/CLAUDE.md`,
  [`docs/chat/corelist-chat-history-backend.md`](docs/chat/corelist-chat-history-backend.md).
- **News tab** (its CoreList feeds and header, Compact / Expanded posts):
  `submodules/TelegramUI/Components/News/CLAUDE.md`.
- **Opening chats, history fills** (holes, poll gate, forum topics and skeletons, News feed opens, non-member read
  state): `submodules/TelegramCore/Sources/State/CLAUDE.md`; a post's comments:
  `submodules/TelegramCore/Sources/TelegramEngine/Messages/CLAUDE.md`.
- **Account state sync** (`AccountStateManager`, `Sources/State/Sync/`: updates, getDifference, the
  `differenceTooLong` reset, history fills confirming stored messages; `Tests/StateSync`): the same
  `submodules/TelegramCore/Sources/State/CLAUDE.md`, and the map [`docs/state-sync.md`](docs/state-sync.md). **The
  rule is that nothing in it gives up on an error** (logout aside; the guide names today's exceptions), and the
  notification extension never resets the account.
- **Rich-text messages, InstantPage V2**: `submodules/InstantPageUI/CLAUDE.md`,
  [`docs/instantpage-richtext.md`](docs/instantpage-richtext.md).
- **Message widgets** (incl. `ChatMessageWidgetBubbleContentNode`):
  `submodules/TelegramUI/Components/MessageWidget/CLAUDE.md`,
  [`docs/message-widgets-native-runtime.md`](docs/message-widgets-native-runtime.md),
  [`Tests/WidgetHarness/CLAUDE.md`](Tests/WidgetHarness/CLAUDE.md).
- **Native HLS player** (incl. `TelegramUniversalVideoContent/Sources/HLSNative/`): `submodules/HLSPlayback/CLAUDE.md`.
- **Rust MTProto engine**: `submodules/MTProtoRustEngine/CLAUDE.md`. **A false logout is the worst outcome there is**:
  read it before touching logout, permanent-key or authorization code in TelegramCore, MtProtoKit or the engine, and
  never loosen the gates it lists.
- **Network telemetry**: `submodules/TelegramCore/Sources/Network/CLAUDE.md`. **WEB proxy carrier**:
  `submodules/WebProxyTransport/CLAUDE.md`.
- **Postbox** (`SqliteValueBox` self-heal, shared-media tombstones): `submodules/Postbox/CLAUDE.md`. Upgrading
  SQLCipher / FFmpeg: `submodules/sqlcipher/CLAUDE.md`, `submodules/ffmpeg/CLAUDE.md`.
- **CI VMs, CI compiler-crash repro**: `build-system/Make/CLAUDE.md`; xctestrunner patch: `build-system/bazel-patches/`.
- **Composer harness** (`Tests/ComposerHarness`, a loginless app hosting the real chat composer, for regression
  tests): [`Tests/ComposerHarness/CLAUDE.md`](Tests/ComposerHarness/CLAUDE.md).
- **MediaGrid** (`submodules/TelegramUI/Components/MediaGrid`, the layer-based photo grid on CoreList's scroll engine,
  with its demo app): `submodules/TelegramUI/Components/MediaGrid/CLAUDE.md`.
- **Framework export lists** (`TelegramUIFramework` and `TelegramCoreFramework` export only what their clients use, in
  release builds only): `Telegram/CLAUDE.md`. A new extension, app library or framework must be added to the rule's
  lists or the *release* link fails; nothing may look up the app's own symbols by name at runtime (`dlsym`).
- **Photo picker grid (MediaGrid v2)**: the layer grid `submodules/TelegramUI/Components/MediaGrid/CLAUDE.md` (its
  PhotoKit stack `MediaGridPhotoLibrary` is described there too); the picker seam and killswitch
  `submodules/MediaPickerUI/CLAUDE.md`.
- **Profile Media tab on MediaGrid** (levels 3/5/15, sparse history holes, killswitch):
  `submodules/TelegramUI/Components/PeerInfo/PeerInfoVisualMediaPaneNode/CLAUDE.md`.
- **Theme settings and the bubble-free mode** (what older builds read, the per-mode accessors):
  `submodules/TelegramUIPreferences/CLAUDE.md`.
- **Smaller ones**: links with a login part (`submodules/UrlWhitelist/`), the code-block highlighter's recursion bound
  (`third-party/libprisma/`), an Apple Metal binary-archive bug (`submodules/MetalEngine/`), wallpaper soft light
  (`submodules/GradientBackground/`), app-side tests ([`docs/app-unit-tests.md`](docs/app-unit-tests.md)), VoiceOver
  screen status and how to check a screen ([`docs/accessibility/voiceover-inventory.md`](docs/accessibility/voiceover-inventory.md)).

## The system ICU: only the SDK's headers are public

`libicucore` ships with iOS, but only the functions `$SDK/usr/include/unicode/*.h` declare (character properties, case
mapping, UTF, IDNA, regex) are public API. Any other (`unumf_*`, `udat_*`, `ucol_*`, `ubidi_*`, `uloc_*`, …) links,
since the SDK's `libicucore.tbd` exports it, and App Store review then rejects the build ("Non-public API usage"). Never
declare an ICU function by hand: locale formatting goes through Foundation, as message widgets' Intl does.
`build-system/Make/ICUImportCheck.py` fails `Make.py build` on any libicucore import of the built `.ipa` that the
SDK's headers do not declare.

## iOS 26/27 windows and touch delivery

Three measured facts that are invisible from the code
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

`ContainerViewLayout.reservedCorners` carries iPhone Duo's corner blocks (the status corner: clock, camera), additional
to `safeInsets`. Both take the system's sizes (occlusion regions, safe area) whenever the system's report fits the
window's posture; a per-posture table names the posture and stands in with its settled sizes for the up to 0.65s after
every rotation and fold that the report is transitional (`iPhoneDuoReservedArea`). Never hardcode the island's size: read
`reservedCorners`. The rules, the layout API and how to check a screen are in
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
  build and review alone: the node a fix changes may not be the one on screen.

## Swift 6.4: `[weak]` in a local closure that also captures a `var`

Swift 6.4 (Xcode 27) miscompiles this shape, at `-Onone` as well as `-O`: a closure literal stored in
a local `let`, with a `[weak x]`/`[unowned x]` capture list, that **also captures a mutable local** and
never escapes (only called directly). `MandatoryAllocBoxToStack` moves the capture box to the stack and
destroys it right after the closure is formed, before the closure is ever called. For an NSObject-derived
`x` the load then reads a dead slot (a crash in `objc_msgSend` on device; macOS 27 traps "not in the weak references
table"); for a native Swift class it silently returns nil, so `guard let x else { return }` skips the work. Closures passed straight to a
non-escaping parameter, or a declared `weak var w = x` captured instead, are compiled correctly.

Write such a closure with a strong capture (`{ [self] i in`), which cannot cycle because it never
escapes (as `processPollOptionItem` in ComposePollScreen and `processTodoItemItem` in ComposeTodoScreen do). In a
binary the fingerprint is a weak/unowned `…Init` whose stack slot gets `…Destroy`ed before the first call to a closure
specialized as `Arg[n] = Stack Promoted from Box`.

## Swift 6.4: SimplifyCFG crash in release builds only

`BorrowUtils.swift:551: Fatal error: cannot get borrow introducers for unknown guaranteed value`,
in pass `SimplifyCFG` (jump threading), crashes `swift-frontend` at `-Osize` while debug builds of the
same source compile, so it first shows up on CI. The known trigger, in `QrStudioCodePaths.init`: a nested
function called from loops, with the cross-module-inlined `QrCodeMatrix.isEye(x:y:)` (an `&&`/`||` chain reading
`self.size` of the borrowed matrix, a struct holding an array). Calling a static `QrCodeMatrix.isEye(x:y:size:)` with a
local `size` avoids it; removing other constructs of the function did not.

Replaying the crashing frontend command from a CI log, without corrupting bazel's module cache:
`build-system/Make/CLAUDE.md`.

## Per-module `-O` and pixel loops

Almost every submodule builds `-Onone` under `--configuration=debug_*`. Exactly **two** override it with
`copts = ["-O"]`: `submodules/GradientBackground` and `submodules/AnimatedStickerNode`. Nothing about a
call site reveals which side of that line it is on. (Third-party C/C++ that runs inside a chat layout pass is
`-O2` in every configuration too: `third-party/quickjs-ng` and twidget's LiteHTML (`OPTIMIZE` in
`third-party/twidget/BUILD`); `-O0` doubles a message widget's boot.)

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

Reimplementing a CoreGraphics operation (CoreGraphics' soft light, `vImageScale_ARGB8888`) and the transparent
wallpaper pattern that a compose must keep: `submodules/GradientBackground/CLAUDE.md`.

## Neighbor descriptors

A `ListViewItem` does not see its neighbors. It sees `ListViewItemNeighbors` — two `AnyEquatable`
descriptors that the adjacent items published via `neighborDescriptor`, read through facet protocols
(`ItemListNeighborFacet`, `HeaderNeighborFacet`, and module-local ones); `nodeConfiguredForParams`, `updateNode`
and `ListViewItemNode.layoutForParams` take no `previousItem:`/`nextItem:`.

**A descriptor must encode everything a neighbor reads.** `ListViewImpl` relayouts a row exactly
when its `ListViewItemNeighbors` value changes (`ListViewItemNode.appliedNeighbors` vs
`ListView.neighbors(at:)`), so a fact omitted from a descriptor goes stale on screen. When adding a
neighbor-dependent behavior, add the fact to the neighbor's payload — never widen the API back to
passing items.

`neighborDescriptor` has **no default implementation**, deliberately: a conservative default would compile
everywhere and silently make such items relayout on every transaction. `AnyEquatable.noNeighborInfluence` is the one-line answer
for items whose neighbors read nothing about them.

`nil` on a side means *no neighbor*; a non-nil descriptor whose facet does not resolve means *a
neighbor that publishes nothing relevant*. Several items depend on that distinction
(`ContactsPeerItem` renders `first` and `firstWithHeader` differently).

**Header families.** "Does this neighbor take part in my header run" is a `ListViewItemHeaderFamily` tag on
`HeaderNeighborFacet`, never a concrete-type cast: consumers that group with any header-bearing neighbor ignore it,
narrow ones compare it (`ContactListActionItem` checks `.contactList` rather than importing `ContactsPeerItem`).

**Neighbor reads hide behind more than `previousItem as?`**: `is <Type>`, helper parameters named `(top:bottom:)`,
bare `== nil` presence checks. `previousItem` is also an overloaded name: `let previousItem = self.item` inside a node's
`asyncLayout` is the node's *previous item state*, nothing to do with neighbors.

Types: `Display/AnyEquatable.swift`, `Display/ListViewItemNeighbors.swift`,
`ItemListUI/ItemListNeighborFacet.swift`,
`ChatMessageItemCommon/{ChatHistoryItemNeighbors,ChatMessageMergeFingerprint}.swift`.

## View frame ownership

A view does not control its own `frame`. The parent (or a layout system) sets the frame; the view positions its own subviews against `self.bounds` in response.

This matters in two places specifically:

- **Reusable components (`UIView`/`ASDisplayNode` subclasses).** Public methods like `update(...)` / `apply(...)` rebuild internal state, mutate child frames, and read `self.bounds` to lay them out — but they do not write `self.frame`. The caller has already chosen the frame; mutating it from inside the component overrides that choice and fights the parent's next layout pass.
- **`asyncLayout`-style content nodes.** The measure pass runs off-main and returns a size; the apply step runs on main and the chat layout system positions the node. A child view that writes `self.frame` from `update()` corrupts the size the parent just measured.

Rare exceptions: top-level view-controller views integrating with the system's first-responder/inset model. If you find yourself wanting `self.frame = …` from inside a child view, refactor so the parent positions it instead.

## Postbox → TelegramEngine refactor (in progress)

A gradual migration removes direct `import Postbox` from consumer submodules in favour of `TelegramEngine`, in waves.
Wave outcomes, the tally of Postbox-free modules, wave-selection guidance, the typealias/wrapper reference and the
`TelegramEngine.Resources` facade inventory (authoritative: `TelegramEngine/Resources/TelegramEngineResources.swift`) are
in [`docs/superpowers/postbox-refactor-log.md`](docs/superpowers/postbox-refactor-log.md); the current wave count and the
open migration candidates are in the `project_postbox_refactor_next_wave.md` memory file.

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

### Engine typealias cheat sheet, forwarders, `MediaResource` migration

The typealias cheat sheet (`PeerId` → `EnginePeer.Id`, …), TelegramCore's free-function forwarders and the
`MediaResource` → `EngineMediaResource` consumer migration are in the refactor log, before its wrapper inventory.
`grep -rh 'public typealias Engine' submodules/TelegramCore/Sources` lists every alias. Prefer non-`EngineRaw*` ones.
A `TelegramEngine.<Area>` facade that leaks raw `MediaResource` changes its signature in place to
`EngineMediaResource`; do **not** add opt-in `EngineMediaResource` overloads beside it.

### Engine wrapper cheat sheet

Postbox types that have an engine wrapper. Prefer these to `EngineRaw*` aliases; the full table, with unwrap methods, is in the log's "Engine wrapper inventory". Not all of them are value types: `EngineMessage`, `EngineRenderedPeer` and `EngineMediaResource` are classes, so two wrappers of one raw object are not `===` (rule 9).

```
Peer → EnginePeer (_asPeer())             RenderedPeer → EngineRenderedPeer
Message → EngineMessage (_asMessage())     Media → EngineMedia (_asMedia())
MediaResource → EngineMediaResource (_asResource()); .Id, .ResourceData, .FetchStatus for its id/data/status
PeerPresence → EnginePeer.Presence         CombinedPeerReadState → EnginePeerReadCounters
ChatListTotalUnreadState → EngineTotalReadCounters   PeerGroupId → EngineChatList.Group
```

`EngineMedia.init(_:)` has a `preconditionFailure()` for any `Media` class outside its cases. Each TelegramCore media class has a case. An app-side pseudo-media class must conform to `EngineCustomMedia`, and wraps as `.custom`; today that is the three link-preview placeholders in `WallpaperPreviewMedia`. `build-system/Make/PostboxImportCheck.py` enforces this on every `Make.py build`/`test`: it fails on any in-scope class, struct, enum, protocol or extension whose inheritance list names `Media` (or `EngineRawMedia`) anywhere without also naming `EngineCustomMedia` (a grep for `: Media` misses `: EngineRawMedia` conformers).

## tgcalls Testbench

This repo includes a tgcalls testbench (CLI tool, Go/Pion SFU, Docker build) layered on top of the iOS source. All testbench code, build instructions, and architecture docs live inside the tgcalls submodule:

- `submodules/TgVoipWebrtc/tgcalls/CLAUDE.md` — top-level testbench overview, build/run commands
- `submodules/TgVoipWebrtc/tgcalls/tools/cli/CLAUDE.md` — CLI test tool architecture
- `submodules/TgVoipWebrtc/tgcalls/tools/go_sfu/CLAUDE.md` — Go SFU internals
- `submodules/TgVoipWebrtc/CLAUDE.md` — tgcalls library internals + macOS/Linux build patches
- `submodules/TgVoipWebrtc/tgcalls/tgcalls/v2wasm/CLAUDE.md` — pump-boundary call core: `InstanceV2ReferenceImpl`'s control logic behind a C ABI, runnable natively or as a WASM module in the vendored WAMR interpreter. **Ships as call versions `18.0.0` (native core) and `19.0.0` (the same source as wasm embedded in the binary)** so a server-side A/B can measure the substrate alone; the client advertises both and the server reconciles. `customParameters.wasm_core_path` and the filesystem module loader are compiled out of the app (`TGCALLS_ALLOW_EXTERNAL_WASM_CORE`, CLI target only) — never add that define to the `TgVoipWebrtc` objc_library.

Build the test binary from this directory with:

`./build-input/bazel-9.2.0-darwin-arm64 build //submodules/TgVoipWebrtc/tgcalls/tools/cli:tgcalls_cli`
