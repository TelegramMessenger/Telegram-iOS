# Postbox → TelegramEngine refactor — log

This file is the historical record of the Postbox → TelegramEngine refactor. It is **not loaded by default** into AI sessions (only `CLAUDE.md` is). Read this file when you need wave-specific context, a full worked example of a pattern, or the running tally of module Postbox-freeness.

The short, actively-maintained rules and references live in `CLAUDE.md` under the "Postbox → TelegramEngine refactor" section. This file holds the narrative backstory, verbose example scripts, and per-wave outcomes that would otherwise bloat every AI session's context.

---

## Wave-selection guidance — full versions

The following subsections are trimmed to terse bullets in `CLAUDE.md`. Full versions (rule + backstory + scripts + per-wave examples) live here.

### Shape-selection backstory

The "leaf module, drop Postbox in isolation" approach only works for modules whose **public API doesn't leak Postbox domain types**. Most candidate leaf modules DO leak such types (`postbox: Postbox` / `account: Account` in public inits, `Media`/`Message` in public function parameters). Those modules need paired caller-migration waves, not isolated refactors.

Before selecting a wave's module list, grep each candidate for:
- `:\s*Postbox\b`, `:\s*Account\b`, `:\s*MediaBox\b` in public signatures → abandon candidate
- `Media`/`Message` as public parameter types → likely needs paired wave with callers

### Inventory at execution time, not just planning time

**Inventory at execution time, not just planning time.** Wave 2's `SaveToCameraRoll` task was planned from a narrow grep that only matched `MediaResource`/`TelegramMediaResource` and missed three `postbox: Postbox` public-function leaks plus multiple `postbox.mediaBox.*` bodies. Planning-time inventory should grep the full set `\b(postbox|mediaBox|transaction|PostboxView|combinedView|MediaResource|PostboxDecoder|PostboxEncoder|MemoryBuffer)\b|^import Postbox` over the module's Sources, not just the tokens specific to that wave's goal. If the planning inventory under-counts, the executor should re-inventory at Task-1 time and abandon early before editing code.

### Two feasible wave shapes

**Two feasible wave shapes.** Wave 1 tried "per-module Postbox drop". Wave 2 tried "per-engine-facade-API migrate MediaResource to EngineMediaResource (modify in place, update all call sites in one commit)". The second shape worked well: narrow, clean commits, no abandonment cascade. Prefer it when the refactor target is an API surface that multiple consumer modules depend on.

### Enum-payload migrations need a full case-site grep

**Enum-payload migrations need a full case-site grep, not just a facade call-site grep.** If a wave changes the payload type of a public enum (wave 4 changed `UploadStickerStatus.complete`'s payload from `CloudDocumentMediaResource` to `EngineMediaResource`), inventory ALL construction and destructure sites of the enum across TelegramCore, not just call sites of the facade that returns it. Wave 4's plan undercounted by 6 consumer sites inside `ImportStickers.swift` itself (3 shortcut `.complete(...)` constructions in guard branches, 3 destructure+field-access sites using `CloudDocumentMediaResource`-specific members). For enum-payload waves, grep `case \.|let \.|\.<caseName>\(` over the enum's defining module before execution and add those sites to the plan.

### Unused-import sweeps are a valid wave shape

**Unused-import sweeps are a valid wave shape.** After a round of facade migrations, consumer files accumulate `import Postbox` lines whose last semantic use was removed. Periodically sweep these:

1. `grep -rl "^import Postbox$" submodules --include="*.swift" | grep -vE "/(TelegramCore|Postbox|TelegramApi)/"` generates the candidate list.
2. `sed -i '' '/^import Postbox$/d' <file>` (BSD `sed`) speculatively drops the import from every candidate.
3. Run the full build **with `--continueOnError`** — without `--keep_going`, bazel stops at the first failing target and surfaces only a few errors per iteration. `Make.py` forwards `--continueOnError` to `--keep_going`; always use it.
4. Each iteration: extract failing files via `grep -E "^submodules/.*\.swift:[0-9]+:[0-9]+: error:" <build-out> | awk -F: '{print $1}' | sort -u`, restore via `git checkout -- <file>`, rebuild.
5. The dependency graph has many layers (wave 6 needed ~18 rebuilds to reach a clean build). Per-iteration failures shrink roughly: 18 → 4 → 5 → 3 → 12 → 4 → 13 → 9 → 11 → ... Accelerate by doing **pattern-based preemptive restores** after the first few iterations: scan still-dropped files for tokens that are definitively Postbox-only (`MediaBox`, `PostboxCoding`, `PostboxDecoder`, `PostboxEncoder`, `TempBoxFile`, `ValueBoxKey`, `Postbox\b`, `PeerId`, `MessageId`, `MediaId`, `MessageIndex`, `MessageAndThreadId`, `PeerNameIndex`, etc. — note that CLAUDE.md's "engine typealias cheat sheet" arrows are migration targets, **not** typealiases in TelegramCore — `PeerId` etc. are still raw Postbox types and files using them need `import Postbox`) and restore those files in bulk.
6. Only restore files from the candidate set. If errors surface in `TelegramCore`, `Postbox`, or `TelegramApi`, halt — the sweep has cascaded beyond its scope.
7. Commit the surviving drops as one atomic commit.

Tally impact from a sweep: dozens of consumer modules can become Postbox-free in a single commit. First run (wave 6): 782 candidates, 18 iterations, 183 survivors, **189 modules** newly Postbox-free. Re-run after every 2-3 facade-migration waves.

### Public-Postbox-type inventory (wave-11-pattern planning)

**Public-Postbox-type inventory (wave-11-pattern planning).** For wave-11-shape candidates (modules whose public init takes `postbox: Postbox, network: Network` purely for avatar/setPeer forwarding), grepping only for `Postbox`/`Network` tokens **undercounts** — public-surface types defined in Postbox can leak without ever naming "Postbox" literally. Wave 16 hit this: the plan missed `EngineMessageHistoryThread.Info?` and `PeerStoryStats?`, both Postbox-defined types whose names don't include "Postbox". Mitigation: build a Postbox-defined-public-types allowlist once, then grep the candidate module against it.

```bash
# Build allowlist once (or re-run if Postbox sources change):
grep -rhE "^public\s+(class|struct|enum|protocol|typealias)\s+\w+" submodules/Postbox/Sources/ \
  | awk '{print $3}' | sed 's/[(:<].*//' | sort -u > /tmp/postbox-public-types.txt

# Then, for each candidate module, grep its sources for any of those names:
grep -rhoE "\b($(cat /tmp/postbox-public-types.txt | tr '\n' '|' | sed 's/|$//'))\b" \
  submodules/<CandidateModule>/Sources/ | sort -u
```

Any hit in a public-surface position (field type, init param type, enum payload type, generic arg) that isn't already a documented typealias is a blocker. "Engine"-prefixed types can still be Postbox-defined — don't trust naming conventions, grep for the defining module. If the module hits only `Postbox` itself (i.e., literal `Postbox`/`Network` pair), it's a clean wave-11 candidate. Otherwise, decide per leak: (a) move the type to TelegramCore if it's a namespace-only class (wave 16a pattern — prototype: `EngineMessageHistoryThread`), (b) accept that the module can't become Postbox-free and ship a partial `engine:`/`stateManager:` collapse that keeps `import Postbox` (wave 16b pattern — `PeerStoryStats` is too baked into Postbox views to move cleanly), (c) abandon the candidate.

### Wave-shape G: facade addition + consumer sweep in one commit

**Wave-shape G: facade addition + consumer sweep in one commit.** Validated at scale across waves 19-26. Six consecutive sessions migrated ~95 consumer sites and added ~15 mediaBox facades, all with clean first-pass builds (exception: wave 26 needed a second pass to add `import RangeSet`). Shape recipe:

1. **Target:** a `MediaBox` (or similar Postbox type) method where Postbox's signature uses clean leaf types (`MediaResourceId`, `Data`, `String`, `Bool`) and the return type is either non-Postbox or has an existing `Engine*` wrapper.
2. **Pre-flight inventory:** grep `context\.account\.postbox\.mediaBox\.<methodName>` over `submodules/` (excluding TelegramCore/Postbox/TelegramApi). Classify each hit:
   - **Shape A**: `context.account.postbox.mediaBox.X(...)` → migratable.
   - **Shape B**: `context.account.postbox.mediaBox.X(id: ...)` (different overload) → migratable with identical pattern.
   - **Shape C**: `account.postbox.mediaBox.X(...)` where `account: Account` is a local (not `AccountContext`) → skip this wave (needs per-module rework).
   - **Shape D**: `self.postbox.mediaBox.X(...)` where `postbox: Postbox` is a stored field → skip this wave.
   - Plus: check for `accountManager.mediaBox.X(...)` which is Account-manager-scoped, a different migration path entirely. Never migrate via `TelegramEngine.Resources.*`.
3. **Facade design rules:**
   - Signatures take `EngineMediaResource.Id` (`MediaResourceId` aliased at call site via `EngineMediaResource.Id(x.id)`) or `EngineMediaResource` (wraps `resource` when the Postbox overload takes a resource with members accessed via `.id`).
   - Parameters with `Bool` defaults (`synchronous: Bool = false`) preserve defaults on the facade.
   - Return types: prefer `Void`, `String`, `String?`, `Signal<T, NoError>` where `T` is a non-Postbox type or an `Engine*` wrapper. Where Postbox return types are wrapped (e.g., `Signal<MediaResourceData, NoError>` → `Signal<EngineMediaResource.ResourceData, NoError>`), confirm the `Engine*` wrapper exists and decide whether consumer-side field-access rewrites are acceptable for the wave.
4. **WIP interference check:** before starting, `git status --short | grep -v "^??"` to list modified files. If any Shape-A site is in a WIP file, either skip those sites (document the skip in the outcome) or wait for the WIP to commit. Wave 23 hit this in `ChatMessageInteractiveMediaNode.swift`.
5. **Name collision check:** if a facade return type names a Swift stdlib type that has availability restrictions (e.g., `RangeSet` — iOS 18+), verify the third-party module import is present in `TelegramEngineResources.swift`. Wave 26 needed `import RangeSet`.
6. **Replace_all usage:** for files with duplicate identical call text, `replace_all=true` on the exact call expression (without leading whitespace) batches the migration. When leading whitespace varies across identical-call sites within a file, the tool still matches if the unchanged prefix (`context.account.postbox.mediaBox.X(...)`) is unique enough — but verify via post-edit grep.
7. **Cheapness:** ~5-50 sites per wave, single atomic commit, expected first-pass-clean build. If post-migration grep for `context\.account\.postbox\.mediaBox\.<methodName>` returns empty (exclude Shape-C/D) and build is green, commit.

---

## Engine wrapper inventory (2026-10-12)

The sanctioned mid-refactor representations of Postbox types, preferred over `EngineRaw*` aliases. Regenerate with `grep -rn 'func _as[A-Z]' submodules/TelegramCore/Sources`.

| Raw Postbox / TelegramCore type | Wrapper | Unwrap |
|---|---|---|
| `Peer` | `EnginePeer` | `_asPeer()` |
| `RenderedPeer` | `EngineRenderedPeer` | (`.peer`, `.peers`, `.chatMainPeer` are `EnginePeer`) |
| `Message` | `EngineMessage` | `_asMessage()` |
| `Media` | `EngineMedia` | `_asMedia()` |
| `MediaResource` | `EngineMediaResource` | `_asResource()` |
| `MediaResourceId` | `EngineMediaResource.Id` | `MediaResourceId(id.stringRepresentation)` |
| `MediaResourceData` | `EngineMediaResource.ResourceData` | — |
| `MediaResourceStatus` | `EngineMediaResource.FetchStatus` | `_asStatus()` |
| `PeerPresence` / `TelegramUserPresence` | `EnginePeer.Presence` | `_asPresence()` |
| `CombinedPeerReadState` | `EnginePeerReadCounters` | `_asReadCounters()` |
| `ChatListTotalUnreadState` | `EngineTotalReadCounters` | `_asCounters()` |
| `PeerGroupId` | `EngineChatList.Group` | `_asGroup()` |
| `ChatListRelativePosition` | `EngineChatList.RelativePosition` | `_asPosition()` |
| `PeerIndexNameRepresentation` | `EnginePeer.IndexName` | `_asIndexName()` |
| `TelegramPeerNotificationSettings` (+ `PeerMuteState`, `PeerMessageSound`, `PeerNotificationDisplayPreviews`) | `EnginePeer.NotificationSettings` (+ `.MuteState`, `.MessageSound`, `.DisplayPreviews`) | `_asNotificationSettings()`, … |
| `GlobalNotificationSettingsSet` (+ `MessageNotificationSettings`, `PeerReactionNotificationSettings`) | `EngineGlobalNotificationSettings` (+ `.CategorySettings`, `.ReactionSettings`) | `_asGlobalNotificationSettings()`, … |
| `ChannelParticipant` / `GroupParticipant` | `EngineChannelParticipant` / `EngineLegacyGroupParticipant` | `_asParticipant()` |
| `LimitsConfiguration` | `EngineConfiguration.Limits` | `_asLimits()` |

`EngineMessage` is a class whose `==` compares field by field; `EnginePeer.==` compares through the concrete peer's `==`. Code that compared raw values (`===`, `stableId`, `isEqual(to:)`) keeps that comparison when retyped. `EngineMedia.init(_:)` ends in `preconditionFailure()` for a `Media` class outside its cases. All 19 TelegramCore media classes have a case. App-side pseudo-media classes conform to `EngineCustomMedia` and wrap as `.custom`. That protocol was added after the 2026-10-12 review, because an earlier version of this sentence missed three app-side `: EngineRawMedia` conformers; see "Post-review fix" after wave 463.

## Wave 1 outcome (2026-04-16)

4 modules done: `ChatInterfaceState`, `ChatSendMessageActionUI`, `ContactListUI`, `DrawingUI`.
6 modules abandoned with recorded reasons in the wave-1 plan: `ActionSheetPeerItem`, `ChatListSearchRecentPeersNode`, `DirectMediaImageCache`, `FetchManagerImpl`, `GalleryData`, `ICloudResources`.

## Wave 2 outcome (2026-04-17)

5 `TelegramEngine` facades migrated to `EngineMediaResource` (signatures changed in place; `_internal_*` Postbox layer unchanged):
- `TelegramEngine.Peers.uploadedPeerPhoto`, `uploadedPeerVideo`, `updatePeerPhoto`
- `TelegramEngine.AccountData.updateAccountPhoto`, `updateFallbackPhoto`
- `TelegramEngine.Contacts.updateContactPhoto`
- `TelegramEngine.Auth.uploadedPeerVideo`

1 consumer submodule fully de-Postboxed: `MapResourceToAvatarSizes` (signature changed from `(postbox: Postbox, resource: MediaResource, …)` to `(engine: TelegramEngine, resource: EngineMediaResource, …)`; 27 call sites migrated).

1 consumer signal type swapped: `AuthorizationUI/AuthorizationSequenceController.swift` (`Signal<TelegramMediaResource?>` → `Signal<EngineMediaResource?>`).

1 task abandoned with recorded reason in the wave-2 plan: `SaveToCameraRoll` (full-module Postbox coupling, needs its own wave).

## Wave 3 outcome (2026-04-18)

3 thin forwarders added on `TelegramEngine.Resources` over `MediaBox`:
- `fetch(reference:userLocation:userContentType:)` → `Signal<FetchResourceSourceType, FetchResourceError>` (Postbox return types remain a documented accepted leak)
- `status(resource: EngineMediaResource)` → `Signal<EngineMediaResource.FetchStatus, NoError>`
- `data(resource: EngineMediaResource, pathExtension:, waitUntilFetchStatus:)` → `Signal<EngineMediaResource.ResourceData, NoError>` (takes a `Bool` rather than exposing `ResourceDataRequestOption`, per YAGNI)

1 consumer submodule fully de-Postboxed: `SaveToCameraRoll`. Public signatures changed from `(context:, postbox: Postbox, userLocation:, …)` to `(context:, userLocation:, …)`; `FetchMediaDataState.data` payload changed from `MediaResourceData` to `EngineMediaResource.ResourceData`; internals rewired through `context.engine.resources.*`. 23 call sites across 14 files migrated atomically with the module.

Pre-flight verified that `ShareController.swift:2406`'s `self.currentContext.stateManager.postbox` is equivalent to `context.account.postbox` in the `ShareControllerAppAccountContext` path (because `AccountStateManager` is constructed with the account's own `postbox`), so the `postbox:` argument could be dropped without behavior change.

No tasks abandoned. Shape validated: "per-engine-facade-API migration + full consumer module rewrite" (the wave-2 shape, scaled up to a full module drop).

Plan: `docs/superpowers/plans/2026-04-18-postbox-to-telegramengine-wave-3.md`

## Wave 4 outcome (2026-04-18)

1 `TelegramEngine` facade migrated in place to `EnginePeer` + `EngineMediaResource` (signature changed; `_internal_uploadSticker` keeps its raw `Peer`/`MediaResource` parameter list):

- `TelegramEngine.Stickers.uploadSticker(peer: Peer → EnginePeer, resource: MediaResource → EngineMediaResource, thumbnail: MediaResource? → EngineMediaResource?, …)`

1 public enum payload migrated: `UploadStickerStatus.complete(CloudDocumentMediaResource, String)` → `.complete(EngineMediaResource, String)`. `_internal_uploadSticker` wraps `EngineMediaResource(uploadedResource)` at its one `.complete(...)` result-construction site — a narrow, spec-allowed one-line deviation from "internal Postbox-facing stays raw", taken to keep `UploadStickerStatus` as a single public enum.

**Plan-time inventory undercount** — worth recording as a lesson. The spec and plan enumerated 2 external call sites and 1 internal construction site. Execution uncovered 6 additional consumer sites inside `ImportStickers.swift` itself that also needed adapting: 3 shortcut `.complete(...)` construction sites (lines 204, 371, 492, each emitting `.complete(CloudDocumentMediaResource, String)` directly from `as? CloudDocumentMediaResource` guards) and 3 destructure sites (lines 216, 384, 505) that accessed `CloudDocumentMediaResource`-specific fields. Each construction site now wraps via `EngineMediaResource(resource)`; each destructure site unwraps with `let rawResource = resource._asResource() as? CloudDocumentMediaResource`. MediaEditorScreen's two `stickerFile(resource:)` calls also needed `as! TelegramMediaResource` casts because `_asResource()` returns the Postbox `MediaResource` protocol while `stickerFile` takes the TelegramCore `TelegramMediaResource` sub-protocol. **Future planning-time inventory for enum-payload migrations should grep not only call-sites of the facade but every `case .complete` / `case let .complete` of the migrated enum across the whole TelegramCore source tree.**

2 external call sites migrated atomically with the facade:
- `submodules/ImportStickerPackUI/Sources/ImportStickerPackController.swift:91` (plus a `peer: Peer → EnginePeer(peer)` wrap, since the local `peer` comes from `postbox.loadedPeerWithId(...)` which returns raw `Peer`)
- `submodules/TelegramUI/Components/MediaEditorScreen/Sources/MediaEditorScreen.swift:8099` (plus 6 cascading sites inside the enclosing block for the new `UploadStickerStatus.complete` payload)

No module becomes Postbox-free in this wave (both caller files import Postbox for unrelated reasons).

Plan: `docs/superpowers/plans/2026-04-18-postbox-to-telegramengine-wave-4.md`

## Wave 5 outcome (2026-04-18)

Completes the last explicitly-named future-wave candidate from the wave-2 final review.

`uploadSecureIdFile(context: SecureIdAccessContext, postbox: Postbox, network: Network, resource: MediaResource)` migrated in place to `(context:, engine: TelegramEngine, resource: EngineMediaResource)`. Function body accesses raw Postbox types via `engine.account.postbox` / `engine.account.network` (internal Postbox-facing layer stays raw per the standing rule).

1 consumer submodule fully de-Postboxed: `SecureIdVerificationDocumentsContext` (PassportUI/Sources). Signature changed from `(postbox: Postbox, network: Network, context: SecureIdAccessContext, update: ...)` to `(engine: TelegramEngine, context: SecureIdAccessContext, update: ...)`; stored props collapsed into a single `engine: TelegramEngine` field. One instantiation site updated in the same commit.

After this wave, the "Known future-wave candidates" list contains only the 4 permanently-blocked classes conforming to `TelegramMediaResource`.

Plan: `docs/superpowers/plans/2026-04-18-postbox-to-telegramengine-wave-5.md`

## Wave 6 outcome (2026-04-19)

First build-verified unused-import sweep. Ran the speculative-drop + build-verify methodology (see "Unused-import sweeps" under Wave-selection guidance above): dropped `import Postbox` from all 782 consumer files where a plain `^import Postbox$` line appeared, iterated 18 full builds with `--continueOnError`, restoring imports on files that failed to compile.

**183 drops survived** (single atomic commit `7b2b74e79b`, 0 insertions / 183 deletions). **189 modules** transitioned to Postbox-free status — full list is inferable by running the methodology's module-scan against HEAD. Representative additions spanning alphabetically: `AccountUtils`, `ActivityIndicator`, `AdUI`, `AlertUI`, `AnimatedStickerNode`, `AppLock`, `AttachmentTextInputPanelNode`, `BotPaymentsUI`, `CalendarMessageScreen`, `CallListUI`, `Camera`, `ChatImportUI`, etc. The running tally below preserves the per-module enumeration only for the ~10 individually-documented waves 1–5 modules. Wave 6's 189 additions are not re-enumerated here because the size would overwhelm the doc; see `git show 7b2b74e79b --stat` for the per-file breakdown and `grep -rL "^(@_exported )?import Postbox" submodules/*/Sources --include="*.swift"` for the current per-module status.

Deviation from plan: the plan capped at 3 iterations; execution needed 18 because the dependency graph is deep and each bazel build surfaces only the currently-compilable layer. Pattern-based preemptive restores (using the symbol list in the "Unused-import sweeps" guidance) were used from iteration 9 onward to accelerate convergence from iteration-by-iteration single-file restores to bulk restores. No unexpected path cascades; no abandoned state.

Plan: `docs/superpowers/plans/2026-04-19-postbox-to-telegramengine-wave-6.md`

## Wave 7 outcome (2026-04-20)

Closed out the seven remaining raw-Postbox leaks in `TelegramEngine.*` public facades surfaced by a post-wave-6 scouting pass. Single atomic commit, one full build, zero abandonment.

Seven `TelegramEngine` facades migrated in place (all `_internal_*` implementations kept raw per the standing rule):

**Messages (3):**
- `downloadMessage(messageId:)` — return `Signal<Message?, NoError>` → `Signal<EngineMessage?, NoError>`. Return-side wrap via `|> map { $0.flatMap(EngineMessage.init) }`.
- `topPeerActiveLiveLocationMessages(peerId:)` — return `Signal<(Peer?, [Message]), NoError>` → `Signal<(EnginePeer?, [EngineMessage]), NoError>`. Return-side tuple wrap.
- `getSynchronizeAutosaveItemOperations()` — **deleted**. Dead facade: sole caller (`StoreDownloadedMedia.swift`) already bypassed it by calling `_internal_getSynchronizeAutosaveItemOperations` directly inside its own transaction block.

**Peers (1):**
- `updatedRemotePeer(peer:)` — return `Signal<Peer, UpdatedRemotePeerError>` → `Signal<EnginePeer, UpdatedRemotePeerError>`. `PeerReference` param kept as-is (no `EnginePeer.Reference` alias today). The sole call site in `ChannelAdminsController.swift` uses `ignoreValues`, so no caller change was needed.

**Resources (4):**
- `renderStorageUsageStatsMessages(…existingMessages:)` — `[EngineMessage.Id: Message]` → `[EngineMessage.Id: EngineMessage]` on both sides. Facade unwraps input via `.mapValues { $0._asMessage() }`, wraps output via `.mapValues(EngineMessage.init)`.
- `clearStorage(peerId:categories:includeMessages:excludeMessages:)` — `[Message]` → `[EngineMessage]`. Facade unwraps via `.map { $0._asMessage() }`.
- `clearStorage(peerIds:includeMessages:excludeMessages:)` — same shape.
- `clearStorage(messages:)` — same shape. No external callers; migrated for overload-set consistency.

**Consumer call-site updates** (5 files):
- `ChatListUI/Sources/ChatListSearchListPaneNode.swift`: dropped now-redundant `.flatMap(EngineMessage.init)` wrap at the `downloadMessage` call site.
- `LocationUI/Sources/LocationViewControllerNode.swift`: dropped now-redundant `.map(EngineMessage.init)` at the `topPeerActiveLiveLocationMessages` call site.
- `LiveLocationManager/Sources/LiveLocationSummaryManager.swift`: dropped redundant `EnginePeer(author)` / `EngineMessage(message)` construction (`author`, `message` are now already `EnginePeer` / `EngineMessage`).
- `TelegramUI/Components/StorageUsageScreen/Sources/StorageUsageScreen.swift`: bridged at 4 facade-call points (1 `renderStorageUsageStatsMessages`, 2 `clearStorage` overloads with message arrays; the `includeMessages: [], excludeMessages: []` site at line 3038 needed no change as empty arrays infer to `[EngineMessage]` just as well).

**Minimal-scope bridging.** `StorageUsageScreen.swift` still has 43 raw `Message`/`MessageId` references inside its `AggregatedData` helper class and surrounding logic — not touched in this wave. A future "StorageUsageScreen full de-Postbox" wave would drop those (migrate `AggregatedData.messages: [MessageId: Message]` → `[EngineMessage.Id: EngineMessage]`, `clearIncludeMessages: [Message]` → `[EngineMessage]`, etc.) and potentially drop `import Postbox`. Out of scope here.

**No modules became Postbox-free in this wave** — all five touched consumer files still import Postbox for reasons unrelated to the migrated facades.

Plan / record: `docs/superpowers/plans/2026-04-20-postbox-to-telegramengine-wave-7.md`.

After this wave, the "Known future-wave candidates" list contains only the 4 permanently-blocked classes conforming to `TelegramMediaResource`. The full public `TelegramEngine.*` facade surface is now engine-typed (modulo those four types).

## Wave 8 outcome (2026-04-20)

`StorageUsageScreen` consumer-module migration of raw `Message` domain types to `EngineMessage`. Scope explicitly narrower than a full de-Postbox: two files touched, module remains `import Postbox` due to two out-of-scope site clusters.

**Types migrated:**
- `StorageFileListPanelComponent.Item.message: Message` → `EngineMessage` (item type co-located with the panel component).
- `StorageUsageScreen.Component.AggregatedData.messages: [MessageId: Message]` → `[EngineMessage.Id: EngineMessage]`; `.clearIncludeMessages` / `.clearExcludeMessages: [Message]` → `[EngineMessage]`. Init param updated to match.
- `StorageUsageScreen.Component.SelectionState.togglePeer(availableMessages:)` param: `[EngineMessage.Id: Message]` → `[EngineMessage.Id: EngineMessage]`.
- `StorageUsageScreen.Component.RenderResult.messages: [MessageId: Message]` → `[EngineMessage.Id: EngineMessage]`.
- `openMessage(message: Message)` → `openMessage(message: EngineMessage)` (external `OpenChatMessageParams.message` / `chatMediaListPreviewControllerData(message:)` calls unwrap via `message._asMessage()` at the two call sites — those APIs still take raw `Message`).

**Wave-7 facade-boundary bridging dropped:** the `renderStorageUsageStatsMessages` call-site's `(…).mapValues(EngineMessage.init)` / `.mapValues { $0._asMessage() }` bridges and the two `clearStorage` call sites' `.map(EngineMessage.init)` wraps all vanish — `AggregatedData.messages` / `.clearIncludeMessages` / `.clearExcludeMessages` are now engine-typed and pass through the facade unchanged. Inside the `AggregatedData.updateSelected...` selected-messages accumulation loop, four `item.message._asMessage()` calls (for imageItems, which hold EngineMessage) drop back to plain `item.message` since the target array is now `[EngineMessage]`. And `StorageMediaGridPanelComponent.Item(message: EngineMessage(message), …)` drops the `EngineMessage(…)` wrap since `message` is already `EngineMessage`.

**Out of scope — future-wave candidates (module still imports Postbox):**
- `StorageUsageScreen.swift:1047-1062` and `3131-3185`: preferences-view observation of `AccountSpecificCacheStorageSettings` via `postbox.combinedView` + `PreferencesView`, and a `postbox.transaction { transaction in transaction.getPeer / transaction.getPeerCachedData as? CachedGroupData / CachedChannelData }` block classifying peer-storage-timeout exceptions. Substantial: requires `EngineData`-subscription rewrite for the preferences observation, plus engine-API equivalents for peer-category classification + cached-data subscriber counts.
- `StorageFileListPanelComponent.swift:105`: `Icon.media(Media, TelegramMediaImageRepresentation)` enum case, constructed only as `.media(TelegramMediaFile, …)` or `.media(TelegramMediaImage, …)` (both TelegramCore types). Trivial future wave: split into `.mediaFile(TelegramMediaFile, …)` / `.mediaImage(TelegramMediaImage, …)`, drop `import Postbox`.

Single atomic commit. Build verified green (59s incremental build, 27 actions). Net −11 lines in `StorageUsageScreen.swift` (simplification).

Plan / record: `docs/superpowers/plans/2026-04-20-postbox-to-telegramengine-wave-8.md`.

## Wave 9 outcome (2026-04-20)

Closes the first of the two "future-wave candidates" left open by wave 8: rewrites both `AccountSpecificCacheStorageSettings` preferences-view observation sites in `StorageUsageScreen.swift` using engine APIs, and drops `import Postbox` from that file.

**Site 1 — `cacheSettingsExceptionCount` signal** (former lines 1047–1087):
- `postbox.combinedView(keys: [.preferences(keys: Set([PreferencesKeys.accountSpecificCacheStorageSettings]))])` + `PreferencesView` extraction →
  `context.engine.data.subscribe(TelegramEngine.EngineData.Item.Configuration.ApplicationSpecificPreference(key: PreferencesKeys.accountSpecificCacheStorageSettings))` + `preferencesEntry?.get(AccountSpecificCacheStorageSettings.self) ?? .defaultSettings`.
- Downstream `EngineDataMap` + `EnginePeer` per-category counting logic unchanged (already engine-only).

**Site 2 — `peerExceptions` signal in `openKeepMediaCategory`** (former lines 3131–3196):
- Same preferences observation replacement as Site 1.
- `postbox.transaction { transaction.getPeer / transaction.getPeerCachedData as? CachedGroupData / CachedChannelData; FoundPeer(peer:subscribers:) }` → `context.engine.data.get(EngineDataMap(...TelegramEngine.EngineData.Item.Peer.Peer.init(id:)))` + pattern match on `EnginePeer.user / .secretChat / .legacyGroup / .channel`.
- Signal element type `[(peer: FoundPeer, value: Int32)]` → `[(peer: EnginePeer, value: Int32)]`. `FoundPeer` wrapper and its `subscribers` field dropped entirely — they were computed by the transaction block but never read by downstream consumers (the only consumer sites read `.isEmpty`, `.count`, and `.prefix(3).map { EnginePeer($0.peer.peer) }`).
- One downstream consumer updated: `peerExceptions.prefix(3).map { EnginePeer($0.peer.peer) }` → `.prefix(3).map { $0.peer }` at the `MultiplePeerAvatarsContextItem` construction (redundant wrap removed since `$0.peer` is already `EnginePeer`).

**Typealias fixup.** With `import Postbox` removed, `var mergedMedia: [MessageId: Int64]` at former line 2397 needed renaming to `[EngineMessage.Id: Int64]`. `MessageId` is the raw Postbox type name — CLAUDE.md's engine-typealias cheat sheet lists these as migration targets, not pre-existing aliases in TelegramCore. Caught by first-pass build failure (`cannot find type 'MessageId' in scope`).

**Reusable pattern.** `TelegramEngine.EngineData.Item.Configuration.ApplicationSpecificPreference(key: ValueBoxKey)` (at `TelegramCore/Sources/TelegramEngine/Data/ConfigurationData.swift:356`) is the general-purpose engine replacement for any `postbox.combinedView(keys: [.preferences(keys: Set([key]))]) + PreferencesView` idiom — takes any `ValueBoxKey`, returns `PreferencesEntry?`, decodes via `.get(T.self)`. Crucially, callers need not `import Postbox` even though `ValueBoxKey` is a Postbox type: passing `PreferencesKeys.<name>` through makes `ValueBoxKey` an inferred-only type that never gets named in the consumer module. Use this pattern when de-Postboxing any future module that observes preferences.

`StorageUsageScreen.swift` is now Postbox-free. The wave 8 outcome's other candidate (`StorageFileListPanelComponent.swift`'s `Icon.media(Media, ...)` enum case) remains — trivial future wave to split into `.mediaFile(TelegramMediaFile, ...)` / `.mediaImage(TelegramMediaImage, ...)` cases, at which point the `StorageUsageScreen` consumer module as a whole becomes Postbox-free.

Net: 1 file changed, +30 / -54. Build verified green (27 actions, cached).

Plan / record: `docs/superpowers/plans/2026-04-20-postbox-to-telegramengine-wave-9.md`.

## Wave 10 outcome (2026-04-20)

Closes the second (and last) future-wave candidate from wave 8: eliminates `StorageFileListPanelComponent.swift`'s `Icon.media(Media, TelegramMediaImageRepresentation)` enum case. **`StorageUsageScreen` (the module as a whole) is now fully Postbox-free** — the other in-module file (`StorageUsageScreen.swift`) landed in wave 9.

**Split the enum case.** `Icon.media(Media, TelegramMediaImageRepresentation)` → two concrete cases `case mediaFile(TelegramMediaFile, TelegramMediaImageRepresentation)` + `case mediaImage(TelegramMediaImage, TelegramMediaImageRepresentation)`. Lossless split: the two construction sites already knew the concrete subtype (`imageIconValue = .media(file, representation)` from a `as? TelegramMediaFile` branch, `.media(image, representation)` from a `as? TelegramMediaImage` branch), and the consumer binding site immediately downcast via `as?` to pick which `setSignal(...)` flavor to call. New split removes the downcast; exhaustiveness-checked switch is both safer and terser.

**Equatable rewritten.** Old: manual outer-`switch` + inner `if case` dispatch, comparing media by `media.id` only. New: switch-over-tuple `(lhs, rhs)` with id-based equality per concrete type (`lFile.fileId == rFile.fileId`, `lImage.imageId == rImage.imageId`). Same id-based equality semantics as before.

**Binding-site rewrite.** Old: `if case let .media(media, representation) = component.icon { ... if let file = media as? TelegramMediaFile { ... } else if let image = media as? TelegramMediaImage { ... } }`. New: a compound case-binding pattern `case let .mediaFile(_, representation), let .mediaImage(_, representation):` lifts the shared `representation` variable, then an inner switch dispatches to the right `setSignal` branch. Works because both cases carry the same `TelegramMediaImageRepresentation` payload type; Swift allows compound case patterns when the bindings have identical types.

**Placeholder `PeerId(...)` construction fixup.** Second-pass build failure after dropping `import Postbox` surfaced a placeholder `PeerId(namespace: PeerId.Namespace._internalFromInt32Value(0), id: PeerId.Id._internalFromInt64Value(0))` in the `measureItem` layout-measurement instance at former line 1062. Naming `PeerId`, `PeerId.Namespace`, and `PeerId.Id` all require `import Postbox` (these are raw Postbox types, not TelegramCore typealiases — consistent with wave 9's `MessageId` → `EngineMessage.Id` fixup). Replaced with `component.context.account.peerId` (a real `EnginePeer.Id` already in scope). Semantically equivalent since the measurement instance's `messageId` is only used for `.peerId` extraction inside image-fetch `userLocation` and for Equatable comparison (the measurement instance isn't compared to anything).

**Lesson.** Placeholder `PeerId(...)` / `MessageId(peerId:...)` constructions in layout-measurement code are a recurring trap for de-Postbox work. Common pattern in this codebase: construct a dummy component instance purely to call `.update(...)` and read back the returned size. The dummy values are not used meaningfully but naming the types pins `import Postbox`. When de-Postboxing, grep for `PeerId(namespace:`/`MessageId(peerId:` with all-zero args and replace with any convenient real value in scope (`context.account.peerId` is almost always available).

Net: 1 file changed, +22 / -29 lines (−7 simplification — new switch-over-tuple Equatable is both terser and more idiomatic).

Plan / record: `docs/superpowers/plans/2026-04-20-postbox-to-telegramengine-wave-10.md`.

## Wave 11 outcome (2026-04-20)

Revisits `ActionSheetPeerItem` — one of the six wave-1 abandonments. The wave-1 blocker was that the public init took `postbox: Postbox` + `network: Network` explicitly, forcing the module to `import Postbox`, and the sole external caller (ShareController, out-of-wave at the time) couldn't be edited. This wave resolves the blocker without any rule-2 violation by routing the pair through `AccountStateManager`.

**Init-surface collapse.** `ActionSheetPeerItem.init(accountPeerId:postbox:network:contentSettings:peer:…)` → `.init(accountPeerId:stateManager:contentSettings:peer:…)`. `AccountStateManager` is a TelegramCore public class whose public API surface includes `postbox: Postbox` and `network: Network` fields; passing the manager as a single handle lets the module hold on to the two values without ever naming `Postbox` in its own source. The setItem call site becomes `self.avatarNode.setPeer(…, postbox: item.stateManager.postbox, network: item.stateManager.network, …)` — Swift's type inference resolves `Postbox` through transitive module visibility (TelegramCore → AvatarNode), no `import Postbox` needed in the consumer.

**Convenience init unchanged in shape.** The `(context: AccountContext, …)` convenience delegates to `(accountPeerId:stateManager:contentSettings:…)`; the two callable forms stay aligned.

**Caller (`ShareController.swift:1146`).** Dropped `postbox: info.account.stateManager.postbox, network: info.account.stateManager.network` → single `stateManager: info.account.stateManager`. `ShareControllerAccountContext` (the per-switchable-account protocol) already exposes `stateManager: AccountStateManager`, so this is a collapse, not a signature divergence. ShareController continues to import Postbox for its own unrelated reasons; no change to its dependency profile.

**Reusable pattern.** For any wave-1-style module that was abandoned because a public init takes `postbox: Postbox, network: Network` with avatar-rendering downstream: collapse to `stateManager: AccountStateManager` (TelegramCore type) and unpack inside the setItem/setPeer body. The pattern applies broadly — most wave-1 abandonments used this param-pair for avatar setup. Candidates to try next: `ChatListSearchRecentPeersNode`, `HorizontalPeerItem`, `SelectablePeerNode`, `ItemListPeerItem`, `ItemListAvatarAndNameInfoItem`, `ItemListStickerPackItem` (verify each by grep first — some may use `postbox` for non-avatar reasons).

Net: 3 files changed, +8 / -15 lines. Build green (5854 actions, ~6min).

Plan / record: (no plan doc this wave — single-module, low-complexity).

## Wave 12 outcome (2026-04-20)

Applies the wave-11 `stateManager: AccountStateManager` collapse pattern to `HorizontalPeerItem` — another wave-1-era candidate whose public init leaked `postbox: Postbox, network: Network`. Additionally ripples the collapse one layer up into `ChatListSearchRecentPeersNode`'s public init so the `HorizontalPeerItem` call site has `stateManager:` in scope.

**`HorizontalPeerItem` fully Postbox-free.** `init(postbox: Postbox, network: Network, …)` + matching stored fields → `init(stateManager: AccountStateManager, …)` + `let stateManager`. SelectablePeerNode.setup call site routes via `item.stateManager.postbox` / `.network`. Module drops `import Postbox` and `//submodules/Postbox:Postbox` dep.

**`ChatListSearchRecentPeersNode` public surface migrated, module still imports Postbox.** Public `init(accountPeerId:postbox:network:…)` → `init(accountPeerId:stateManager:…)`. Two private helpers (`item(…)` on `ChatListSearchRecentPeersEntry` and `preparedRecentPeersTransition(…)`) get the same collapse for forwarding. Internal uses of raw postbox (`_internal_recentPeers`, `postbox.peerView`, `postbox.combinedView`, `_internal_managedUpdatedRecentPeers`) rewritten to `stateManager.postbox` / `stateManager.network` — the module stays on `import Postbox` because of `PostboxViewKey` / `UnreadMessageCountsItem` / `UnreadMessageCountsView` usage inside the peerViews-to-unread-counts pipeline. That pipeline could be rewritten against `EngineDataMap` + `TelegramEngine.EngineData.Item.Peer.Notifications.*` in a future wave, but the public surface simplification is valuable standalone.

**Two external caller sites migrated:**
- `ShareController/Sources/ShareControllerRecentPeersGridItem.swift:66-67` — `postbox: context.stateManager.postbox, network: context.stateManager.network` → `stateManager: context.stateManager` (ShareControllerAccountContext protocol already exposes `stateManager`).
- `ChatListUI/Sources/ChatListRecentPeersListItem.swift:125-126` — `postbox: item.context.account.postbox, network: item.context.account.network` → `stateManager: item.context.account.stateManager`.
- `SettingsUI/Sources/DeleteAccountPeersItem.swift:51-52` (call site for `HorizontalPeerItem`) — `postbox: context.account.postbox, network: context.account.network` → `stateManager: context.account.stateManager`.

**Lesson reinforcement.** The wave-11 collapse pattern is very cheap to ripple through intermediate owners. Whenever a consumer module takes `(postbox:Postbox, network:Network)` purely to forward them to another call downstream, collapse to `stateManager: AccountStateManager` — no propagation fan-out required for the raw pair because the stateManager is a single handle. Even when the intermediate owner itself uses raw `postbox.peerView` internally (like this wave's `ChatListSearchRecentPeersNode`), the public surface still gets the collapse at zero cost.

Net: 6 files changed, +26 / -36 lines. Build verified green (incremental, 136 actions).

Plan / record: (no plan doc this wave — pattern-application, low-complexity).

## Wave 13 outcome (2026-04-20)

Targeted `AttachmentTextInputPanelNode` at the user's request. On inspection, the module was already Postbox-free at the source level (swept in wave 6) — its two `.swift` files compile fine without `import Postbox`. Two leftover items were fixed:

1. **Dead `//submodules/Postbox:Postbox` BUILD dep** — wave 6 swept `^import Postbox$` lines from source but never touched BUILD files. `AttachmentTextInputPanelNode/BUILD` (and, it turns out, 97 other modules' BUILDs — see wave 14) still listed the dep despite no source file needing it. Removed.
2. **Two raw `peerId?.namespace == Namespaces.Peer.SecretChat` checks** (lines 436, 2102) migrated to use the existing `PeerId.isSecretChat` extension at `submodules/TelegramCore/Sources/Utils/PeerUtils.swift:615`. (First-pass attempt introduced a duplicate `isSecretChat` extension and failed with "invalid redeclaration" — note for future waves: always grep TelegramCore for an existing helper before adding.)

**No new TelegramEngine methods/types introduced.** The refactor was smaller than anticipated; the module's migration debt had already been paid down by wave 6's source-level sweep. The BUILD-dep leftover and the namespace-equality sites were the only remaining items. Both are quality-of-life cleanups rather than structural migration.

**Observation that drove wave 14.** Wave 6's methodology-note in the "Unused-import sweeps" guidance only measured Postbox-freeness by `^import Postbox$` lines in sources. After touching `AttachmentTextInputPanelNode/BUILD` in this wave, I noticed many other wave-6-swept modules still carry dead BUILD deps, ~= the wave-6 survivor count. That's the whole of wave 14.

Net: 2 files changed, +2 / -3 lines.

Plan / record: (no plan doc this wave — discovery pass).

## Wave 14 outcome (2026-04-20)

Build-dep sweep analogous to wave 6's source-import sweep: drop `//submodules/Postbox:Postbox` (and `//submodules/Postbox`) from every BUILD whose source files no longer `import Postbox`.

**Methodology.**
1. For each `submodules/*/BUILD` referencing `submodules/Postbox`, check whether any `.swift` file in the module's `Sources/` tree has `^import Postbox$`.
2. If none do, speculatively drop the Postbox dep line from the BUILD via `sed -i '' -e '/^[[:space:]]*"\/\/submodules\/Postbox\(:Postbox\)\{0,1\}",[[:space:]]*$/d'`.
3. Full `Make.py build --continueOnError`.
4. Restore any BUILD that now fails to compile (none did).
5. Commit surviving drops.

**Result.** 98 candidate BUILDs identified. **Zero iterations needed** — first-pass build came up green (80 incremental actions, no restores). Net: 98 BUILD files, −98 lines (each lost exactly its `//submodules/Postbox` dep line).

**Why zero iterations.** Bazel Swift rules require source-level `import` for symbol resolution. If a module compiled after wave 6's `import Postbox` sweep, then none of its source files are physically referencing Postbox symbols. The BUILD-level dep was always redundant — it was carried for historical reasons (code likely once imported Postbox but was migrated off) but had no effect on either compilation or the actual dependency graph (Postbox is still transitively pulled in by TelegramCore, which every module depends on). Dropping it is a metadata cleanup with no semantic effect.

**Lesson / reusable pattern.**
- After every source-level `import Postbox` sweep (wave-6 shape), run a matching BUILD-dep sweep immediately. Same candidate set, near-zero execution risk, same commit.
- Script for identifying candidates:
  ```bash
  find submodules -name "BUILD" -type f | while read build; do
    dir=$(dirname "$build")
    if grep -q "submodules/Postbox" "$build" 2>/dev/null && [ -d "$dir/Sources" ]; then
      if ! grep -rq "^import Postbox$" "$dir/Sources" 2>/dev/null; then
        echo "$dir"
      fi
    fi
  done
  ```
- After waves 13+14, 194 modules still list `//submodules/Postbox` in BUILD — all of them have source files still importing Postbox.

Net (wave 14 alone): 98 files changed, 0 insertions / 98 deletions.

Plan / record: (no plan doc this wave — mechanical sweep).

## Wave 15 outcome (2026-04-20)

Applies the wave-11/12 `stateManager: AccountStateManager` collapse pattern to `SelectablePeerNode` — another wave-1-era candidate listed in the post-wave-14 shortlist. Module becomes fully Postbox-free (source + BUILD).

**`SelectablePeerNode` fully Postbox-free.** Two public setup methods migrated:
- `setup(accountPeerId: EnginePeer.Id, postbox: Postbox, network: Network, …)` → `setup(accountPeerId:, stateManager: AccountStateManager, …)`.
- `setupStoryRepost(accountPeerId: EnginePeer.Id, postbox: Postbox, network: Network, …)` → `setupStoryRepost(accountPeerId:, stateManager: AccountStateManager, …)`.

Internal forwards rewired: `AvatarNode.setPeer(…, postbox: stateManager.postbox, network: stateManager.network, …)` and `EmojiStatusComponent(postbox: stateManager.postbox, …)`. Neither site names `Postbox` in the consumer — Swift infers through transitive module visibility.

**Namespaces.Peer.SecretChat fixup (×3).** Replaced `peer.peerId.namespace == Namespaces.Peer.SecretChat` checks with `peer.peerId.isSecretChat` at three sites, matching the wave-13 pattern (`PeerId.isSecretChat` at `TelegramCore/Sources/Utils/PeerUtils.swift:611`). The third site (`updateSelection` in the not-selected branch) additionally needed an `?? false` fallback — previous expression was `self.peer?.peerId.namespace == Namespaces.Peer.SecretChat` (optional-equals-non-optional produces `Bool`), new expression is `(self.peer?.peerId.isSecretChat ?? false)`.

**Share-Extension boundary — `stateManager:` over `engine:`.** `SelectablePeerNode` is used by `ShareControllerPeerGridItem`, whose context is `ShareControllerAccountContext`. That protocol exposes `stateManager: AccountStateManager` and `engineData: TelegramEngine.EngineData`, but **no `engine: TelegramEngine`** — and the Share Extension's `ShareControllerAccountContextExtension` concrete impl has no `Account`, so constructing a full `TelegramEngine` (`init(account: Account)`) is physically unreachable there. This is the documented "rare but genuine" fallback to `stateManager:` from the user-preference memory (`feedback_postbox_refactor_handle.md`) — prefer `engine:` except when crossing the Share-Extension boundary.

**Three external call sites migrated:**
- `HorizontalPeerItem/Sources/HorizontalPeerItem.swift:227` (wave 12's `stateManager:` field now forwards directly): `postbox: item.stateManager.postbox, network: item.stateManager.network` → `stateManager: item.stateManager`.
- `ShareController/Sources/ShareControllerPeerGridItem.swift:237` (setup): `postbox: context.stateManager.postbox, network: context.stateManager.network` → `stateManager: context.stateManager`.
- `ShareController/Sources/ShareControllerPeerGridItem.swift:273` (setupStoryRepost): same.

**Convenience init unchanged.** `setup(context: AccountContext, …)` now delegates with `stateManager: context.account.stateManager`; signature unchanged — `JoinLinkPreviewPeerContentNode.swift:147` (the one caller using the convenience init) needed no edit.

Net: 4 files changed, +12 / -17 lines. Build verified green (193 actions, 131s — Telegram.ipa target built successfully).

Plan / record: (no plan doc this wave — pattern-application, low-complexity).

## Wave 16 outcome (2026-04-20)

Two-commit wave targeting `ItemListPeerItem`. Planning-time inventory (`project_postbox_wave16_plan.md`) only grepped for `Postbox`/`Network` tokens and missed two Postbox-defined public-surface types: `EngineMessageHistoryThread.Info?` (on `threadInfo`) and `PeerStoryStats?` (on `storyStats`). The first-pass "drop `import Postbox`" attempt failed at build time. Rather than abandon, the wave split into 16a (move `EngineMessageHistoryThread` to TelegramCore — clean, independently valuable) and 16b (partial `engine:` collapse on `ItemListPeerItem`, keeping `import Postbox` because `PeerStoryStats` remains Postbox-defined).

**Wave 16a — move `EngineMessageHistoryThread` to TelegramCore.** Before: Postbox declared an empty `public final class EngineMessageHistoryThread` namespace with a nested `public final class Item`; TelegramCore's `ForumChannels.swift` added the `.Info` nested type via `public extension EngineMessageHistoryThread { final class Info … }`. The outer name's Postbox residency forced every consumer of `.Info` to `import Postbox` too. After: promote Postbox's internal `MutableMessageHistoryThreadIndexView.Item` to a top-level public type `MessageHistoryThreadIndexItem`; delete the empty `EngineMessageHistoryThread` class from Postbox; move the class shell into `ForumChannels.swift`, collapsing the existing extension into a proper class definition (`public final class EngineMessageHistoryThread { class Info … }`).

`MessageHistoryThreadIndexView.items` type changes from `[EngineMessageHistoryThread.Item]` to `[MessageHistoryThreadIndexItem]`; its init simplifies (no more wrap/unwrap conversion — the old init re-built items element-by-element just to swap the outer wrapper name). The second public extension on `EngineMessageHistoryThread` (`.NotificationException`, at `ForumChannels.swift:1318`) works unchanged — same-module extension after the class moves.

Zero consumer-site changes: the two Postbox-consumer iteration sites (`ChatListUI/Sources/Node/ChatListNodeLocation.swift:229`, `ShareController/Sources/ShareControllerNode.swift:2086`) iterate with `for item in view.items` (no type annotation) and access only fields that exist identically on both types (`id`, `info`, `index`, `pinnedIndex`, `tagSummaryInfo`, `topMessage`, `embeddedInterfaceState`).

Commit `3bb22d503c`. Net: 2 files, +67 / −111 (Postbox file nets −174 lines, TelegramCore file +4).

**Wave 16b — `ItemListPeerItem.Context` `engine:` collapse.** Wave-11 pattern applied to `ItemListPeerItem.Context.Custom`. Before: `Context.Custom.init(accountPeerId:, postbox: Postbox, network: Network, animationCache:, animationRenderer:, isPremiumDisabled:, resolveInlineStickers:)` + matching stored fields; `Context` had computed `postbox: Postbox` and `network: Network` that switched over the `.account` / `.custom` cases. After: `Context.Custom.init(accountPeerId:, engine: TelegramEngine, animationCache:, animationRenderer:, isPremiumDisabled:, resolveInlineStickers:)`; `Context` has one computed `engine: TelegramEngine` that returns `context.engine` for the `.account` case and `custom.engine` for the `.custom` case. Six internal forwards rewire from `item.context.postbox` / `item.context.network` to `item.context.engine.account.postbox` / `item.context.engine.account.network` (three `EmojiStatusComponent(postbox:…)` sites and three `AvatarNode.setPeer(…, postbox:…, network:…, …)` sites).

Handle choice: `engine:` (not `stateManager:`). The sole external `.custom(Custom(...))` construction site codebase-wide is `PeerInfoSettingsItems.swift:121` — main-app-only, doesn't cross the Share-Extension boundary. `peerAccountContext` in that loop is typed `AccountContext` (from the `accountsAndPeers: [(AccountContext, EnginePeer, Int32)]` field), so `.engine: TelegramEngine` is directly available. Per the standing guidance from `feedback_postbox_refactor_handle.md`, prefer `engine:` except when physically forced to `stateManager:` by a Share-Extension boundary.

All 37 other `ItemListPeerItem(…)` construction sites use the `.account(context: AccountContext)` convenience overload (at L485) and need no change. `PeerInfoScreenMemberItem.swift:223` forwards its own `context: ItemListPeerItem.Context` field straight through (pass-through) — no change.

Module does **not** become Postbox-free: `PeerStoryStats?` remains on the `storyStats` public-surface field. `PeerStoryStats` is defined in `Postbox/Sources/ChatListView.swift:281` and is deeply baked into Postbox view APIs (`PeerView.storyStats`, `PeerStoryStatsView.storyStats`, `ChatListEntry.storyStats`, `MessageHistoryView.peerStoryStats`, `Postbox.getPeerStoryStats(peerId:)`). Moving it would require a cross-module wrapper rewrite across Postbox, TelegramCore, and every view consumer — out of scope for wave 16.

Commit `a5432e44a8`. Net: 2 files, +17 / −30.

**Lessons.**
- **Public-surface inventory must go beyond the collapse-target tokens.** Waves 11/12/15's `stateManager`/`engine` collapses were clean because their target modules had no other Postbox-defined public types. Wave 16's planning inventory only grepped for `Postbox`/`Network` and missed `EngineMessageHistoryThread` + `PeerStoryStats` — both symbols whose names happen to not include `Postbox`. For future wave-11-pattern candidates, planning-time grep should include the full alphabet of Postbox-defined public types: `^public\s+(class|struct|enum|protocol|typealias)\s+\w+` over `submodules/Postbox/Sources/` to build an exhaustive type-name allowlist, then grep for any of those names in the candidate module's public surface.
- **"Engine"-prefixed types can still be Postbox-defined.** `EngineMessageHistoryThread` has an "Engine" prefix but was declared in Postbox all along; the `.Info` nested type living in TelegramCore was a code-organization half-measure that still forced `import Postbox` on consumers. Don't trust naming conventions; grep for the defining module.
- **Splitting a failing wave into a cleanup + a partial collapse is often the right move.** Wave 16 could have been abandoned entirely when the build failed — instead, the `EngineMessageHistoryThread` move (which had been a latent cleanup opportunity for the entire history of the `.Info` extension) was promoted to a standalone commit (16a), and the partial `engine:` collapse shipped as a second commit (16b). Both are independently valuable; the wave's "module becomes Postbox-free" goal didn't land but other goals did.
- **The "promote internal Postbox `Item` to top-level, drop Postbox wrapper class, move wrapper class to TelegramCore" pattern generalizes.** Any Postbox-defined class whose only role is to namespace a TelegramCore extension is a candidate for this move. Future audit target: `grep -l "public extension <ClassName>" submodules/TelegramCore/Sources/` where `<ClassName>` is a Postbox-defined outer type with no semantic content of its own.

Plan / record: `project_postbox_wave16_plan.md` (updated with outcome).

## Wave 17 outcome (2026-04-20)

Applies the wave-11/12/15 `stateManager: AccountStateManager` collapse pattern to `ItemListAvatarAndNameInfoItem` — another wave-1-era candidate. Module becomes fully Postbox-free (source + BUILD). Clean one-shot execution (no abandonment, no replan).

**`ItemListAvatarAndNameInfoItem.ItemContext` enum case collapsed.** Before: `case other(accountPeerId: EnginePeer.Id, postbox: Postbox, network: Network)` + matching destructure at L761 + `AvatarNode.setPeer(…, postbox: postbox, network: network, …)` internal forward. After: `case other(accountPeerId: EnginePeer.Id, stateManager: AccountStateManager)` + `case let .other(accountPeerId, stateManager):` destructure + `AvatarNode.setPeer(…, postbox: stateManager.postbox, network: stateManager.network, …)` forward. The `.accountContext(AccountContext)` sister case is unchanged.

**Share-Extension-boundary handle choice: `stateManager:`.** The sole external `.other(...)` construction site codebase-wide is `DeviceContactInfoController.swift:413`, inside a ternary that fires only when `arguments.context` is not a `ShareControllerAppAccountContext` — i.e., when running inside the Share Extension. `ShareControllerAccountContext` (protocol at `AccountContext/Sources/ShareController.swift:16`) exposes `stateManager: AccountStateManager` but not `engine: TelegramEngine`, and constructing a full `TelegramEngine` is physically unreachable in the Share Extension's `ShareControllerAccountContextExtension` impl (no `Account`). Per `feedback_postbox_refactor_handle.md` and the wave-15 precedent, use `stateManager:` at Share-Extension boundaries.

**Pre-flight inventory was correct.** Running the public-Postbox-type inventory grep returned only `Postbox` itself (the one enum-case payload leak) — no `EngineMessageHistoryThread`-style surprises. Wave 17 validates the post-wave-16 lesson: when planning-time inventory uses the full Postbox public-types allowlist (not just `Postbox`/`Network` tokens), wave-11-shape candidates execute cleanly.

**Single external caller migrated:**
- `PeerInfoUI/Sources/DeviceContactInfoController.swift:413` — `postbox: arguments.context.stateManager.postbox, network: arguments.context.stateManager.network` → `stateManager: arguments.context.stateManager`. The enclosing `PeerInfoUI` module still imports Postbox for its own unrelated reasons; that stays.

The 5 other `ItemListAvatarAndNameInfoItem(itemContext:…)` construction sites codebase-wide all use `.accountContext(arguments.context)` and need no change (`ChannelBannedMemberController.swift:321`, `DeviceContactInfoController.swift:415`, `ChannelAdminController.swift:370`, `CreateChannelController.swift:197`, `CreateGroupController.swift:324`).

**Pattern-consistency note (reinforced).** `accountPeerId: EnginePeer.Id` is kept as a separate enum-case payload even though `AccountStateManager` also exposes `accountPeerId`. This matches waves 11/12/15 (`ActionSheetPeerItem`, `ChatListSearchRecentPeersNode`, `SelectablePeerNode` all kept `accountPeerId` explicit alongside `stateManager`). Future wave-11-pattern executions should default to this shape unless a specific reason exists to collapse further.

Net: 3 files changed, +4 / -5 lines (ItemListAvatarAndNameItem.swift: +2 / -3, DeviceContactInfoController.swift: +1 / -1, BUILD: −1). Build verified green for target modules (`ItemListAvatarAndNameInfoItem`, `PeerInfoUI` both compiled and linked successfully); the one unrelated failing target in the full build (`ChatMessageInteractiveMediaNode.swift`) is user-uncommitted work-in-progress that predates this wave.

Plan / record: (plan doc `project_postbox_wave17_plan.md` deleted post-commit per the plan's own post-commit housekeeping instructions).

## Wave 18 outcome (2026-04-20)

Mixed-shape wave targeting `ItemListStickerPackItem`. Originally shortlisted (post-wave-17) as "likely wave-11 shape", but plan-writing-time inspection invalidated that hypothesis — the module's public API doesn't take `postbox:`/`network:`. Actual shape combined three existing wave patterns plus a narrow typealias addition. Module becomes fully Postbox-free (source + BUILD).

**Three narrow typealiases added to TelegramCore.** `submodules/TelegramCore/Sources/TelegramEngine/Utils/EnginePostboxCoding.swift` grew by 3 lines:

- `EngineItemCollectionId = ItemCollectionId` — needed at public closure-param positions.
- `EngineFetchResourceSourceType = FetchResourceSourceType` — needed at `var updatedFetchSignal` type annotation.
- `EngineFetchResourceError = FetchResourceError` — same.

Per CLAUDE.md rule 1 these narrow-utility typealiases are explicitly allowed (same shape as the existing `EngineMemoryBuffer`/`EnginePostboxDecoder`/… batch). Cheat sheet updated.

**Wave-4 enum-payload migration on `StickerPackThumbnailItem`.** Public enum case `animated(MediaResource, PixelDimensions, Bool, Bool)` → `animated(EngineMediaResource, PixelDimensions, Bool, Bool)`. Equatable `==` simplified: `lhsResource.isEqual(to: rhsResource)` → `lhsResource == rhsResource` (uses `EngineMediaResource.==` which has identical semantics). Two construction sites wrapped via `EngineMediaResource(thumbnail.resource)` / `EngineMediaResource(itemFile.resource)`. Two destructure-and-forward sites unwrap via `resource._asResource()` when handing off to `chatMessageStickerPackThumbnail(resource: MediaResource)` and `AnimatedStickerResourceSource(account:, resource: MediaResource, …)`. One `resource.id` site (for `shortLivedResourceCachePathPrefix`) needs the raw `MediaResourceId`, handled by a local `let rawResource = resource._asResource()` that serves both the `.id` read and the `AnimatedStickerResourceSource` init in the same block.

**Wave-3 facade swap.** `fetchedMediaResource(mediaBox: item.context.account.postbox.mediaBox, userLocation: .other, userContentType: .sticker, reference: resourceReference)` → `item.context.engine.resources.fetch(reference: resourceReference, userLocation: .other, userContentType: .sticker)`. Engine facade (`TelegramEngine.Resources.fetch`) already exists from wave 3; no new TelegramEngine API needed.

**External-caller check confirmed zero source edits needed.** `StickerPackThumbnailItem` has no external consumers (UndoUI declares its own nested-private same-named enum). The 6 external `ItemListStickerPackItem(setPackIdWithRevealedOptions:)` caller sites all pass closures with inferred param types; `EngineItemCollectionId` being a typealias to `ItemCollectionId` makes the types interchangeable. The 3 module-field declarations outside the target module that name `(ItemCollectionId?, ItemCollectionId?) -> Void` explicitly (`SettingsUI/Stickers/ArchivedStickerPacksController.swift:27`, `SettingsUI/Stickers/InstalledStickerPacksController.swift:27`, and the init at L32/L42 of those same files) compile unchanged — those modules still import Postbox for their own reasons, and `EngineItemCollectionId == ItemCollectionId` so no rename is required.

**BUILD dep dropped.** `//submodules/Postbox:Postbox` removed from `submodules/ItemListStickerPackItem/BUILD`.

**Pre-existing `ChatMessageInteractiveMediaNode.swift` WIP still present at build time — no longer failing.** The uncommitted change introduces an `allowSticker` validation around secret-chat sticker playback (~30 lines added in the `currentReplaceAnimatedStickerNode` block). Per wave-17's note it had failed to compile; on this wave's full build (`bazel build Telegram/Telegram`, 565 actions, 258s, 0 errors) it compiled and linked without issue. Either the user fixed it between waves 17 and 18, or the bazel dependency graph simply needed a full rebuild. Either way, wave 18's build was clean end-to-end — `Telegram.ipa` target built successfully, zero errors across the entire project.

**Pattern-consistency note.** Wave 18 is the third wave (after 3 and 9) where the cheapest path requires adding narrow TelegramCore-side typealiases rather than keeping `import Postbox` in the consumer. The threshold is: if the consumer needs to NAME a Postbox-defined type (not just use it via inference), and no engine-prefixed alias exists, adding a narrow typealias is preferred over `import Postbox`. The alternative of refactoring the code to avoid naming the type (e.g., reshaping `var foo: Signal<T, E>?` to infer from first assignment) is usually unwieldy when the var is conditionally-assigned; typealiases win on readability.

Net: 3 files changed.
- `submodules/TelegramCore/Sources/TelegramEngine/Utils/EnginePostboxCoding.swift`: +3 / -0.
- `submodules/ItemListStickerPackItem/Sources/ItemListStickerPackItem.swift`: ~13 lines touched across 9 sites; net +4 / -4.
- `submodules/ItemListStickerPackItem/BUILD`: 0 / -1.
- `CLAUDE.md`: +3 cheat-sheet lines + this outcome paragraph.

Plan / record: `memory/project_postbox_wave18_plan.md` (deleted post-commit per the plan's own housekeeping instructions).

## Wave 19 outcome (2026-04-20)

Single-facade expansion. Additive-only — adds `TelegramEngine.Resources.shortLivedResourceCachePathPrefix(id: EngineMediaResource.Id) -> String` at `submodules/TelegramCore/Sources/TelegramEngine/Resources/TelegramEngineResources.swift:456`. Body: `self.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(MediaResourceId(id.stringRepresentation))`.

No consumer migrations this wave. Known consumers (≥25 call sites across ~15 modules: AvatarVideoNode, DrawingUI, SettingsUI/ThemePickerGridItem, PremiumUI/StickersCarouselComponent, ReactionSelectionNode, ReactionContextNode, ChatSendMessageActionUI, ItemListStickerPackItem, ChatThemeScreen, ThemeCarouselItem, PeerInfoBirthdayOverlay, SettingsThemeWallpaperNode, MediaEditorComposerEntity, ChatQrCodeScreen, ChatMessageAnimatedStickerItemNode, ChatMessageItemView, GiftCompositionComponent) migrate in a follow-up wave using the pattern `X.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(Y.resource.id)` → `X.context.engine.resources.shortLivedResourceCachePathPrefix(id: EngineMediaResource.Id(Y.resource.id))`.

**Why not bundle consumer migration in the same wave?** Wave-3's original shape did bundle (3 facades + 1 full consumer module in one commit), but the consumer pool for this particular facade is large (~25 sites) and each call site only partially de-Postboxes its module — the caller modules need full inventory before deciding whether to drop `import Postbox`. Keeping wave 19 narrow (facade-only) lets follow-up waves approach consumer-module migration on a per-module basis without the facade-addition blocking anything.

Net: 1 file changed, +4 / -0.

Plan / record: (no plan doc this wave — single-method addition, target pre-identified in `project_postbox_refactor_next_wave.md`).

## Wave 20 outcome (2026-04-21)

Consumer sweep for the wave-19 `shortLivedResourceCachePathPrefix` facade. 22 call sites across 16 modules migrated atomically. Pattern (repeated identically at every site): `X.context.account.postbox.mediaBox.shortLivedResourceCachePathPrefix(Y.resource.id)` → `X.context.engine.resources.shortLivedResourceCachePathPrefix(id: EngineMediaResource.Id(Y.resource.id))`.

**Modules migrated (alphabetical):**
- `AvatarVideoNode/Sources/AvatarVideoNode.swift` (1 site)
- `ChatSendMessageActionUI/Sources/ChatSendMessageContextScreen.swift` (1 site)
- `DrawingUI/Sources/DrawingStickerEntityView.swift` (1 site)
- `ItemListStickerPackItem/Sources/ItemListStickerPackItem.swift` (1 site; simplified from wave-18's `let rawResource = resource._asResource(); …shortLivedResourceCachePathPrefix(rawResource.id)` + `AnimatedStickerResourceSource(…, resource: rawResource, …)` to `…shortLivedResourceCachePathPrefix(id: resource.id)` + `AnimatedStickerResourceSource(…, resource: resource._asResource(), …)` — drops the intermediate `let rawResource`)
- `PremiumUI/Sources/StickersCarouselComponent.swift` (2 sites)
- `ReactionSelectionNode/Sources/ReactionContextNode.swift` (2 sites)
- `ReactionSelectionNode/Sources/ReactionSelectionNode.swift` (6 sites — 4 unique expression templates, handled via targeted Edits against the unique argument expression at each call)
- `SettingsUI/Sources/ThemePickerGridItem.swift` (1 site)
- `TelegramUI/Components/Chat/ChatMessageAnimatedStickerItemNode/Sources/ChatMessageAnimatedStickerItemNode.swift` (2 sites)
- `TelegramUI/Components/Chat/ChatMessageItemView/Sources/ChatMessageItemView.swift` (1 site)
- `TelegramUI/Components/Chat/ChatQrCodeScreen/Sources/ChatQrCodeScreen.swift` (1 site)
- `TelegramUI/Components/ChatThemeScreen/Sources/ChatThemeScreen.swift` (1 site)
- `TelegramUI/Components/Gifts/GiftAnimationComponent/Sources/GiftCompositionComponent.swift` (3 sites)
- `TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/PeerInfoBirthdayOverlay.swift` (2 sites)
- `TelegramUI/Components/Settings/SettingsThemeWallpaperNode/Sources/SettingsThemeWallpaperNode.swift` (1 site)
- `TelegramUI/Components/Settings/ThemeCarouselItem/Sources/ThemeCarouselItem.swift` (1 site)

**One site intentionally skipped:** `TelegramUI/Components/MediaEditor/Sources/MediaEditorComposerEntity.swift:245`. That site uses a local `postbox: Postbox` init-parameter, not `context.account.postbox`, so the migration would require changing the init's parameter from `postbox:` to something engine-based and fanning out to its callers. Out of scope — handled by a future module-scoped wave.

**No modules became Postbox-free this wave.** Each of the 16 migrated modules still has other Postbox usage (raw `Postbox` types in signatures, `fetchedMediaResource(mediaBox:)` calls, `postbox.transaction`, etc.). Consumer-side `shortLivedResourceCachePathPrefix` closure is just one of several reasons these modules import Postbox. Future wave-shape: module-scoped de-Postbox per-module inventory.

**Pattern validation.** This is the most mechanical consumer sweep to date — all 22 sites followed identical shape, allowing `replace_all=true` for sites with duplicate identical call expressions (ReactionSelectionNode hit this at 3 sites for `largeListAnimation`, 2 for `stillAnimation`, 1 for `listAnimation`). First-pass build was clean (35 actions, 0 errors) — no iteration loop. Confirms the wave-19 facade shape is sound.

**Build verification.** `bazel build Telegram/Telegram --keep_going` — 2042 action cache hits + 35 new actions, 0 errors, `Telegram.ipa` up-to-date.

Net: 16 files changed, all edits mechanical (before → after): +22 insertions / -22 deletions at migrated sites, plus 1 deletion in ItemListStickerPackItem (wave-18 `let rawResource` line dropped). Approximate total: +22 / -23.

Plan / record: (no plan doc this wave — mechanical sweep).

## Wave 21 outcome (2026-04-21)

Combined wave-19+wave-20 shape: facade addition + consumer sweep in a single atomic commit. Adds `TelegramEngine.Resources.completedResourcePath(id: EngineMediaResource.Id, pathExtension: String? = nil) -> String?` facade; sweeps 29 consumer sites across 14 files.

**Facade added at `TelegramCore/Sources/TelegramEngine/Resources/TelegramEngineResources.swift:460`.** Body: `self.account.postbox.mediaBox.completedResourcePath(id: MediaResourceId(id.stringRepresentation), pathExtension: pathExtension)`. Wraps the Postbox `MediaBox.completedResourcePath(id: MediaResourceId, pathExtension: String?)` overload; consumers that previously called the resource-taking overload (`MediaBox.completedResourcePath(_ resource: MediaResource, …)`) migrate through the id path (`.resource.id` is already `MediaResourceId`).

**28 Shape-A consumer sites + 1 Shape-B (already-id-overload) migrated:**
- `SettingsUI/Sources/Themes/EditThemeController.swift` (1 site)
- `BrowserUI/Sources/BrowserPdfContent.swift` (1 site)
- `BrowserUI/Sources/BrowserDocumentContent.swift` (1 site)
- `GalleryUI/Sources/SecretMediaPreviewController.swift` (1 site)
- `TelegramUI/Components/MediaEditor/Sources/MediaEditor.swift` (1 site, `pathExtension: "mp4"`)
- `TelegramUI/Components/Settings/WallpaperGridScreen/Sources/WallpaperUtils.swift` (7 sites across 3 functions; 4 unique expression templates, handled via `replace_all=true` where identical)
- `TelegramUI/Components/Settings/ThemeAccentColorScreen/Sources/ThemeAccentColorController.swift` (1 site)
- `TelegramUI/Components/Settings/WallpaperGalleryScreen/Sources/WallpaperGalleryController.swift` (5 sites; 4 used `resource` expr identically via `replace_all=true`, 1 used `file.file.resource`)
- `TelegramUI/Components/MediaEditorScreen/Sources/MediaEditorScreen.swift` (1 site, `pathExtension: nil`)
- `TelegramUI/Components/Chat/ChatMessageWebpageBubbleContentNode/Sources/ChatMessageWebpageBubbleContentNode.swift` (1 site)
- `TelegramUI/Components/Chat/ChatMessageMediaBubbleContentNode/Sources/ChatMessageMediaBubbleContentNode.swift` (7 sites, all identical `telegramFile.resource` — handled via `replace_all=true`)
- `TelegramUI/Components/Chat/ChatMessageAttachedContentNode/Sources/ChatMessageAttachedContentNode.swift` (1 site)
- `TelegramUI/Sources/OpenChatMessage.swift` (1 site)
- `TelegramUI/Sources/Chat/ChatControllerMediaRecording.swift` (1 site)
- `TelegramUI/Components/Stories/StoryContainerScreen/Sources/StoryItemImageView.swift` (1 site, Shape B — was already using the `id:` overload; migrated identically to `EngineMediaResource.Id(...)`)

**8 sites intentionally skipped (Shape C/D).** Listed in the plan — 5 Shape-C sites that access a raw `account: Account` parameter (no `.engine` on `Account`) and 3 Shape-D sites that carry a local `postbox: Postbox` stored field. Both shapes need module-scoped init-signature rework rather than per-site sweep; defer to future waves.

**No modules became Postbox-free.** Each consumer has other Postbox usage (signatures, transactions, other mediaBox calls). Matches waves 19/20's expectation.

**Build validation.** `bazel build Telegram/Telegram --keep_going` — clean first-pass build (569 processes, 1556 action cache hits + 30 local + 532 worker, 240s, 0 errors, `Telegram.ipa` up-to-date).

**Pattern validation.** Wave-shape G (facade addition + consumer sweep in a single commit) works well when the consumer pool is bounded and mechanical. 29 sites in 14 files is comfortably within the threshold. Kept waves 19 and 20 separate because 25+ sites across that many modules was at the edge of reviewability; wave 21's similar fan-out fits because the plan pre-classified every site by shape. When the plan does the classification work upfront, combined waves are cheaper to review and ship.

Net: 14 files changed. TelegramEngineResources.swift: +4 / -0. Consumer files: +29 / -29 (mechanical rewrite at each site). CLAUDE.md: +outcome paragraph.

Plan / record: `memory/project_postbox_wave21_plan.md` (deleted post-commit per the plan's own housekeeping instructions).

## Wave 22 outcome (2026-04-21)

Follows wave 21's pattern: facade addition + consumer sweep in a single atomic commit. Adds `TelegramEngine.Resources.storeResourceData(id: EngineMediaResource.Id, data: Data, synchronous: Bool = false)` facade; sweeps 46 consumer sites across 17 files.

**Facade added at `TelegramCore/Sources/TelegramEngine/Resources/TelegramEngineResources.swift:464`.** Body: `self.account.postbox.mediaBox.storeResourceData(MediaResourceId(id.stringRepresentation), data: data, synchronous: synchronous)`. Wraps Postbox's `MediaBox.storeResourceData(_ id: MediaResourceId, data: Data, synchronous: Bool)` full-file overload. The range-store overload (`MediaBox.storeResourceData(_:range:data:)`) is used at a single site inside `HLSVideoJSNativeContentNode.swift:302` via a local `postbox: Postbox` field (Shape D), which is out of scope for this wave; the range overload gets no facade wrapper this round.

**46 Shape-A consumer sites migrated:**
- `ImportStickerPackUI/Sources/ImportStickerPackControllerNode.swift` (2)
- `DebugSettingsUI/Sources/DebugController.swift` (8 — 6 identical `gzippedData` batched via `replace_all=true`; `logData`, `allStatsData` handled individually)
- `BrowserUI/Sources/BrowserWebContent.swift` (1)
- `TelegramUI/Sources/CreateChannelController.swift` (4)
- `TelegramUI/Sources/CreateGroupController.swift` (4)
- `TelegramUI/Sources/Chat/ChatControllerPaste.swift` (1)
- `TelegramUI/Sources/Chat/ChatControllerOpenDocumentScanner.swift` (3)
- `TelegramUI/Sources/Chat/ChatControllerMediaRecording.swift` (2)
- `TelegramUI/Components/LegacyInstantVideoController/Sources/LegacyInstantVideoController.swift` (2)
- `TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/PeerInfoScreenAvatarSetup.swift` (2)
- `TelegramUI/Components/Settings/WallpaperGridScreen/Sources/WallpaperUtils.swift` (6 — 3 `thumbnailResource`, 3 `resource`; both handled via `replace_all=true`)
- `SettingsUI/Sources/Themes/ThemePreviewController.swift` (1)
- `SettingsUI/Sources/Themes/EditThemeController.swift` (1)
- `TelegramUI/Components/Stories/StoryContainerScreen/Sources/StoryItemSetContainerViewSendMessage.swift` (3)
- `TelegramUI/Components/VideoMessageCameraScreen/Sources/VideoMessageCameraScreen.swift` (2)
- `TelegramUI/Components/MediaEditorScreen/Sources/CreateLinkOptions.swift` (1)
- `TelegramUI/Components/MediaEditorScreen/Sources/MediaEditorScreen.swift` (3)

**Out of scope — not migrated this wave:**
- `accountManager.mediaBox.storeResourceData(...)` sites (Account-manager-scoped, not account-scoped) — 13+ sites across WallpaperGalleryItem, WallpaperGalleryController, ThemeAccentColorController, WallpaperUtils, WebBrowserSettingsController, ThemeUpdateManager, OpenResolvedUrl, and others. These are a different migration path entirely (not a `TelegramEngine.Resources.*` target) and stay raw.
- `account.postbox.mediaBox.storeResourceData(...)` (raw `Account`, no `AccountContext`) — ~9 sites in LegacyMediaPickerUI, TelegramCallsUI, InAppPurchaseManager, AuthorizationUI, PeerInfoScreenAvatarSetup closures, WallpaperResources. Shape C from wave-21 taxonomy. Needs per-module rework.
- `self.postbox.mediaBox.storeResourceData(...)` / `postbox.mediaBox.storeResourceData(...)` inside TelegramCore internals (`TransformOutgoingMessageMedia.swift`, `AccountStateManager.swift`, `AvailableReactions.swift`, `SaveSecureIdValue.swift`, `PeerPhotoUpdater.swift`, `NotificationSoundList.swift`, `Stories.swift`, `Authorization.swift`, `WebpagePreview.swift`). These are Postbox-internal layer by design — keep as-is.
- `HLSVideoJSNativeContentNode.swift:302` — uses the range-store overload via local `postbox: Postbox` field. Out of scope.

**No modules became Postbox-free.** Matches waves 19/20/21 expectation — each consumer has other Postbox usage.

**Build validation.** `bazel build Telegram/Telegram --keep_going` — clean first-pass build (571 processes, 1554 action cache hits + 30 local + 532 worker, 229s, 0 errors, `Telegram.ipa` up-to-date).

**Pattern validation.** Wave-shape G (facade + consumer sweep in one commit) scales well up to 46 sites in 17 files when the pattern is mechanical. Heavy `replace_all=true` usage where call-text is identical across sites (DebugController's 6 `gzippedData` sites, WallpaperUtils' 6 sites split into 2 batches by first-arg variable, ChatControllerOpenDocumentScanner's identical `(resource.id, data: data, synchronous: true)` pattern) keeps diff noise to the minimum. 46 sites, mostly done via replace_all + a few individual edits.

Net: 17 consumer files + 1 TelegramCore file + CLAUDE.md. TelegramEngineResources.swift: +4 / -0. Consumer files: +46 / -46 (mechanical rewrite).

Plan / record: (no plan doc this wave — mechanical sweep following wave-21 recipe).

## Wave 23 outcome (2026-04-21)

Smallest wave so far: `cancelInteractiveResourceFetch` facade addition + consumer sweep. Same shape as waves 21/22.

**Facade added at `TelegramCore/Sources/TelegramEngine/Resources/TelegramEngineResources.swift:468`.** Body: `self.account.postbox.mediaBox.cancelInteractiveResourceFetch(resourceId: MediaResourceId(id.stringRepresentation))`. Wraps Postbox's `MediaBox.cancelInteractiveResourceFetch(resourceId: MediaResourceId)` overload (the `_ resource: MediaResource` overload delegates to the id version anyway).

**5 of 7 Shape-A consumer sites migrated:**
- `PeerAvatarGalleryUI/Sources/PeerAvatarImageGalleryItem.swift` (1)
- `GalleryUI/Sources/Items/ChatAnimationGalleryItem.swift` (1)
- `GalleryUI/Sources/Items/ChatImageGalleryItem.swift` (1)
- `GalleryUI/Sources/Items/ChatDocumentGalleryItem.swift` (1)
- `GalleryUI/Sources/Items/ChatExternalFileGalleryItem.swift` (1)

**2 sites intentionally skipped:** `ChatMessageInteractiveMediaNode.swift:1474, 1709` — this file has pre-existing uncommitted WIP (the `allowSticker` validation around secret-chat sticker playback, carried forward since before wave 17). Editing the 2 sites would mix my wave-23 changes with the user's WIP in a single git diff, which `git add` can't cleanly separate. Deferred until the WIP lands or a narrow follow-up wave intentionally includes both. Note: a future wave that aims to drop those 2 sites should first either (a) wait for the WIP to be committed or (b) use `git stash --keep-index` + targeted edits + selective staging to split the diff cleanly.

**Pattern note on WIP interference.** This is the first wave to hit this failure mode — previous waves' mechanical sweeps happened not to touch `ChatMessageInteractiveMediaNode.swift`. Future sweeps should grep their candidate set against `git status`'s modified-files list before starting, and either (a) defer sites in WIP files, (b) wait for the WIP to commit, or (c) stage selectively via `git add --patch`-equivalent paths.

**Build validation.** `bazel build Telegram/Telegram --keep_going` — clean first-pass build (558 processes, 1567 action cache hits + 19 local + 532 worker, 236s, 0 errors, `Telegram.ipa` up-to-date).

Net: 5 consumer files + 1 TelegramCore file + CLAUDE.md. TelegramEngineResources.swift: +4 / -0. Consumer files: +5 / -5.

Plan / record: (no plan doc this wave — mechanical sweep).

## Wave 24 outcome (2026-04-21)

`moveResourceData` facade additions + consumer sweep. Same shape as waves 21-23.

**Two facades added at `TelegramCore/Sources/TelegramEngine/Resources/TelegramEngineResources.swift`:**
- `moveResourceData(id: EngineMediaResource.Id, toTempPath: String)` wraps the `(MediaResourceId, toTempPath:)` overload.
- `moveResourceData(from: EngineMediaResource.Id, to: EngineMediaResource.Id, synchronous: Bool = false)` wraps the `(from: MediaResourceId, to: MediaResourceId, synchronous:)` overload.

Postbox's third overload `(MediaResourceId, fromTempPath:)` has no consumer-side usage; no facade added this wave (YAGNI).

**6 Shape-A consumer sites migrated (5 files):**
- `TelegramUI/Sources/Chat/ChatControllerMediaRecording.swift` (1, `toTempPath:`)
- `TelegramUI/Sources/OverlayAudioPlayerController.swift` (1, `from:to:synchronous:`)
- `TelegramUI/Components/ComposePollScreen/Sources/ComposePollScreen.swift` (2)
- `TelegramUI/Components/Chat/ChatMessagePollBubbleContentNode/Sources/ChatMessagePollBubbleContentNode.swift` (2)

**Build validation.** `bazel build Telegram/Telegram --keep_going` — clean first-pass build (563 processes, 272s, 0 errors).

Net: 5 consumer files + 1 TelegramCore file + CLAUDE.md. TelegramEngineResources.swift: +8 / -0. Consumer files: +6 / -6.

Plan / record: (no plan doc this wave — mechanical sweep).

## Wave 25 outcome (2026-04-21)

`copyResourceData` facade additions + consumer sweep. Same shape as waves 21-24.

**Two facades added:** `copyResourceData(id: EngineMediaResource.Id, fromTempPath: String)` and `copyResourceData(from: EngineMediaResource.Id, to: EngineMediaResource.Id, synchronous: Bool = false)`.

**4 Shape-A consumer sites migrated (3 files):**
- `PeerAvatarGalleryUI/Sources/AvatarGalleryController.swift` (2, `from:to:synchronous:`)
- `ImportStickerPackUI/Sources/ImportStickerPackControllerNode.swift` (1, `from:to:` — simplified from `localResource._asResource().id` to `localResource.id` since operands are `EngineMediaResource`)
- `TelegramUI/Sources/Chat/ChatControllerPaste.swift` (1, `id:fromTempPath:`)

**Minor simplification lesson.** When a consumer already has an `EngineMediaResource`-typed local (e.g., from a wave-18-migrated callee), prefer `localResource.id` over `EngineMediaResource.Id(localResource._asResource().id)` — the two are semantically equivalent since `EngineMediaResource.id` is defined as `Id(self.resource.id)`. This halves the verbosity at the call site and removes a redundant unwrap-and-rewrap.

**Build validation.** Clean first-pass build (563 processes, 242s, 0 errors).

Net: 3 consumer files + 1 TelegramCore file + CLAUDE.md. TelegramEngineResources.swift: +8 / -0.

Plan / record: (no plan doc this wave — mechanical sweep).

## Wave 27 outcome (2026-04-22)

`preferencesView` consumer sweep (wave-9 pattern continuation). No new TelegramCore facades — leverages existing `TelegramEngine.EngineData.Item.Configuration.ApplicationSpecificPreference(key:)`.

**Shape.** Replace `context.account.postbox.preferencesView(keys: [<key>])` — returning `Signal<PreferencesView, NoError>` — with `context.engine.data.subscribe(TelegramEngine.EngineData.Item.Configuration.ApplicationSpecificPreference(key: <key>))` — returning `Signal<PreferencesEntry?, NoError>`. Downstream, rename `<name>.values[<key>]?.get(<Type>.self)` → `<name>?.get(<Type>.self)` at each closure parameter.

**30 consumer files, ~40 call sites migrated** across ChatListUI, ContactListUI, DebugSettingsUI, GalleryUI, PeersNearbyUI, SettingsUI, TelegramCallsUI, TelegramUI, TelegramUI/Components, WebSearchUI. Full list in `git show --stat <wave-27-commit>`.

**Multi-key sites (PresentationCallManager).** 3 sites used `preferencesView(keys: [voipConfiguration, appConfiguration])`. Migrated via the two-arg `engine.data.subscribe(itemA, itemB) |> take(1)` overload, which returns `Signal<(PreferencesEntry?, PreferencesEntry?), NoError>`. Closures that accessed `preferences.values[X]?.get(...)` rewritten to `preferences.0?.get(...)` and `preferences.1?.get(...)`.

**Direct-postbox-param helper migrated.** `AccountContext.swift`'s `getAppConfiguration(postbox: Postbox)` helper (one internal caller only) was rewritten to `getAppConfiguration(engine: TelegramEngine)` in the same commit, switching its single call site from `getAppConfiguration(postbox: account.postbox)` to `getAppConfiguration(engine: self.engine)`.

**Annotation update in NotificationExceptionControllerNode.swift.** An explicit signal type `Signal<(…, PreferencesView, …), NoError>` in a `mapToSignal` return was updated to `Signal<(…, PreferencesEntry?, …), NoError>`. The file still imports Postbox because `PreferencesEntry` is (for now) a Postbox-defined type surfaced through TelegramCore's `EnginePreferencesEntry` typealias — a future wave-6-style `import Postbox` sweep would clean up such imports where they're now the only Postbox reference.

**Deliberately skipped in this wave.**
- `TelegramPermissionsUI/Sources/PermissionSplitTest.swift:100` — `permissionUISplitTest(postbox: Postbox)` is a public API whose product value `PermissionUISplitTest` itself stores `postbox: Postbox` to satisfy the `SplitTest` protocol. Proper migration requires a protocol-level refactor (or wholesale rewrite of the SplitTest abstraction) beyond this wave's scope.
- 5 TelegramCore-internal `postbox.preferencesView(...)` sites (ChatListFiltering × 3, ContentSettings × 1, ManagedGlobalNotificationSettings × 1) — the refactor only migrates consumer modules, not TelegramCore internals.

**Build validation.** Clean first-pass build (748 processes, 227s, 0 errors). No new facades to test, shape was validated across 30 files on the first attempt.

**Lesson — multi-key preferencesView migration.** `engine.data.subscribe(itemA, itemB)` exists and returns a Swift tuple. When a Postbox `preferencesView(keys: [K1, K2])` call is inside a `combineLatest(...)` whose downstream closure accesses `.values[K1]` and `.values[K2]`, prefer the two-arg subscribe form (vs. two separate subscribes combined externally) — it preserves `combineLatest` arity exactly. Rewrite `.values[K1]?.get(T.self)` → `.0?.get(T.self)`, `.values[K2]?.get(T.self)` → `.1?.get(T.self)`. The closure parameter name stays (e.g., `preferences`) because the tuple destructure preserves the variable-name semantics at the call site.

Net: 30 consumer files. No TelegramCore changes. CLAUDE.md facade-inventory table unchanged (no new facades).

Plan / record: `memory/project_postbox_wave27_plan.md` (deleted post-wave).

## Wave 26 outcome (2026-04-21)

`resourceRangesStatus` + `removeCachedResources` facade additions + consumer sweep. Combines two independent small sweeps into one commit.

**Two facades added:**
- `resourceRangesStatus(resource: EngineMediaResource) -> Signal<RangeSet<Int64>, NoError>` wraps the single `(MediaResource) -> Signal<RangeSet<Int64>, NoError>` overload. Takes `EngineMediaResource` (not `id:`) because Postbox's overload only accepts a resource, not an id — consumers pass `.resource` already. Facade unwraps via `_asResource()`.
- `removeCachedResources(ids: [EngineMediaResource.Id], force: Bool = false, notify: Bool = false) -> Signal<Float, NoError>` wraps the `([MediaResourceId], force:, notify:) -> Signal<Float, NoError>` overload. Maps ids internally.

**`import RangeSet` added to `TelegramEngineResources.swift`.** The `RangeSet<Int64>` return type caused a name collision with Swift stdlib's `RangeSet` (iOS 18+ only) until the local `RangeSet` module is imported. `TelegramCore/BUILD` already declared the dep at line 23 (`//submodules/Utils/RangeSet:RangeSet`), so no BUILD change needed.

**4 Shape-A consumer sites migrated (3 files):**
- `PhotoResources/Sources/PhotoResources.swift` (1)
- `TelegramUI/Components/Stories/StoryContainerScreen/Sources/StoryChatContent.swift` (1)
- `ChatListUI/Sources/ChatListSearchContainerNode.swift` (2)

For `ChatListSearchContainerNode.swift:1398`, the caller uses a `Set<MediaResourceId>` local — wave leaves the local as-is and maps at the call site via `resourceIds.map { EngineMediaResource.Id($0) }`. Migrating the local to `Set<EngineMediaResource.Id>` is out of scope (module keeps `import Postbox` for unrelated reasons).

**Build validation.** Clean build (563 processes, 265s, 0 errors) on the second attempt after adding `import RangeSet`.

**Lesson — Swift-stdlib-vs-third-party-module name collisions.** When a facade signature references a type name that exists both in Swift stdlib (potentially availability-restricted) and in a third-party module, the compiler picks the stdlib one by default. Fix: import the third-party module explicitly. In this codebase, `RangeSet` is provided by `submodules/Utils/RangeSet:RangeSet`, and TelegramCore already depends on it. Use `import RangeSet` at the file top.

Net: 3 consumer files + 1 TelegramCore file + CLAUDE.md. TelegramEngineResources.swift: +9 / -0 (including `import RangeSet`).

Plan / record: (no plan doc this wave — mechanical sweep).

## Wave 31 outcome (2026-04-23)

Second build-verified `^import Postbox$` sweep on consumer modules since wave 6 (2026-04-19). Same methodology: speculative-drop + `--continueOnError` build loop with pattern-based preemptive restores.

**Candidate set narrowing.** Initial candidate grep `grep -rl "^import Postbox$" submodules --include="*.swift"` returned **1184** files. 606 of those live in `submodules/TelegramCore/Sources/` — TelegramCore legitimately `import Postbox`; the TelegramCore files were accidentally included and had to be reverted via `git checkout -- submodules/TelegramCore/Sources/` before re-seeding the drop. Final consumer candidate set: **578** files. **Lesson for future sweep invocations: the candidate-set grep must filter out `submodules/TelegramCore/` as well as `submodules/Postbox/` / `submodules/TelegramApi/`.** Wave 6's methodology note at step 1 (line 37) already calls this out, but the TelegramCore carve-out is easy to miss because TelegramCore doesn't `@_exported import Postbox`, so from a pure re-exports perspective it's indistinguishable from a consumer.

**9 build iterations to convergence** (plus 1 aborted first iteration for the TelegramCore scope error). Per-iteration failure counts: 18 → 2 → 9 → 12 → 1 → 1 → 3 → 1 → 4 → 0. Surfacing pattern was typical of a speculative-drop sweep: errors bubble one dependency-graph layer at a time.

**Per-iteration symbol expansion.** The wave-6 preemptive-restore symbol list (CLAUDE.md's "Unused-import sweeps" guidance) needed extensions for this sweep:
- Iter 3 surfaced `CodableEntry`, `CachedMediaResourceRepresentation`, `CachedMediaRepresentationKeepDuration`.
- Iter 4 surfaced `PostboxViewKey`, `OrderedItemListView`, `UnreadMessageCountsItem`, `ChatListEntrySummaryComponents`, `PeerStoryStats`, `ItemCollectionId` (note: typealias `EngineItemCollectionId` exists but raw name still requires `import Postbox`), and broadened `\bMedia\b`, `\bMessage\b`, `\bPeer\b`.
- Iter 5 surfaced `FetchResourceSourceType` (same typealias caveat).
- Iter 6 surfaced `StoryId`.
- Iter 7 surfaced `ChatListIndex`.
- Iter 8 surfaced `PreferencesEntry` (typealias caveat), `PeerView`, `RenderedPeer`.
- Iter 9 surfaced `declareEncodable`.
- Iter 10 surfaced `ItemCollectionItemIndex`, `ValueBoxEncryptionParameters`, `fileSize`, plus a restore-script bug (see below).

**Restore-script bug: `#if canImport(...)` blocks.** The naive restore inserter picks the last `^import ` line and appends `import Postbox` after it. If the last import sits inside an `#if canImport(AppCenter) ... #endif` preprocessor block, the restored `import Postbox` lands inside that block and is only active under that configuration. `AppDelegate.swift` in `submodules/TelegramUI/Sources/` hit this (original had `import Postbox` at line 7; drop + restore put it inside the `#if canImport(AppCenter)` block at line 51); the build failed in iter10 on `cannot find type 'Postbox' in scope` errors even though a literal `grep ^import Postbox$` matched. Fixed by manually moving the import out of the `#if` block. **Lesson for future restore-script work: insert the restored `import Postbox` BEFORE the first `#if` or `#endif` line, not after the last `import` line, to avoid preprocessor-scope traps.**

**Results: 9 source-level surviving drops + 2 duplicate-import dedups.** Final diff: 11 files changed, +2 / -13.

Surviving drops:
- `submodules/AuthorizationUI/Sources/AuthorizationSequencePhoneEntryController.swift`
- `submodules/AuthorizationUI/Sources/AuthorizationSequenceSplashController.swift`
- `submodules/DebugSettingsUI/Sources/DebugAccountsController.swift`
- `submodules/LegacyDataImport/Sources/LegacyPreferencesImport.swift`
- `submodules/MediaPlayer/Sources/ChunkMediaPlayerDirectFetchSourceImpl.swift`
- `submodules/TelegramUI/Components/Stories/StoryContainerScreen/Sources/StoryItemImageView.swift`
- `submodules/TelegramUI/Sources/ChatLinkPreview.swift`
- `submodules/TelegramUI/Sources/ChatSearchResultsController.swift`
- `submodules/TelegramUI/Sources/MediaManager.swift`

Duplicate-import dedups (files had two `^import Postbox$` lines; kept exactly one — unrelated-but-latent cleanup surfaced incidentally by the sweep):
- `submodules/TelegramUI/Components/ChatControllerInteraction/Sources/ChatControllerInteraction.swift` (2 imports → 1)
- `submodules/TelegramUI/Sources/ChatHistoryListNode.swift` (2 imports → 1)

**Spurious-diff cleanup step (new procedure, adopted this wave).** After convergence, `git diff --numstat` showed 564 modified files but only 9 were genuine drops. The other 553 were "1 addition + 1 deletion" — files where the original `import Postbox` at line X was deleted by the drop and re-inserted at line Y by the restore (different position because restore inserts after "last import line" regardless of original placement). These aren't semantic changes but do produce noisy diffs. Identified via `git diff --numstat | awk '$1 == 1 && $2 == 1 {print $3}'` and reverted via `xargs -I{} git checkout -- {}`. **Lesson: the wave-6 methodology should add a post-convergence "revert 1-add-1-del spurious diffs" step before committing. Alternative: improve the restore script to insert at the exact original line. Either way, the final diff should be limited to real semantic changes.**

**No modules became fully Postbox-free this wave.** Each of the five containing modules still has other files importing Postbox (TelegramUI: 350 remaining, LegacyDataImport: 4, MediaPlayer: 9, AuthorizationUI: 2, DebugSettingsUI: 1). By this point most trivially-droppable imports have been drained; the remaining Postbox-importing files mostly carry real usage. **Re-run cadence lesson: yield per re-run is declining.** Wave 6 yielded 183 drops + 189 modules freed; wave 31 yielded 9 drops + 0 modules freed. Consider spacing future sweeps to every 4–6 facade waves rather than 2–3.

**Wave 14 BUILD-dep sweep companion: 0 drops.** Ran the wave-14-style `find submodules -name BUILD | filter-by-no-source-import` check: **0 BUILD candidates**. The 191 BUILDs still listing `//submodules/Postbox` all have at least one Sources/*.swift that actually imports Postbox. One outlier (`submodules/SpotlightSupport/BUILD`) has zero source files but a non-trivial `deps = [...]` list including `//submodules/Postbox`; deliberately left alone (stale-BUILD-on-empty-module is a different class of cleanup and carries unknown side effects).

Net: 11 files changed (9 + 2), +2 / -13 lines. Clean first-attempt verification build without `--continueOnError` (880 actions, 1354 action cache hits, 262s).

Plan / record: (no plan doc this wave — mechanical sweep).

## Wave 32 outcome (2026-04-24)

`resourceStatus` residue sweep. One new facade overload (`status(id:resourceSize:)`) + 4 migrated sites across 2 consumer files. Commit `289fc908bc`.

**Facade added** in `TelegramEngineResources.swift`:
- `status(id: EngineMediaResource.Id, resourceSize: Int64) -> Signal<EngineMediaResource.FetchStatus, NoError>` wraps Postbox's `resourceStatus(MediaResourceId, resourceSize:)` overload. Body mirrors the existing `status(resource:)` facade, converting id via `MediaResourceId(id.stringRepresentation)` and mapping the result via `EngineMediaResource.FetchStatus.init`.

**4 migrated sites (2 files):**
- `ChatListSearchContainerNode.swift:1059` — new `status(id:resourceSize:)` overload. Caller supplies `EngineMediaResource.Id(downloadResource.id)` directly (String initializer; `downloadResource.id: String`) — no raw `MediaResourceId(...)` wrap needed. Mirrors the pre-existing `EngineMediaResource.Id(downloadResource.id)` usage at line 1107.
- `ChatMessageInteractiveMediaNode.swift:1769` — existing `status(resource:)` facade (wave 3).
- `ChatMessageInteractiveMediaNode.swift:1799` — same.
- `ChatMessageInteractiveMediaNode.swift:1809` — existing `resourceRangesStatus(resource:)` facade (wave 26).

**Local preserved deliberately.** `let postbox = context.account.postbox` at `ChatMessageInteractiveMediaNode.swift:1767` stays because line 1793 feeds `postbox` to `HLSVideoContent.minimizedHLSQualityPreloadData(postbox: Postbox, ...)` — that is a third-party-function boundary needing raw `Postbox`. Only the `resourceStatus`/`resourceRangesStatus` call sites within that scope migrate.

**Case-pattern sharing.** `MediaResourceStatus` (raw Postbox) and `EngineMediaResource.FetchStatus` (engine wrapper) have identical case names (`.Fetching`, `.Paused`, `.Local`, `.Remote`). The inner `switch status` at 1770-1779 keeps its `MediaResourceStatus` return type annotation — input case matching works for the engine type, constructed `MediaResourceStatus` return values still compile (`MediaResourceStatus` is in scope via `import Postbox` on line 4). This is the wave-29/30 lesson in action: no enum-case edits required.

**Inventory scope narrowing from memory's prediction.** The memory's `wave 32+ candidates` section predicted ~12 Shape-B/C sites in the residue sweep. Execution-time re-grep reclassified most of them:
- **Coupled to `accountManager.mediaBox.resourceStatus` siblings (6 sites in 3 files):** `ThemePreviewControllerNode:271+277`, `WallpaperGalleryItem:799+805+834+840`, `SettingsThemeWallpaperNode:284+285`. Each pair has an `accountManager`-sourced fallback whose return type is raw `Signal<MediaResourceStatus, NoError>`. Migrating only the `account.postbox` branch breaks the shared sibling type at the `mapToSignal`/`combineLatest` merge point. Deferred until accountManager-side has an engine facade.
- **Shape-C init-param refactor (3 sites in 3 files):** `LegacyWebSearchGallery:248` (free function `legacyWebSearchItem(account: Account, ...)`), `NativeVideoContent:455` (init takes `postbox: Postbox`), `VerticalListContextResultsChatInputPanelItem:229` (item stores `account: Account`). Each needs an init-param change + caller threading — per-module mini-refactor, not wave-shape-G territory.
- **`approximateSynchronousValue` overload:** only call site (`SettingsThemeWallpaperNode:284`) is in the accountManager-coupled bucket above. Adding the facade now would land dead code.

Effective wave scope: 4 sites (the uncoupled subset). Still worth committing as its own wave — closes the `resourceStatus` arc for every site where migration is currently unblocked.

**Build validation.** Clean build (558 processes, 236s, 0 errors). No `--continueOnError` needed — first attempt green.

**Lesson — siblings-define-scope in resource-status migrations.** When an assignment uses `A.resourceStatus(...)` in one branch and `B.resourceStatus(...)` in another (via `if`/`mapToSignal`/`combineLatest`), the branches' return types must match. If `A` has an engine facade but `B` does not (e.g., `accountManager.mediaBox` has no engine wrapper yet), neither branch is migratable in isolation — the whole group must wait. Pre-flight sibling-check for each `resourceStatus` hit: is the enclosing `statusSignal = ...` expression a single source or a multi-source merge?

**Lesson — Shape-B/C classification requires read, not grep.** The memory's wave-32 candidate table classified sites by single-line grep ("`account.postbox.mediaBox.resourceStatus`"). That pattern matches both the fully-migratable `context.account.postbox.mediaBox.X` form (Shape-A via AccountContext) AND the `(local) account.postbox.mediaBox.X` Shape-C form (requires init-param refactor). Distinguishing requires reading 5-10 lines of context to find the `account` binding: field? local? init param? closure capture? Add this as a mandatory step in the per-site inventory for future residue waves.

Plan / record: (no plan doc this wave — small residue sweep).

---

## Wave 33 outcome (2026-04-24)

`loadedPeerWithId` consumer sweep. 60 sites migrated across 37 consumer files. No new facades, no typealiases. Commit `16d017853a`.

**Migration pattern** (per user's explicit direction):

```swift
context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: peerId))
|> mapToSignal { peer -> Signal<EnginePeer, NoError> in
    if let peer {
        return .single(peer)
    } else {
        return .never()
    }
}
```

This replaces `context.account.postbox.loadedPeerWithId(peerId)` while preserving signature shape. The `mapToSignal` wrapper is critical: Postbox's `loadedPeerWithId` returns `.never()` (signal never emits) when the peer is missing — it does NOT wait for loading. The engine-data equivalent `get(Peer.Peer(id:))` returns `Signal<EnginePeer?, NoError>` (optional snapshot). Unwrapping with `.never()`-on-nil preserves original semantics exactly, while keeping the outer shape `Signal<EnginePeer, NoError>` non-optional so callers' closures don't have to cascade new optional handling.

**Category distribution (per pre-flight Explore catalog, 60 sites):**

| Category | Count | Body change |
|---|---|---|
| Cat-A (trivial) | 22 | Only EnginePeer-compatible members; type swap only. |
| Cat-B (concrete-type cast) | 25 | `peer as? TelegramUser/Group/Channel/SecretChat` → `if case let .user(user)` (etc.). |
| Cat-C (feeds Peer-typed API) | 13 | `peer._asPeer()` at call point (`makePeerInfoController`, `makeChatRecentActionsController`, `makeChatQrCodeScreen`, `FoundPeer.init`, `SendAsPeer.init`). |

(Cat-B + Cat-C bumped slightly from Explore's catalog after in-edit reclassifications.)

**Engine-access variations:**
- Most consumer modules use `context.engine.data.get(...)` on `AccountContext`.
- `ShareSearchContainerNode.swift` uses `context.engineData.get(...)` because `ShareControllerAccountContext` exposes `engineData: TelegramEngine.EngineData` but not a full `engine`.
- `CallStatusBarNode.swift` (has raw `account: Account` from switch case) constructs `TelegramEngine(account: account)` inline.
- `PresentationGroupCall.swift` uses `self.accountContext.engine.data` instead of the stored `self.account.postbox`.

**TelegramCore internal sites (36) unchanged.** `Postbox.swift` (2 defs), `State/AccountViewTracker.swift`, `State/FetchChatList.swift`, `State/SynchronizePeerReadState.swift`, `Suggestions.swift`, and all `TelegramCore/Sources/TelegramEngine/` internal `_internal_*` helpers still call `postbox.loadedPeerWithId(...)` — they are the Postbox-facing layer.

**Pre-flight efficiency.** An Explore subagent cataloged all 60 sites by category from a single prompt (one-line-per-site output). That catalog made the sweep straightforward: most files fell into identical patterns, enabling template-substitution Edits. Total context spent on discovery was small compared to doing 60 per-site full reads in the main thread.

**Build validation.** First-pass clean build (47 actions, 70s) after sweep completion. Earlier pilot (2 sites, 20s) validated pattern before scaling to all 60.

**Lessons:**

- **`loadedPeerWithId` returns `.never()` on missing peer, not a pending Signal.** Old common misreading: treating it as a "wait-until-loaded" primitive. Actual Postbox source at `Postbox.swift:3925`: `if let peer = self.peerTable.get(id) { return .single(peer) } else { return .never() }`. Preserve this by wrapping `engine.data.get` in `mapToSignal` with the `.never()` fallback — don't replace with plain `|> compactMap { $0 }` (which would drop the signal entirely rather than completing immediately when peer exists).

- **"Keep the signatures to help the typechecker" as a migration principle.** The user (2026-04-24) explicitly directed: keep call-site outer Signal signatures stable (`Signal<EnginePeer, NoError>` non-optional), even at the cost of a 6-line inline `mapToSignal` wrapper at each site. Rationale: 60 sites × optional-cascade body changes > 60 × 6-line wrapper. This is a general principle for sweeps — if the alternative is rewriting every body to handle optionals, prefer the signal-level wrapper to contain the change.

- **Pre-flight cataloging via Explore subagent.** For sweeps with variable per-site body shapes (unlike facade-migration-with-identical-call-expression sweeps), a dispatch to `Explore` with a category-classification prompt collapses inventory cost. Explore's output is small (~60 one-line entries); avoids pulling 60 file fragments into the main thread's context. Required for wave shapes where inventory is non-uniform.

- **Shape-C peer-fed-to-API pattern needs `_asPeer()` at call, not facade.** Because `makePeerInfoController(peer: Peer)` / `FoundPeer(peer: Peer, ...)` / `SendAsPeer(peer: Peer, ...)` / `makeChatQrCodeScreen(peer: Peer, ...)` all stay on raw `Peer` (they're AccountContext-protocol or TelegramCore struct-init APIs whose migration is its own multi-wave effort), the bridge is a single `._asPeer()` at the call. Don't try to also migrate those APIs in the sweep — blast radius too large.

- **Engine-access varies by containing context.** Plain `context.engine.data` works for ~85% of sites; the remainder need `TelegramEngine(account: account)` construction or `engineData` protocol property. Build a per-site `context` type check into pre-flight for call-site categories where `AccountContext` isn't guaranteed.

Plan / record: no plan doc this wave — user specified the migration pattern directly; the Explore catalog + commit message captured decisions.

---

## Wave 34 outcome (2026-04-24)

`FoundPeer.peer: Peer → EnginePeer`. Public field-type migration on the struct in `submodules/TelegramCore/Sources/TelegramEngine/Peers/SearchPeers.swift`. Atomic 12-file commit `fdd5b93998`. ~135 insertions / ~134 deletions.

**Migration shape.** The field-type change is necessarily atomic (half-migrated FoundPeer doesn't compile across consumers), so all edits land in one commit. `_internal_searchPeers` keeps `import Postbox` (still calls `postbox.transaction` etc.) and wraps raw peer values with `EnginePeer(peer)` at the FoundPeer constructor sites. `==` body changes from `lhs.peer.isEqual(rhs.peer)` to `lhs.peer == rhs.peer`.

**Final scope (vs planned ~70 semantic edits → actual ~135 line insertions):**
- 5 `._asPeer()` bridge-drops at FoundPeer constructor sites (e.g., `FoundPeer(peer: peer._asPeer(), ...)` → `FoundPeer(peer: peer, ...)`)
- 22+ redundant `EnginePeer(peer.peer)` wrap drops (the field is now EnginePeer; `EnginePeer.init(_ peer: Peer)` doesn't accept an EnginePeer argument so the wrap fails to compile)
- 30+ Postbox-concrete-type downcasts (`peer.peer as? TelegramX` / `is TelegramX`) rewritten to `if case let .X(x) = peer.peer` enum-pattern form
- ~10 `._asPeer()` outflow bridges added where `peer.peer` flows into APIs that still take raw `Peer`: `ContactListPeer.peer(peer:)`, `canSendMessagesToPeer(_:)`, `EngineRenderedPeer(peer:)` legacy paths

**Inventory undercounting — pattern.** Original Explore inventory pass missed 4 of 12 final consumer files. The grep `grep -rln "FoundPeer\b"` only catches files that name `FoundPeer` as a literal type. Files that USE `peer.peer` access on FoundPeer values without naming the type itself were invisible to that grep. The build verification pass surfaced them:

| File | Surfaced by | Edits needed |
|---|---|---|
| `TelegramCore/Calls/GroupCalls.swift` | iter 1 | 2 internal FoundPeer constructors needed `EnginePeer(peer)` wraps |
| `ShareController/ShareSearchContainerNode.swift` | iter 2 | 4 errors: 2 C2 downcasts + 2 outflow-bridge needs |
| `ContactListUI/ContactsSearchContainerNode.swift` | iter 3 | 7 errors: nested `if !(peer is X)` rewrite + multiple downcasts/outflows |
| `PeerInfoUI/ChannelMembersSearchContainerNode.swift` | iter 4 | 6 errors across 2 near-identical loop blocks |
| `ChatListUI/ChatListSearchListPaneNode.swift` (extra site) | iter 5 | 1 missed C2 site at line 3723 (in `.globalPeer(foundPeer, …)` enum case body, far from the other ChatListUI edits) |

5 build iterations total before clean (each iteration: edit → re-build, ~50–60s incremental). First-pass would have needed a much wider pre-flight grep — see lessons.

**Lessons:**

- **Inventory grep must include the access pattern, not just the type name.** For a field-type migration, ALL of:
  - `<Type>(peer:` constructors
  - `<x>.peer.<member>` reads (verify `<x>` type is `<Type>`, not RenderedPeer/SendAsPeer/etc.)
  - `<x>.peer as?` / `<x>.peer is` downcasts
  - `<api>(<x>.peer)` arg passes (where `<api>` may take the old protocol)
  
  Use `for x in Y` binding-tracing to determine if `<x>` is the migrated type. The wave-34 pre-flight ran the first three but not the fourth (outflow-arg sites), and partially missed the second (because the Explore agent classified by literal `FoundPeer` token rather than by `peer.peer` semantics in context).

- **`if !(peer is A || peer is B)` rewrite uses `switch case A, B: break / default: ...`.** When the original Postbox code uses a negated disjunction of type-checks, the cleanest enum-pattern equivalent is a `switch` with combined cases in one arm — not nested `if case`s. (Used in ChatListSearchListPaneNode:1024 and ContactsSearchContainerNode:502/544.)

- **Inner `peer` shadowing.** Many `else if let peer = peer.peer as? TelegramChannel` Postbox patterns shadow the loop variable. The enum-pattern rewrite renames the inner binding to `channel` to avoid double-shadowing the EnginePeer outer loop var. Block-internal references to `.info` etc. then move from `peer.info` to `channel.info`.

- **Build iteration = inventory completion.** When the inventory undercounting becomes apparent (build surfaces 5+ unexpected sites), don't abandon — iterate. Each build is fast (~50s incremental) and each error is actionable (`error: cast from EnginePeer to unrelated type X always fails` → C2 rewrite; `argument type EnginePeer does not conform to expected type Peer` → outflow bridge). The inventory grows by file, fix-then-rebuild converges in 5 iterations even when ~30% of sites were missed up front.

- **Bridge sites generated by this wave point to next-ring migration targets.** The ~10 `._asPeer()` outflow bridges land at `ContactListPeer.peer(peer:)`, `canSendMessagesToPeer(_:)`, and `EngineRenderedPeer(peer:)` (legacy raw-Peer constructor in some paths — e.g., `EngineRenderedPeer(peer: foundPeer.peer)` doesn't need a bridge in newer EnginePeer-aware paths but does where the local var was already raw-Peer-extracted). These three signatures are the obvious wave-35+ candidates for the next ring of migration.

**Plan / record:** `docs/superpowers/plans/2026-04-24-foundpeer-engine-peer-migration.md`. Spec: `docs/superpowers/specs/2026-04-24-foundpeer-engine-peer-migration-design.md`.

---

## Wave 35 outcome (2026-04-24)

`SendAsPeer.peer: Peer → EnginePeer`. Public field-type migration on the struct in `submodules/TelegramCore/Sources/TelegramEngine/Messages/SendAsPeers.swift`. Atomic 7-file commit `583c8b1f7c`. 22 insertions / 26 deletions.

**Migration shape.** Same atomic-field-type pattern as wave 34 but scoped to a smaller consumer surface. The `_internal_*SendAsAvailablePeers` functions keep `import Postbox` and wrap raw peer values with `EnginePeer(peer)` at the 4 SendAsPeer constructor sites. Manual `==` body dropped in favor of synthesized Equatable (`EnginePeer: Equatable`, `Int32?` and `Bool` already Equatable).

**Final scope (vs planned ~15 semantic edits → actual 22/26 line diff):**
- 3 `._asPeer()` bridge-drops at SendAsPeer constructor sites (ChatControllerLoadDisplayNode:772, ChatTextInputPanelComponent:848, StoryItemSetContainerViewSendMessage:249)
- 7 redundant `EnginePeer(peer.peer)` / `EnginePeer($0.peer)` / `EnginePeer(value.peer)` wrap drops across ChatSendAsPeerListContextItem (4 sites), ChatTextInputPanelNode (1), StoryItemSetContainerViewSendMessage (1), StoryItemSetContainerComponent (1)
- 1 `peer.peer as? TelegramChannel` downcast rewritten to `if case let .channel(channel) = peer.peer` (ChatSendAsPeerListContextItem:73) with `peer.info → channel.info` rename in the shadowed scope
- 2 `EnginePeer(channel)` wraps added where raw `TelegramChannel` is constructed into `SendAsPeer(peer: ...)` (ChatControllerLoadDisplayNode:805, 823)
- 1 signal-chain simplification: `(sendAsPeer?.peer).flatMap(EnginePeer.init)` → `sendAsPeer?.peer` at StoryItemSetContainerViewSendMessage:4080
- 1 signal-chain simplification: `.map({ EnginePeer($0.peer) })` → `.map({ $0.peer })` at StoryItemSetContainerViewSendMessage:4081

**Inventory undercount = 1 site (vs wave 34's 5).** The pre-flight Explore catalog missed `StoryItemSetContainerComponent.swift:3069` (`currentPeer: EnginePeer(value.peer)` → `value.peer`). The implementer caught it during the edit phase before the build, so no iteration was needed. The wave-34 explicit pattern grep (including `.peer as?`/`is`/outflow-args/`EnginePeer(.peer)`/`._asPeer()`) dramatically reduced undercounting — 1/7 sites missed (~14%) vs wave 34's 4/12 (~33%).

**First-pass clean build.** No errors surfaced by the Bazel build at all. 461 total actions, 196.583s elapsed, `INFO: Build completed successfully`. Contrast with wave 34's 5 build-iterations-to-converge.

**Lessons:**

- **Wave 34's explicit-pattern pre-flight inventory works.** For future Peer-typed-API waves, the minimum grep pattern set is: `<Type>\b` literal token, `\.<fieldName>\s+(as\?|is)\s+Telegram`, `EnginePeer\(\w+\.<fieldName>\)`, `<api>\(<x>\.<fieldName>` for known outflow APIs, and `\._asPeer\(\)` (to catch bridge-drop opportunities). Wave 35 used this full pattern set and hit ~14% undercount vs wave 34's ~33%.

- **Smaller target + validated pattern = faster wave.** Wave 35 went from spec-commit (`72d4384af0`) to outcome-commit in a single session with one clean build, versus wave 34's multi-iteration convergence. When the wave is a replay of a just-validated pattern on a smaller surface, expect minimal iteration.

- **Inner-peer shadowing rename works.** The wave-34 lesson about renaming `peer` → `channel` in `if case let .channel(channel) = peer.peer` applied cleanly. Single instance this wave (ChatSendAsPeerListContextItem:73) — no issues.

- **Name collisions remain a scope hazard.** Pre-flight identified `sendAsPeers: [EnginePeer]` (LiveStreamSettingsScreen, ShareWithPeersScreen) and `availableSendAsPeers: [EnginePeer]` (ChatSendStarsScreen) as name-only collisions — different type, same identifier. Confirmed these stayed untouched and out of scope. Future Peer-typed-API waves should continue the name-collision disambiguation pass.

- **Bridge sites generated by this wave — zero new outflow bridges.** Unlike wave 34 (which added ~10 `._asPeer()` outflow bridges pointing to `ContactListPeer.peer(peer:)` / `canSendMessagesToPeer(_:)` / `EngineRenderedPeer(peer:)` as next-ring targets), wave 35 added no outflow bridges. All consumer-side `.peer` flows either stayed as `.peer.id` accesses (PeerId unchanged) or were simplifications of existing `EnginePeer(.peer)` wraps. Net: no new next-ring targets surfaced from wave 35.

**Plan / record:** `docs/superpowers/plans/2026-04-24-sendaspeer-engine-peer-migration.md`. Spec: `docs/superpowers/specs/2026-04-24-sendaspeer-engine-peer-migration-design.md`.

---

## Wave 36 outcome (2026-04-24)

`ContactListPeer.peer(peer: Peer, isGlobal:, participantCount:) → peer: EnginePeer`. Enum-case payload migration on the public type in `submodules/AccountContext/Sources/ContactSelectionController.swift`. Atomic 15-file commit `069a060de1`. 57 insertions / 59 deletions.

**Migration shape.** Same atomic-payload-type pattern as wave 34/35 but wider: 15 consumer files vs wave 35's 7, vs wave 34's 12. Beyond the payload change, the cascading `ContactListPeer.indexName` return type changed from `PeerIndexNameRepresentation` to `EnginePeer.IndexName` — an unexpected discovery during plan-writing that dropped 2 additional `EnginePeer.IndexName(...)` wraps at ContactListNode:517.

**Final scope (vs planned 8 files / ~41 semantic edits → actual 15 files / 57/59 diff):**

- **Definition (1 file):** `AccountContext/ContactSelectionController.swift` — case payload type, indexName return type, `==` operator body (`lhsPeer.isEqual(rhsPeer)` → `lhsPeer == rhsPeer`).
- **20 `._asPeer()` outflow bridge-drops** across ContactListNode (12), ContactsSearchContainerNode (3), ContactMultiselectionController (2), ContactMultiselectionControllerNode (1), ContactSelectionControllerNode (2). `replace_all=true` on `._asPeer(), isGlobal:` was the unifying substring.
- **20+ `EnginePeer(peer)` inflow wrap-drops** at destructure sites across ContactListNode (4), ContactsController (1), ContactsSearchContainerNode (4), ContactMultiselectionController (4), ContactMultiselectionControllerNode (1), ContactSelectionController (2), PeerSelectionControllerNode (3), SharedAccountContext (2).
- **2 `EnginePeer.IndexName(...)` wrap-drops** at the sort-comparator at ContactListNode:517 (enabled by the cascading return-type change).
- **8 Postbox-concrete cast rewrites** to EnginePeer case patterns across ContactListNode:182-186/1968 (4 sites, including the 3-branch user/group/channel cast-chain), CallController:524/542 (the intermediate `let peer = EnginePeer(peer)` lines became redundant after migration), StoryItemSetContainerViewSendMessage:2041/2074, DeviceContactInfoController:1419, ChatSendAudioMessageContextPreview:89, ChatControllerOpenAttachmentMenu:557/610/1746/1788 (4 identical sites, `replace_all` on the full line).
- **2 `._asPeer()` outflow bridges ADDED** at ContactMultiselectionController:386/403 where the destructured peer flows into `peerTokenTitle(peer: Peer)` (out-of-scope callee; future-wave bridge target).

**Inventory undercount = 7 files / ~20 sites (vs wave 35's 1 site).** Much higher miss rate than wave 35 — ~46% by file count. Root cause: the pre-flight grep for ContactListPeer destructures used literal `\(peer, _, _\)` binding; binding names varied in practice (`contact`, `lhsPeer`, `rhsPeer`, `contactPeer`, `id`). Files missed:

1. `DeviceContactInfoController.swift:1418/1419` — `case let .peer(contact, _, _)` + `contact as? TelegramUser`
2. `CallController.swift:523/541` — `case let .peer(peer, _, _)` + redundant `let peer = EnginePeer(peer)` pattern
3. `ChatSendAudioMessageContextPreview.swift:88/89` — `case let .peer(contact, _, _)` + `contact as? TelegramUser`
4. `PeerSelectionControllerNode.swift:901-903/1590-1592` — 2 destructures with `EnginePeer(peer)` inflow wraps
5. `StoryItemSetContainerViewSendMessage.swift:2040-2041/2073-2074` — 2 `contact as? TelegramUser` casts
6. `ChatControllerOpenAttachmentMenu.swift:556-1787` — 4 `contact as? TelegramUser` casts
7. `SharedAccountContext.swift:3295-3302` — `case let .peer(peer, _, _)` + 2 `EnginePeer(peer)` inflow wraps

**Six build iterations to converge** vs wave 35's single first-pass-clean. Iterations 1-6 surfaced errors in batches of 2-8 errors; each was a mechanical fix (drop wrap, rewrite cast, add `._asPeer()` bridge for outflow to out-of-scope `peerTokenTitle`). Final iteration (#6) clean.

**Lessons:**

- **Pre-flight grep must use `\(\w+, _, _\)` not `\(peer, _, _\)` for enum-payload destructures.** Swift destructure patterns bind the payload to any legal identifier; the variable name is not semantic. Future Peer-typed-enum-payload waves should use `case let \.<caseName>\((\w+),` (or similar wildcard binding) and then per-destructure scan the next ~15 lines for `<binding> as\?`/`<binding> is`/`EnginePeer\(<binding>\)` / outflow-arg patterns.

- **"No-edit consumer" claims need stricter verification.** Wave 36's "verify-only" list included ChatSendAudioMessageContextPreview because the initial inventory found only `[ContactListPeer]` at collection level. The deeper scan missed a `case let .peer(contact, _, _)` + `contact as? TelegramUser` pattern inside the file's `update(...)` method. For future waves, "no-edit" claims should run the wildcard-binding destructure grep described above, not just a construction-site grep.

- **Outflow-to-out-of-scope-API bridges may need addition during the wave.** ContactMultiselectionController:386/403 needed `._asPeer()` bridges added where none existed pre-migration — the pre-migration code passed raw `Peer` to `peerTokenTitle(peer: Peer)` because the destructured peer was raw Peer. Post-migration, the destructured peer is EnginePeer, so a bridge is required. Future waves with same-scope outflow to not-yet-migrated Peer-typed APIs should pre-flight expect to add bridges.

- **Cascading computed-property return type migration** (here: `ContactListPeer.indexName` from `PeerIndexNameRepresentation` to `EnginePeer.IndexName`) is a legitimate scope expansion when the enum's properties leak Postbox-typed values. Wave 36 caught this during plan-writing, not execution — a successful plan-review win. Future waves should grep the enum's definition file for computed properties returning Postbox-defined types.

- **Build-iteration convergence is acceptable** when the wave's surface is large and pre-flight undercount is non-trivial. The cost of 6 build iterations (~5-20 minutes each in the Telegram-iOS build) is real but manageable. The alternative — exhaustive pre-flight to achieve first-pass-clean — is more expensive in plan-writing tokens and controller wall time. For waves expected to have >5 file touches, plan should explicitly budget for 3-5 build iterations.

- **Ratchet effect confirmed.** Wave 36 was predominantly bridge-removal (20 outflow + 20 inflow + 2 IndexName) with only 2 bridge additions. Matches the expected ratchet behavior: earlier waves 33/34/35 added bridges at Peer/EnginePeer boundaries precisely so wave 36 could drop them atomically. The 2 new bridges added (ContactMultiselectionController:386/403 → peerTokenTitle) become next-wave drop candidates once `peerTokenTitle(peer: Peer)` migrates.

**Plan / record:** `docs/superpowers/plans/2026-04-24-contactlistpeer-engine-peer-migration.md`. Spec: `docs/superpowers/specs/2026-04-24-contactlistpeer-engine-peer-migration-design.md`.

---

## Wave 37 outcome (2026-04-24)

`peerTokenTitle(peer: Peer → EnginePeer)`. Private free function in `submodules/TelegramUI/Sources/ContactMultiselectionController.swift`. Atomic single-file commit `734ab44dd2`. 7 insertions / 7 deletions.

**Migration shape.** Ring-2 cleanup of bridges wave 36 installed. The function body was already round-tripping: callers unwrapped `EnginePeer → Peer` with `._asPeer()` only for the body to re-wrap with `EnginePeer(peer).displayTitle(...)`. Flipping the parameter to `EnginePeer` drops both the 5 call-site bridges and the 1 body-side wrap. Zero semantic change — verified by code-quality reviewer: `displayTitle(strings:displayOrder:)` is defined only on `EnginePeer` (LocalizedPeerData/PeerTitle.swift:29), and `EnginePeer.Id` is a typealias for `PeerId` so `peer.id.isReplies` and `peer.id == accountPeerId` resolve identically.

**Final scope:**
- 1 signature change (L21): `peer: Peer` → `peer: EnginePeer`
- 1 body simplification (L27): `EnginePeer(peer).displayTitle(...)` → `peer.displayTitle(...)`
- 5 `._asPeer()` bridge-drops at call sites (L171, L201, L386, L403, L748)

**Pre-flight inventory was exact.** Zero undercount: the pre-flight grep enumerated exactly 6 call-site matches (1 definition + 5 bridges), and the implementer's 3 Edit operations (one unique + two `replace_all=true`) hit all 5 bridge sites on first pass. No scope creep, no out-of-scope edits.

**First-pass-clean build.** 946 total actions, 259.250s elapsed, `INFO: Build completed successfully`, 0 errors. As a reset wave after wave 36's 6-iteration convergence, this was the expected outcome for a single-file mechanical change targeting a private function.

**Subagent-driven execution.** First wave executed via `superpowers:subagent-driven-development` with a consolidated implementer dispatch (Tasks 1–3 bundled since all three were grep + mechanical Edit on one file). Two-stage review (spec + code quality) passed cleanly. Controller directly handled build, commit, and log/memory updates.

**Lessons:**

- **Bundling mechanical plan-tasks is valid for same-file micro-waves.** When a plan's tasks are all Edit operations on a single file with no inter-task branches, consolidating into one implementer dispatch preserves the review structure (spec + quality still gated) while avoiding per-task subagent overhead. For larger waves with multi-file surface or branching logic, keep per-task dispatch.

- **Private-function ring-2 cleanups are first-pass-clean candidates.** The ratchet behavior observed in waves 33–36 — prior waves add bridges at next-ring boundaries — creates trivially-closable cleanup waves whenever the next-ring callee is itself a private or small-surface function. Wave 37's target (private free function, 5 bridge sites, all in-file) hit the ceiling of what this shape can yield.

- **Post-wave 36 bridge inventory reduced by 5.** ContactMultiselectionController:171/201/386/403/748 are now Peer-free at the `peerTokenTitle` arg; the file still retains `import Postbox` for other APIs (L459's `SelectedPeer.peer(peer: Peer, ...)` feed), so file-level Postbox-free remains a later-wave target.

**Plan / record:** `docs/superpowers/plans/2026-04-24-peertokentitle-engine-peer-migration.md`. Spec: `docs/superpowers/specs/2026-04-24-peertokentitle-engine-peer-migration-design.md`.

---

## Wave 38 outcome (2026-04-24)

`canSendMessagesToPeer(_ peer: Peer → EnginePeer, ignoreDefault:)`. Public utility function in `submodules/TelegramCore/Sources/Utils/CanSendMessagesToPeer.swift`. Atomic multi-file commit `45729bad1c`. 12 files changed, 25 insertions / 24 deletions.

**Migration shape.** Mixed-direction ring-2 cleanup: 18 Shape-A bridge drops (`._asPeer()` at call sites where caller already holds `EnginePeer`) plus 5 Shape-C bridge adds (`EnginePeer(peer)` wraps where caller holds raw Postbox `Peer`). Function body preserved by inserting a single `let peer = peer._asPeer()` shadow as the first body line — the four `peer as? TelegramUser/TelegramGroup/TelegramSecretChat/TelegramChannel` branches remain unchanged and the file still `import Postbox`.

**Final scope:**
- 1 signature change (CanSendMessagesToPeer.swift:9): `peer: Peer` → `peer: EnginePeer`
- 1 body insertion (CanSendMessagesToPeer.swift:10): `let peer = peer._asPeer()`
- 18 Shape-A drops across 7 files: ContactsSearchContainerNode (3), ChatImageGalleryItem (1), UniversalVideoGalleryItem (1), StoryItemSetContainerViewSendMessage (1), ShareSearchContainerNode (3), ChatListSearchListPaneNode (6), ChatListNode (3)
- 5 Shape-C adds across 5 files: LegacyAttachmentMenu, ChatInterfaceInputContexts, ShareSearchContainerNode, ShareController, ChatPresentationInterfaceState
- ShareSearchContainerNode has mixed shape (3 drops + 1 add)

**Pre-flight inventory was exact.** 24 total grep matches = 1 definition + 23 call sites; 18 Shape-A + 5 Shape-C. Post-migration grep: 0 `_asPeer()` residue, 5 `EnginePeer(` wraps, 24 total matches. No scope creep. No WIP-drift adjustments needed.

**First-pass-clean build.** 568 total actions, 233.471s elapsed, `INFO: Build completed successfully`, 0 compilation errors. This contradicts the memory's pre-wave prediction of 3–5 build iterations per wave-36 lesson — the lesson remains valid for waves with cascading type-inference surfaces, but wave 38's surface (a utility function called only at points that already bridge `EnginePeer ↔ Peer` in both directions) had no such cascades. The Shape-A/C classification captured the full surface before code changes began.

**Subagent-driven execution.** Executed via `superpowers:subagent-driven-development`. Implementer dispatch bundled plan Tasks 1–5 (grep + all 24 edits + post-edit grep) since all were mechanical and on known files. Two-stage review (spec + code quality) passed without review-loop iterations. Controller handled build, commit, and log/memory updates.

**Lessons:**

- **Bundled multi-file dispatch is valid when pre-flight classification is exact.** Wave 36's per-task-dispatch rule (from CLAUDE.md) was formulated for waves with expected 3–5 build iterations driven by type-inference cascades. Wave 38 demonstrates that a multi-file wave with an exact upfront Shape-A/C classification and a cascading-free surface (all call sites are leaf arguments to a `Bool`-returning utility) can use the bundled dispatch shape safely. Gate: (a) all edits are mechanical Edit operations; (b) pre-flight grep enumerates every call-site explicitly; (c) return type of the migrated API does not propagate into caller type inference. When these hold, bundled dispatch saves subagent overhead without sacrificing review coverage.

- **First-pass-clean multi-file waves exist.** The memory's pre-wave prediction of "not first-pass-clean territory" was conservative and came from wave 36's 6-iteration experience. Wave 38's 12-file mechanical migration built clean on first attempt because the spec's explicit Shape-A/C classification enumerated all 23 sites, and the function's `Bool` return prevents caller-side type-inference cascades. Future multi-file waves should update expectations when (a) the classification is exact and (b) the return type does not propagate.

- **Shape-C wraps remain valid additions.** Five sites had to add `EnginePeer(peer)` at the call because the enclosing scope still holds raw Postbox `Peer` (from `RenderedPeer.peers` lookups, `ChatPresentationInterfaceState.renderedPeer.peer`, or `as? TelegramChannel` casts). These adds are acceptable — the alternative is a per-scope refactor (RenderedPeer → EngineRenderedPeer cascades) that would expand blast radius. Future waves targeting `RenderedPeer` would drop these 5 wraps.

**Plan / record:** `docs/superpowers/plans/2026-04-24-cansendmessagestopeer-engine-peer-migration.md`. Spec: `docs/superpowers/specs/2026-04-24-cansendmessagestopeer-engine-peer-migration-design.md`.

---

## Wave 39 outcome (2026-04-24)

`AccountContext.makePeerInfoController(... peer: Peer → EnginePeer ...)`. Public protocol method on `AccountContext` (`submodules/AccountContext/Sources/AccountContext.swift:1371`) and its `SharedAccountContextImpl` implementation (`submodules/TelegramUI/Sources/SharedAccountContext.swift:1937`). Atomic multi-file commit `5385abc9bd`. **52 files changed**, 80 insertions / 79 deletions.

**Migration shape.** Body-shadow ring-2 cleanup at the largest scale yet attempted. The protocol + impl signatures change to `peer: EnginePeer`; the impl body adds `let peer = peer._asPeer()` as its first statement, preserving the private downstream `peerInfoControllerImpl(peer: Peer, ...)` and all of its Peer-typed helpers as out-of-scope. Mixed-direction at consumer sites: 58 Shape-A drops + 3 Shape-A-variant guard-statement drops + 12 Shape-C `EnginePeer(...)` wraps. Net **-49 bridges**.

**Final scope:**
- 1 protocol-signature change (AccountContext.swift:1371)
- 1 impl-signature change + 1 body-shadow insertion (SharedAccountContext.swift:1937–1938)
- 3 Shape-A self-call drops in same file (SharedAccountContext.swift:3335, 3483, 4016)
- 3 Shape-A-variant guard-statement drops (SettingsSearchableItems.swift around 1020/1046/1080): `guard let peer = peer?._asPeer() else { return }` → `guard let peer = peer else { return }`. The call-site `peer:` argument line is unchanged; the upstream guard now binds `peer` as `EnginePeer` (the closure parameter from `engine.data.get(...)`) rather than re-shadowing as raw `Peer`.
- 12 Shape-C `EnginePeer(...)` wraps across 8 files: BlockedPeersController:270, ChannelMembersController:707, ChannelBlacklistController:381, ChatRecentActionsControllerNode:1011, PeerInfoScreen:4306, ChatControllerNavigationButtonAction (4 sites: 441/461/471/492), ChatControllerOpenPeer (2 sites: 218/359), ChatControllerLoadDisplayNode:4362
- 55 additional Shape-A drops across 42 consumer files
- 4 incidental trailing-whitespace strips picked up by Edit tool (functionally identical)

**Pre-flight inventory was exact.** Total grep matches at planning time: 75 (1 protocol decl + 1 impl + 73 consumer call sites) of which 58 had inline `peer: <expr>._asPeer()` (Shape-A), 3 had upstream-guard `peer?._asPeer()` patterns (Shape-A-variant), and 12 had raw `peer: <expr>` (Shape-C). Post-migration grep for `_asPeer()` at `makePeerInfoController` call sites: 0. Post-migration grep for `EnginePeer(` at the 12 Shape-C sites: all present. No scope creep, no Postbox/TelegramCore/TelegramApi edits. The implementer noted that `BlockedPeersController.swift:270` already had `peer: peer` (no `_asPeer()`) — this was correctly classified Shape-C in the spec, and the wrap was applied as planned.

**Property-typing pre-verification matters.** Spec phase identified that `RenderedPeer.peer`/`chatMainPeer` (Postbox extension at PeerUtils.swift:512 and Postbox/RenderedPeer.swift:38) return raw `Peer?`, while `EngineRenderedPeer.peer`/`chatMainPeer` (TelegramCore/Peers/Peer.swift:623/627) return `EnginePeer?`. Six Shape-C sites depend on `RenderedPeer` (Postbox), so `EnginePeer(...)` wraps were correct. Sites that consume `EngineRenderedPeer` would need `peer: peer` only — not a concern here, but a checklist item for next-wave Shape-C planning.

**First-pass-clean build.** 658 total actions, 210.520s elapsed, 1565 cache hits + 142 disk-cache + 444 worker, `INFO: Build completed successfully`, 0 errors. Strongest confirmation yet of the wave-38 lesson: **first-pass-clean is achievable for 50+ file waves when (a) the migrated API's return type is non-propagating** (`ViewController?` is an optional reference type, like wave-38's `Bool` — caller-side type inference does not branch on it), **(b) pre-flight Shape-A/A-variant/C classification is exact, and (c) the body-shadow boundary is preserved.** Pre-wave estimate budgeted 2–4 iterations on the assumption that a 50-file change at a popular API surface would surface destructure cascades; the actual outcome exceeded expectations.

**Subagent-driven execution.** Executed via `superpowers:subagent-driven-development`. Implementer dispatch bundled plan Tasks 1–5 (signature + body-shadow + 3 self-call drops + 3 guard rewrites + 12 wraps + 55 Shape-A drops, 70+ Edit operations across 52 files). Two-stage review (spec + code quality) passed without re-review iterations. Spec reviewer verified all 73 sites, the body-shadow placement at line 1938, the guard-statement form change in SettingsSearchableItems, and the unchanged-out-of-scope confirmation for `peerInfoControllerImpl` at line 4434. Code quality reviewer noted only the 4 incidental trailing-whitespace strips as "minor — leave as-is, tiny improvement". Controller handled build, commit, and log/memory updates.

**Lessons:**

- **Shape-A-variant: drop the upstream `_asPeer()` rather than wrapping at the call site.** When a guard-statement immediately upstream of a `makePeerInfoController` call unwraps `EnginePeer? → Peer?` via `peer?._asPeer()`, prefer rewriting the guard to `guard let peer = peer else` (keeping the local as `EnginePeer`) over adding `EnginePeer(peer)` at the call. The variant: zero net change at the call line, -1 `_asPeer()` upstream. This pattern occurs whenever a closure parameter from `engine.data.get(...)` is opt-unwrapped immediately before a Peer-typed-API call.

- **First-pass-clean ceiling is higher than wave-36 implied.** Wave 36's 6-iteration convergence (15 files, ContactListPeer.peer enum-payload migration) led to a memory rule "multi-file = budget 3–5 iterations". Wave 38 first-pass-clean (12 files, Bool return) suggested the rule doesn't apply universally. Wave 39 first-pass-clean (52 files, ViewController? return) extends this: even at 50+ files, the determinant is return-type propagation behavior + pre-flight classification accuracy, not file count. Updated heuristic: **budget for first-pass-clean when** (return-type is non-propagating) AND (Shape classification is exact); **budget for 3–5 iterations when** (return type is a generic container, struct with associated types, or enum that participates in caller-side inference).

- **Bundled implementer dispatch scales to 70+ edits across 52 files.** The wave-38 lesson ("bundled multi-file dispatch is valid when pre-flight classification is exact") held at this scale. Two-stage review (spec then code-quality) over the aggregate output preserved review coverage. No per-task subagent dispatches were needed.

- **Atomic-stage exclusion of pre-existing WIP is necessary at large diff sizes.** Wave 39's working tree contained an unrelated WIP file (`ChatMessageTransitionNode.swift` — function-signature/animation changes on `beginAnimation`) that was modified outside the session. The commit phase explicitly enumerated all 52 wave-39 files in the `git add` invocation rather than using `git add -u` or `git add .`. This is a permanent rule for this project: never use bulk-stage commands; always enumerate files when committing a wave.

- **Ratchet expansion: 12 new Shape-C wraps for future waves.** The 12 `EnginePeer(...)` wraps installed at this wave become drop candidates for later waves migrating their upstream sources: `RenderedPeer → EngineRenderedPeer` (would drop 6 wraps at sites consuming `renderedPeer.peer`/`chatMainPeer`), `RenderedChannelParticipant.peer → EnginePeer` (would drop 2 at ChannelMembers/ChannelBlacklist), and others. Net economics still strongly favor the wave: -61 + 12 = -49 bridges.

**Plan / record:** `docs/superpowers/plans/2026-04-24-makePeerInfoController-engine-peer-migration.md`. Spec: `docs/superpowers/specs/2026-04-24-makePeerInfoController-engine-peer-migration-design.md`.

---

## Wave 40 outcome (2026-04-24)

Commit: `d3c48379fe`. Bundle of `AccountContext.makeChatQrCodeScreen` + `makeChatRecentActionsController` peer `Peer → EnginePeer` — the trivial sibling follow-up to wave 39, completing the "Option 1 cluster" (`makePeerInfoController` family) from the wave-38 memory. 8 Swift files + plan doc / 11 edits. Pre-flight classification was already done in the wave-39 design doc's "Out of scope" section — no fresh pre-flight needed.

**Classification:**
- 2 protocol decls (`AccountContext.swift:1401`, `:1461`)
- 2 impl decls + body-shadows (`SharedAccountContext.swift:2302`, `:2731`)
- 2 Shape-A-variant guard rewrites (`SettingsSearchableItems.swift:971`, `:989` — `guard let peer = peer?._asPeer()` → `guard let peer = peer`, keeping the local as `EnginePeer`)
- 3 Shape-A drops (`ContactsController.swift:478`, `ChannelAdminsController.swift:734`, `GroupStatsController.swift:915`)
- 2 Shape-C wraps (`PeerInfoScreen.swift:4623`, `PeerInfoScreenOpenChat.swift:115`) — both consume `data.peer: Peer?` from `PeerInfoScreenData`, so they're ratchet markers for a future `PeerInfoScreenData.peer Peer → EnginePeer` wave.

Net −3 bridges (−5 `_asPeer()` drops, +2 `EnginePeer(...)` wraps).

**Build outcome:** First-pass-clean for wave-40 files. The initial run failed due to pre-existing unrelated WIP in `ChatMessageTransitionNode.swift` (unterminated string literals in debug `print` statements the user was mid-editing); the wave-40 files produced zero diagnostics. After the user fixed the WIP, the subsequent build completed in 23.9s (mostly cache-warm) with zero errors.

**Lessons:**

- **Bundled sibling migration with shared pre-flight is cheap.** Wave 39's "Out of scope" section pre-classified all 7 of this wave's consumer sites. That planning overhead was already paid; wave 40 only needed to verify classifications still hold (one grep per site-group) and apply mechanical edits. Total time from plan-write to commit: ~30 minutes (dominated by the ~3-minute build). This validates a general pattern: when a wave defers siblings with an explicit "Out of scope" classification section, the follow-up wave is structurally trivial.

- **Small-scale bundled implementer dispatch is still the right choice.** 11 edits across 8 files fits comfortably in one implementer call, matching the wave-38/39 lesson at smaller scale. No per-task dispatches were needed; two-stage review (spec then code-quality) took one round each.

- **Pre-existing WIP in the working tree can cause module-scope build failures that mask the wave's own status.** When `ChatMessageTransitionNode.swift` had parse errors from an unrelated user WIP, the whole `TelegramUI` Swift module failed to parse before type-checking ran — so wave-40 files got syntax-verified but not type-verified. Diagnostic approach: grep the build output for error lines whose file path is NOT in the wave's file list; if the only errors are outside, the wave is likely clean, but complete type verification requires the unrelated WIP to be reverted or fixed. In this case the user fixed it; in future cases either ask the user, temporarily stash the WIP, or note the incomplete verification in the commit.

**Plan / record:** `docs/superpowers/plans/2026-04-24-makeChatQrCodeScreen-recentActions-engine-peer-migration.md`. No separate spec — the pre-flight was reused from wave 39's spec ("Out of scope" section in `docs/superpowers/specs/2026-04-24-makePeerInfoController-engine-peer-migration-design.md`).

---

## Wave 41 outcome (2026-04-24)

Commit: `32573c9808`. `RenderedChannelParticipant.peer: Peer → EnginePeer` — a TelegramCore foundational-type field migration affecting 28 files (11 TelegramCore + 17 consumer) / 1124 insertions / 89 deletions. First foundational-type field migration since `FoundPeer.peer` / `SendAsPeer.peer` / `ContactListPeer.peer` (waves 34–36); differs in that `RenderedChannelParticipant` is a public TelegramCore struct with both TelegramCore-internal construction sites and a broad consumer surface, so the wave touched TelegramCore internals too, not just consumer modules.

**Classification:**
- 1 struct field change (`ChannelParticipants.swift`): `peer: Peer → peer: EnginePeer` + init param + Equatable `lhs.peer.isEqual(rhs.peer) → lhs.peer == rhs.peer`
- 16 TelegramCore-internal constructor sites wrapped with `EnginePeer(peer)` across 9 files (RequestStartBot, AddPeerMember, ChannelAdminEventLogs [7 calls], ChannelBlacklist, ChannelMembers, ChannelOwnershipTransfer [2 calls], JoinChannel, PeerAdmins, Ranks)
- 1 TelegramCore-internal ADD-ASPEER (`SearchGroupMembers.swift:83` — pre-flight miss: `participants.map({ $0.peer })` consumed by outer `[Peer]`-returning closure)
- ~32 consumer DROP sites (removing `EnginePeer(participant.peer)` wraps or `._asPeer()` downgrades)
- 9 consumer CAST sites (`if let user = participant.peer as? TelegramUser, user.botInfo != nil` → `if case let .user(user) = participant.peer, user.botInfo != nil`)
- 3 consumer ADD-ASPEER (PeerInfoMembers:33 contains the `PeerInfoMember.peer: Peer` accessor ratchet; ChatRecentActionsHistoryTransition:675 + :2275 for `SimpleDictionary<PeerId, Peer>` subscript assignment)
- 7 consumer ADD-WRAP constructor sites (ChannelMembersSearchContainerNode + ChannelMembersSearchControllerNode legacy-group paths, ChatControllerAdminBanUsers:226) — ratchet markers for a future wave migrating `peerView.peers[id]` / `authors: [Peer]` upstream flows to EnginePeer
- 2 consumer `is TelegramChannel` → `if case .channel = participant.peer` rewrites (ChannelBlacklistController:370, :377)

Net ~−13 bridges. Drops the 2 Shape-C wraps installed by wave 39 (ChannelMembersController:707, ChannelBlacklistController:381) as promised by the wave-39 ratchet plan.

**Build outcome:** Three iterations.
1. First build surfaced `SearchGroupMembers.swift:83` — a TelegramCore-internal consumer of `$0.peer` on RCP that the plan's grep missed (grep only looked for `RenderedChannelParticipant(` constructors inside TelegramCore).
2. Second build surfaced `ShareWithPeersScreen.swift:777, 780` — an entire file missed in pre-flight because the initial grep was scoped to files already known to import RCP; this file gets RCP indirectly via `TemporaryCachedPeerDataManager.recent(...)`'s `updated:` callback.
3. Third build: clean (172 total actions).

**Lessons:**

- **Property-access migration has a broader grep surface than constructor migration.** Waves 34–36 migrated foundational types by grepping `<Type>(` constructors. That works because the consumer's use of the type is always preceded by a construction. Wave 41's RCP differs: RCP is constructed inside TelegramCore and handed to consumers as an opaque reference, so consumer usage looks like `participant.peer.X` (with any name, any subscript, any map closure). **Grep for the type's field-access patterns across the entire repo**, not just files that explicitly reference the type. For RCP specifically: `grep -rn 'RenderedChannelParticipant\|\.peer as?\|EnginePeer(.*\.peer)\|participant\.peer' submodules/` would have caught ShareWithPeersScreen.swift. File this as a **permanent pre-flight rule** for future property-access migrations.

- **TelegramCore-internal consumer sites need the same inventory discipline as consumer-module sites.** The wave-41 plan enumerated 10 TelegramCore files for *construction* site updates but didn't grep for *consumption* sites — `SearchGroupMembers.swift:83` consumes `$0.peer` on RCP inside TelegramCore. Pre-flight for any foundational-type field migration must grep both construction AND consumption across the whole repo, not stratified by module.

- **"Plan says N sites" numbers can be low; use `replace_all=true` defensively.** The plan listed 1 `EnginePeer(participant.peer)` site in ChannelBlacklistController.swift but the file actually had 5; listed 2 CAST sites in ChannelMembersSearchControllerNode.swift but the file had 4. The implementer correctly used `replace_all=true` on the unique-pattern greps, catching all sites. **Pre-flight should report "N site(s) per file at these lines" — if confidence is low, recommend replace_all directly.**

- **Spec review caught `is TelegramChannel` that grep did not.** `participant.peer is TelegramChannel` does not match any of the usual migration-pattern greps (`EnginePeer(...)`, `as? TelegramUser`, `._asPeer()`). The spec reviewer caught it by reading the code. Would have been a build error anyway — the project compiles with `-warnings-as-errors` across 658/665 modules, so Swift's "'is' test always fails" warning promotes to an error — but catching it at spec time saves one build iteration. **Add `is Telegram(Channel|User|Group|SecretChat)` to the pre-flight token set** for any Peer → EnginePeer field migration so it's flagged at plan time rather than iteration time.

- **First-pass-clean is NOT the right bar for foundational-type field migration.** Waves 37–40 achieved first-pass-clean. Wave 41 needed 3 iterations — and none of the three errors were the implementer's fault; all three were pre-flight misses. Heuristic update: **foundational-type field migrations (where the field is accessed via a generic property name like `.peer`) should budget 2–4 build iterations**, not first-pass-clean. The broader the grep surface, the more misses slip through.

- **Ratchet economics of ADD-WRAP consumer constructors.** Wave 41 added 7 consumer `peer: EnginePeer(peer)` wraps at `RenderedChannelParticipant(...)` constructor sites in ChannelMembersSearch*Node and ChatControllerAdminBanUsers, where the local is still raw `Peer` from a legacy path (`peerView.peers[id]` / `authors: [Peer]`). These are ratchet markers: when the upstream legacy path migrates to EnginePeer, these wraps drop. The economics are net positive (−13 bridges) even counting the adds.

**Plan:** `docs/superpowers/plans/2026-04-24-renderedchannelparticipant-peer-engine-peer-migration.md`.
**Spec:** `docs/superpowers/specs/2026-04-24-renderedchannelparticipant-peer-engine-peer-migration-design.md`.

---

## Wave 42 outcome (2026-04-24)

`PeerInfoScreenData.peer: Peer? → EnginePeer?` — a single-module (18-file) struct-field migration entirely contained within `submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/`. `PeerInfoScreenData` is a consumer-module data class, not a public TelegramCore type, so the wave never touched TelegramCore — contrast wave 41 which had to update TelegramCore construction sites.

**Classification:**
- 1 struct-field change + 1 init-param change in PeerInfoData.swift
- 4 construction-site edits adding `.flatMap(EnginePeer.init)` wraps at `peer:` arguments built from `peerView.peers[...]` (PeerInfoData.swift L1027, L1620, L1867, L2205); 1 construction site unchanged (L1100, `peer: nil`)
- ~25 consumer DROP sites (removing `EnginePeer(peer)` wraps where the local `peer` was bound from `data.peer` / `self.data?.peer`)
- ~25 consumer CAST sites (`if let user = data.peer as? TelegramUser, ...` → `if case let .user(user) = data.peer, ...`)
- ~5 consumer `is TelegramXxx` rewrites on data.peer-derived locals (PeerInfoScreen.swift L3981, L4133, L4192, L4194)
- ~10 consumer ADD-WRAP `?._asPeer()` helper bridges for internal helpers that stay `peer: Peer?` (PeerInfoScreenPerformButtonAction:62 calling `peerInfoIsChatMuted`; PeerInfoScreen:5399/5805 calling `self.headerNode.update(peer:...)`; PeerInfoScreen:5857 calling `peerInfoCanEdit`; etc.) plus one inline `_asPeer()` bridge inside `peerInfoIsCopyProtected` because `isCopyProtectionEnabled` is not exposed on `EnginePeer`

Net ~−30 bridges. Drops the ~5 wave-40 `EnginePeer(peer)` wraps that were directly in scope (the plan initially overestimated which sites would drop — some `EnginePeer(peer)` calls in PeerInfoScreen.swift are inside closures whose `peer` parameter comes from a caller, not from `data.peer`, and those correctly survived).

**Build outcome:** Two iterations.
1. First build surfaced `peerInfoIsCopyProtected` helper: `peer.isCopyProtectionEnabled` failed against `EnginePeer` because that property is `Peer`-protocol-only and is not forwarded by `EnginePeer`. Fix: inline `peer._asPeer().isCopyProtectionEnabled` bridge at the helper callsite (helper signature stays `Peer?`).
2. Second build: clean.

**Lessons:**

- **EnginePeer is not a strict superset of Peer's property surface.** `EnginePeer` forwards `id`, `displayTitle(...)`, `compactDisplayTitle`, `isPremium`, `smallProfileImage`, `largeProfileImage`, and other common properties, but Peer-only properties like `isCopyProtectionEnabled` are NOT forwarded. Migration-time surprise: a property access that worked on raw `Peer` can fail against `EnginePeer`. **Bridge pattern:** inline `peer._asPeer().isCopyProtectionEnabled` at the callsite, OR if the helper already takes `Peer?`, bridge upstream with `?._asPeer()` and keep the access unchanged. Pre-flight addition: grep migrated consumer surfaces for `.X` accesses where `X` is a Peer-protocol property not in EnginePeer's forwarding set. (Alternative: extend `EnginePeer` with more forwarders, but that's a larger TelegramCore change out of scope for a single wave.)

- **Wave-42 was not first-pass-clean despite being a consumer-module wave.** Contrast wave 41: 3 iterations due to broader grep-surface misses. Wave 42: 2 iterations due to a single property-forwarding-gap miss. Heuristic update: **even consumer-module property-access migrations budget 2 iterations**, because Peer/EnginePeer interface parity is never verified end-to-end at pre-flight time.

- **Plan-stated wrap-drop counts can be wrong in both directions.** The plan listed 15+ `EnginePeer(peer)` drop sites in PeerInfoScreen.swift citing specific lines (1331, 1339, 1346, 1561, 2353, ...) — but on inspection, lines 1331/1339/1346 are inside a `peer`-parameter closure (`openPeerContextAction = { ..., peer, ... in ... }`) where `peer` comes from the closure's caller, not from `data.peer`. Those wraps correctly stayed. The implementer correctly judged each binding context before deciding whether to drop. **Rule for plan writing:** when naming specific line numbers as drop-candidates, verify the `if let peer = ...` / closure-param binding in the actual file text, not just the `EnginePeer(peer)` grep result.

- **Wave-41 lesson reconfirmed (`is Telegram*` rewrite):** all 5 `is TelegramChannel|User|Group|SecretChat` checks on `data.peer`-derived locals were caught at plan time (via the pre-flight grep token set including `is Telegram...`), not at build time. `-warnings-as-errors` would have caught them at build time but pre-flight catches save an iteration.

- **Internal-helper bridge economics.** The PeerInfoScreen module has ~6 internal helpers (`canEditPeerInfo`, `peerInfoIsChatMuted`, `peerInfoHeaderButtons`, `peerInfoHeaderActionButtons`, `peerInfoCanEdit`, `availableActionsForMemberOfPeer`, `peerInfoIsCopyProtected`) that still take `peer: Peer?`. Wave 42 added ~10 `?._asPeer()` bridges at their callsites. A follow-up wave migrating those helper signatures would drop exactly those 10 bridges — small, well-scoped, strong candidate for wave 42.x.

**Plan:** `docs/superpowers/plans/2026-04-24-peerinfoscreendata-peer-engine-peer-migration.md`.

---

## Wave 43 outcome (2026-04-24)

Migrated six PeerInfoScreen module helpers — `canEditPeerInfo`, `availableActionsForMemberOfPeer`, `peerInfoHeaderActionButtons`, `peerInfoHeaderButtons`, `peerInfoCanEdit`, `peerInfoIsChatMuted` (plus nested `isPeerMuted`) — from `peer: Peer?` to `peer: EnginePeer?`. All internal `as? TelegramUser|Channel|Group` and `is TelegramX` patterns inside the helper bodies (PeerInfoData.swift lines 2265–2670) rewritten to `case let .user/.channel/.legacyGroup` / `case .x = peer` enum patterns. No TelegramCore changes. No new typealiases.

**Classification:**
- 6 helper signature migrations + 12 `as?` / `is` body rewrites in PeerInfoData.swift
- 7 DROPs of `._asPeer()` / `?._asPeer()` bridges installed by wave 42 (sites in PeerInfoScreenAvatarSetup, PeerInfoScreenPerformButtonAction ×3, PeerInfoScreenOpenMember, PeerInfoScreen:5857, PeerInfoProfileItems)
- 2 CONVERTs at PeerInfoScreen.swift:1905/1961 (`peer: group` / `peer: channel` extracted from `case let` → `peer: data.peer`, preserving the `group`/`channel` binding for body use)
- 10 ADD-WRAPs at call sites inside enclosing methods that still take raw `Peer?` (PeerInfoHeaderNode ×3, PeerInfoHeaderEditingContentNode ×5, PeerInfoEditingAvatarNode, PeerInfoEditingAvatarOverlayNode) — `.flatMap(EnginePeer.init)` for optional Peer, `EnginePeer(peer)` for non-optional (post-`guard let peer = peer`) Peer
- 2 ADD-WRAPs at raw-`Peer` member-item sites (PeerInfoScreenMemberItem, PeerInfoMembersPane)

Net ~+5 wraps overall (7 drops, 12 adds) — less important than the headline: the helper signatures now live on the engine side. The 12 ADDs are all staged for drop in follow-up waves that migrate the four `update(peer: Peer?, ...)` methods (PeerInfoHeaderNode, PeerInfoHeaderEditingContentNode, PeerInfoEditingAvatarNode, PeerInfoEditingAvatarOverlayNode) and the two raw-`Peer` enclosingPeer storage fields (PeerInfoScreenMemberItem.enclosingPeer is actually `Peer?`, PeerInfoMembersPane's local `enclosingPeer: Peer`).

**Build outcome:** 2 iterations.
1. First build surfaced one error: `PeerInfoScreenMemberItem.item.enclosingPeer` was declared `let enclosingPeer: Peer?` (optional) — the plan had prescribed `EnginePeer(item.enclosingPeer)` (non-optional form). Fix: `.flatMap(EnginePeer.init)` at the callsite. One-line correction.
2. Second build: clean.

**Commit:** `d53e0d50f4c0e3e68c4e4c1ce255e76f43f56d4b` (12 files + plan).

**Lessons:**

- **Plan-declared property optionality can be wrong — verify `let X: T?` vs `let X: T` at plan-write time.** Wave 43's plan described `item.enclosingPeer` as non-optional `Peer` based on how it was used (`item.enclosingPeer as? TelegramChannel`, `item.enclosingPeer is TelegramChannel` compile against `Peer` non-optional OR optional protocol). The declaration was actually `Peer?`. The one-site plan-declaration mismatch cost one build iteration. **Rule for plan writing:** for every ADD-WRAP site, cite the declaration line, not just the usage. `grep -nE "(let|var)\s+\w+:\s*Peer\??" <file>` gives unambiguous optionality.

- **Helper-signature migrations with zero Peer-only property access are first-iteration-clean except for optionality surprises.** Wave 42's lesson (EnginePeer property-forwarding gap) did not recur here because wave 43's helpers only did `as?` / `is` casts — pure enum-rewrite territory. Pre-flight verified each helper body used only `.id` and concrete-type accesses (`TelegramChannel.hasPermission(...)` etc., which stay on concrete types post-migration). The only iteration cost was the optionality mismatch above. **Heuristic: if a helper's body does not touch the `peer` parameter outside of `as?`/`is`/`.id`/`.id.isX`, budget 1 iteration + optionality-audit pass.**

- **`case .x = peer` without binding is the correct `-warnings-as-errors` form when the branch body doesn't need the concrete value.** Wave 43's `peerInfoIsChatMuted` body at lines 2641/2643 uses `case .user = peer` and `case .legacyGroup = peer` (no inner binding) — because the branches only read `globalNotificationSettings.privateChats.enabled` / `.groupChats.enabled`, never the concrete `TelegramUser` / `TelegramGroup`. Had the migration emitted `case let .user(_) = peer` with `_`, or `case let .user(user) = peer` with `user` unused, `-warnings-as-errors` would fail. **Pre-flight rule: for each `peer is TelegramX` → `case .x = peer` rewrite, check whether the branch body accesses the concrete type. If not, use bare-case form; if yes, bind.**

- **Bundled-dispatch subagent flow + two-stage review works cleanly for ≥10-site single-commit migrations.** Wave 43 dispatched one implementer (bundled Tasks 1–7), then spec reviewer, then code quality reviewer. All three completed in roughly 10 minutes of subagent time. Spec reviewer caught zero misses (implementer self-caught the optionality deviation in iteration 1). Code quality reviewer surfaced only minor observational notes (no Critical / Important issues). **Continues to confirm wave-39/40/41/42 finding: for ≤30-file / ≤50-edit wave shapes, the bundled flow is reliable; TaskCreate tracking adds no value at this size.**

**Plan:** `docs/superpowers/plans/2026-04-24-peerinfoscreen-helpers-engine-peer-migration.md`.

---

## Wave 44 outcome (2026-04-24)

Migrated `RenderedChannelParticipant.peers: [PeerId: Peer]` to `[EnginePeer.Id: EnginePeer]`. Closes the wave-41 ratchet — the public RCP struct no longer leaks raw `Peer` types in any field (the surviving `presences: [PeerId: PeerPresence]` is out of scope; PeerPresence is a Postbox protocol requiring a separate migration). No new typealiases. No engine wrapper structs.

**Classification:**
- 1 declaration: `ChannelParticipants.swift:11/14` field + init default
- 8 TelegramCore producer migrations (`ChannelMembers`, `RequestStartBot`, `ChannelOwnershipTransfer`, `JoinChannel`, `AddPeerMember`, `PeerAdmins`, `ChannelBlacklist`, `Ranks`) — each builds a local `var peers: [EnginePeer.Id: EnginePeer] = [:]` inside a `postbox.transaction` and wraps insertions with `EnginePeer(...)`. All producers pre-existed with the same structural pattern: 14 raw insertions became 14 wrapped insertions.
- 6 consumer DROPs of `EnginePeer(peer).displayTitle(...)` → `peer.displayTitle(...)` in `ChannelAdminsController`, `ChannelMembersSearchContainerNode` (×4), `ChannelBlacklistController`
- 5 consumer DROPs of `.mapValues({ $0._asPeer() })` transforms at RCP constructor call sites in `ChannelAdminsController`, `ChannelMembersSearchContainerNode` (×2), `ChannelMembersSearchControllerNode` (×2)
- 2 consumer ADDs of `._asPeer()` at `ChatRecentActionsHistoryTransition.swift` iteration sites — line 673 (`participant.peers`) and line 2273 (`new.peers` inside `participantSubscriptionExtended`), where the iterated `EnginePeer` is inserted into an outer `SimpleDictionary<PeerId, Peer>`.

Net consumer-surface: **−10 bridges**. TelegramCore-internal: +~12 wraps inside files that already `import Postbox`. No new `import Postbox` in any consumer module; no Postbox-hygiene regression.

**Build outcome:** 2 iterations.
1. First build surfaced one error: `cannot assign value of type 'EnginePeer' to subscript of type '(any Peer)?'` at `ChatRecentActionsHistoryTransition.swift:2273` — a second RCP.peers iteration site the plan's `participant\.peers` pre-flight grep missed because the local RCP binding was named `new` (from `case let .participantSubscriptionExtended(prev, new)`). Wider grep `\b(participant|new|prev|rcp|renderedParticipant)\.peers\b` confirmed only one additional site. Fix: identical `._asPeer()` unwrap as line 673.
2. Second build: clean.

**Commit:** `ca69fa8cbb` (14 files, 38 insertions / 38 deletions).

**Lessons:**

- **Property-access field migrations need a name-agnostic grep surface, not a binding-name-prefixed one.** Wave 41's lesson said "repo-wide grep surface, not a stratified one." Wave 44 extends it: the binding name of the RCP varies by enum-case-destructure site. In `ChatRecentActionsHistoryTransition` specifically, one switch arm destructures the RCP enum case as `case let .participantSubscriptionExtended(prev, new):` — the local is `new`, not `participant`. Pre-flight grep token set for RCP.peers iteration sites should be `\b(participant|new|prev|rcp|renderedParticipant|channelParticipant)\.peers\b`. For the general case: **for any `T.<field>` migration on a type passed opaquely through enum-case-destructures, enumerate the common destructure binding names (`prev`, `new`, `current`, `lhs`, `rhs`, etc.) in the plan's pre-flight grep.**

- **Iteration-site-plus-insertion-into-foreign-container pattern is a canonical ADD-UNWRAP shape.** When a foundational type's dict field is migrated to engine types but a caller iterates the dict and inserts values into an outer container still typed with raw Postbox values (here `SimpleDictionary<PeerId, Peer>`), an `._asPeer()` unwrap is required at the insertion line. This pattern repeated twice in `ChatRecentActionsHistoryTransition` — both iteration sites have the same enclosing structure (build a raw-Peer `SimpleDictionary` → iterate RCP.peers → insert). **Future migrations on dict-like fields: grep for `for (_, X) in <F>.peers { <container>[X.id] = X }` patterns and anticipate the unwrap.**

- **Producer-side migration is low-risk for field-type-parameter changes on local transaction-built dicts.** All 8 TelegramCore producers had the identical structural pattern (`var peers: [PeerId: Peer] = [:]` → insertions → pass to RCP constructor). Mechanical `EnginePeer(...)` wrap at each insertion with no side effects. No chain-migration concerns because every producer builds locally. **Shape heuristic: if producers build their contribution dict locally via `transaction.getPeer` calls, field-type migration is mechanical and fits a bundled-dispatch wave well.**

- **Declaration-level `[PeerId: Peer] = [:]` init default shifts transparently.** The init-default literal `[:]` works as either `[PeerId: Peer]` or `[EnginePeer.Id: EnginePeer]`; 12 RCP construction sites with no `peers:` arg required zero changes. **Shape heuristic: default-valued Postbox-typed parameters are free on migration when the default literal is the empty collection form.**

- **Consumer `.mapValues({ $0._asPeer() })` transforms on engine-typed source dicts become no-op drops on the target field migration.** Wave 44 dropped 5 such transforms cleanly because each source dict was already `[EnginePeer.Id: EnginePeer]` (verified at plan time by reading 20-line spans around each site). **Shape heuristic: when a consumer-side constructor call site uses `peers: X.mapValues({ $0._asPeer() })`, it signals the source is already engine-typed and the target field-type migration would drop the unwrap transform entirely.**

- **Wave-41 lesson reconfirmed: foundational-type field migrations budget 2–3 iterations, not first-pass-clean.** Wave 44 hit 2 iterations because of the enum-destructure-binding-name grep miss; a more exhaustive pre-flight grep would have caught it as a first-pass-clean.

**Plan:** `docs/superpowers/plans/2026-04-24-rcp-peers-engine-migration.md`.

---

## Wave 45 outcome (2026-04-24)

Migrated the four `update(..., peer: Peer?, ...)` methods across the PeerInfoHeader node hierarchy — `PeerInfoHeaderNode.update`, `PeerInfoHeaderEditingContentNode.update`, `PeerInfoEditingAvatarNode.update`, `PeerInfoEditingAvatarOverlayNode.update` — from raw `Peer?` to `EnginePeer?`. Consumer-surface ratchet that drops ~15 wave-43-era ADD-WRAP bridges. Single-module wave (all four files live in `submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/`). No new typealiases. No engine wrapper structs. The stored `PeerInfoHeaderNode.peer: Peer?` field stays raw (intentional scope cap) and is bridged with `peer?._asPeer()` at assignment.

**Classification:**
- 4 signature changes: `peer: Peer?` → `peer: EnginePeer?` at PHN:496, PHECN:52, PEAN:61, PEAON:63.
- 15 DROP wraps across the four files:
  - PHN body: 7 drops at :524 (listContainerNode.peer), :548 (peerInfoHeaderActionButtons), :549 (peerInfoHeaderButtons), :571 (backgroundCoverSubject = .peer), :1218 (displayTitle), :1964 (listContainerNode.update), :2361 (peerInfoIsChatMuted).
  - PHECN body: 5 drops at :59, :88, :93, :159, :162 (all `canEditPeerInfo` wraps).
  - PEAN body: 2 drops at :66 (canEditPeerInfo) and :88 (avatarNode.setPeer).
  - PEAON body: 1 drop at :85 (canEditPeerInfo).
- 5 enum-case rewrites in PHN: `peer as? TelegramChannel` / `peer as? TelegramUser` → `case let .channel(x) = peer` / `case let .user(x) = peer` at :622, :1225, :1238, :1273, :2354.
- 7 enum-case rewrites in PHECN: `peer as? TelegramUser/Group/Channel` at :73, :77, :86 (no-bind), :91 (no-bind), :107 (inner rebind), :154.
- 1 enum-case rewrite in PEAN: `peer as? TelegramChannel` at :93.
- 1 enum-case rewrite in PEAON: `peer as? TelegramChannel` at :74.
- 4 `_asPeer()` bridges ADDED at Peer-only-property sites (wave-42 lesson pattern):
  - PEAN:159 `PeerReference(peer._asPeer())` — PeerReference.init takes raw Peer.
  - PEAN:166 `peer._asPeer().isCopyProtectionEnabled` — property not forwarded on EnginePeer.
  - PHECN:115 `(peer?._asPeer() as? TelegramUser)?.lastName` — inline expression form kept; chose bridge over multi-line `case let` expansion.
  - PHN:521 `self.peer = peer?._asPeer()` — stored raw Peer? field stays raw.
- 1 ADD wrap at PHN:363 (`itemsUpdated` closure) — closure reads stored raw `self.peer` and forwards to the migrated `PEAN.update`.
- 1 ADD bridge at PHN:1815 for `self.avatarListNode.update(..., peer: peer?._asPeer(), ...)` — `PeerInfoAvatarListNode.update(size:avatarSize:isExpanded:peer:...)` still takes raw `Peer?` (plan pre-flight missed this site). Candidate for wave 46.
- 2 external call sites in `PeerInfoScreen.swift` at :5399 and :5805 reshuffled: `peer: self.data?.savedMessagesPeer ?? self.data?.peer?._asPeer()` → `peer: self.data?.savedMessagesPeer.flatMap(EnginePeer.init) ?? self.data?.peer`. Net-zero at these sites (swap `?._asPeer()` bridge for `.flatMap(EnginePeer.init)` wrap).

Net consumer-surface: **−10 bridges** (15 drops − 4 internal `_asPeer()` bridges − 1 internal closure ADD-WRAP at :363 − 1 :1815 bridge the plan missed; the two external call sites are net-zero). No new `import Postbox` in any consumer module; no Postbox-hygiene regression.

**Build outcome:** 1 iteration (first-pass-clean).

**Commit:** `6b7a23867c` (5 files, 41 insertions / 41 deletions).

**Lessons:**

- **Plan pre-flight grep for call sites must include internal sibling-method callers, not just the target method's direct callers.** The plan enumerated the three internal call sites of PEAN.update / PHECN.update / PEAON.update inside PeerInfoHeaderNode.update's body (:633, :1816, :1817) and the `itemsUpdated` closure (:363), plus the two external call sites (:5399, :5805). It MISSED the `self.avatarListNode.update(..., peer:...)` call at PHN:1815 — a different target node's update method (`PeerInfoAvatarListNode.update(size:avatarSize:isExpanded:peer:...)`) that happens to live on the line immediately before `self.editingContentNode.avatarNode.update(peer: peer, ...)` at :1816. Pre-flight grep token `\.update\(.+peer:` over the four files would have caught it. Fix for future pre-flight grep: for each signature migration, grep ALL `update` methods called with the migrated param and verify each target's signature — not just the siblings being migrated.

- **Wave-43 binding-rule continues to hold at scale.** All 13 `as? TelegramUser/Group/Channel` rewrites in this wave obeyed the bind-when-used / no-bind-when-unused rule (PHECN:86 and :91 used `case .legacyGroup = peer` / `case .channel = peer` no-bind form because the branch body only appends field keys; all 11 others bind because the branch uses the concrete value). Zero `-warnings-as-errors` unused-binding risks surfaced during review. **Rule confirmed as durable.**

- **EnginePeer forwarding audit is worth a pre-flight pass for multi-property-accessing methods.** PHN's `update` method body accesses ~15 EnginePeer-forwarded properties (id, isFake, isScam, isPremium, isVerified, debugDisplayTitle, displayTitle, addressName, effectiveProfileColor, emojiStatus, verificationIconFileId, profileImageRepresentations, etc.) plus 2 concrete-class properties requiring enum bindings (`.phone` on TelegramUser; `.info` on TelegramChannel). Without a pre-flight forwarding audit against `submodules/TelegramCore/Sources/TelegramEngine/Peers/Peer.swift:485-560` (the EnginePeer property-forwarding extension), iteration surprises are likely. This wave's audit at plan time caught `isCopyProtectionEnabled` as the only non-forwarded property in PHN's body — matching the single bridge in PHN. **Rule: for multi-access methods, read the EnginePeer property-forwarding extension in full at plan time; enumerate every `peer.X` site and mark forwarded vs not.**

- **Case-pattern-against-optional is idiomatic and compiles cleanly.** All rewrites use `if case let .user(user) = peer` (or sibling case forms) against `EnginePeer?` — Swift extracts through Optional implicitly. Precedent: `PeerInfoScreenSettingsActions.swift:200` `if case let .user(user) = self.data?.peer, let phoneNumber = user.phone`. Build did not complain at any rewrite site. **Conservative fallback `if let peer, case let .x(y) = peer` is NOT needed; drop from future plans' "fallback" sections.**

- **Bundling net-zero external-call-site migrations with net-negative internal drops is fine for ratchet-focused waves.** The two PHN.update call sites in PeerInfoScreen.swift swap one bridge form for another (`?._asPeer()` → `.flatMap(EnginePeer.init)`) — literally net-zero on wrap count. The wave accepted this because (a) the internal drops (~15) dominate, (b) migrating `savedMessagesPeer` field to remove the external wrap would expand scope to a different file's public struct field, and (c) the wave-goal was "ratchet wave-43 ADDs", which is accomplished purely via internal drops. **Heuristic: if external call sites are net-zero and the internal scope is net-negative, bundle them; don't let the external net-zero block the ratchet.**

**Plan:** `docs/superpowers/plans/2026-04-24-peerinfoheader-update-bundle-engine-peer.md`.

---

## Wave 46 outcome (2026-04-25)

Migrated the PeerInfoScreen-local avatar chain: `PeerInfoAvatarListNode.update(peer:)` together with `PeerInfoAvatarTransformContainerNode.update(peer:)` / `.updateStoryView(peer:)` and the private `Params.peer` stored field — raw `Peer?` → `EnginePeer?` across 4 files. Ratchet wave: drops the wave-45 ADD at `PeerInfoHeaderNode.swift:1815` plus a pre-existing external bridge at `PeerInfoScreen.swift:2574`, collapses one internal wave-45 wrap inside PIATCN's `setPeer` body, and adds 2 `_asPeer()` bridges for Peer-only surfaces (`PeerReference.init` and `.isCopyProtectionEnabled`). Net: −1 bridge. The PeerInfoScreen-local `PeerInfoAvatarListNode` class shadows a same-named submodule class — the wave targets the local (PeerInfoScreen/Sources) file only; the submodule is untouched. No new typealiases. No engine wrapper structs. No `import Postbox` change.

**Classification:**
- 4 signature changes: `peer: Peer?` → `peer: EnginePeer?` on `PeerInfoAvatarListNode.update(peer:)` and its `arguments` tuple, plus `PeerInfoAvatarTransformContainerNode.update(peer:)`, `.updateStoryView(peer:)`, and the private `Params.peer` stored field.
- 2 DROPs at call sites (ratchet-value):
  - `PeerInfoHeaderNode.swift:1815` — `peer: peer?._asPeer()` → `peer: peer` (the wave-45 ADD flagged for ratchet).
  - `PeerInfoScreen.swift:2574` — `peer: peer?._asPeer()` → `peer: peer` (pre-existing external bridge; direct caller of `updateStoryView`).
- 1 internal WRAP collapsed inside PIATCN's `setPeer(...)` body: `peer: EnginePeer(peer)` → `peer: peer` (type flowed once upstream migrated).
- 2 ADDs inside PIATCN body for Peer-only surface:
  - PIATCN ~:404 `PeerReference(peer._asPeer())` — `PeerReference.init` takes raw `Peer`, not `EnginePeer`.
  - PIATCN ~:406 `peer._asPeer().isCopyProtectionEnabled` — property defined on the `Peer` protocol (`PeerUtils.swift:236`), not forwarded on EnginePeer (same finding as wave 45 for PEAN:166).
- 2 `as? TelegramChannel` → `case let .channel(...) = peer` rewrites inside PIATCN (both `update` and `updateStoryView` bodies test `channel.isForumOrMonoForum`; the `let channel` binding is retained because the body uses the concrete value).

Net consumer-surface: **−1 bridge** (2 drops + 1 wrap collapse − 2 adds). External API: no change.

**Build outcome:** 1 iteration (first-pass-clean). Full-project Bazel build 29.587s; only PeerInfoScreen + TelegramUI recompiled.

**Commit:** `5ca99da5a7` (4 files, 13 insertions / 13 deletions).

**Lessons:**

- **Shadowing-class-name pre-flight disambiguation.** `PeerInfoAvatarListNode` is defined in two places: `submodules/PeerInfoAvatarListNode/Sources/PeerInfoAvatarListNode.swift` (the submodule) AND `submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/PeerInfoAvatarListNode.swift` (the PeerInfoScreen-local class that shadows it). Wave 46's pre-flight nearly targeted the wrong file when the plan inspected the signature by class name alone. Mitigation for future waves: when the target method's signature has distinctive parameter names (here `avatarSize:isForum:threadId:threadInfo:`), grep against those distinctive tokens alongside the class name to disambiguate — and when the class name appears in multiple files, resolve the module path before writing the plan.

- **Chain-audit extends via sibling internal methods (`updateStoryView` pattern).** The initial audit targeted only the `update(peer:)` chain. But `PeerInfoAvatarTransformContainerNode.update`'s tail calls `self.updateStoryView(peer:)` — which also takes raw `Peer?`. Expanding the wave to include `updateStoryView` was a single-file additional edit and additionally dropped the `PeerInfoScreen.swift:2574` external bridge (a direct caller of `updateStoryView`, not `update`). Pattern for future chain waves: grep the target implementation body for `self\.\w+\(.+peer:` to find internal sibling methods whose signature migration naturally bundles with the primary chain.

- **First-pass-clean extends to chain migrations when both forwarding audit and scope audit are done at plan time.** Wave 46 is the 4th consecutive wave (42/43/44/45/46 — wave 44 needed 2 iterations) hitting 0-to-1-iteration convergence. The 1-iteration-clean pattern is reproducible when (a) the `_asPeer()` bridge sites are identified at plan time by cross-referencing the body against the EnginePeer property-forwarding extension AND `PeerReference`'s init overloads, and (b) enum-case conversions are pre-written in the plan with bindless-vs-binding form pre-classified. Both inputs were present in the wave 46 plan.

- **Chain-bundling heuristic validated at 3 methods / 4 files.** Migrating a narrow call chain (`PeerInfoAvatarListNode.update` → `PIATCN.update` → `PIATCN.updateStoryView`) + all external call sites in a single commit is the right granularity: the internal `peer` variables flow transparently once each downstream signature migrates, and the external call-site greps (2 sites total) complete the ratchet. Net: clean atomic commit, no bridging churn remains at the boundary. For future chain waves, bundle the chain methods plus external callers in one commit; don't split by method.

**Plan:** `docs/superpowers/plans/2026-04-25-peerinfo-avatar-chain-engine-peer.md`.

---

## Wave 47 outcome (2026-04-25)

Migrated the stored `PeerInfoHeaderNode.peer` field from `Peer?` to `EnginePeer?`. Single-file wave; field is `private`, so no external API change. 4 edits / 1 file, all inside `submodules/TelegramUI/Components/PeerInfo/PeerInfoScreen/Sources/PeerInfoHeaderNode.swift`.

**Edits:**
- Line 92: `private var peer: Peer?` → `private var peer: EnginePeer?`
- Line 363 (`itemsUpdated` closure): `peer: EnginePeer(peer)` → `peer: peer` (drops bridge; `peer` is captured from `strongSelf.peer`).
- Line 521 (assignment in `update`): `self.peer = peer?._asPeer()` → `self.peer = peer`.
- Line 2054 (ProfileLevelInfoScreen push closure): `peer: EnginePeer(peer),` → `peer: peer,`.

PHN:426 (`peer.profileImageRepresentations.isEmpty`) compiles unchanged because `profileImageRepresentations` is forwarded by `EnginePeer` (`Peer.swift:485`).

Net consumer-surface: **−3 internal bridges**.

**Build outcome:** 2 iterations.
- Iteration 1 failed at PHN:363 — pre-flight grep used `self\.peer\b` and missed the `strongSelf.peer` capture inside the `itemsUpdated` closure body. The memory file's wave-47 candidate notes had explicitly flagged PHN:363; the omission was in the executor's grep, not the plan's identification.
- Iteration 2 clean. Full-project Bazel build 28.727s; only PeerInfoScreen + TelegramUI recompiled.

**Commit:** `d7b7536440` (4 insertions / 4 deletions in PHN.swift; plan file added).

**Lessons:**

- **Pre-flight grep for stored-field migrations must include closure-capture aliases (`strongSelf`, `self_`, etc.), not just `self.<field>`.** Wave 47's first-iteration failure was 100% avoidable: the same field is referenced via `strongSelf.peer` inside an `itemsUpdated` closure, and the bare `self\.peer\b` grep missed it. For future stored-field migrations, the canonical grep pattern is `(self|strongSelf|[a-zA-Z_]*[Ss]elf)\.<field>\b`. The convention `strongSelf` appears throughout the PeerInfo codebase whenever closures use `[weak self]`.
- **Memory-stored candidate notes can pre-list the bridge sites.** The memory file `project_postbox_refactor_next_wave.md` had explicitly named PHN:363 (`itemsUpdated` closure read), PHN:521 (stored assignment), and PHN:2054 (ProfileLevelInfoScreen push wrap) before the wave started. Reading those during plan-write would have caught the iteration-1 miss. Treat the wave-N+1 candidate notes in memory as a load-bearing input to the plan, not just narrative.
- **Single-file `private` stored-field migrations are the cleanest possible wave shape.** No external API surface, no cross-module recompilation, blast radius bounded to the same file's other methods. When a wave reaches this shape, it is a near-zero-risk drop. Future stored-field-migration waves should be explicitly classified during planning as "single-file private" / "cross-file private" / "public-surface" to set the iteration budget.

**Plan:** `docs/superpowers/plans/2026-04-25-phn-peer-stored-field-engine-peer.md`.

---

## Wave 48 outcome (2026-04-25)

Migrated `PeerInfoScreenData.savedMessagesPeer: Peer? → EnginePeer?`. Cross-file struct-field migration contained within the PeerInfoScreen module; the field has no external consumer (`grep -rEn "(\w+\??)\.savedMessagesPeer\b"` matches only inside the PeerInfoScreen sources). 5 edits across 2 files.

**Edits:**
- `PeerInfoData.swift:388` — field decl `Peer?` → `EnginePeer?`.
- `PeerInfoData.swift:444` — init param `Peer?` → `EnginePeer?`.
- `PeerInfoData.swift:1622` — drop `?._asPeer()` bridge. The source local `let savedMessagesPeer: Signal<EnginePeer?, NoError>` (PID:1313) already produces `EnginePeer?`; the bridge was an artificial demotion.
- `PeerInfoScreen.swift:5399` and `:5805` — drop `.flatMap(EnginePeer.init)` bridge in `headerNode.update(... peer: ...)` call. The `peer` parameter of `headerNode.update` has been `EnginePeer?` since wave 45, and the `??` coalescing operand `self.data?.peer` has been `EnginePeer?` since wave 42; once the field migrates, both ends of the expression are `EnginePeer?` and the `flatMap` bridge falls out.

The other 4 init kwarg sites (PID:1029, :1102, :1869, :2207) all pass `nil` and require no change.

**Build outcome:** 1 iteration (first-pass-clean). Full-project Bazel build 29.858s; only PeerInfoScreen + TelegramUI recompiled.

**Commit:** `1e4c2eea33` (5 insertions / 5 deletions; plan file added).

**Lessons:**

- **Internal-storage demotion → external re-promotion** is a high-yield ratchet pattern. The field had a `?._asPeer()` demotion at the storage site, then `.flatMap(EnginePeer.init)` re-promotions at every read. Migrating the field type drops both ends in one wave — the underlying signal pipeline never needed the `Peer?` form at all. Pattern to look for in future PSD-class migrations: any field whose initialization expression names `_asPeer()` strongly indicates that the field's source data is already `EnginePeer?`. Grep candidate fields' init expressions for `_asPeer()` to surface these high-leverage migrations.

- **Containment audit must distinguish field declarations on different types.** The grep `grep -rln "savedMessagesPeer"` returned 6 modules outside PeerInfoScreen. All matched references were independent declarations on unrelated types (TelegramEngineMessages, ChatListUI nodes, ChatControllerContentData). The narrower regex `(\w+\??)\.savedMessagesPeer\b` filtered to actual field-access patterns and confirmed no external consumer. For future struct-field migrations, prefer the access-pattern regex over plain text grep; common field names will hit unrelated declarations and inflate apparent blast radius.

- **`replace_all=true` is correct for verbatim-duplicated call sites.** PIS:5399 and :5805 are byte-identical `headerNode.update(...)` calls with the same `peer:` argument. Single-Edit-with-replace_all replaced both atomically. No collisions because the `headerNode.update` argument list with `flatMap(EnginePeer.init)` is sufficiently long to be unique.

- **Wave-shape G' (sibling-of-wave-42 ratchet) revalidated.** Wave 42 migrated `PeerInfoScreenData.peer: Peer? → EnginePeer?`. Wave 48 follows the same pattern on a sibling field. Future waves on `chatPeer`, `linkedDiscussionPeer`, `linkedMonoforumPeer` will not all be this clean: `chatPeer` has 5 `as? TelegramX` checks downstream + cross-method propagation into ClearPeerHistory; `linkedMonoforumPeer` has an `as? TelegramChannel` check at PIPI:1197. Field-by-field selection should consider downstream consumer shape, not just declaration site.

**Plan:** `docs/superpowers/plans/2026-04-25-peerinfoscreendata-savedmessagespeer-engine-peer.md`.

---

## Wave 49 outcome (2026-04-25)

Bundled migration: `PeerInfoScreenData.linkedDiscussionPeer` + `.linkedMonoforumPeer`, both `Peer? → EnginePeer?`. Cross-file struct-field migration over 2 files. Bundled because both fields share parallel local-source patterns (raw `peerView.peers[id]` dict lookup) and the same single consumer file (`PeerInfoProfileItems.swift`). The bundle is justified: the source-of-truth init blocks compute `discussionPeer` and `monoforumPeer` as a sibling pair at PID:1836–1843 and again at PID:2131–2138; migrating one without the other would leave a half-Peer-half-EnginePeer init block.

**Edits:**

`PeerInfoData.swift` (12 edits via `replace_all=true` on the parallel pair):
- Lines 396–397 — field decls Peer? → EnginePeer?.
- Lines 453–454 — init params Peer? → EnginePeer?.
- Lines 1836+2131 — `var discussionPeer: EnginePeer?` (parallel pair).
- Lines 1838+2133 — `discussionPeer = EnginePeer(peer)` (lift raw Peer at boundary).
- Lines 1841+2136 — `var monoforumPeer: EnginePeer?` (parallel pair).
- Lines 1843+2138 — `monoforumPeer = peerView.peers[linkedMonoforumId].flatMap(EnginePeer.init)` (lift Peer? at boundary).

`PeerInfoProfileItems.swift` (3 edits):
- :1102 — `EnginePeer(peer).displayTitle(...)` → `peer.displayTitle(...)`.
- :1197 — `if let monoforumPeer = data.linkedMonoforumPeer as? TelegramChannel` → `if case let .channel(monoforumPeer) = data.linkedMonoforumPeer`. The `case .channel` payload is `TelegramChannel`, so the downstream `monoforumPeer.sendPaidMessageStars` access at :1198 continues to compile.
- :1409 — `EnginePeer(linkedDiscussionPeer).displayTitle(...)` → `linkedDiscussionPeer.displayTitle(...)`.

**Net bridge accounting:**
- ADDs (4): boundary lifts at PID:1838, :1843, :2133, :2138. These lift the Postbox-typed `peerView.peers[...]` dict-lookup result to the engine type at the data-flow boundary — the canonical Postbox→Engine position. Mirrors wave 42's `peer.flatMap(EnginePeer.init)` lift at PID:1620.
- DROPs (2): displayTitle `EnginePeer(...)` wraps at PIPI:1102 and :1409.
- Plus 1 idiom cleanup (PIPI:1197 — `as?` cast → enum-case pattern); no text saving but better Swift idiom.

The +4/−2 net text-bridge count is acceptable here because the ADDs are not "internal bridges" — they're the canonical Postbox→Engine boundary that any well-typed engine field requires. Wave-tracking should distinguish "boundary lifts" (correct, permanent) from "internal bridges" (incorrect, ratchet target).

**Build outcome:** 1 iteration (first-pass-clean). Full-project Bazel build 29.479s; only PeerInfoScreen + TelegramUI recompiled. Pre-flight EnginePeer-property forwarding audit (`addressName` at Peer.swift:461; `displayTitle` is an EnginePeer instance method; `case .channel` binds `TelegramChannel`; `TelegramChannel.sendPaidMessageStars` exists at SyncCore_TelegramChannel.swift:215) all verified at plan time and proved correct.

**Commit:** `79698e4513` (15 edits across 2 files; plan added).

**Lessons:**

- **Bundle waves around source-of-truth coherence, not just consumer overlap.** Wave 49's bundling was justified primarily by the *source* side: both fields are computed in the same init block as a sibling pair (PID:1836–1843, :2131–2138). Migrating only one would leave the init block in a half-typed state and force an artificial bridge. Future bundling decisions should weight this "shared source-of-truth init" factor at least as heavily as "shared consumer file."

- **Boundary-lift bridges are not "internal bridges" — wave-tracking should distinguish.** Wave-49's +4 ADDs are at the Postbox↔Engine boundary (raw `peerView.peers[...]` Postbox-typed dict → engine-typed field). They are the *correct* place for the lift; they will not ratchet away in a future wave. Internal bridges (e.g. PID:1622's `_asPeer()` in wave 48, or `EnginePeer(...)` wraps at consumer-side display calls) are the actual ratchet targets. Future wave outcome reports should categorize ADDs as "boundary lift" vs "internal bridge" to avoid confusion in net-bridge accounting.

- **Parallel-pair `replace_all=true` works for multi-line blocks when the parallel pair is byte-identical.** PID:1836–1843 and PID:2131–2138 are byte-identical 9-line blocks. One Edit-with-replace_all applied the type+wrap rewrite to both. Pre-flight verification: `diff <(sed -n '1836,1843p' file) <(sed -n '2131,2138p' file)` returned empty before the edit. Pattern generalizes to any "compute the same locals in two adjacent init paths" code structure (a common shape in PeerInfoData.swift's signal pipelines).

- **Whitespace nuance with `replace_all` multi-line edits.** The blank separator between the two `var X: Peer?` blocks had trailing spaces (Swift code with whitespace-trimming editor settings). The new_string used a clean blank line; the resulting file has a plain `\n` separator instead of `                \n`. Cosmetic only — no compile impact — but worth noting for future plans: when the indentation-sensitive pre-text uses trailing whitespace, mirror it exactly in the new_string to avoid inadvertent normalization.

- **`case .channel` pattern at field-binding compiles cleanly against `EnginePeer?` (re-confirmed wave 45 lesson).** No `if let ... case let .channel = ...` two-step needed; single-step `if case let .channel(monoforumPeer) = data.linkedMonoforumPeer` works directly.

**Plan:** `docs/superpowers/plans/2026-04-25-peerinfoscreendata-linked-peers-engine-peer.md`.

---

## Wave 50 outcome (2026-04-25)

`enclosingPeer: Peer? → EnginePeer?` migration across the PeerInfo members chain. 19 edits across 3 files (`PeerInfoScreenMemberItem.swift`, `PeerInfoMembersPane.swift`, `PeerInfoProfileItems.swift`). Cross-file private struct-field migration with stored-form ratchet (wave-47 taxonomy: "cross-file private"). Closes the wave-48-pattern internal-demotion-and-external-re-promotion ratchet at PIMP:354–363, where `engine.data.subscribe(...)` produced an `EnginePeer?` that was demoted to `Peer?` for storage and then re-promoted at every consumer.

**Edits:**

`PeerInfoScreenMemberItem.swift` (7 edits):
- :23 — stored field `let enclosingPeer: Peer? → EnginePeer?`.
- :34 — init param `Peer? → EnginePeer?`.
- :152, :154 — `as? TelegramChannel` / `as? TelegramGroup` → `case let .channel(channel)` / `case let .legacyGroup(group)`.
- :178 — `peer: item.enclosingPeer.flatMap(EnginePeer.init)` → `peer: item.enclosingPeer` (auto-promotes to `EnginePeer?`).
- :181, :187 — `is TelegramChannel` → `case .channel = ...` (wave-41 always-false-warning fix).

`PeerInfoMembersPane.swift` (11 edits):
- :92, :271, :442 — three func sigs `enclosingPeer: Peer → EnginePeer`.
- :113, :115 — `as? TelegramChannel` / `as? TelegramGroup` → `case let .channel(channel)` / `case let .legacyGroup(group)`.
- :139 — `peer: EnginePeer(enclosingPeer)` → `peer: enclosingPeer` (drop wrap, auto-promotes).
- :142, :148 — `is TelegramChannel` → `case .channel = ...`.
- :293 — stored field `private var enclosingPeer: Peer? → EnginePeer?`.
- :361 — `strongSelf.enclosingPeer = enclosingPeer._asPeer()` → `strongSelf.enclosingPeer = enclosingPeer`.
- :363 — `strongSelf.updateState(enclosingPeer: enclosingPeer._asPeer(), ...)` → `..., enclosingPeer: enclosingPeer, ...`.

`PeerInfoProfileItems.swift` (1 edit):
- :852 — `enclosingPeer: peer._asPeer()` → `enclosingPeer: peer` (boundary lift; `peer` is already `EnginePeer` from the closure scope's `data.peer` post-wave-42).

**Net bridge accounting:**
- DROPs (5): 2× `_asPeer()` demotion (PIMP:361, :363), 1× `EnginePeer(...)` wrap (PIMP:139), 1× `flatMap(EnginePeer.init)` (PSMI:178), 1× boundary `_asPeer()` lift (PSPB:852).
- ADDs (0): no new bridges. Pattern conversions (`as?` → `case let`, `is` → `case`) are not bridges; they're idiom shifts mandated by the EnginePeer enum representation.
- Pass-through call sites at PIMP:275, :276, :437, :438, :451, :485 needed no edits — types flow transparently through stored field, local var, and func params after the signature changes.

**Build outcome:** 1 iteration (first-pass-clean). Full-project Bazel build 29.290s; only PeerInfoScreen + TelegramUI recompiled. Continues the wave 42/45/46/48/49 first-pass-clean streak (6 of last 8 waves first-pass-clean; wave 44 was 2 iterations, wave 47 was 2 iterations).

**Commit:** `a1b77bcf74` (19 edits across 3 files).

**Lessons:**

- **The wave-48 internal-demotion ratchet pattern is reliably first-pass-clean.** When the source signal already produces the engine type and is being demoted at storage, migrating the storage to the engine type is a 1-iteration target if the consumer's only Peer-only access is through `as? TelegramX` / `is TelegramX` (mechanical conversions to `case let`/`case`). Wave 50 reproduces the wave-48 pattern verbatim and lands the same first-pass-clean outcome.

- **Pre-flight EnginePeer-property forwarding audit confirmed unnecessary for `case let`-bound concrete types.** The `case let .channel(channel)` / `case let .legacyGroup(group)` patterns bind a `TelegramChannel` / `TelegramGroup` directly — methods like `.hasPermission(.editRank)` and `.hasBannedPermission(.banEditRank)` are class methods on the concrete type and call cleanly without `_asPeer()`. The forwarding audit in earlier waves was load-bearing for properties accessed *off the bare EnginePeer* (e.g., `peer.displayTitle` requiring an EnginePeer method); when accessed off a case-bound concrete type, no audit is needed.

- **Bundling rationale: PSMI + PIMP + PSPB:852 share the same data-flow contour.** `PeerInfoProfileItems.swift:852` is the only producer of `PeerInfoScreenMemberItem` in the migration's scope (PSI:132 also produces but with `enclosingPeer: nil`, no edit needed). PIMP and PSMI form a tight pane–node pair. The 1-edit PSPB inclusion was non-controversial because the PSPB:852 site is the canonical Postbox→Engine boundary above the migrated chain. Boundary-lift inclusion for a 1-edit site is correct.

- **Bundled implementer dispatch with a single subagent is the right shape for a 19-edit / 3-file mechanical wave.** Per-task subagent dispatch (1 task per file) would have triggered three implementer roundtrips and three review rounds for what is essentially one cohesive editing unit that doesn't pass build at any per-file checkpoint. The subagent-driven-development skill's "fresh subagent per task" convention adapts to "fresh subagent per cohesive editing unit" when individual tasks are not independently verifiable.

**Plan:** `docs/superpowers/plans/2026-04-25-peerinfo-enclosingpeer-engine-peer.md`.

---

## Wave 51 outcome (2026-04-25)

`GroupsInCommonListEntry.peer: Peer → EnginePeer` migration in `PeerInfoGroupsInCommonPaneNode.swift` (single-file private struct-field). 7 edits, 1 file, **first-pass-clean**. Wave-shape: narrow internal struct-field migration with deliberate boundary scoping — public init's `openPeerContextAction: (Bool, Peer, …)` field left unmigrated to avoid cascading into `PeerInfoPaneContainerNode` (parent), `PeerInfoRecommendedPeersPaneNode` (sibling pane sharing the closure type), and upstream callers in `PeerInfoScreen.swift`. Saved for a coordinated wave once a wider closure-type sweep is justified.

**Edits:**

`PeerInfoGroupsInCommonPaneNode.swift` (7 edits):
- :28 — stored field `var peer: Peer → var peer: EnginePeer`.
- :35 — `lhs.peer.isEqual(rhs.peer)` → `lhs.peer == rhs.peer` (EnginePeer is `Equatable`; was Peer-protocol method).
- :42 — `item()` closure params `(Peer) -> Void` → `(EnginePeer) -> Void` and `(Peer, ASDisplayNode, ContextGesture?) -> Void` → `(EnginePeer, ASDisplayNode, ContextGesture?) -> Void`.
- :44 — `peer: EnginePeer(self.peer)` → `peer: self.peer` (drop wrap; `ItemListPeerItem.peer:` already takes `EnginePeer`).
- :54 — `preparedTransition()` closure params, same migration as :42.
- :232 — `GroupsInCommonListEntry(... peer: peer)` → `peer: EnginePeer(peer)` (boundary lift; `peer.peer` source is `RenderedPeer.peer: Peer?`).
- :236 — `self?.chatControllerInteraction.openPeer(EnginePeer(peer), …)` → `self?.chatControllerInteraction.openPeer(peer, …)` (drop wrap; `peer` is now `EnginePeer` from migrated closure param).
- :238 — `self?.openPeerContextAction(false, peer, node, gesture)` → `self?.openPeerContextAction(false, peer._asPeer(), node, gesture)` (internal bridge to still-Peer-typed stored field at PIGCP:68/109).

**Net bridge accounting:**
- DROPs (2): 1× `EnginePeer(...)` wrap (PIGCP:44 → ItemListPeerItem), 1× `EnginePeer(...)` wrap (PIGCP:236 → chatControllerInteraction.openPeer).
- ADDs (2): 1× boundary lift `EnginePeer(peer)` (PIGCP:232; `RenderedPeer.peer: Peer?` → struct field; correct/permanent), 1× internal `_asPeer()` bridge (PIGCP:238) to the still-`Peer`-typed stored `openPeerContextAction` field.
- Net internal bridges: **−1**. Boundary lifts: **+1**.

**Build outcome:** 1 iteration (first-pass-clean). Full-project Bazel build 29.454s; PeerInfoScreen + TelegramUI recompiled. Continues the first-pass-clean streak (waves 42, 45, 46, 48, 49, 50, 51 — 7 of last 9 waves first-pass-clean; waves 44 and 47 each took 2 iterations).

**Commit:** `f2b67a1b54` (7 edits in 1 file).

**Lessons:**

- **Narrow-wave shape works for struct-field migrations even when the field flows into closure params.** The internal closures (`item()`, `preparedTransition()`) can be migrated independently from the public init's stored closure field, by sandwiching the still-Postbox-typed boundary at the closure that captures the stored field. This adds one `_asPeer()` bridge at the boundary but keeps the wave atomic and first-pass-clean.
- **Boundary-lift accounting clarifies wave value.** Net internal-bridge count (−1) is the correct progress metric; boundary lifts (+1) at `RenderedPeer.peer` are permanent until `RenderedPeer → EngineRenderedPeer` lands. The wave is a real ratchet step even with net-zero raw bridge count.
- **Memory-stored field name was wrong (memory said `PeerEntry`, actual was `GroupsInCommonListEntry`).** Verify struct identifiers at plan time. Doesn't affect the wave but should keep memory accurate for future planning.

---

## Wave 52 outcome (2026-04-25)

`PeerInfoPaneContainerNode.openPeerContextAction` closure parameter `Peer → EnginePeer` cascade across `PeerInfoPaneContainerNode` (PIPC), `PeerInfoGroupsInCommonPaneNode` (PIGCP), `PeerInfoRecommendedPeersPaneNode` (PIRP), and `PeerInfoScreen.swift` (PIS) — closes the wave-51 PIGCP:238 `_asPeer()` bridge and unifies the closure type across both sibling panes. 4 files, 8 type-site edits + 5 drops, **first-pass-clean**.

**Edits:**

- `PeerInfoPaneContainerNode.swift` (2): :411 init param closure type, :640 stored field closure type — both `(Bool, Peer, …) → (Bool, EnginePeer, …)`.
- `PeerInfoGroupsInCommonPaneNode.swift` (3): :68 stored field, :109 init param, :238 dropped `peer._asPeer()` (the wave-51 bridge — closed in this wave).
- `PeerInfoRecommendedPeersPaneNode.swift` (5): :68 inner item closure, :88 dropped `peer._asPeer()`, :94 `preparedTransition` closure, :119 stored field, :155 init param.
- `PeerInfoScreen.swift` (3): :1331 dropped `EnginePeer(peer)` wrap (`chatInterfaceInteraction.openPeer`), :1340 dropped `EnginePeer(peer)` wrap (`joinChannel(peer:)`), :1348 dropped `EnginePeer(peer)` wrap (second `chatInterfaceInteraction.openPeer`).

**Net bridge accounting:**
- DROPs (5): 2× internal `_asPeer()` (PIGCP:238 + PIRP:88), 3× `EnginePeer(peer)` wrap (PIS:1331 / :1340 / :1348).
- ADDs (0). The four forwarding closures (PIPC:1044–1045, PIRP:273–274 / :303–304, PIS:1319) all use parameter type inference, so the closure-type cascade ripples through automatically without explicit edits at those sites.
- Net internal bridges: **−5**. No boundary lifts (the migration unifies closure types end-to-end inside the module; receiving APIs already accepted `EnginePeer`).

**Build outcome:** 1 iteration (first-pass-clean). Full-project Bazel build 29.52s. Streak continues — 8 of last 10 waves first-pass-clean (42, 45, 46, 48, 49, 50, 51, 52; waves 44 and 47 each took 2 iterations).

**Commit:** `c86aa1aba3` (4 files, 13 insertions, 13 deletions).

**Lessons:**

- **Closure-type cascade as a wave-shape variant of struct-field migration.** When the migrating type is a closure parameter (not a struct field), Swift's parameter-type inference at every forwarding-closure site does the cascade automatically — no explicit edits needed at type-inferred sites. Wave 52 had 5 inferred-cascade sites (PIPC:1044, PIRP:273/303, PIS:1319) and only 8 explicit type-site edits (init params + stored fields). Compare to wave 50 (struct-field cascade with 19 explicit edits).
- **Pre-flight receiving-API verification is load-bearing for closure-type migrations.** Wave 52's plan verified `chatControllerInteraction.openPeer: (EnginePeer, …)` and `joinChannel(peer: EnginePeer)` BEFORE writing the wave, ensuring the 3 PIS body wraps would drop without compensating ADDs. If either API still took raw `Peer`, the migration would have re-introduced wraps inside the closure body, defeating the wave's purpose.
- **The wave-51 deferral was the correct call.** Wave 51 explicitly noted `openPeerContextAction: (Bool, Peer, …)` would NOT migrate within that wave's scope. Wave 52 closed it cleanly with a 4-file unit. This validates the wave-47 lesson: "memory-stored wave-N+1 candidate notes are load-bearing plan input." The deferral pre-classified the candidate, and wave 52 picked it up directly.
- **Bundled implementer dispatch with Haiku confirmed for closure-type cascades.** Wave 50 established Haiku-sufficiency for mechanical wave-shape edits (19 edits). Wave 52 reproduces with 13 edits — implementer applied all edits byte-perfectly first attempt, all greps passed, build first-pass-clean. Total cost ~56k implementer tokens.

---

## Wave 53 outcome (2026-04-25)

`PeerInfoScreenData.chatPeer: Peer? → EnginePeer?` field migration with deliberately narrow scope (defers `ClearPeerHistory.init.chatPeer: Peer` and `openClearHistory.chatPeer: Peer` to a future wave). 3 files / 14 insertions / 14 deletions / **first-pass-clean** Bazel ~29.5s.

**Edits:**

`PeerInfoData.swift` (PSD, 6 edits):
- :387 — field decl `let chatPeer: Peer? → let chatPeer: EnginePeer?`.
- :443 — init param `chatPeer: Peer? → chatPeer: EnginePeer?`.
- :1028, :1621, :1868, :2206 — boundary lifts at PSD-internal init call sites: `chatPeer: peer → chatPeer: peer.flatMap(EnginePeer.init)` (1028), `chatPeer: peerView.peers[peerId/groupId] → chatPeer: peerView.peers[...].flatMap(EnginePeer.init)` (1621/1868/2206). Each matches the sibling `peer:` line on the same construction.

`PeerInfoScreenOpenChat.swift` (PISOC, 2 edits):
- :25 — `chatLocation: .peer(EnginePeer(peer)) → chatLocation: .peer(peer)` (drop wrap).
- :89 — same pattern (drop wrap).

`PeerInfoScreenPerformButtonAction.swift` (PISPBA, 6 edits):
- :428 — `if let secretChat = chatPeer as? TelegramSecretChat → if case let .secretChat(secretChat) = chatPeer`.
- :431 — `} else if let group = chatPeer as? TelegramGroup → } else if case let .legacyGroup(group) = chatPeer`.
- :435 — `} else if let user = chatPeer as? TelegramUser → } else if case let .user(user) = chatPeer`.
- :439 — `} else if let channel = chatPeer as? TelegramChannel → } else if case let .channel(channel) = chatPeer`.
- :463 — `if let channel = chatPeer as? TelegramChannel → if case let .channel(channel) = chatPeer` (separate `if`, not in the else-if chain).
- :851 — `chatPeer: chatPeer → chatPeer: chatPeer._asPeer()` (1× ADD `_asPeer()` boundary bridge for unmigrated `ClearPeerHistory.init.chatPeer: Peer`).

**Net bridge accounting:**
- DROPs (2): `EnginePeer(peer)` wrap at PISOC:25 + PISOC:89.
- ADDs (1): `_asPeer()` at PISPBA:851 (boundary with unmigrated `ClearPeerHistory.init`).
- Boundary lifts (4): PSD:1028, :1621, :1868, :2206 — `Peer? → EnginePeer?` at the data-flow boundary into the migrated struct field. Permanent until upstream `RenderedPeer.peer / peerView.peers` migrate.
- Net internal bridges: **−1**.

**Build outcome:** 1 iteration (first-pass-clean). Full-project Bazel ~29.5s. Streak: 9 of last 11 waves first-pass-clean (42, 45, 46, 48, 49, 50, 51, 52, 53; waves 44 and 47 each took 2 iterations).

**Commit:** `438b4d7f46` (3 files, 14/14 line changes).

**Lessons:**

- **Narrow-scope is the right wave shape when bundling produces net-negative accounting.** Bundling wave 53 with `ClearPeerHistory.init` + `openClearHistory` migrations would have dropped 4 `EnginePeer(chatPeer)` wraps in `openClearHistory` body BUT added 4–6 `EnginePeer(...)` boundary lifts at PISPBA call sites (where `channel`/`group`/`user` Peer locals get passed). Pre-flight call-site classification turned this from "tempting bundle" into "net-negative bundle" — the deferral is correct.
- **`as? Telegram*` cluster conversion is mechanically safe even with `else if` chains.** 5 conversions in the same `.more` case body, all sharing the `chatPeer` scrutinee. Each `case let .x(y) = chatPeer` has the same scope semantics as the original `let y = chatPeer as? X` — `y` shadows nothing in the surrounding scope, control flow is preserved, and `else if` chains over EnginePeer's 4-case enum are equivalent to the original sequential `as?` casts.
- **Boundary-lift uniformity check.** Each `chatPeer:` PSD construction site already had a sibling `peer:` line one above with `peer.flatMap(EnginePeer.init)` or `peerView.peers[...].flatMap(EnginePeer.init)`. The wave-53 edits are byte-identical to the sibling pattern. Pre-flight verification ("does the sibling line use the same construction?") is the simplest signal that boundary lifts are idiomatic for the surrounding code.
- **Memory's "30+ sites / multi-iter" overcount.** Memory's wave-53 estimate captured the BUNDLED scope; narrow scope reduces to 14 sites / 1-iteration. Future memory updates should distinguish "bundled candidate site count" from "narrow candidate site count" so wave-N+1 budgets aren't anchored too high.

---

## Wave 54 outcome (2026-04-25)

`ClearPeerHistory.init.chatPeer` + `openClearHistory.chatPeer` `Peer → EnginePeer` bundled method-signature migration. Closes wave-53's deferred sibling. 2 files / 16 insertions / 16 deletions / **first-pass-clean** Bazel 31.484s. Commit `e3da090a7f`.

**Edits:**

`PeerInfoScreen.swift` (PIS, 10 edits):
- :3213 — `openClearHistory(... chatPeer: Peer) → ... chatPeer: EnginePeer)`.
- :3230, :3232, :3251, :3269 — drop 4 internal display-call wraps `EnginePeer(chatPeer).compactDisplayTitle → chatPeer.compactDisplayTitle` (the hot-path ratchet target).
- :7416 — `ClearPeerHistory.init(... chatPeer: Peer, cachedData:) → ... chatPeer: EnginePeer, cachedData:`.
- :7421 — `} else if chatPeer is TelegramSecretChat { → } else if case .secretChat = chatPeer {` (no-bind pattern; case body uses no fields from the secretChat).
- :7425 — `} else if let group = chatPeer as? TelegramGroup { → } else if case let .legacyGroup(group) = chatPeer {`.
- :7436 — `} else if let channel = chatPeer as? TelegramChannel { → } else if case let .channel(channel) = chatPeer {`.
- :7464 — `if let user = chatPeer as? TelegramUser, user.botInfo != nil { → if case let .user(user) = chatPeer, user.botInfo != nil {`.

`PeerInfoScreenPerformButtonAction.swift` (PISPBA, 6 edits):
- :851 — DROP wave-53 ADD: `chatPeer: chatPeer._asPeer() → chatPeer: chatPeer`.
- :857 — boundary lift: `chatPeer: user → chatPeer: EnginePeer(user)` (TelegramUser local from `case let .user(user)` upstream).
- :1067, :1073 — `chatPeer: channel → chatPeer: EnginePeer(channel)` (TelegramChannel locals).
- :1234, :1240 — `chatPeer: group → chatPeer: EnginePeer(group)` (TelegramGroup locals).

**Net bridge accounting:**
- DROPs (5): 4 internal `EnginePeer(chatPeer).compactDisplayTitle` wraps in PIS:openClearHistory body + 1 `_asPeer()` bridge at PISPBA:851 (the wave-53 ADD).
- ADDs (5): 5 boundary `EnginePeer(...)` lifts at PISPBA call sites.
- Conversions (4): `is`/`as?` → `case let` on PIS:7421/7425/7436/7464.
- Type-site (2): signature changes on PIS:3213 and PIS:7416.
- Net internal bridges: **0 raw count** — but the **ratchet kills 4 internal display-call wraps in the hot path** (PIS:3230/3232/3251/3269); only call-site boundary lifts remain, and those are permanent until upstream PISPBA sites get further migrated (e.g., to flow EnginePeer locals end-to-end).

**Build outcome:** 1 iteration (first-pass-clean). Full-project Bazel 31.484s. Streak: 10 of last 12 waves first-pass-clean (42, 45, 46, 48, 49, 50, 51, 52, 53, 54; waves 44 and 47 each took 2 iterations).

**Lessons:**

- **Bundled deferral closure cleanly inverts the wave-53 narrow-scope decision.** Wave 53 deferred this bundle because the call-site classification at that time was "5 boundary lifts vs. 4 wrap drops = net-negative" — but the analysis missed that closing wave-53's 1 ADD is also a drop. The actual full accounting at wave-54 time: 5 drops (4 wraps + wave-53 ADD) vs. 5 lifts (1 user + 2 channel + 2 group) = 0 raw count, with ratchet benefit of 4 hot-path wraps killed. Wave-by-wave deferral followed by closure is the right shape when the bundle's first half is independently valuable (wave 53 dropped 2 PISOC wraps and migrated the field type on its own merit).
- **`case .secretChat = chatPeer` (no-bind pattern) compiles cleanly under `-warnings-as-errors`.** No "unused binding" warning because there is no binding. The original `chatPeer is TelegramSecretChat` form is structurally similar — both are predicate checks with no name to discard.
- **`peer:` parameter unused in body is fine for `-warnings-as-errors`.** `openClearHistory(... peer: Peer, ...)` body never references `peer`; this passed wave 53 and continues to pass wave 54. Function-parameter unused warnings are not enabled in this codebase's compile flags. Confirms a wave-53 implicit assumption.
- **Bundled signature migration with mechanical `as?` cluster + small call-site count = 1-iteration target.** 2 files, 16 edits, 4 case-let conversions, 5 boundary lifts, 1 wave-53-ADD drop, 4 hot-path wrap drops. Full-project Bazel completed in one shot.

---

## Wave 55 outcome (2026-04-25)

`PeerInfoScreenViewControllerNode.deletePeerChat(peer:)` private-method first-arg `Peer → EnginePeer`. 1 file / 4 edits / **first-pass-clean** Bazel 29.284s. Commit `4818a0f090`.

**Edits:** all in `PeerInfoScreen.swift`:
- :4502 — drop `_asPeer()` at `openDeletePeer` ActionSheet button: `self?.deletePeerChat(peer: peer._asPeer(), globally: true) → self?.deletePeerChat(peer: peer, globally: true)`.
- :4556 — same drop at `openLeavePeer` TextAlertAction.
- :4564 — definition signature `peer: Peer → peer: EnginePeer`.
- :4573 — drop internal wrap inside body: `EngineRenderedPeer(peer: EnginePeer(peer)) → EngineRenderedPeer(peer: peer)` passed to `chatListController.maybeAskForPeerChatRemoval`.

**Net:** 3 drops, 0 adds. Both call sites' `peer` is `EnginePeer` (sourced from `engine.data.get(...Item.Peer.Peer(id:))` returning `Signal<EnginePeer?, NoError>`). Hot-path bridges eliminated end-to-end from delete/leave entry points down to `maybeAskForPeerChatRemoval`. Streak: 11 of last 13 first-pass-clean.

**Lessons:**

- **Single-file private-method migration with both call sites already EnginePeer = pure-drop wave shape.** The `_asPeer()` bridge at the call site exists *because* the receiving method was Peer-typed; once both endpoints are migrated, the bridge becomes deletable in the same wave. Pre-flight grep for `<method>(.*\._asPeer\(\))` patterns surfaces this shape immediately.

---

## Wave 56 outcome (2026-04-25)

`PeerInfoInteraction.openPeerInfo` closure-type and `PeerInfoScreenViewControllerNode.openPeerInfo` private-method first-arg `Peer → EnginePeer` cascade. 3 files / 7 edits / **first-pass-clean** Bazel 29.074s. Commit `31433fc1d4`.

**Edits:**

`PeerInfoInteraction.swift` (PII, 2 edits):
- :45 — `let openPeerInfo: (Peer, Bool) -> Void → (EnginePeer, Bool) -> Void`.
- :123 — same closure type in init param.

`PeerInfoScreen.swift` (PIS, 2 edits):
- :4304 — `private func openPeerInfo(peer: Peer, ...) → ... peer: EnginePeer`.
- :4306 — drop internal `EnginePeer(peer)` wrap (passed to `makePeerInfoController` which already takes EnginePeer post-wave-39).
- :1482 — boundary lift: `strongSelf.openPeerInfo(peer: member.peer, ...) → ... peer: EnginePeer(member.peer)` (`PeerInfoMember.peer` is still `Peer`, depends on RenderedPeer foundational migration).

`PeerInfoProfileItems.swift` (PIPI, 2 edits):
- :524 — drop `_asPeer()` bridge: `interaction.openPeerInfo(managedByBot._asPeer(), false) → interaction.openPeerInfo(managedByBot, false)` (`managedByBot` is EnginePeer? from PSD field).
- :860 — boundary lift: `interaction.openPeerInfo(member.peer, true) → interaction.openPeerInfo(EnginePeer(member.peer), true)`.

**Net:** 2 drops (PIS:4306 wrap + PIPI:524 _asPeer bridge), 2 boundary lifts (PIS:1482 + PIPI:860 at PeerInfoMember.peer source sites). Net raw count = 0 but 1 hot-path bridge eliminated. The 2 boundary lifts will close when `PeerInfoMember.peer` migrates (depends on RenderedPeer foundational session). Streak: 12 of last 14.

**Lessons:**

- **PIS:520-521 lambda forwarding `peer, isMember in self?.openPeerInfo(...)` needs no edit when the closure-field type migrates.** Swift parameter-type inference cascades from the migrated closure-field type to the lambda's parameter, and the lambda body forwards an EnginePeer to the migrated method. This is the same lesson as wave 52's PIPC.openPeerContextAction cascade — when the lambda's only role is to forward the parameter, the type re-bind is invisible at the lambda site.
- **Net-zero migrations are still worth doing when they consolidate a hot path.** Even though wave 56 has 2 drops and 2 adds, the 2 adds are at sources that will likely migrate later (PeerInfoMember.peer foundational), and the 2 drops include a hot-path `_asPeer()` ratchet at PIPI:524. The migration also makes the chain (`interaction.openPeerInfo → self.openPeerInfo → makePeerInfoController`) cleanly EnginePeer end-to-end, so future migrations can reason about it without bridge-hopping.

---

## Wave 57 outcome (2026-04-25)

Add `EnginePeer.isCopyProtectionEnabled` forwarding property in TelegramCore + drop 4 consumer-side `_asPeer().isCopyProtectionEnabled` bridges. 5 files / 5 edits / **first-pass-clean** Bazel 237.868s (cascade compile from TelegramCore touch). Commit `a5fc9fcf0e`.

**Edits:**

`TelegramCore/Sources/TelegramEngine/Peers/Peer.swift` (1 edit, 1 addition):
- Appended `var isCopyProtectionEnabled: Bool { return self._asPeer().isCopyProtectionEnabled }` to the existing `public extension EnginePeer { ... }` block (sibling to isDeleted, isScam, isVerified, isPremium).

Consumer drops (4 edits across 4 files):
- `PeerInfoEditingAvatarNode.swift:166` — `peer._asPeer().isCopyProtectionEnabled → peer.isCopyProtectionEnabled` (NativeVideoContent.captureProtected).
- `PeerInfoAvatarTransformContainerNode.swift:406` — same.
- `PeerInfoData.swift:2259` — `peerInfoIsCopyProtected(data:)` body.
- `PeerAvatarGalleryUI/Sources/AvatarGalleryItemFooterContentNode.swift:128` — `canShare = !peer.isCopyProtectionEnabled` (peer from `case let .image(_, _, _, _, peer, _, _, _, _, _, _, _) = entry`, which is `EnginePeer?`).

**Net:** 4 internal `_asPeer()` bridge drops; 0 adds. Other `_asPeer()` calls at adjacent lines (e.g., `PeerReference(peer._asPeer())` at PIED:159 / PIATCN:404) remain — `PeerReference.init` still takes raw Postbox Peer.

**Cascade compile:** full-project Bazel 237.868s (vs. ~30s typical) due to TelegramCore touch triggering downstream module rebuilds. Behavior parity verified by build success.

**Lessons:**

- **EnginePeer forwarding-extension addition is a high-leverage wave shape when ≥3 consumer sites use the same `_asPeer().<prop>` pattern.** Cost: 1 line in TelegramCore. Benefit: drops N consumer-side bridges (4 in this wave) and unlocks future call-site simplifications that pattern-match on the property. The wave-26 lesson "EnginePeer forwarding audit is load-bearing for multi-property methods" extends to "single-property forwarding is a wave shape on its own when the access-count threshold is met."
- **TelegramCore touches incur cascade-recompile cost (~210s extra wall-clock).** Worth budgeting; not a blocker. Future TelegramCore-touching waves should weight cascade time as part of wave-shape planning.
- **`EnginePeer` cases (.user/.legacyGroup/.channel/.secretChat) all preserve the underlying Postbox Peer's flag access via `_asPeer()`** — the forwarding implementation is a one-line wrapper. No case-by-case logic needed for properties that already exist on `Peer` protocol's extension. Rule of thumb: any `var <prop>` on `extension Peer` in PeerUtils.swift can be forwarded mechanically.

---

## Wave 58 outcome (2026-04-25)

`AccountContext.openAddPeerMembers` + `presentAddMembersImpl` cross-module `groupPeer: Peer → EnginePeer` migration. 6 files / 9 edits / **2 build iterations**. Commit `261c086c15`. Bazel 180.751s (iter 1, failure with 1 error) + 29.946s (iter 2, clean) = ~210s wall-clock.

**Edits:**

Protocol + impl (2 edits, 2 files):
- `AccountContext.swift:1456` — protocol method `groupPeer: Peer → groupPeer: EnginePeer`.
- `SharedAccountContext.swift:2351` — implementation signature.

`PresentAddMembers.swift` (4 edits, 1 file):
- :14 — public function signature.
- :38 — `if let group = groupPeer as? TelegramGroup → if case let .legacyGroup(group) = groupPeer`.
- :47 — `} else if let channel = groupPeer as? TelegramChannel, ... → } else if case let .channel(channel) = groupPeer, ...`.
- :210 — **iter-2 fix:** drop now-redundant `EnginePeer(groupPeer)` wrap inside body — `peer: EnginePeer(groupPeer) → peer: groupPeer` (after parameter is EnginePeer, wrapping it again doesn't compile).

Call sites (3 edits, 3 files):
- `PeerInfoScreen.swift:4606` — drop `_asPeer()`: `groupPeer: groupPeer._asPeer() → groupPeer: groupPeer` (`groupPeer = data.peer` is EnginePeer? post-wave-42).
- `ChatListUI/Sources/ChatListController.swift:3815` — drop `_asPeer()`: `groupPeer: peer._asPeer() → groupPeer: peer` (`peer` from `engine.data.get(...Item.Peer.Peer(id:))` is EnginePeer).
- `TelegramUI/Sources/Chat/ChatControllerLoadDisplayNode.swift:4006` — boundary lift: `groupPeer: peer → groupPeer: EnginePeer(peer)` (`peer` from `renderedPeer?.peer` is Postbox Peer; needed because `is TelegramGroup || is TelegramChannel` pre-check still runs against the Peer-typed local).

**Net:** 3 drops (2 `_asPeer()` at PIS:4606 + CLC:3815, 1 redundant `EnginePeer()` wrap at PAM:210), 1 boundary lift (CCLDN:4006), 2 case-let conversions in PAM body. Net internal-bridge progress: **−2**.

**Iter-2 lesson — pre-flight scope must include "internal wraps inside the migrated function's body."** Pre-flight grep covered:
- `<func>(...<arg>:` call sites ✓
- `<arg> as? Telegram*` casts ✓
But missed:
- `EnginePeer(<arg>)` wraps INSIDE the migrated body — once the parameter type changes, those become invalid.

Adding `<arg>\b` (the parameter name) to the pre-flight grep would have caught the PAM:210 site. Cheap rule going forward: grep the body for `EnginePeer\(<paramname>\)` before declaring inventory complete.

**Lessons:**

- **Cross-module migration with protocol method = uniform 2-iter target unless body is small.** `AccountContext` protocol method touches 3 callers + 1 impl + 1 forwarding free function with internal body. Each axis can hide one missed reference. Wave 58 hit one such miss (PAM:210); this is typical. Budget 2 iters for protocol-method migrations even when all axes look complete in inventory.
- **Boundary-lift planning is correct when the call-site's source is foundational.** CCLDN:4006 boundary lift is permanent until `RenderedPeer.peer` migrates. Adding it now is the right shape — defers the foundational migration without inflating the wave to that scope.
- **Pure cross-module migrations don't always cascade-recompile through TelegramCore.** Wave 58 touched TelegramUI consumers + AccountContext protocol but NOT TelegramCore; iter-2 rebuild was 29.9s (typical). Compare to wave 57's 237.9s when TelegramCore was touched.

---

## Wave 59 outcome (2026-04-25)

`_asPeer() as? TelegramX` micro-cluster migration. 4 files / 7 edits / **first-pass-clean** Bazel 25.833s. Commit `6ca4058ae8`.

**Edits:**

- `PeerInfoHeaderEditingContentNode.swift:115` — `(peer?._asPeer() as? TelegramUser)?.lastName ?? ""` → `if case let .user(user) = peer { updateText = user.lastName ?? "" } else { updateText = "" }` (preserves `?? ""` fallback semantics on cast-failure path).
- `StarsTransactionsScreen.swift:1288` — `if let channel = subscription.peer._asPeer() as? TelegramChannel { ... }` → `if case let .channel(channel) = subscription.peer { ... }`.
- `StarsTransactionScreen.swift:280` — `if let creationDate = (subscription.peer._asPeer() as? TelegramChannel)?.creationDate, creationDate > 0 {` → `if case let .channel(channel) = subscription.peer, channel.creationDate > 0 { additionalDate = channel.creationDate ... }`. (TelegramChannel.creationDate is non-optional Int32.)
- `ChatListSearchContainerNode.swift:927` — `if let user = message.author?._asPeer() as? TelegramUser { ... }` → `if case let .user(user) = message.author { ... }` (message.author is EnginePeer?).

**Net:** 4 internal `_asPeer() as? TelegramX` cast bridges eliminated; 0 adds. PIHEC site adds explicit `else { updateText = "" }` to preserve original cast-failure fallback.

**Lessons:**

- **`_asPeer()` is a tag for "this value is EnginePeer" by construction.** `_asPeer()` only exists on `EnginePeer`; calling it on any other type (including `Peer` protocol) doesn't compile. So every consumer-side `X._asPeer()` is provably an EnginePeer source — no need to verify per-site. This invariant makes bulk `_asPeer()` cluster migrations safe.
- **Preserve cast-failure-path semantics when converting `as?` clusters.** Original `(X as? TelegramUser)?.lastName ?? ""` returns `""` if X is nil OR not TelegramUser OR lastName is nil. Naive `if case let .user(user) = X { updateText = user.lastName ?? "" }` only sets updateText for the .user case, leaving it nil for other cases. Add explicit `else` branch when the original `??` fallback is load-bearing.

---

## Wave 60 outcome (2026-04-25)

Add `PeerReference.init?(_ peer: EnginePeer)` convenience init in TelegramCore + drop **49** consumer-side `PeerReference(X._asPeer())` bridges across 29 files / 53 insertions / 49 deletions. **First-pass-clean** Bazel 238.803s (cascade compile). Commit `b6cc2bfbd1`.

**TelegramCore extension addition:**

`submodules/TelegramCore/Sources/ApiUtils/ApiUtils.swift` — appended `init?(_ peer: EnginePeer) { self.init(peer._asPeer()) }` to the existing `public extension PeerReference` block.

**Consumer drops:** 49 sites where `PeerReference(X._asPeer())` becomes `PeerReference(X)`. 12 distinct expression patterns: `$0`, `author`, `bot.peer`, `component.peer`, `component.slice.effectivePeer`, `component.slice.peer`, `item.peer`, `participantPeer`, `peer`, `peerValue`, `primary.1`, `self.peer`. All EnginePeer-typed by the `_asPeer()` invariant.

**Execution method:** Python regex replacement (`re.sub` with pattern `PeerReference\(([^)(]+)\._asPeer\(\)\)` → `PeerReference(\1)`). Non-`)`-non-`(` capture group ensures the match is the smallest expression before the trailing `._asPeer())`. Tested against all 12 distinct expression patterns including chained property accesses and closure-arg captures.

**Net:** 49 internal `_asPeer()` bridge drops; 0 adds. Largest single-wave consumer-drop count to date.

**Lessons:**

- **The wave-57 forwarding-extension pattern scales to bulk init/method addition.** Convenience init/method overload in TelegramCore (1 line) drops N consumer bridges (49 in this case). Cost: 1 line + bulk consumer migration. Benefit: O(N) bridges dropped. Threshold for triggering this shape is ≥5 consumer sites (anything fewer is per-site case-by-case).
- **Python regex with `[^)(]+` capture is the safe automation primitive for migrating `Wrapper(X._asPeer())` patterns.** Greedy `.*` captures cause over-match. Non-greedy `.*?` is fragile in BSD sed. The `[^)(]+` capture explicitly avoids both `(` and `)` inside the captured expression, which works for chained property accesses (`a.b.c`), closure args (`$0`), and tuple-indexed accesses (`primary.1`). 49 sites all replaced safely.
- **The `_asPeer()` invariant guarantees migration safety.** Because `_asPeer()` only compiles on EnginePeer, no per-site type verification is needed for `Wrapper(X._asPeer()) → Wrapper(X)` migrations once the EnginePeer-accepting overload is added.

---

## Wave 61 outcome (2026-04-25)

Drop 6 `_asPeer().X` consumer-side bridges where X is already on the EnginePeer forwarding extension. 3 files / 6 edits / **first-pass-clean** Bazel 19.351s. Commit `5d497cc5e9`.

**Edits:**

- `ChannelVisibilityController.swift:1478` — `peer?._asPeer().usernames` → `peer?.usernames`.
- `PeerInfoCoverComponent.swift:74` — `peer._asPeer().profileColor` → `peer.profileColor`.
- `PeerInfoCoverComponent.swift:82` — `peer._asPeer().nameColor` → `peer.nameColor`.
- `StoryItemSetContainerComponent.swift:6700/6956/7274` — `component.slice.effectivePeer._asPeer().usernames` → `component.slice.effectivePeer.usernames` (replace_all=true; 3 sites).

**Net:** 6 internal `_asPeer()` bridge drops; 0 adds. All 6 sites used properties (`usernames`, `profileColor`, `nameColor`) already present on `public extension EnginePeer` block in TelegramCore — no new TelegramCore touch needed (no cascade compile).

**Skipped:** `peer._asPeer().indexName.indexTokens` at `ChannelDiscussionGroupSearchContainerNode.swift:157` — `EnginePeer.indexName` returns wrapper enum `EnginePeer.IndexName` without `.indexTokens`. Needs a separate IndexName extension or consumer refactor. Defer.

---

## Wave 62 outcome (2026-04-25)

Add 4 EnginePeer forwarding entries (isMonoForum, associatedPeerId, hasCustomNameColor, hasSensitiveContent) + drop 5 consumer-side `_asPeer().X` bridges. 6 files / 9 edits / **first-pass-clean** Bazel 237.769s (cascade compile). Commit `cdce0dba01`.

**TelegramCore extension additions** (Peer.swift, 4 entries — 16 lines):

```swift
var isMonoForum: Bool {
    return self._asPeer().isMonoForum
}
var associatedPeerId: Id? {
    return self._asPeer().associatedPeerId
}
var hasCustomNameColor: Bool {
    return self._asPeer().hasCustomNameColor
}
func hasSensitiveContent(platform: String) -> Bool {
    return self._asPeer().hasSensitiveContent(platform: platform)
}
```

All four forwarding implementations live in `submodules/TelegramCore/Sources/Utils/PeerUtils.swift` on the `extension Peer { ... }` block. The `Id` typealias on EnginePeer is `PeerId`, so `associatedPeerId: Id?` is type-equivalent to the underlying `Peer.associatedPeerId: PeerId?`.

**Consumer drops** (5 sites):

- `ThemeSettingsController.swift:428` — `accountPeer._asPeer().hasCustomNameColor` → `accountPeer.hasCustomNameColor`.
- `AgeVerificationScreen.swift:31` — `peer._asPeer().hasSensitiveContent(platform: "ios")` → `peer.hasSensitiveContent(platform: "ios")`.
- `TextProcessingScreen.swift:1281` — `peer._asPeer().isMonoForum` → `peer.isMonoForum`.
- `ShareSearchContainerNode.swift:478` — `mainPeer._asPeer().associatedPeerId` → `mainPeer.associatedPeerId`.
- `ChatListSearchListPaneNode.swift:153` — `maybeChatPeer._asPeer().associatedPeerId` → `maybeChatPeer.associatedPeerId`.

**Net:** 5 internal bridge drops; 0 adds.

**Lessons:**

- **Bundle multi-property forwarding additions in a single TelegramCore touch.** When 4 properties each unblock 1-2 consumer drops, bundling the additions into one wave amortizes the cascade-recompile cost (~210s) across 5 drops instead of paying 4× across 4 separate waves.

---

## Wave 63 outcome (2026-04-25)

`resolvedAreStoriesMuted(peer:)` Peer → EnginePeer cross-module function-signature migration. 5 files / 11 edits / **first-pass-clean** Bazel 239.818s (cascade compile). Commit `499edc0ddb`.

**TelegramCore signature change** (`ChangePeerNotificationSettings.swift`):
- :65 — `peer: Peer → peer: EnginePeer`. Body uses only `peer.id` (works on EnginePeer).
- :117 — internal call site boundary lift: `peer: peer → peer: EnginePeer(peer)` (peer source is `transaction.getPeer(peerId)` returning Postbox Peer).

**Consumer drops** (9 sites, 4 files):
- `ContactContextMenus.swift:50` — drop `_asPeer()`.
- `ChatListController.swift:3317` — drop `_asPeer()`.
- `StoryItemSetContainerComponent.swift:7224` — drop `_asPeer()` on `component.slice.effectivePeer`.
- `StoryChatContent.swift` — 6 sites (lines 210, 212, 1287, 1599, 2490, 2492); pattern `peer: peer._asPeer(),` → `peer: peer,` via `replace_all=true`.

**Net:** 9 drops, 1 boundary lift = **−8 internal bridges**.

**Lessons:**

- **Cross-module function-signature migration is a uniform 1-iter target when (a) the function body uses only EnginePeer-compatible properties and (b) all call sites have EnginePeer-typed sources via `_asPeer()`.** Pre-flight grep `<func>.*_asPeer` enumerates all consumer-side bridges; each drop is mechanical. Internal call sites in TelegramCore that pass Postbox Peer-typed locals get a boundary lift.
- **`replace_all=true` shines when the same parameter pattern repeats in a single file.** StoryChatContent had 6 identical `peer: peer._asPeer(),` patterns — one Edit call with `replace_all=true` replaced all of them. Saves 5 round-trips.

---

## Wave 64 outcome (2026-04-25)

`RenderedPeer.convenience init(peer: EnginePeer)` in TelegramCore + 5 consumer drops. 3 files / 6 edits / **first-pass-clean** Bazel 237.725s (cascade compile). Commit `109c2fe172`. Wave-shape: foundational TelegramCore extension addition (wave-57 pattern). Original `init(peer: Peer)` retained as designated init; Swift overload resolution selects the EnginePeer init only when the argument is EnginePeer-typed. Sites: PeerInfoSettingsItems:131 + ChatListSearchListPaneNode:4173/4213/4336/4371.

## Wave 65 outcome (2026-04-25)

`MergedAvatarsNode.update(peers: [Peer]) → [EnginePeer]` + private `PeerAvatarReference.init(peer:)` cascade. 6 files / 9 edits / **3 iter**. Commit `37c680c86c`. Iter-2 missed `groupsInCommon: [Peer]` field at ChatUserInfoItem; iter-3 missed `recentVoterPeers: [Peer]` and `avatarPeers: [Peer]` at ChatMessagePollBubbleContentNode. Lesson: **migrating a public function's array-of-Peer parameter forces a transitive inventory of *all* `[Peer]` field declarations across consumer modules**. Pre-flight grep should include `\[Peer\]\s*=\s*\[\]` and similar local/field decls.

## Wave 66 outcome (2026-04-25)

`VoiceChatJoinScreen.setPeer` + `VoiceChatPreviewContentNode.init` chain Peer→EnginePeer. Single file / 5 edits / first-pass-clean. Commit `148aa53f3f`. Net **−3** internal bridges. Wave-55 single-file pure-drop pattern.

## Wave 67 outcome (2026-04-25)

`_internal_storedMessageFromSearchPeer` signature Peer→EnginePeer + return type Signal<Peer>→Signal<EnginePeer>. 3 files / 5 edits / first-pass-clean Bazel 226.884s. Commit `3732fb66b6`. Drops `peer._asPeer()` and `|> map { EnginePeer(result) }` in `ensurePeerIsLocallyAvailable`. Net **−1** with 2 internal boundary lifts inside TelegramCore body.

## Wave 68 outcome (2026-04-25)

`SelectivePrivacyPeer.convenience init(peer: EnginePeer, participantCount:)` + 3 consumer drops. 4 files / 4 edits / first-pass-clean (initial 221s after TelegramCore touch + 17s consumer-only rebuild). Commit `73811a4e5d`. Original `init(peer: Peer)` and stored `peer: Peer` field unchanged — full migration of the field deferred (69 references repo-wide).

## Wave 69 outcome (2026-04-25)

`_internal_storedMessageFromSearchPeers` (plural) Peer→EnginePeer. Closes wave-67 sibling. 2 files / 3 edits / first-pass-clean Bazel 225.143s. Commit `42252eb9fd`. Drops `peers.map { $0._asPeer() }` in `ensurePeersAreLocallyAvailable`.

## Wave 70 outcome (2026-04-25)

`StatsMessageItem.peer` + `ChannelStatsController .post` enum-case payload + `MessageStatsController` local var Peer→EnginePeer cascade. 3 files / 9 edits / **3 iter**. Commit `f14dfe2273`. Iter-2 missed `entries.append(.post)` building sites at ChannelStatsController:1429/1433. Iter-3 missed `arePeersEqual(lhsPeer, rhsPeer)` Equatable comparison at L639 — replaced with `lhsPeer == rhsPeer` since EnginePeer is Equatable. **Pre-flight rule: when migrating an enum-case payload from Peer to EnginePeer, grep the same enum's `==` Equatable conformance for `arePeersEqual` calls.** Net **−5** internal bridges.

## Wave 71 outcome (2026-04-25)

`peerInfoControllerImpl` signature Peer→EnginePeer + drop `_asPeer()` shadow at SAC:1938. 1 file / 6 edits / first-pass-clean Bazel 24.582s. Commit `1650bc1521`. Wave-shape: single-file private-function with shadow-assignment pattern (`let peer = peer._asPeer()` shadowing the EnginePeer parameter to a Peer local). Mechanical conversion of body's 4 `as?`/`is` checks. Cheap rebuild because no public API change.

## Wave 72 outcome (2026-04-25)

`canSendMessagesToPeer` body cleanup: drop `_asPeer()` shadow + restructure `as?` casts as exhaustive switch on EnginePeer cases. 1 file / 1 edit / first-pass-clean Bazel 25.792s. Commit `98e7158b7a`. Wave-shape: TelegramCore-internal body cleanup. Public API was already EnginePeer (wave 38) — this wave only refactors the implementation. Cheap rebuild despite TelegramCore touch.

## Wave 73 outcome (2026-04-25)

`ChatQrCodeScreenImpl.Subject.peer` enum-payload Peer→EnginePeer + `QrContentNode.peer` field migration + drop `_asPeer()` shadow at SAC:2731. 2 files / 8 edits / **2 iter**. Commit `0faf4a0336`. Iter-2 missed two additional `peer as? TelegramX` casts at QrContentNode body L1742/L1744; also fixed an over-aggressive `replace_all=true` that caught a different `peer: EnginePeer(peer)` site at MessageContentNode L2184 where the local `peer` is Postbox-typed (boundary lift restored).

**Lesson reinforced: `replace_all=true` on a parametric wrapping pattern (`peer: EnginePeer(peer)`) must verify ALL matches share the same scope/source.** When the same call appears in multiple scopes with different local-variable types, `replace_all` propagates the wrong intent. Mitigation: grep first to verify unique-scope assumption, or fall back to per-site Edit when unsure.

---

## Wave 103 outcome (2026-04-26): ABANDONED

`ChatRecentActionsControllerNode.peer: Peer → EnginePeer` (wave-71-shadow close). Implementation built and committed (`e60a8692a7`, build clean at iter-3 / 41s), then **reverted** (`git reset --hard HEAD~1`) after pre-flight failure surfaced.

**Spec promised:** −1 boundary `_asPeer()` (CRAC:277) + −1 `import Postbox` (CRACN:5) + 0 ADD wraps. 7 edits / 2 files / 1 iter.

**Actual outcome before revert:** −1 boundary `_asPeer()` (CRAC:277) + −1 `EnginePeer(strongSelf.peer)` wrap (CRACN:535, bonus) + 0 `import Postbox` drops (raw `Message`/`MessageId` references for `AdminLogEventAction` payloads block the drop) + **+2 ADD `_asPeer()` wraps** (CRACN:228 for `canSetupAutoremoveTimeout` Peer-protocol extension, CRACN:737 for `chatRecentActionsHistoryPreparedTransition(peer: Peer)` helper). Net wrap delta: **0**, not the promised −1. Net `import Postbox` drop: **0**, not the promised −1.

**Why "extend in follow-up" was rejected:** Migrating `chatRecentActionsHistoryPreparedTransition(peer:)` to `EnginePeer` to drop the CRACN:737 ADD bridge would cascade into `ChatRecentActionsEntry.item(peer:)`. Inventory found 75 ADD-bridge sites in the helper body: 72 `peers[peer.id] = peer` stores into a `SimpleDictionary<PeerId, Peer>` (the type required by `Message(...)` constructor's `peers:` parameter) plus 3 `filterMessageChannelPeer(peer)` calls. Net cost of dropping 1 bridge: **+74 new bridges**. Catastrophic regression.

**Pre-flight failure modes (lessons):**

- **Pre-flight grep for `self.<field>.X` access must enumerate Peer-protocol extension methods, not just downcast patterns.** Wave-103 spec grepped `self.peer as\?` and `self.peer\.id\b` but missed `self.peer.canSetupAutoremoveTimeout(...)` at CRACN:228. `canSetupAutoremoveTimeout` is a `public extension Peer` method in `AccountContext/Sources/ChatController.swift:1013` — not on `EnginePeer`. **Mitigation:** future wave specs that retype a stored field from `Peer` to `EnginePeer` MUST grep for ALL `self.<field>.<method>(` patterns and verify each method is reachable on `EnginePeer` (not just on the `Peer` protocol). Build a method-allowlist for `EnginePeer` from `extension EnginePeer` declarations in TelegramCore and intersect.

- **Pre-flight grep for `<field>` flowing into Peer-typed function parameters.** Wave-103 spec missed that `peer` was passed to `chatRecentActionsHistoryPreparedTransition(peer: Peer)` at CRACN:737. The helper sits in a different file (`ChatRecentActionsHistoryTransition.swift`) but the same submodule. **Mitigation:** grep `: peer\b|, peer:|peer: peer\b|peer:\s*self\.peer` across the entire submodule, classify each call site as (a) target accepts EnginePeer (clean), (b) target accepts Peer (would need `_asPeer()` ADD or co-migration of target), (c) target accepts `EnginePeer(peer)` wrap (clean drop).

- **Wave-71-shadow close is NOT always cheap.** The implicit assumption ("caller already has EnginePeer; just drop the boundary `_asPeer()` and retype the storage") only holds when ALL of: (a) every `self.<field>.X` access has an EnginePeer-compatible counterpart, (b) every function call passing `self.<field>` accepts EnginePeer, (c) no protocol-conformance constraint on the stored field exists. Wave 71 itself worked because `peerInfoControllerImpl` was a single private function with mechanical body. Wave 103 failed because the file participates in a deep helper-cascade that builds Postbox `Message` values — and `Message`'s `peers: SimpleDictionary<PeerId, Peer>` constructor parameter is a hard barrier.

- **The `Message(... peers: SimpleDictionary<PeerId, Peer>, ...)` constructor is a hard wave barrier.** Any helper that builds Message values from a peer-typed parameter has Cat-3 ADD-bridge sites everywhere it stores the migrated peer into the peers dict. ChatRecentActionsHistoryTransition.swift has 70+ such constructions. Future waves should treat Message-building helpers as red-flagged candidates and pre-flight inventory their `peers[X.id] = X` store sites before promising any `peer: Peer → EnginePeer` migration upstream.

- **Spec self-review must include an "ADD wraps inventory" pass.** The wave-103 spec claimed "ADD wraps: 0" but the pre-flight grep didn't actually verify this — only the cast/`is` patterns were enumerated. Future spec template: a dedicated "ADD-wrap risk grep" section listing the regex patterns checked (Peer-protocol method calls, function calls accepting `: Peer`, dictionary stores into `[PeerId: Peer]`).

**Outcome:** wave-103 candidate marked **abandoned** in `project_postbox_refactor_next_wave.md`. Spec and plan docs retained at `docs/superpowers/specs/2026-04-26-postbox-wave-103-chat-recent-actions-controller-node-design.md` and `docs/superpowers/plans/2026-04-26-postbox-wave-103-chat-recent-actions-controller-node.md` as record of the failed attempt.

---

## Wave 103 (retry) outcome (2026-04-26)

`accountManager.mediaBox.storeResourceData(...)` Shape-A drain against the wave-94 `AccountManagerResources.storeResourceData(id:data:synchronous:)` facade. 5 sites / 2 files / 3 Edit calls (1 single + 2 `replace_all=true` batches) / **first-pass-clean** Bazel 29.5s (warm cache). Commit `92230b0691`. Sites: ThemeUpdateManager:112 (with `synchronous: true`), WallpaperResources:973+1214 (`reference.resource.id` pattern, replace_all), WallpaperResources:1260+1523 (`file.file.resource.id` pattern, replace_all).

**Net delta:** −5 raw `mediaBox.X` accesses, +5 facade calls, +5 `EngineMediaResource.Id(...)` wraps (canonical engine-side, not Postbox bridges).

**Lesson reinforced:** wave-shape-G drain against an existing facade is the cheapest reliable wave shape. 1-iter, ~30s build, single atomic commit. Pre-flight risk inventory takes ~5 minutes; implementation takes ~30s. Use this shape after a difficult abandonment to rebuild momentum.

**Wave-shape-G drain after a failed wave-71-shadow:** the contrast between the abandoned wave-103 (`peer: Peer → EnginePeer` field migration with hidden 75-site cascade) and the retry (5-site call-rewrite drain) illustrates why facade-drain waves and field-migration waves are categorically different. Drains have bounded scope (only sites matching a literal text pattern); field migrations have unbounded scope (any consumer of any field-typed value). Future wave selection should prefer drains when the goal is consistent forward progress and reserve field migrations for sessions with explicit budget for cascade investigation.

---

## Wave 104 outcome (2026-04-26)

`accountManager.mediaBox.resourceData(...)` Shape-A drain (3 of 8 candidate sites) against the wave-32 / wave-94 `AccountManagerResources.data(resource:)` facade. 1 file / 6 Edit calls (3 call rewrites + 3 consumer-side `.complete` → `.isComplete` renames) / **first-pass-clean** Bazel 11.7s. Commit `08fc3f721e`. Sites: WallpaperResources:957 (`reference.resource`), :1164 (`fileReference.media.resource`), :1264 (`file.file.resource`).

**Net delta:** −3 raw `mediaBox.X` accesses, +3 facade calls, +3 `EngineMediaResource(...)` wraps, +3 consumer field renames (`.complete` → `.isComplete` to match `EngineMediaResource.ResourceData`'s renamed field).

**Deferred (from the original 8-site candidate set):**
- 2 sites in `FetchCachedRepresentations.swift:482, 490` — flow `data: MediaResourceData` into `fetchCachedScaledImageRepresentation` / `fetchCachedBlurredWallpaperRepresentation` (raw-`MediaResourceData`-typed `resourceData:` parameter). Migration would cascade those functions OR require boundary `MediaResourceData` reconstruction. Defer.
- 3 sites in `WallpaperResources.swift:33, 59, 401` — coupled to postbox-side via `combineLatest(accountManager.mediaBox.resourceData(X), account.postbox.mediaBox.resourceData(X))` returning typed `Signal<(MediaResourceData, MediaResourceData), NoError>`. Migrating one side without the other breaks the tuple type. Defer until postbox-side is also drainable or a paired-resource facade is designed.

**Lesson — "Postbox-typed-function-parameter barrier" pattern (generalized):** wave 103's abandonment introduced this concept for `Message(... peers: SimpleDictionary<PeerId, Peer>, ...)` — any helper that builds a `Message` value forces ADD bridges at every `peers[X.id] = X` store. Wave 104 finds the same pattern at the result-type-flow level: `fetchCachedScaled*Representation(resourceData: MediaResourceData)` is a barrier that forces ADD bridges at every site whose closure flows the migrated result into it. Both are instances of "a Postbox-typed function parameter blocks upstream migration of values that flow into it." Pre-flight inventory must enumerate not just type-level uses of the migrated symbol but also the function-parameter-typed barriers it transitively flows into.

**Lesson — "field rename at wrapper-type boundaries":** `EngineMediaResource.ResourceData.isComplete` is renamed from `MediaResourceData.complete`. Each migrated call site has a paired consumer rename. This is a small but mandatory step the spec must call out per-site; an undocumented rename would surface as a build error referencing a property that doesn't exist on the new wrapper. The rename is verifiable per-site by reading the closure body that consumes the result.

---

## Wave 105 outcome (2026-04-26)

`DeviceContactInfoSubject` enum-payload Peer? → EnginePeer? migration. 5 files / 17 edits / **first-pass-clean** Bazel 203s (foundational AccountContext touch). Commit `0c76724409`. Wave-91-pattern multi-module enum-payload + completion-callback signature migration.

**Type changes:** 3 enum case payloads (`Peer?` → `EnginePeer?`), 2 completion-callback signatures (`(Peer?, ...) -> Void` → `(EnginePeer?, ...) -> Void`), 1 computed property (`peer: Peer?` → `peer: EnginePeer?`). All in `AccountContext.swift`.

**Net delta:** −10 wraps dropped, +2 wraps added (Pattern E ADD bridges at Chat-side construction sites where `peerAndContactData.0` is raw `Peer?`), +1 downcast → case-let conversion. **Net wrap delta: −8.**

Per-pattern breakdown:
- Pattern A (5 sites): `_asPeer()` drops at construction sites where source is already `EnginePeer?`. DeviceContactInfoController.swift:1289, 1443, 1489 + StoryItemSetContainerViewSendMessage.swift:2132 + OpenChatMessage.swift:443.
- Pattern B (2 sites): `_asPeer()` drops at completion-call sites. DeviceContactInfoController.swift:1105, 1224.
- Pattern C (3 sites): `.flatMap(EnginePeer.init)` simplifications when destructured `peer` is already `EnginePeer?` post-migration. DeviceContactInfoController.swift:942, 944, 946.
- Pattern D (1 site): downcast `as? TelegramUser` → `case let .user(peer)`. DeviceContactInfoController.swift:849.
- Pattern E (2 sites): ADD `.flatMap(EnginePeer.init)` wraps at construction sites where source is raw `Peer?`. ChatControllerOpenAttachmentMenu.swift:683, 1850.

**Lesson — "thorough pre-flight inventory pays for itself":** wave 105 was the first wave-71-shadow-style (field/payload migration with cascade risk) attempted after the wave-103 abandonment forced a discipline reset. Pre-flight inventory took ~15 minutes (full 4-layer wave-71-shadow-checklist sweep, including verifying 8 destructure sites + 5 callback consumers + 3 `subject.peer` accesses + 12 construction sites across 8 files). The inventory caught the 2 ADD bridges at Chat sites that an Explore-agent pass had initially miscategorized — verified by direct grep of `peerAndContactData` source signal types. Cost-of-care: 15 minutes of pre-flight + 5 minutes of one-line spec fix vs. the wave-103 cost of a build-and-revert cycle. Recommendation: apply the same discipline to every future wave-71-shadow candidate. The inventory cost is a tiny fraction of the abandoned-wave cost.

**Lesson — "documented ADD bridges are net-positive":** ADD bridges are not always disqualifying. The wave-71-shadow risk feedback emphasizes inventorying them, not avoiding them entirely. When the migration delivers net-negative wrap delta even after accounting for the ADD bridges (here: −10 drops vs. +2 adds = −8 net), the wave is still worth doing. The ADD bridges are also documented in the spec and commit message, so future waves migrating the upstream `peerAndContactData` source can drop them as part of that migration's natural cascade.

---

## Phase 2026-10: guard, hygiene, regression rollback (waves 438+)

The phase's spec and plans were working documents and were not kept on master; their decisions, and each wave's equivalence argument, are recorded in the entries below and in CLAUDE.md's refactor rules. Waves 106–437 are recorded in commits `1b85d8ccb0` and the squashes `86d1456552`, `69bfc65da7`, `ea0f6a685c`, `e918b353ec`, `bf01b4c858`, `4107263747`, `b8ee5493d9`.

Baseline at `8de02bc574` (outside TelegramCore/Postbox): 188 Swift files import Postbox (146 source, 42 test), up from 119 at `b8ee5493d9`; 87 BUILD files declare the dep. The regression came from code written while nothing stopped new imports, and partly from TelegramCore's own public surface: `InstantPage.media: [MediaId: Media]` forces the rich-text composer, converter and preview builders to name raw `Media`.

### Wave 438 (W1): hygiene (2026-10-12)

- **21 orphan deps removed.** These library rules declared `//submodules/Postbox` while no source in their package mentions Postbox: ChatListSearchRecentPeersNode, HashtagSearchUI, ListMessageItem, PeerInfoUI, PlatformRestrictionMatching, AttachmentFileController, ChatHistoryEntry, ChatInlineSearchResultsListComponent, ChatMessageInteractiveFileNode, ForumCreateTopicScreen, GiftSetupScreen, GroupStickerPackSetupController, RankChatPreviewItem, AutomaticBusinessMessageSetupScreen, BusinessIntroSetupScreen, PeerNameColorScreen, QuickReactionSetupController, ThemeAccentColorScreen, WallpaperGalleryScreen, WallpaperGridScreen, PeerListItemComponent. (ComposerHarness's two library rules are not orphans: their sources live under `Tests/`, which the scan counts as test sources.)
- **9 undeclared imports declared.** These library rules had sources importing Postbox through rules_swift's transitive search path without declaring the dep: ChatPresentationInterfaceState, TelegramCallsUI, TelegramStringFormatting, ChatMessageItemCommon, ChatRichTextEditorComposer, ComposePollScreen, RichTextAttachmentScreen, RichTextEditorMessageConversion, WalletContext. Later waves remove these again as their files migrate.
- **3 unused imports dropped**, all of which held: `StorageUsageExceptionsScreen.swift`, `ChatMessageMergeFingerprint.swift`, `ShareScreen.swift`. The ShareScreen package is now Postbox-free, and its dep is removed.
- **Counts:** in-scope source files importing Postbox went from 146 to 143. BUILD files declaring the dep (any rule) went from 87 to 70: −21 orphans, −1 ShareScreen, +5 new files. Four of the nine declarations landed in BUILD files that already carried the dep on a test rule.
- **Docs:** CLAUDE.md rule 6 corrected (tests exist), rules 9–11 added (no behaviour change, in-place TelegramCore API changes, a log entry per wave), plus a wrapper cheat sheet. This log gained the "Engine wrapper inventory".
- **Equivalence:** the diff contains only BUILD dep lines and three deleted `import Postbox` lines, from files that name no Postbox symbol, so no overload can resolve differently. A full `debug_sim_arm64` build is green (499 actions).

### Wave 439 (W2): the guard (2026-10-12)

Two commits: `build: add PostboxImportCheck` (the script plus 23 unit tests in `build-system/Make/tests/`), then this wave's wiring.

- **`submodules/Postbox/AllowedImporters.txt`:** 143 files, generated from the post-438 tree. `build-system/Make/PostboxImportCheck.py` runs at the top of `Make.py build` and `Make.py test`.
- **Bazel visibility:** `//submodules/Postbox:Postbox` is now visible to `:clients` (67 packages, TelegramCore included) and `:test_clients` (4: ComposerHarness, TextFormat, EditableTokenListNode, PeerInfoPaneNode) instead of `//visibility:public`. Before the change, the 70 packages declaring the dep were diffed against the two groups: identical.
- **Check:** 0.27 s on a warm checkout. `git ls-files` and the filesystem walk (used in the CI VM, which has no `.git`) both find the same 143 importers.
- **Negative checks**, each reverted:
  - (a) an unlisted `import Postbox` fails, naming file and line;
  - (b) the same import under a `Tests/` directory passes;
  - (c) listing a file that doesn't import Postbox fails as stale, naming the allowlist line;
  - (d) a Postbox dep added to the freed RankChatPreviewItem package fails Bazel analysis with "target '//submodules/Postbox:Postbox' is not visible". It was the only visibility error in the graph.
- **Mutation check of the unit tests:** 8/8 mutants killed (stale check, directory pruning, attribute forms, test exemption, whitespace path splitting, non-ASCII output, sort check, `Postbox` prefix over-match).
- **Not run:** `Make.py generateProject`, because it ends by opening Xcode. The structural check above covers its graph.
- **Known gap:** nothing flags a package that keeps declaring the dep after its last importer leaves. That is how the 21 orphans built up during waves 358–437. The next phase decides whether the script should flag orphan declarations too.
- **Equivalence:** no app behaviour change; build tooling and visibility only. Full build green.

### Wave 440: typealias-only files (2026-10-12)

The 14 "class T" files: their only Postbox names had a non-`EngineRaw*` engine alias.

- **Files that dropped `import Postbox`, all 14, none kept:**
  - `Telegram/SiriIntents/MessageSearchScope.swift`. It gained `import TelegramCore`, since it had imported only Postbox, for `MessageId`.
  - `Telegram/WidgetKitWidget/TodayViewController.swift`
  - `AttachmentUI/AttachmentPanel.swift`
  - `SettingsUI/.../NotificationExceptionControllerNode.swift`
  - `SettingsUI/.../PrivacyAndSecurityController.swift`
  - `CommunityEditScreen.swift`
  - `MediaEditorCollageDraftWriter.swift`
  - `PeerInfoData.swift`
  - `ButtonActionCodec.swift`
  - `ShareExtensionContext.swift`
  - TelegramUI's `AccountContext.swift`
  - `EphemeralBotCommandResolution.swift`
  - `OpenResolvedUrl.swift`
  - `WalletTonConnect.swift`
- **Swaps:**
  - `PeerId` -> `EnginePeer.Id`, `MessageId` -> `EngineMessage.Id`, `MessageIndex` -> `EngineMessage.Index`, `MessageTags` -> `EngineMessage.Tags`, `MediaId` -> `EngineMedia.Id`
  - `PreferencesEntry`, `TempBox`, `TempBoxFile`, `ValueBoxEncryptionParameters`, `CachedPeerData`, `ChatLocationInput`, `StoryId`, `PeerStoryStats`, `PostboxEncoder`/`Decoder`, `AdaptedPostboxEncoder`/`Decoder` and `MemoryBuffer` -> their `Engine*` aliases
  - `ValueBoxKey` -> `EngineDataBuffer`
- **Inventory false positives:** `Logger` is TelegramCore's top-level class (Postbox's is nested in `StorageBox`), and `Entry`/`Item`/`Component`/`Content` are nested names.
- **Freed:**
  - Packages AttachmentUI, SettingsUI, CommunityEditScreen and ShareExtensionContext, whose BUILD deps were removed and which left `clients`.
  - `//Telegram:WidgetExtensionLib`'s dep, since `Telegram/WidgetKitWidget` has no other importer. `//Telegram` stays in `clients`.
- **Counts:** `AllowedImporters.txt` 143 -> 129; `clients` 67 -> 63.
- **Equivalence:** typealias identity only, so values, overloads and dispatch are unchanged. A script mapped each added Swift line's aliases back to their Postbox names and compared it with the removed line: 91 of 91 lines are pure swaps. The only other Swift changes are the 14 deleted imports and the one added `import TelegramCore`.
- **Verification:** full build green (519 actions). `IntentsExtensionTests`, `SettingsUITests` and `RichTextEditorMessageConversionTests` passed.

### Wave 441: `InstantPage.media` is `[EngineMedia.Id: EngineMedia]` (2026-10-12)

`InstantPage`'s public surface forced its consumers (the rich-text composer and converter, the preview builders, the Instant View and browser renderers) to name raw `Media`. It now speaks `EngineMedia`, changed in place with no compatibility overload.

- **TelegramCore shape:**
  - The stored property is now `let rawMedia: [MediaId: Media]` (internal), behind `public var media: [EngineMedia.Id: EngineMedia]`, computed with `rawMedia.mapValues(EngineMedia.init)`.
  - The designated init became `init(blocks:rawMedia:...)` (internal). The public `convenience init(blocks:media:[EngineMedia.Id: EngineMedia]...)` converts with `_asMedia()`.
  - PostboxCoding, FlatBuffers, `==`, `allMedia()` and `Accessor.MediaIterator` keep working on `rawMedia`, so the stored encodings and equality are byte- and result-identical.
  - 13 TelegramCore sites were renamed `media` -> `rawMedia`. They were found by building with no public `media` at all, twice, because one closure in `WebpagePreview` had masked its errors. Among them was `ApiUtils/InstantPage.swift:499`, which the planning grep had missed.
- **Consumers:**
  - InstantPageUI's two layouts and the reference controller lost a now-redundant `mapValues(EngineMedia.init)`.
  - The `updatedMediaIfNeeded` loops in `InstantPageControllerNode` and `BrowserInstantPageContent` unwrap at the raw-typed helper and wrap its result.
  - `GalleryData.instantPageBlockMedia` now takes `[EngineMedia.Id: EngineMedia]`; the tapped media unwraps with `_asMedia()`. `instantPageGalleryMedia` reads `page.media` once, above its `for block in page.blocks` loop. The final review caught it rebuilding the computed dictionary on every block; fixed in a follow-up commit.
  - `BrowserMarkdown` and `BrowserReadability` wrap their builder dictionaries.
  - `InstantPagePreviewText` unwraps for its merge.
  - `InstantPageBuilder` unwraps nested pages and wraps at construction. Retyping its `[String: Media]` API is a later wave.
  - Constructions passing `media: [:]` (tests, formula and button editors, the thinking bubble) compile unchanged.
- **Precondition:** `EngineMedia.init(_:)` traps on a `Media` class outside its cases, and the computed property now runs it on reads that stayed raw before. All 19 TelegramCore media classes are covered. `TelegramMediaWebFile` is non-final and has no subclasses. The only other conformer is a Postbox test fixture, and no protocol refines `Media`.
- **Equivalence:** every consumer change passes the same objects through. `EngineMedia.init` stores its argument, `_asMedia()` returns it, and `mapValues` keeps keys and layout. Every read of a page's `media` outside TelegramCore was listed and checked. Library modules build with `-warnings-as-errors`, so an always-failing `as?` on a wrapper could not compile silently.
- **Files freed:** none. These consumers still name other Postbox types. The wave removes the TelegramCore surface that forced them to, and the allowlist stays at 129.
- **Verification:**
  - Full build green.
  - Passed: `TelegramStringFormattingTests`, `InstantPageUITests`, `RichTextEditorMessageConversionTests`, `ChatListUITests`, `TextFormatTests` and `ChatRichTextEditorComposerTests`.
  - `TelegramCoreTests`: 258 of 263 pass, including `InstantPageCustomEmojiTests`. The 5 failures are all in `ApiConstructorCompatibilityTests` (`userFull`/`walletUserAddress` layouts), and the runner ends with `tests exited with '11'`.
  - **Both reproduced at the base `8de02bc574`**, where the same 263 tests ran: the same 5 failures at the same lines (56, 57, 60, 61, 71) and the same exit 11. So the failure is pre-existing and independent of this phase. The test predates the TL engine rewrite `52a7bbfe55`, which looks like where `userFull`/`walletUserAddress` lost their second layout.

### Wave 442: single-site retypes (2026-10-12)

These were the easiest targets left after wave 441. The classifier, re-run with string literals stripped, found one file it had misfiled: `CommunityViewScreen`, whose "Media" was the image name `"Media Editor/Adjustments"`.

- **`NotificationRecipientAccount.swift`:** `notificationRecipientAccountName(accountPeer:)` takes `EnginePeer?`.
  - Its caller in `NotificationService.swift` wraps with `.flatMap(EnginePeer.init)`, and the tests pass `.user(...)`.
  - `EnginePeer.addressName` and `.debugDisplayTitle` forward to the raw peer, so behaviour is identical.
  - `EnginePeer.init(_:)` covers all five `Peer` classes (`preconditionFailure` otherwise; the only other conformer is a Postbox test fixture).
- **`WallpaperUploadManager.swift`:** the private `TelegramWallpaper.mainResource` and `areMediaResourcesEqual` are typed `TelegramMediaResource?`, the subtype CLAUDE.md prefers. The values were already `TelegramMediaResource`, `isEqual(to:)` dispatches identically, and `mediaBox.cachedResourceRepresentation` still receives the same object.
- **`CommunityViewScreen.swift`:** `[EnginePeer.Id: CachedPeerData]` became `[EnginePeer.Id: EngineCachedPeerData]` at 10 sites, a typealias swap. The CommunityViewScreen package is now Postbox-free; its dep is removed and it left `clients`.
- **Counts:** `AllowedImporters.txt` 129 -> 126; `clients` 63 -> 62.
- **Verification:** full build green (33 actions); `NotificationServiceTests` passed. The diff is three dropped imports, one wrapper-retyped function with a wrapping caller and wrapped test fixtures, two narrowed private signatures, and ten alias swaps.

### Wave 443: the Instant View cluster (2026-10-12)

Four files were blocked only by alias names and one wrapper site each: `InstantPageControllerNode.swift`, `InstantPageMediaOpen.swift`, `BrowserInstantPageContent.swift` and `ComposePollScreen.swift`.

- **Alias swaps:** `MediaId` -> `EngineMedia.Id` (13 + 13), `PeerId` -> `EnginePeer.Id`, and `MessageId` -> `EngineMessage.Id`, done with a whole-token script that skips strings and comments and never touches compound names. The alias checker shows 24 of 24 swapped lines are pure.
- **`updatedMediaIfNeeded` (both nodes):** now `(EngineMedia) -> EngineMedia?`, a `switch` on `.image`/`.file`. It used to take raw `Media` and test with `as? TelegramMediaImage` / `as? TelegramMediaFile`. Both classes are final and disjoint, and `EngineMedia.init` maps exactly those casts, so the same branch runs; the result is the `.image(...)`/`.file(...)` the caller used to build. Wave 441's `_asMedia()`/`EngineMedia(...)` in the two update loops is gone.
- **Three throwaway `Message(...)` builders** (the location preview in the two Instant View controllers, and the poll-attachment preview) became `EngineMessage(stableId:...)`. That initializer rebuilds `peers`/`associatedMessages` through dictionaries, but all three pass empty ones, so the result is the same empty `SimpleDictionary`. `author` (`.user(peer)`) and `media` (`.geo(map)`, `EngineMedia(attached)`) wrap the same objects. `LocationViewController` takes the engine message directly; the gallery's `.standaloneMessage` takes `message._asMessage()`, the object the old code wrapped.
- **Freed:** packages InstantPageUI, BrowserUI and ComposePollScreen; their deps were removed and they left `clients`.
- **Counts:** `AllowedImporters.txt` 126 -> 122; `clients` 62 -> 59.
- **Verification:** full build green (100 actions, then 2 after a whitespace-only touch-up); `InstantPageUITests` passed. BrowserUI and ComposePollScreen have no test target.

### Wave 444: preview builders and two chat-node locals (2026-10-12)

- **`ChatMessageInteractiveInstantVideoNode.swift`:**
  - The reply local is `EngineMessage?`, wrapped where it is read from `associatedMessages` and unwrapped for `ChatMessageReplyInfoNode.Arguments(message: EngineRawMessage?)`.
  - The forward-source local is `EnginePeer?`. It is wrapped at assignment, which moved the existing `flatMap(EnginePeer.init)` from its one reader to its one writer, and unwrapped for `ChatMessageAppliedForwardInfo(source: Peer?)`.
  - `StoryId` -> `EngineStoryId`.
- **`MediaPickerSelectedListNode.swift`:** the two "messages preview" builders use `EngineMessage(stableId:...)` with `peers: [peerId: .user(peer)]`. That is one entry, so no order exists to lose. The author and peer are the same `TelegramUser` object, and the media is `.action(...)`. `makeChatMessagePreviewItem` gets `_asMessage()`.
- **`ChatSendAudioMessageContextPreview.swift`:**
  - The contact and voice preview builders use `EngineMessage(...)`, with empty peer maps.
  - `ChatSendGroupMediaMessageContextPreview.messages` is `[EngineMessage]`, wrapping the same `withUpdatedTimestamp(0)` copies. Its one reader unwraps once per message, so `ChatMessageBubbleContentItem` receives identical objects.
  - `MediaId` -> `EngineMedia.Id`.
- **Freed:** packages MediaPickerUI, ChatSendAudioMessageContextPreview and ChatMessageInteractiveInstantVideoNode; their deps were removed and they left `clients`.
- **Counts:** `AllowedImporters.txt` 122 -> 119; `clients` 59 -> 56.
- **Verification:** full build green (100 actions). None of the three packages has a test target.

### Wave 445: PeerInfoMembers and EditAccessoryPanelNode (2026-10-12)

This is file-level progress; both packages still have other importers.

- **`PeerInfoMembers.swift`:**
  - `PeerInfoMember.legacyGroupMember` carries `EngineRenderedPeer` instead of `RenderedPeer`, built with `EngineRenderedPeer(peer: EnginePeer(peer))`, and the `peer` accessor no longer wraps.
  - `PeerId` and `PeerStoryStats` were swapped for their aliases.
  - **Equality is unchanged, which matters because `PeerInfoMember` is `Equatable` and drives list diffing.** `RenderedPeer.==` compares peers by `Peer.isEqual`, and `EngineRenderedPeer.==` by `EnginePeer.==`. Every peer class's `isEqual` is `self == other` (checked for all five classes), and `EnginePeer.==` matches on the same `==`. Both initializers build the same one-entry map with no associated media, so order cannot differ.
- **`EditAccessoryPanelNode.swift`:**
  - The stored message and the `updateMessage` parameter are `EngineMessage?`, wrapped where `postbox.messageAtId` delivers.
  - `updateMessage` unwraps once into a local named `message`, so its raw-API body runs on the same object.
  - `MessageId` was swapped for its alias.
- **Counts:** `AllowedImporters.txt` 119 -> 117.
- **Verification:** full build green (24 actions, then a rebuild after a whitespace-only touch-up). Neither package has a test target.

### Wave 446: ShareSearchContainerNode and ApplicationContext (2026-10-12)

File-level progress.

- **`ShareSearchContainerNode.swift`:** the local search results are wrapped at the source (`postbox.searchPeers(...) |> map { $0.map(EngineRenderedPeer.init) }`) instead of where entries are built.
  - The premium filter's `as? TelegramUser` became a `.user` case match. `EnginePeer.init` maps exactly `TelegramUser` to `.user`, so the same users match.
  - Entry building lost its `EnginePeer(...)` and `EngineRenderedPeer(...)` wraps, since the values already are those.
  - The array is the same, mapped element-wise, so order and filtering are unchanged.
- **`ApplicationContext.swift`:**
  - Two closure return-type annotations that spelled TelegramCore's `notificationMessages` element type (`[([Message], PeerGroupId, Bool, MessageHistoryThreadData?)]`) were removed. Swift infers the identical type.
  - `PeerId`, `MessageId` and `StoryId` were swapped for their aliases.
- **Counts:** `AllowedImporters.txt` 117 -> 115.
- **Verification:** full build green (147 actions). ShareController and TelegramUI have no test target.

### Wave 447: the rich-message preview builder (2026-10-12)

These two files were part of the May–October regression: `TelegramStringFormatting/Sources/InstantPagePreviewBuilder.swift` and `InstantPagePreviewText.swift`.

- **`InstantPagePreviewEnvironment.media`:** now `[EngineMedia.Id: EngineMedia]`. Its three `as? TelegramMediaFile` lookups go through a new `file(_:)` helper matching `.file`. `TelegramMediaFile` is final and `EngineMedia.init` maps exactly it to `.file`, so the same files are found.
- **Six public preview signatures** take `[EngineMedia.Id: EngineMedia]`. `InstantPage.previewAttributedText(associatedMedia:)` merges with `self.media` directly, with the same `uniquingKeysWith` rule, the same keys and the same objects.
- **The four callers** wrap `message.associatedMedia` with `.mapValues(EngineMedia.init)`: MessageContentKind, ChatListItemStrings, ForwardAccessoryPanelNode and ChatInputMessageAccessoryPanel. The Postbox-importing test (exempt) converts its fixture the same way.
- **Counts:** `AllowedImporters.txt` 115 -> 113. TelegramStringFormatting stays in `clients`, because `ServiceMessageStrings.swift` still imports Postbox.
- **Verification:** full build green (501 actions); `TelegramStringFormattingTests` and `ChatListUITests` passed.

### Wave 448: WalletContext and ShareWithPeersScreen (2026-10-12)

- **`WalletOperations.swift` and `WalletContextImpl.swift`:** both imported Postbox and named nothing from it. The classifier had flagged `Transaction`, which is WalletContext's own nested type (`typealias Transaction = WalletContext.Transaction`). The imports were dropped, and the build confirms they were unused.
- **`ShareWithPeersScreen.swift`:** the folder-preview `selectedMedia` local is `EngineMedia?` (`.image`/`.file`, chosen by the same `as?` tests), unwrapped for `DirectMediaImageCache.getImage(media:)`, which receives the same object.
- **Freed:** packages WalletContext (whose dep wave 438 had declared) and ShareWithPeersScreen; their deps were removed and they left `clients`.
- **Counts:** `AllowedImporters.txt` 113 -> 110; `clients` 56 -> 54.
- **Verification:** full build green (498 actions). Neither package has a test target.

### Wave 449: two regression files in TelegramUI (2026-10-12)

- **`TelegramUI/Sources/WalletTonConnect.swift`:**
  - `walletTonConnectRequestRoute` takes `EngineMessage` and unwraps once, leaving its body unchanged. `AppDelegate` drops the `._asMessage()` it had added, and `ChatController` wraps.
  - `PeerId` was swapped at its two real uses. The `MessageId` names in `WalletTonConnectNotificationQueue` are that struct's own generic parameter, so they were deliberately left alone. A whole-token swap would have broken them.
- **`ChatRecentActionsFilterController.swift`:**
  - The public `channelRecentActionsFilterController(peer:)`, which has no callers in the repository, and its private entries helper take `EnginePeer`. The helper's `as? TelegramChannel` became a `.channel` match.
  - `PeerId` was swapped for its alias (10 sites).
- **Counts:** `AllowedImporters.txt` 110 -> 108.
- **Verification:** full build green (24 actions). No test covers either function.

### Wave 450: the rich-message conversion package (2026-10-12)

This is the first half of the composer cluster, the core of the May–October regression.

- **`composeRichMessage(media:)`, `normalizedBlocks(media:)` and `buildInstantPage(media:)`** take `[String: EngineMedia]`. `pageMedia` is `[EngineMedia.Id: EngineMedia]` and goes straight into `InstantPage(media:)`. Nested pages no longer round-trip through `_asMedia()`.
  - `EngineMedia.id` equals the raw `.id` for every case: `.todo` and `.liveStream` return nil, as their raw classes do.
  - The location branch's `as? TelegramMediaMap` became `case let .geo(map)`. The first build caught the always-failing cast through `-warnings-as-errors`, which is exactly the safety net these retypes rely on.
- **The one external caller passing media** (`ChatControllerOpenAttachmentMenu.swift:1104`) wraps its dictionary with `.mapValues(EngineMedia.init)`. Wave 451 retypes that dictionary at its source.
- **Freed:** the RichTextEditorMessageConversion library; its dep was removed. The package moved from `clients` to `test_clients`, because `ButtonActionCodecTests` still imports Postbox.
- **Counts:** `AllowedImporters.txt` 108 -> 106.
- **Verification:** full build green (152 actions, after the cast fix); `RichTextEditorMessageConversionTests` passed.

### Wave 451: the composer bridges (2026-10-12)

This is the rest of the composer cluster: the media currency of the composer-to-article-editor handoff went from `[String: Media]` to `[String: EngineMedia]`.

- **Shape:** TelegramCore's `ChatInputMediaItem.media` stays raw. `DocumentChatInputContentBridge` converts exactly where it meets it (`ChatInputMediaItem(media: resolved._asMedia(), …)` in, `registerMedia(EngineMedia(item.media))` out). Everything above speaks `EngineMedia`:
  - `composerMediaKey`, `documentMediaAndEmoji(Async)` and `chatInputContent(fromDocument:media:)`;
  - the bridge's `resolveMedia`/`registerMedia` closures;
  - `RichTextEditorChatInputNode.mediaByID`;
  - `RichTextAttachmentScreen`'s public send, schedule and sync closures, `Subject` payloads, `attachedMedia` and `currentMedia`.

  The TextFormat and harness tests that build `ChatInputMedia` are untouched.
- **Identity:** `composerMediaKey`'s fallback for an id-less medium is `ObjectIdentifier(media._asMedia() as AnyObject)`, the same object as before. Using the wrapper enum there would have boxed a fresh object each time and changed the key.
- **Pick and preupload:**
  - The attachment pick path stores `.image`/`.file`/`.geo` of the same objects.
  - `preuploadPrimaryResource` is `(EngineMedia) -> TelegramMediaResource?` and returns the resources its `as?` tests found.
  - A preupload completion stores the cloud `EngineMedia` it already had, instead of unwrapping and rewrapping it.
- **Wraps removed:** the input node's media-view provider and media-control bridge, and `RichTextAttachmentScreen`'s preupload list and media-view resolution, had wrapped with `EngineMedia(...)`. They read the dictionary directly now, and wave 450's `.mapValues(EngineMedia.init)` in `ChatControllerOpenAttachmentMenu` is gone.
- **Persistence unchanged:** `ChatControllerOpenAttachmentMenu`'s `RichTextDraft` is persisted with Postbox coding, so it keeps raw storage. It converts when a draft is saved (`mapValues { $0._asMedia() }`) and when it is reopened (`mapValues(EngineMedia.init)`), so the stored bytes are unchanged. That file keeps importing Postbox for its decoder.
- **Freed:**
  - The ChatRichTextEditorComposer library: its dep was removed and the package moved to `test_clients`.
  - The RichTextAttachmentScreen package: its dep was removed and it left `clients`.
- **Counts:** `AllowedImporters.txt` 106 -> 102; `clients` 53 -> 51.
- **Verification:**
  - Full build green, after three compile-driven passes that each named a remaining boundary.
  - `ChatRichTextEditorComposerTests` and `RichTextEditorMessageConversionTests` passed.
  - The tests that call the bridge pass `[:]`, `nil` and `_ in`, which infer the new types.

### Wave 452: three local class-W files (2026-10-12)

Each wrapper retype stays inside its own file.

- **`ChatControllerLoadDisplayNode`** (TelegramUI):
  - typealias swaps (`PeerId`, `MessageId`, `MediaId`, `MessageIndex`, `MessageAttribute`);
  - the hidden-media local is now `[EngineMessage.Id: [EngineRawMedia]]`.

  That local exists only to be assigned to `ChatControllerInteraction.hiddenMedia`, which is declared with exactly that type, as `PeerInfoGifPaneNode` and `ChatListSearchMediaNode` declare the same local. Wrapping each medium in `EngineMedia` and unwrapping it on assignment would be a wrap/unwrap pair with no boundary, which is the case the EngineRaw-alias guidance allows.
  - One `MessageAttribute` token was missed by the swap script (its string-literal splitter lost parity on an interpolated string). It was fixed by hand. Every other swap count matched the classifier's hit lines exactly, so nothing extra was swapped.
- **`ChatQrCodeScreen`**: `Subject.messages([Message])` and `MessageContentNode.messages` are now `[EngineMessage]`.
  - The case is never constructed outside the file; the only external construction is `.peer`, in `SharedAccountContext`.
  - Member reads return the same values; `media` and `peers` are still raw-typed on `EngineMessage`.
  - `MessageReference(_:)` (×2) and `stringWithAppliedEntities(message:)`, which takes `EngineRawMessage?`, get `message._asMessage()`. That is the held object, so identity is unchanged.
  - It was the package's only importer: the dep was removed and the package left `clients`.
- **`ChatSearchResultsContollerNode`** (TelegramUI): `ChatListSearchEntry.message` is now `(EngineMessage, EngineRenderedPeer, EnginePeerReadCounters?, …)`. The three conversions `item(...)` made when building `ChatListItem` now happen where the entry is built: `EngineMessage(message)`, `EngineRenderedPeer(peer)` and `EnginePeerReadCounters(state:isMuted: false)`. Entry `==` is unchanged:
  - `id` and `stableVersion` read through to the raw message.
  - `EngineRenderedPeer ==` is `RenderedPeer ==` field for field: `peerId`, the peers through `EnginePeer ==` (each peer class's `isEqual` is its `==`), and `areMediaDictionariesEqual`.
  - `EnginePeerReadCounters` synthesizes `==` over `(state, isMuted)` with `isMuted` always false, so it reduces to the old `CombinedPeerReadState?` comparison.
  - `RenderedPeer(message:)` became `EngineRenderedPeer(message:)`, which wraps that very initializer. `RenderedPeer(peer:)` became `EngineRenderedPeer(peer: EnginePeer(…))`: the same `peerId`, one peer and empty `associatedMedia`.
- **Counts:** `AllowedImporters.txt` 102 -> 99; `clients` 51 -> 50.
- **Verification:** full build green on the first pass. None of the three has a test target.
- **Log correction:**
  - The `clients` counts in the entries for waves 439–451 were recounted from each commit's `submodules/Postbox/BUILD` and corrected in place.
  - Wave 439 installed the group with 67 packages, not 68, and every later entry had carried that off-by-one.
  - Wave 451 went 53 -> 51, because it removed two packages from `clients`.
  - The `AllowedImporters.txt` counts were already right.

### Wave 453: forward-info display and service-message strings (2026-10-12)

Two libraries whose last Postbox importer was a single class-W file.

- **`ChatMessageItemCommon`'s forward-info resolver:**
  - `ChatMessageAppliedForwardInfo.source` and the resolver's `peerDisplayTitle` closure are now `EnginePeer`.
  - The resolver wraps where it reads the raw forward info. The `author.id != forwardSource.id` test stays on the raw peers.
  - A cached `previouslyApplied.source` is returned as stored.
  - The five item-node callers lost their wraps:
    - each `{ EnginePeer(peer).displayTitle(…) }` became `{ peer.displayTitle(…) }`, since the wrap moved into the resolver;
    - every `forwardSource.flatMap(EnginePeer.init)` went, as did InteractiveInstantVideo's `.flatMap(EnginePeer.init)` / `?._asPeer()` round trip;
    - the Sticker and InstantVideoItem nodes' `EngineRawPeer?` locals became `EnginePeer?`.
  - The bubble's story-forward path wraps the raw peer it reads from `firstMessage.peers`.
- **`ServiceMessageStrings`:** the two private helpers take the `EngineMessage` every caller already held, in place of its `peers` / `associatedMedia`.
  - The lookups read the same dictionaries.
  - The peer-title overload now gets `[EnginePeer]`, built where the old one wrapped each peer at render time.
  - Plus two typealias swaps.
- **Tests:** `ChatMessageForwardInfoDisplayTests` changed in five lines:
  - its stand-in title function takes `EnginePeer`;
  - three applied-info fixtures wrap their peers;
  - one expected title is computed from `EnginePeer(admin)`.
- **Freed:** both libraries; their deps were removed. The packages moved from `clients` to `test_clients`, because their tests import Postbox.
- **Counts:** `AllowedImporters.txt` 99 -> 97; `clients` 50 -> 48.
- **Verification:** full build green on the first pass; `ChatMessageItemCommonTests` and `TelegramStringFormattingTests` (see the commit).

### Wave 454: reaction selection and the Stars transaction screen (2026-10-12)

Two packages whose only importer was one class-W file.

- **`ReactionContextNode`:** `animateReactionSelection(customEffectResource:)` (both overloads) and its `additionalAnimationResource` local are now `TelegramMediaResource?`, CLAUDE.md's preferred subtype.
  - No caller outside the file passes the parameter: all twelve rely on the `nil` default, and the internal overload only forwards its own argument.
  - The local is assigned only `TelegramMediaFile.resource` or that parameter.
  - Its one consumer, `AnimatedStickerResourceSource(account:resource:)`, takes `MediaResource`; the upcast hands over the same object.
  - Typealias swaps: `MediaId`, and `ItemCollectionId` (including `groupId.base as? EngineItemCollectionId`, the same cast through an identity alias).
- **`StarsTransactionScreen`:**
  - The three `openMedia` closure types (component, sheet component, `openMediaImpl`) are now `[EngineRawMedia]` / `(EngineRawMedia) -> …`. That media flows from a raw source into raw sinks: `StarsImageComponent.action` (already `EngineRawMedia`), `TelegramMediaPaidContent.extendedMedia` and the gallery's transition arguments. Wrapping it would be a wrap/unwrap pair with no boundary, the case the EngineRaw-alias guidance allows. The types are identical, so no call site changed.
  - The throwaway gallery message uses the memberwise `EngineMessage` init, with `media: [.paidContent(…)]` and empty `peers` / `associatedMessages`, and is passed as `message._asMessage()`. The init builds the same `Message`: the same media object, empty `SimpleDictionary`s, no author.
  - Plus one `MessageId` swap.
- **Freed:** both packages; their deps were removed and they left `clients`. Neither has a test target.
- **Counts:** `AllowedImporters.txt` 97 -> 95; `clients` 48 -> 46.
- **Verification:** full build green on the first pass.

### Wave 455: the auto-download predicates take EngineMedia (2026-10-12)

`TelegramUIPreferences`' only importer was `MediaAutoDownloadSettings.swift`.

- **Shape:** `shouldDownloadMediaAutomatically(…, media: EngineMedia?, …)`, `shouldPredownloadMedia(…, media: EngineMedia)` and the private `categoryAndSizeForMedia` take the wrapper.
  - The type tests became case matches: `.image` / `.webFile` for the `is` pair, `case let .file(file)` for the `as?`, and `default: nil` for the rest.
  - The sticker and voice tests became `if case let .file(file)? = media`.
  - `media?.id?.namespace` now reads `EngineMedia.id`.
  - The short-circuit order (`isAd`, network, sticker) is unchanged.
- **Equivalence of the case match:**
  - `TelegramMediaImage` and `TelegramMediaFile` are final.
  - `TelegramMediaWebFile` is not final, but nothing subclasses it.
  - `EngineMedia.init` dispatches by ordered `as` casts over unrelated classes, so a wrapped value is in exactly the case its class tested true for.
- **Call sites:** 32 of the 33, in 11 files, wrap their argument; the 33rd passes `nil`. Each argument's binding was checked first:
  - 26 values statically `TelegramMediaFile` / `TelegramMediaImage` (bound by `if let … as?`, `case let .file`, the renderer's typed `shouldAutoDownload*` closures or `PrefetchItem.animatedEmojiSticker`) take `.file(x)` / `.image(x)`;
  - `selectedFile!` takes `.file(selectedFile!)`;
  - the optional `selectedFile` takes `.flatMap(EngineMedia.file)`, keeping nil as nil;
  - the unwrapped `EngineRawMedia` `contentMediaValue` takes `EngineMedia(…)`.

  A script made the edits only on lines containing the call, asserting exactly one replacement per line, and the diff shows exactly 32 changed caller lines.
- **Also:** two typealias swaps each of `PeerId` and `PreferencesEntry`. Two blank-line indents the Edit tool stripped were restored.
- **Freed:** the TelegramUIPreferences package; its dep was removed and it left `clients`. It has no test target.
- **Counts:** `AllowedImporters.txt` 95 -> 94; `clients` 46 -> 45.
- **Verification:** full build green on the first pass.
- **Correction (post-review):** the `ChatMessageAttachedContentNode` call site wraps `contentMediaValue`, which can be one of three app-side link-preview pseudo-media classes. `EngineMedia.init` trapped on them, where the old raw predicate returned `isAd`. Fixed by `EngineCustomMedia` / `.custom`; see "Post-review fix" after wave 463.

### Wave 456: the animated-sticker and poll bubble packages (2026-10-12)

Two chat bubble packages whose only importer was one class-W file.

- **The convention these follow:**
  - The bubble content contract is already engine-typed with raw aliases: `ChatMessageBubbleContentNode.transitionNode(messageId: EngineMessage.Id, media: EngineRawMedia, …)` and `updateHiddenMedia(_: [EngineRawMedia]?)`, overridden with exactly those types by the bubble nodes freed earlier.
  - `ChatMessageReplyInfoNode.Arguments.message` is `EngineRawMessage?`.
  - Values flowing between those contracts and the item's raw message or media take the contract's own types: wrapping them would be wrap/unwrap pairs with no boundary.
- **`ChatMessagePollBubbleContentNode`:**
  - the two overrides take the base class's types;
  - the option node's `message`, `currentMedia`, `transitionNode(media:)`, `optionNodeForMedia` and the option layout closures take `EngineRawMessage` / `EngineRawMedia`;
  - plus `PeerId` / `MessageId` swaps.

  Every swap count matched the classifier's hit lines exactly (5, 4, 3, 1).
- **`ChatMessageAnimatedStickerItemNode`:**
  - `replyMessage` takes the `EngineRawMessage?` of the reply arguments it feeds.
  - `playEffectAnimation(resource:)` takes `TelegramMediaResource`. Its only callers are its own node's two sites, passing `file._parse().resource` and a video thumbnail's `resource`, and the body hands the resource to `AnimatedStickerResourceSource`, which takes `MediaResource`. `ChatMessageItemView`'s private method of the same name is unrelated.
  - Plus `StoryId`, `MemoryBuffer` and `MediaId` swaps.
- **Freed:** both packages; their deps were removed and they left `clients`.
- **Counts:** `AllowedImporters.txt` 94 -> 92; `clients` 45 -> 43.
- **Verification:** full build green on the first pass. Neither package has a test target.

### Phase 2026-10 exit inventory (after wave 456)

This is the state the spec's "Phase exit" asks for, and the input to the next phase's spec. It was measured on the committed tree at wave 456 (`ba5e4fdd5d`).

**Totals.**

| | baseline `8de02bc574` | after wave 456 |
|---|---|---|
| In-scope source files importing Postbox (`AllowedImporters.txt`) | 146 | 92 |
| Packages in `clients` | 67 (at the guard's install, wave 439) | 43 |
| Packages in `test_clients` | 4 | 8 |

**Update after wave 463.** The six signature files and the two no-decision files left the allowlist in waves 457–463. Totals are now 84 importers, 39 `clients` and 8 `test_clients`.

Class W is down to six files:
- the five heavy ones listed below;
- `ChatControllerOpenAttachmentMenu`, which is raw by design.

Classes R (9) and H (69) are unchanged.

**By class** (the heuristic classifier from the spec; each wave re-inventories its own files):

| Class | Files |
|---|---|
| T | 0 |
| W | 14 |
| R | 9 |
| H | 69 |

**The 28 May–October regression files.** 24 are clean. The other four stay, each for a recorded reason:
- `MediaEditor/Sources/MediaEditorDraft.swift` and `MediaEditorScreen/Sources/StorySource.swift`: class H, blocked by `OrderedItemListEntry`, which has no engine equivalent (next phase).
- `Telegram/SiriIntents/SiriSendMessageTarget.swift`: class H, blocked by `Transaction`; it runs a Postbox transaction directly (next phase).
- `TelegramUI/Sources/ChatControllerOpenAttachmentMenu.swift`: kept by design (wave 451). The persisted `RichTextDraft` is Postbox-coded and keeps its raw `[String: Media]` storage, so the file keeps `PostboxDecoder` / `PostboxEncoder` and the raw `Media` they code.

**Remaining class W (14), triaged for the next decision:**
- *Wrapper-local; no decision needed:*
  - `TelegramCallsUI/PresentationCallManager.swift`: `Peer` lives in private signal tuples that round-trip through `_asPeer()` / `EnginePeer(…)`. The package stays in `clients` (`PresentationGroupCall` is class R).
  - `ChatMessageItemImpl/ChatMessageDateHeader.swift`: needs a new `EngineMessage.AssociatedThreadInfo` typealias (rule 3 allows it; rule 4's discovery grep found none). Its `Peer` field has two external constructors (`ChatMessageItemImpl`, `SharedAccountContext`).
- *Needs the EngineRaw-or-defer decision.* Each has a public or cross-module signature whose wrapper retype would cascade:
  - `ChatMessageInteractiveMediaNode/ChatMessageInteractiveMediaNode.swift`: the public `asyncLayout` message and media parameters, called by the bubble nodes;
  - `PeerInfoVisualMediaPaneNode/PeerInfoVisualMediaPaneNode.swift`: its sibling copies in `PeerInfoGifPaneNode` and `ChatListSearchMediaNode` already use `EngineRawMessage` / `EngineRawMedia`;
  - `TelegramUI/Sources/OpenChatMessage.swift`, `TelegramUI/Sources/SharedAccountContext.swift`, `PeerInfoScreen/PeerInfoScreen.swift` and `MediaEditorScreen/MediaEditorScreen.swift`.
- *Heavy regardless:*
  - `ChatRecentActionsController/ChatRecentActionsHistoryTransition.swift` (177 hit lines; wave 71's analysis found 75 bridge sites);
  - `GalleryUI/Items/UniversalVideoGalleryItem.swift`;
  - `GalleryUI/Items/ChatAnimationGalleryItem.swift` and `ChatImageGalleryItem.swift`: `MediaResource` would likely become `TelegramMediaResource`, but check `setupStatus`'s callers. GalleryUI stays in `clients` regardless, because `GalleryController` is class R.
  - `TelegramUI/Sources/InChatPrefetchManager.swift`.
- *Raw by design:* `ChatControllerOpenAttachmentMenu.swift`.

**Blocking tokens across the 78 class R and H files** (number of files naming each):

| Files | Class | Token |
|---|---|---|
| 45 | H | `Postbox` (a `postbox: Postbox` parameter or stored handle; rule 2 forbids an alias) |
| 12 | H | `MediaBox` |
| 10 | R | `PostboxViewKey` |
| 7 | R | `MessageHistoryView` |
| 6 | H | `MediaBoxFetchPriority` |
| 6 | R | `PeerView` |
| 5 | H | `ChatListEntrySummaryComponents` |
| 4 | R | `OrderedItemListView`, `CachedPeerDataView` |
| 3 | H | `MediaResourceFetchParameters`, `MediaResourceStorageLocation`, `Transaction`, `ChatListFilterPredicate` |
| 3 | R | `MessageHistoryEntry`, `MutableMessageHistoryEntryAttributes` |
| 2 | H | `ChatListView`, `PeerIndexNameRepresentation`, `PendingMessageActionType`, `ChatListEntryMessageTagSummaryComponent`, `ChatListEntryPendingMessageActionsSummaryComponent`, `ChatListEntryMessageTagSummaryKey`, `PeerPresencesView`, `CombinedView`, `OrderedItemListEntry`, `StoryStatesView`, `PeerNotificationSettings`, `AdditionalMessageHistoryViewData`, `MediaBoxFileContextV2Impl` |
| 2 | R | `MessageHistoryThreadIndexView`, `ChatInterfaceStateView`, `MessageHistorySavedMessagesIndexView`, `ItemCollectionItem`, `BasicPeerView`, `CachedMediaResourceRepresentation` |
| 1 | H | `setValueBoxStrictErrorHandling`, `stringIndexTokens`, `matchStringIndexTokens`, `ChatListMessageTagSummaryResultComponent`, `ChatListMessageTagActionsSummaryResultComponent`, `ChatListMessageTagSummaryResultCalculation`, `arePeersEqual`, `MessageView`, `ItemCollectionInfoView`, `StoryView`, `StoryItemsView`, `TypingDraftsView`, `PeerAndThreadId`, `HistoryView`, `MessageHistoryViewOrderStatistics`, `MultiplePeersView`, `PeerStoryStatsView` |
| 1 | R | `CombinedReadStateView`, `ItemCollectionInfo`, `MediaResourceDataFetchCopyLocalItem` |

**Class R and H files with their blocking tokens.**

Class R (9):
- `FeaturedStickersScreen/FeaturedStickersScreen.swift`: `ItemCollectionInfo ItemCollectionItem`
- `GalleryUI/GalleryController.swift`: `MessageHistoryEntry MessageHistoryView MutableMessageHistoryEntryAttributes`
- `PremiumUI/PremiumIntroScreen.swift`: `OrderedItemListView PostboxViewKey`
- `StatisticsUI/ChannelStatsController.swift`: `MessageHistoryView`
- `TelegramCallsUI/PresentationGroupCall.swift`: `PeerView`
- `EntityKeyboard/EmojiPagerContentSignals.swift`: `OrderedItemListView`
- `StickerPickerScreen/StickerPickerScreen.swift`: `OrderedItemListView PostboxViewKey`
- `TelegramUI/Sources/ChatController.swift`: `PeerView`
- `TelegramUI/Sources/ChatHistoryEntriesForView.swift`: `MessageHistoryView`

Class H (69), by area:
- **Media pipeline (`Postbox` handle / `MediaBox`):**
  - MediaPlayer: `ChunkMediaPlayer`, `ChunkMediaPlayerV2`, `FFMpegFileReader`, `FFMpegMediaFrameSource`, `FFMpegMediaFrameSourceContext`, `MediaPlayer`, `MediaPlayerFramePreview`, `TimeBasedVideoPreload`, `UniversalSoftwareVideoSource`.
  - TelegramUniversalVideoContent: `NativeVideoContent`, `PlatformVideoContent`, `SystemVideoContent`, `WebEmbedVideoContent`, and `HLSVideoContent` / `HLSVideoJSNativeContentNode`, which also name `MediaBoxFileContextV2Impl`, `MediaResourceFetchParameters` and `MediaResourceStorageLocation`.
  - `AccountContext/UniversalVideoNode`, `AccountContext/FetchMediaUtils` (`MediaBoxFetchPriority`), `FetchManagerImpl` (`MediaBoxFetchPriority`), `FetchVideoMediaResource` (`MediaBoxFetchPriority`, `MediaResourceDataFetchCopyLocalItem`), `PhotoResources` (`MediaBox`, `MediaBoxFetchPriority`), `StickerResources` (`MediaBox`, `CachedMediaResourceRepresentation`, `ItemCollectionItem`), `DirectMediaImageCache` (`MediaBox`).
  - TelegramUI: `FetchCachedRepresentations` (`CachedMediaResourceRepresentation`), `StoreDownloadedMedia`, `TransformOutgoingMessageMedia`, `DocumentPreviewController`.
- **Avatars, stickers and emoji (`Postbox` handle):** `AvatarNode`, `PeerAvatar`, `TelegramAnimatedStickerNode`, `EmojiStatusComponent`, `EmojiTextAttachmentView`, `EntityKeyboard/InlineFileIconLayer`, `ChatEntityKeyboardInputNode` (`ItemCollectionInfoView`, `OrderedItemListView`, `PostboxViewKey`), `LegacyPaintStickersContext`.
- **Media editor:** `MediaEditorComposer`, `MediaEditorComposerEntity`, `MediaEditorVideoExport` (all `Postbox`), `MediaEditorDraft`, `StorySource` (`OrderedItemListEntry`).
- **Presentation data:** `ChatControllerBackgroundNode`, `MakePresentationTheme`, `PresentationData` (`MediaBox`); `ChatMessageBubbleItemNode` (`MediaBox`).
- **Chat list (views and summary components):** `ChatListController`, `ChatListSearchListPaneNode`, `ChatListNodeLocation` (15 tokens, from `ChatListView` / `PostboxViewKey` / the summary components), and `ShareController` / `ShareControllerNode` (the same family, plus `Postbox`).
- **Chat history:** `ChatHistoryListNode`, `ChatHistoryViewForLocation`, `ChatControllerNode`, `ChatControllerContentData`, `CreateGroupController` (`MultiplePeersView`), `ChatPresentationInterfaceState` (`arePeersEqual`), `SecretMediaPreviewController` (`MessageView`, history-entry types).
- **Stories:** `StoryChatContent` (`StoryView`, `StoryItemsView`, `StoryStatesView`, `PeerPresencesView`, `CombinedView`, `Transaction`, …).
- **Extensions and app:**
  - `Telegram/NotificationService/NotificationService.swift`: `MediaBox`, the fetch parameters, `Postbox`, `setValueBoxStrictErrorHandling`.
  - SiriIntents: `IntentContacts` (`Postbox`, `Transaction`), `IntentHandler` (`MediaBox`), `IntentMessages` (`ChatListView`, `MessageHistoryView`, `Postbox`), `SiriSendMessageTarget` (`Transaction`).
  - `TelegramUI/Sources/AppDelegate.swift` (`Postbox`).
- **Other `Postbox` handles:** `PassportUI` (`LegacySecureIdAttachmentMenu`, `SecureIdLocalResource`), `ShareItems`, `TelegramPermissionsUI/PermissionSplitTest`, `TelegramAccountAuxiliaryMethods`, and `TemporaryCachedPeerDataManager` (`ChannelMemberCategoryListContext`, which also names `PeerStoryStatsView` / `PostboxViewKey`, and `PeerChannelMemberCategoriesContextsManager`).

**`.postbox` access outside TelegramCore and Postbox, non-test, comments stripped.** This is the next phase's metric. Measured with four spellings; the spec's baseline of 257 files used a spelling that was not recorded, so these are not a delta against it:

| Spelling | Files | Sites |
|---|---|---|
| `account.postbox` (any use, including passing the handle on) | 224 | 573 |
| `.postbox.<member>` | 142 | 392 |
| `account.postbox.<member>` | 124 | 306 |
| any `postbox` identifier | 268 | 1591 |

Of the 142 files with a `.postbox.<member>` access, 95 do not import Postbox.

By member (`.postbox.<member>`, 392 sites):

| Sites | Member |
|---|---|
| 234 | `mediaBox` |
| 49 | `transaction` |
| 29 | `peerView` |
| 23 | `combinedView` |
| 11 | `itemCollectionsView` |
| 8 | `aroundMessageHistoryViewForLocation` |
| 8 | `messagesAtIds` |
| 7 | `messageAtId` |
| 4 | `clearCaches` |
| 3 | `tailChatListView`, `searchPeers`, `messageView`, `multiplePeersView` |
| 2 | `setCanBeginTransactions` |
| 1 | `seedConfiguration`, `optimizeStorage`, `addHiddenChatIds`, `unsentMessageIdsView`, `searchContacts` |

By `.postbox.mediaBox.<member>`:

| Sites | Member |
|---|---|
| 60 | `resourceData` |
| 23 | `cachedResourceRepresentation` |
| 20 | `storeResourceData` |
| 19 | `completedResourcePath` |
| 6 | `cancelInteractiveResourceFetch` |
| 4 | `cacheStorageBox` |
| 3 | `cachedRepresentationCompletePath`, `storageBox` |
| 2 | `moveResourceData`, `internal_resourceDataIsCached`, `fetchedResource`, `storeCachedResourceRepresentation`, `basePath` |
| 1 | `cachedRepresentationPathForId`, `resourceStatus`, `resourceRangesStatus`, `resourcePath` |

**Known gap:** nothing flags an *orphan* Postbox dep, meaning a package that declares the dep while no source of its own imports it. The visibility group only rejects packages outside the list.

### Continued after the 2026-10-12 decision: the class-W signature files, with wrappers

The exit inventory above handed back one decision: whether the six class-W files with a raw type in a public or cross-module signature take an `EngineRaw*` alias or a real wrapper retype through their callers. The user chose the second ("prefer to do new wrappers").

The waves below therefore type those signatures as `EngineMessage` / `EngineMedia` / `EnginePeer` even where that adds a wrap at the caller and an unwrap at the callee. A new wrapper type is added only where no existing wrapper or non-raw alias fits, and none was needed in this batch.

The `EngineRaw*` sinks from waves 452, 454 and 456 (`ChatControllerInteraction.hiddenMedia`, `updateMessageReaction`, `playMessageEffect`, the bubble `transitionNode` / `updateHiddenMedia` overrides) stay as they are in this batch. A file freed here unwraps at those boundaries.

### Wave 457: `PresentationCallManager` (2026-10-12)

One of the two remaining class-W files that needed no decision: its `Peer` lived only in private signal tuples.

- **The ringing-state tuples** `(AccountContext, Peer, CallSessionRingingState, Bool, NetworkType)` carry `EnginePeer` (five spellings: four signal types and `ringingStatesUpdated`'s parameter).
  - The producer passes the `EnginePeer` it got from `engine.data.get(…Item.Peer.Peer…)` instead of `peer._asPeer()`.
  - The two `PresentationCallImpl(peer:)` sites pass `firstState.1` instead of `EnginePeer(firstState.1)`. That is the same enum over the same payload, since `EnginePeer(p._asPeer())` re-wraps the peer `p` holds.
  - `firstState.1.id` reads the same `PeerId`.
- **The start-call transaction** returns `(EnginePeer?, String?)` from `transaction.getPeer(peerId).flatMap(EnginePeer.init)`.
  - Its consumer's `peer as? TelegramUser` became `case let .user(peer) = peer`. `EnginePeer.init` maps `TelegramUser` to `.user`, so the two match exactly the same values.
  - `debugDisplayTitle` is public on `EnginePeer` and returns `_asPeer().debugDisplayTitle`.
  - The `postbox.transaction` call itself stays. It names no Postbox type (the closure's parameter is inferred), so it is a `.postbox` site for the next phase, not a class-W blocker.
- **Swaps:** 11 `PeerId` spellings became `EnginePeer.Id`.
- **Freed:** the file. `TelegramCallsUI` stays in `clients` because `PresentationGroupCall` is class R.
- **Counts:** `AllowedImporters.txt` 92 -> 91; `clients` 43.
- **Verification:** full build green on the first pass. `TelegramCallsUITests` passed (16 tests, 0 failures). It covers `SharedCallAudioContext`, not this file, but the package changed.

### Wave 458: `ChatMessageInteractiveMediaNode` (2026-10-12)

The media node's public layout signature carried a raw message and media into the two bubble nodes that host it.

- **The signature.** Both `asyncLayout` forms take `EngineMessage` / `EngineMedia`: the instance form, called by `ChatMessageMediaBubbleContentNode`, and the static `asyncLayout(_:)`, called by `ChatMessageAttachedContentNode`.
  - The two callers wrap: `EngineMessage(item.message)` with `EngineMedia(selectedMedia!)`, and `EngineMessage(message)` with `EngineMedia(contentMediaValue)`. The force unwrap is unchanged.
  - The layout closure binds the parameters as `engineMessage` / `engineMedia` and unwraps them once into the `message` / `media` locals the rest of the body already used. The body, including every comparison against the previous layout, therefore runs on the same raw objects as before:
    - `isSemanticallyEqual(to:)`, the story-entry `!=`, `flags !=`, `id !=`;
    - every `as?` cast.
  - The apply step stores the wrappers it received.
- **The stored `message` / `media`** became `EngineMessage?` / `EngineMedia?`. Every read unwraps with `?._asMessage()` / `?._asMedia()`, which returns the identical object. That includes the 14 + 13 explicit `self.`/`strongSelf.` reads and the snapshot of the previous layout (`currentMessage`, `currentMedia`).
  - **Four reads used implicit `self`** (`media as? …` in `hitTest`'s sending branch, and three in `updateStatus` outside the scope of its `var media` local). The first build caught all four as always-failing casts under `-warnings-as-errors`. They now unwrap explicitly.
  - Every other bare `media` / `message` read outside the layout closure was checked to be a local. That includes two `media?.id == mediaId` comparisons that would have compiled silently against `EngineMedia`.
- **`selectStoryMedia`** returns `EngineMedia?` (a private helper whose return type must be named). Its six callers unwrap. A story item's media is an image or a file, both covered by `EngineMedia.init`.
- **The closures.** `updateMessageReaction` / `playMessageEffect` take `EngineMessage`.
  - The node's one invocation passes the stored wrapper.
  - The four setters in the two bubble nodes forward `message._asMessage()` to `ChatControllerInteraction`'s `EngineRawMessage` sinks, which stay as they are in this batch.
  - `updateMessageReaction` is set but never invoked by the node.
- **Swaps:** 21 `MediaResourceStatus` spellings became `EngineMediaResourceStatus`, and 3 `MediaId` became `EngineMedia.Id`.
- **Cost:** one `EngineMessage` allocation per layout pass from the bubble callers, beside the layout work itself.
- **Freed:** `ChatMessageInteractiveMediaNode`; its dep was removed and it left `clients`.
- **Counts:** `AllowedImporters.txt` 91 -> 90; `clients` 43 -> 42.
- **Verification:** full build green on the second pass, after fixing the four implicit reads. The package has no test target.
- **Correction (post-review):** the layout call in `ChatMessageAttachedContentNode` wraps `contentMediaValue`, which can be an app-side `WallpaperPreviewMedia`, `UniqueGiftPreviewMedia` or `GiftAuctionPreviewMedia`. `EngineMedia` had no case for those, so `EngineMedia.init` trapped on wallpaper, theme, NFT-gift and gift-auction link previews. The "Review Focus 3" check missed them because it grepped only `: Media`. Fixed by `EngineCustomMedia` / `.custom`; see "Post-review fix" after wave 463.

### Wave 459: `PeerInfoVisualMediaPaneNode` (2026-10-12)

The shared-media grid pane. Its sibling copies in `PeerInfoGifPaneNode` and `ChatListSearchMediaNode` had taken `EngineRawMessage` / `EngineRawMedia`. This one takes the wrappers, per the decision above.

- **The grid item.** `VisualMediaItem.message` is an `EngineMessage`. The list mapping wraps the raw history entry once.
  - Reads that only need `id`, `stableId`, `index` or `timestamp` read them through the wrapper, which forwards each to the same `Message`.
  - Reads that hand the message to a raw API unwrap with `_asMessage()`: `ListMessageItem(message:)`, `isSensitiveContent`, the cell renderer's `let message = …`, and `ChatControllerInteraction.openMessage` / `openMessageContextActions`.
  - `messageAtPoint` and `findLoadedMessage(id:)` used to wrap a fresh `EngineMessage` per call and now return the stored one. It is the same `Message` underneath, and `EngineMessage ==` compares fields.
- **The item interaction** (private): `openMessage` / `openMessageContextActions` take `EngineMessage`, and its closures unwrap into the raw sinks. Neither closure is invoked anywhere.
- **Hidden media.** `hiddenMedia` is `[EngineMessage.Id: [EngineMedia]]`, and the gallery-hidden-ids handler wraps each media once. The values are never read; the two uses test key presence.
- **The cell's media.** `selectedMedia` is `EngineMedia?`, assigned `.image(image)`, `.image(cover)` or `.file(file)`.
  - It is unwrapped by the `if let` that feeds `DirectMediaImageCache`. Every later cast is inside that binding, so it sees the same raw object as before.
  - `videoCover` is `TelegramMediaImage?`.
- **The two shimmer fake messages** use the memberwise `EngineMessage` initializer: `media: [.file(fakeFile)]`, empty `peers` / `associatedMessages`. The result is the same `Message` graph, as in wave 454. `ListMessageItem` gets `_asMessage()`.
- **The stored-state key** is built with `EngineDataBuffer(length:)` (an alias of `ValueBoxKey`), so it holds the same bytes.
- **Swaps:** 8 `MessageTags`, 8 `MessageId`, 10 `PeerId` and 2 `MediaId` spellings became their engine aliases.
- **First build:** one error. `findLoadedMessage(id:)` returned `EngineMessage(item.message)`, which no longer type-checks, and now returns `item.message`.
- **Freed:** `PeerInfoVisualMediaPaneNode`; its dep was removed and it left `clients`.
- **Counts:** `AllowedImporters.txt` 90 -> 89; `clients` 42 -> 41.
- **Verification:** full build green on the second pass. The package has no test target.

### Wave 460: `PeerInfoScreen` (2026-10-12)

The profile screen's last raw spellings, none of them in a cross-module signature once read closely.

- **The Instant View gallery message.** `foundGalleryMessage` is `EngineMessage?`.
  - Both lookups already return `EngineMessage` (`messageForGallery`, `findLoadedMessage`), so their `_asMessage()` calls went. `ensureMessagesAreLocallyAvailable` was already fed the wrapper.
  - `makeInstantPageController` (still `EngineRawMessage` in the `SharedAccountContext` protocol until wave 462) gets `_asMessage()`. That is the same object it got before.
- **Hidden gallery media.** The handler builds `[EngineMessage.Id: [EngineMedia]]` and assigns `hiddenMedia.mapValues { $0.map { $0._asMedia() } }` to `ChatControllerInteraction.hiddenMedia`, which stays `[EngineMessage.Id: [EngineRawMedia]]` in this batch.
  - The dictionary that lands there holds the same media objects under the same keys.
  - It runs only when the hidden-id set changes.
- **Clear history.**
  - `openClearHistory`'s raw `peer` parameter was never read (its body uses `chatPeer` only), so it was removed with its three arguments in `PeerInfoScreenPerformButtonAction`.
  - `ClearPeerHistory.init` takes `peer: EnginePeer` (it reads only `peer.id`) and `cachedData: EngineCachedPeerData?`. Its three callers wrap the user, channel or group they already had.
- **The location screen's synthesized message** uses the memberwise `EngineMessage` initializer: `author: peer` (the `EnginePeer` it unwrapped before) and `media: [.geo(map)]`. It is handed to `LocationViewController(subject:)` directly instead of being wrapped after construction.
- **Swaps:** 1 `MessageTags`, 10 `MessageId`, 11 `PeerId`, 2 `MediaId` and 2 `CachedPeerData` spellings became engine aliases (`EngineCachedPeerData` is an existing alias, not a raw one).
- **Freed:** `PeerInfoScreen`; its dep was removed and it left `clients`.
- **Counts:** `AllowedImporters.txt` 89 -> 88; `clients` 41 -> 40.
- **Verification:** full build green on the first pass. The package has no test target.

### Wave 461: `ChatMessageDateHeader` and `makeChatMessageAvatarHeaderItem` (2026-10-12)

The chat's avatar header. Its item and node held a raw `Peer`, and the item took a raw `Message`; one `SharedAccountContext` factory passes both through.

- **New alias (rule 3 allows typealiases; rule 4's discovery grep found none):** `EngineMessage.AssociatedThreadInfo = Message.AssociatedThreadInfo`, beside `EngineMessage`'s other nested aliases. The date header's `.thread(id:info:)` case uses it.
- **The header item.** `ChatMessageAvatarHeader.peer` is `EnginePeer?`. Its init takes `peer: EnginePeer?` and `message: EngineMessage`, and unwraps the message once into a local. Its body reads the same raw fields: `adAttribute`, `id`, `timestamp`, `forwardInfo`.
- **The header node.** `peer` is stored as `EnginePeer?`. `updatePeer(peer:)` and `setPeer(…peer:…)` take `EnginePeer` (external label unchanged, internal name `enginePeer`) and unwrap it into a raw `peer` local.
  - Their bodies therefore compare and read exactly as before: `nameColor`, `smallProfileImage`, `displayLetters`, `isDeleted`, `isPremium`, `largeProfileImage`, `id`.
  - The previous peer is unwrapped too.
  - The `EnginePeer(peer)` re-wraps inside those two methods now pass the `enginePeer` they received, which wraps the same payload.
  - The two other reads of the stored peer unwrap: the context-menu gesture, into `openPeerContextMenu`'s `EngineRawPeer`, and the tap handler, into its `as? TelegramChannel` test.
  - Every bare `peer` in the node class was listed, and each was confirmed to be a local of `updatePeer` / `setPeer`.
- **The protocol.** `SharedAccountContext.makeChatMessageAvatarHeaderItem` takes `peer: EnginePeer, message: EngineMessage` (was `EngineRawPeer` / `EngineRawMessage`).
  - `SharedAccountContextImpl` passes both straight to the header.
  - `DrawingMessageRenderer`, its only caller, drops its `_asPeer()` / `_asMessage()`.
  - `ChatMessageItemImpl` wraps the effective author and the message when it builds the header: two small allocations per item that has an avatar header.
- **The harness stub.** The composer harness's generated `HarnessSharedAccountContext` stub was regenerated with its tool. Run against HEAD's protocol, the tool first reproduced the committed stub exactly, except for the source path in the header comment. The change is the one member's signature.
- **Swaps:** 5 `PeerId`, 1 `MessageId` and 5 `PeerStoryStats` spellings became their engine aliases.
- **Freed:** `ChatMessageItemImpl`; its dep was removed and it left `clients`.
- **Counts:** `AllowedImporters.txt` 88 -> 87; `clients` 40 -> 39.
- **Verification:**
  - Full build green on the first pass.
  - `//Tests/ComposerHarness:ComposerHarness` built separately, because the app build does not compile it.
  - The package has no test target.

### Wave 462: `OpenChatMessage` and the rest of `SharedAccountContext` (2026-10-12)

Three `SharedAccountContext` members still carried a raw message or peer: two of their protocol requirements were `EngineRawMessage` / `EngineRawPeer`, and the TelegramUI implementations were spelled `Message` / `Peer`.

- **`makeInstantPageController(context:message:sourcePeerType:)` and `openChatWallpaper(context:message:present:)`** take `EngineMessage`. So do `makeInstantPageControllerImpl`, `openChatWallpaperImpl` and `openChatTheme`, which are TelegramUI-internal.
  - `makeInstantPageControllerImpl` passes the message straight to `instantPageAndAnchor(message:)`, which already took the wrapper.
  - The wallpaper and theme functions unwrap once into a local, because their bodies hand the raw message to `WallpaperListSource` and read `message.media`.
- **Their callers:**
  - **ChatController's three handlers** (`openInstantPage`, `openWallpaper`, `openTheme`) bound `messageInCurrentHistoryView(id)?._asMessage()` only to feed these calls. They now bind the `EngineMessage` itself.
  - **The other sites wrap a raw message:** ChatController's `openUrl` (`Message?` parameter), ChatRecentActions (×2) and the chat-list search pane.
  - **PeerInfoScreen** drops its `_asMessage()` from wave 460.
- **`makeChatMessagePreviewItem`** takes `messages: [EngineMessage]`, `tapMessage: ((EngineMessage) -> Void)?` and `accountPeer: EnginePeer?`.
  - The implementation unwraps the messages once into the local it already used.
  - It wraps the raw message `ChatControllerInteraction` hands its two tap closures.
  - It passes `accountPeer` through where it used to `flatMap(EnginePeer.init)` it.
- **The 26 preview call sites in 16 files** were rewritten inside each call's own parenthesis-balanced extent, by a script that refuses any argument shape it does not know:
  - 6 had unwrapped an `EngineMessage` with `_asMessage()` or `map { $0._asMessage() }`, and now pass it directly;
  - 18 wrap a raw message;
  - 2 wrap an inline `EngineRawMessage(...)` constructor;
  - 2 non-nil `accountPeer` arguments wrap with `flatMap(EnginePeer.init)`.

  The only two non-nil `tapMessage` closures ignore their argument.
- **Swaps in `SharedAccountContext.swift`:**

  | Raw spelling | Engine spelling | Count |
  |---|---|---|
  | `PeerId` | `EnginePeer.Id` | 19 |
  | `MessageId` | `EngineMessage.Id` | 10 |
  | `MessageIndex` | `EngineMessage.Index` | 2 |
  | `HistoryViewInputTag` | `EngineHistoryViewInputTag` | 2 |
  | `ValueBoxEncryptionParameters` | `EngineValueBoxEncryptionParameters` | 1 |
  | `CachedMediaResourceRepresentationResult` | `EngineCachedMediaResourceRepresentationResult` | 1 |

  Plus one `MessageId` in `OpenChatMessage.swift`.
- **The harness stub** was regenerated; it changed in exactly the three members' signatures.
- **Freed:** `OpenChatMessage.swift` and `SharedAccountContext.swift`. TelegramUI stays in `clients` (it has class R and H files).
- **Counts:** `AllowedImporters.txt` 87 -> 85; `clients` 39.
- **Follow-up, not done here:** none of the preview callers imports Postbox. The ones that build a fake message do it through the `EngineRawMessage` alias: BubbleSettings, TextSize, the theme previews, WallpaperGalleryItem, ForwardPrivacyChatPreviewItem, ReactionChatPreviewItem, ChatGiftPreviewItem and the other preview items. Moving them to the memberwise `EngineMessage` initializer would retire those aliases, as an `EngineRaw`-reduction wave.
- **Verification:** full build green on the first pass; `//Tests/ComposerHarness:ComposerHarness` built separately.

### Wave 463: `MediaEditorScreen` (2026-10-12)

The story editor's message/gift preview and its sticker-save path.

- **The preview's message list** is a `Signal<[EngineMessage], NoError>`.
  - The message-subject branch appends the `EngineMessage`s that `engine.data.get` returns, instead of unwrapping them.
  - The gift branch builds its synthesized message with the memberwise `EngineMessage` initializer: `media: [.action(TelegramMediaAction(…starGiftUnique…))]`, empty `peers` / `associatedMessages`. That is the same `Message` graph as before (the wave 454 pattern).
  - The consumer's `messages.first?.media.first(where:)` reads `EngineMessage.media`, which is the same raw `[Media]`.
  - `DrawingMessageRenderer(messages:)` takes the list as is, where it used to re-wrap every element.
- **`performSave(toStickerResource:)`** takes `TelegramMediaResource?`.
  - Its one non-nil caller passes `file.resource` of a `TelegramMediaFile`.
  - The body reads only `toStickerResource != nil` and `toStickerResource.id` (into `EngineMediaResource.Id`).
- **Swaps:** 1 `MessageId` and 1 `MediaId` spelling became their engine aliases.
- **Freed:** `MediaEditorScreen.swift`. The package stays in `clients`, because `StorySource.swift` is class H (`OrderedItemListEntry`).
- **Counts:** `AllowedImporters.txt` 85 -> 84; `clients` 39.
- **Verification:** full build green on the first pass. The package has no test target.

### Post-review fix: `EngineCustomMedia` (2026-10-12)

A fresh reviewer over waves 451–463 found one **critical** defect.

- **The defect.** `ChatMessageAttachedContentNode` wraps its content media with `EngineMedia(contentMediaValue)` twice: for the auto-download predicate (wave 455) and for the media node's layout (wave 458).
  - That value can be one of three app-side pseudo-media classes: `WallpaperPreviewMedia`, `UniqueGiftPreviewMedia` or `GiftAuctionPreviewMedia`.
  - `ChatMessageWebpageBubbleContentNode` builds them for `telegram_background`, `telegram_theme`, `telegram_nft` and `telegram_auction` link previews, and the attached-content node forces them onto the non-inline branch.
  - They conformed to `EngineRawMedia`, and `EngineMedia` had no case for them. So `EngineMedia.init` reached `preconditionFailure()`, which traps in release too, as soon as such a bubble was laid out.
  - The check that should have caught it (`grep -rn ': Media\b'`, in CLAUDE.md and in this log) cannot see a `: EngineRawMedia` conformance.
- **The fix, choosing a wrapper over reverting to `EngineRawMedia`, per the user's "prefer new wrappers":**
  - TelegramCore declares `public protocol EngineCustomMedia: Media`.
  - `EngineMedia` gains `case custom(EngineCustomMedia)`. `init` maps an `EngineCustomMedia` to it before the trapping default, so any other unknown class still traps. `id` returns the payload's id, and `_asMedia()` returns the payload object.
  - The three preview classes now conform to `EngineCustomMedia` instead of `EngineRawMedia`.
  - **`==`:** the existential payload ends Equatable synthesis, so `EngineMedia.==` is hand-written. It applies the synthesized rule to every existing case: same case, payloads compared with `==`. `.custom` compares with `isEqual(to:)`, a relation that never existed before because these values could not be wrapped.
- **Why this restores the old behaviour exactly at both sites:**
  - **The predicate:** `.custom` falls into `categoryAndSizeForMedia`'s `default: return nil`, so for these previews the result is `isAd` again, as the raw path computed it before wave 455.
  - **The media node:** its layout closure unwraps with `_asMedia()`, which returns the original object. The node's existing `WallpaperPreviewMedia` / `UniqueGiftPreviewMedia` / `GiftAuctionPreviewMedia` branches see it unchanged.
  - **The reviewer's minor trap surfaces close too:** the gallery-hidden-ids wraps (459/460) and the media bubble's `EngineMedia(selectedMedia!)` (458) can no longer trap on these classes.
- **No other exhaustive `switch` over `EngineMedia`** exists outside `Media.swift`, in sources or tests, so nothing else changed. No test target references a signature changed in waves 451–463, which closes the reviewer's "declined to judge" item on test compilation.
- **Docs:** CLAUDE.md's `EngineMedia` note and this log's wrapper-inventory sentence now name `EngineCustomMedia`, and give a grep that covers all three conformance spellings. Waves 455 and 458 carry correction pointers.
- **Ruling: no failing test first.** A `preconditionFailure` cannot be caught in an XCTest, and neither package has a test target. Equivalence is shown in the diff above. Cost if wrong: a small wave instead puts `EngineRawMedia` back at the media node and adds a call-site guard at the predicate.
- **Verification:** full build green.

### Phase: `.postbox` access and MediaBox calls

- **Spec and plan:** working documents, not kept on master. Their decisions follow, and the waves record the rest.
- **Decisions taken with the user:**
  - MediaBox calls first;
  - a second shrink-only file list for `.postbox` access;
  - one MediaBox member family per wave;
  - UI-specific types stay out of TelegramCore (`EngineCustomMedia` stays; representations get an engine protocol);
  - a call whose result must feed raw-typed code is deferred and recorded, not converted.

### Wave P1: the `.postbox` access guard (2026-10-12)

- **The check.** `build-system/Make/PostboxImportCheck.py` checks a second list, `submodules/Postbox/AllowedPostboxAccess.txt`, in the same run as the import list.
  - It has the same scope rules, and the same messages for duplicate, unsorted, out-of-scope, stale and missing entries.
  - An unlisted user of `.postbox` fails with `<path>:<line>: uses .postbox, …`.
  - Make.py's existing call (`PostboxImportCheck.run`) picks it up with no change.
- **Detection.** `strip_comments_and_strings` blanks `//` comments, nested `/* */` comments and string literals, triple-quoted ones included, while keeping newlines. It keeps the code inside string interpolation, so `"\(account.postbox.mediaBox.basePath)/x"` counts as access and a `.postbox` mention in a comment or log string does not.
- **`--report`** prints the measures every wave records:
  - importers;
  - files on the access list;
  - handle sites (`.postbox` with no member called);
  - `.postbox.mediaBox` sites, by member;
  - MediaBox-only files.
- **Tests:** 23 → 36 in `build-system/Make/tests` (detection, scope, list rules, both lists in one pass, report).
  - A mutation run on a scratch copy checked that each key test catches its fault: interpolation treated as a string, line comments kept, strings kept, block comments not nested, stale access entries ignored, handle sites miscounted.
  - It showed that the plan's nested-comment case did not catch a non-nesting stripper, because the `.postbox` sat before the inner `*/`. The case was changed to `/* outer /* inner */ account.postbox, still comment */`.
- **The list** starts with every in-scope file that uses `.postbox`: 252 files.
- **CLAUDE.md** rule 12 now covers it.
- **Baseline, from `--report` at `537d203ebb`:**
  - 84 importers;
  - 252 access files;
  - 379 handle sites;
  - 229 `.postbox.mediaBox` sites in 31 MediaBox-only files.

  The spec's baseline (253 / 382 / 234) came from a script that stripped only line comments, so it counted a handful of sites inside block comments, such as `ReactionImageComponent.swift:82` and `FetchCachedRepresentations.swift:118`.

  | Sites | `mediaBox.` member |
  |---|---|
  | 81 | `(handle)` |
  | 57 | `resourceData` |
  | 23 | `cachedResourceRepresentation` |
  | 20 | `storeResourceData` |
  | 19 | `completedResourcePath` |
  | 6 | `cancelInteractiveResourceFetch` |
  | 4 | `cacheStorageBox` |
  | 3 each | `cachedRepresentationCompletePath`, `storageBox` |
  | 2 each | `basePath`, `fetchedResource`, `internal_resourceDataIsCached`, `moveResourceData`, `storeCachedResourceRepresentation` |
  | 1 each | `cachedRepresentationPathForId`, `resourcePath`, `resourceStatus` |

- **Verification:** guard tests 36/36; `PostboxImportCheck` clean on the tree; full build green, with the extended check running first.

### Wave P2: `EngineMediaResourceRepresentation` (2026-10-12)

- **The protocol.** TelegramCore declares `public protocol EngineMediaResourceRepresentation: CachedMediaResourceRepresentation`, next to `EngineMediaResource`. It has the same shape as `EngineCustomMedia: Media`: TelegramCore stores and serves representations but never enumerates their kinds, which stay app-side.
- **The adopters.** The 15 representation classes conform to it instead of `EngineRawCachedMediaResourceRepresentation`:
  - 14 in `MediaResources/Sources/CachedResourceRepresentations.swift`;
  - `YoutubeEmbedStoryboardMediaResourceRepresentation`.

  No raw conformance remains (the grep over all conformance spellings is empty).
- **Equivalence.** Only the declared conformance changed. The instances reaching MediaBox are the same, and so are their `uniqueId`, `keepDuration` and `isEqual(to:)`. The generators and the construction sites are untouched.
- **What is left.** Each class's `isEqual(to:)` still names the raw protocol through `EngineRawCachedMediaResourceRepresentation`, because it is the Postbox requirement. That is recorded for the `EngineRaw`-sink work.
- **Verification:** full build green; `//Tests/ComposerHarness:ComposerHarness` green.

### Wave P3: `resourceData` (2026-10-12)

**New facade:** `engine.resources.rangeData(resource:size:range:)`, which forwards `mediaBox.resourceData(_:size:in:)` and returns `Signal<(Data, Bool), NoError>`. Its callers pass no `mode` or flags, so MediaBox's own defaults apply as before.

**Rewrites:**
- **Engine.** `account.postbox.mediaBox.resourceData(r, …)` becomes `TelegramEngine(account: account).resources.data(resource: EngineMediaResource(r), …)`. Where a context is at hand, it is `context.engine.resources`.
- **Options** map onto the facade exactly as its own body maps them back:
  - `.complete(waitUntilFetchStatus: w)` → `waitUntilFetchStatus: w`;
  - `.incremental(waitUntilFetchStatus: w)` → `waitUntilFetchStatus: w, incremental: true`;
  - PhotoResources' `!progressive ? .complete(…false) : .incremental(…false)` → `waitUntilFetchStatus: false, incremental: progressive`.
- **`pathExtension` and `attemptSynchronously`** pass through unchanged.
- **Consumers** rename `.complete` → `.isComplete` and `.size` → `.availableSize`, on exactly the lines that read the returned value. `path` is unchanged.
- **Comparisons.** None of the converted sites compared `MediaResourceData` values (no `==` or `distinctUntilChanged`), so no explicit comparison was needed.

**Sites.** Of the 49 Account-rooted `resourceData` calls, 33 were converted, 14 deferred, 1 moved to P5 and 1 skipped.

| Decision | Sites |
|---|---|
| Converted (33) | `WalletCollectibleImageComponent.swift:16`; `WallpaperResources.swift`: 98, 113, 123, 964, 1185, 1208, 1847; `FetchCachedRepresentations.swift`: 147, and the range reads 155, 162, 232; `PhotoResources.swift`: 278, 302, 319, 355, 372, 416, 1083, 2068, 2097, 2293, 2729, 2754, 2770, 2780, 2929; `StickerResources.swift`: 538, 560, 579; `DirectMediaImageCache.swift`: 276 (range read), 281; `ChatImageGalleryItem.swift:914` |
| Deferred (14) | `WallpaperResources.swift`: 32, 54, 58. They return or merge into a raw `EngineRawMediaResourceData` signal that is `combineLatest`'d with `accountManager.mediaBox` and returned as-is. |
| | `FetchCachedRepresentations.swift`: 44, 52, 131, 139, 181, 190, 200, 211, 219, 234. The data is handed to generator helpers whose parameter is `resourceData: MediaResourceData`. |
| | `PhotoResources.swift:3252`, which feeds `decryptedResourceData(data:)`. |
| Moved to P5 | `WallpaperResources.swift:402`. It is one half of a ternary whose other half is a `cachedResourceRepresentation`, so both halves must change type together. |
| Skipped | `ReactionImageComponent.swift:82`, which is inside `/* */`. |

**Equivalence.**
- Each facade body is the MediaBox call with the same arguments. `data(resource:)` calls `resourceData(_ resource:…)`, which MediaBox itself forwards to the id form.
- `TelegramEngine(account:)` only stores the account, so `resources` reaches the same `account.postbox.mediaBox`.
- `ResourceData` copies `path`, `size` and `complete` from the `MediaResourceData` it wraps. There is one extra small allocation per emission on these paths (image and sticker loading), and no behaviour change.

**Freed:** `WalletCollectibleImageComponent.swift` left the access list. No file stopped importing Postbox, since the deferred and other uses remain.

**Report after the wave:** access files 252 → 251; `.postbox.mediaBox` sites 229 → 197; `mediaBox.resourceData` 57 → 25. The 25 are the 15 Account-rooted sites left (14 deferred, plus line 402 for P5) and 10 on non-Account receivers (`self.postbox`, `resource.postbox`, emoji-layer contexts).

**Verification:** full build green on the first pass; `//Tests/ComposerHarness:ComposerHarness` green.

### Wave P4: store, completed path, move, cancel (2026-10-12)

**New facade:** `engine.resources.moveResourceData(id:fromTempPath:)`, beside the existing `toTempPath:` form.

**The 22 Account-rooted calls, all converted.** Every receiver is a bare `account`, so the engine is `TelegramEngine(account: account).resources`.

| Calls | Files | Rewrite |
|---|---|---|
| 13 `storeResourceData` | LegacyMediaPickers ×5, VideoChatScreenParticipantContextMenu ×2, CommunityEditScreen, PeerInfoScreenAvatarSetup ×4, CreatePeerAvatarSetup | `storeResourceData(id: EngineMediaResource.Id(x.id), data:, synchronous:)`; `synchronous:` only where the site passed it, and both defaults are `false` |
| 5 `completedResourcePath` | ManagedAnimationNode, NotificationSoundSelection, ManagedDiceAnimationNode, PrefetchManager, WallpaperResources:1477 | `completedResourcePath(id: EngineMediaResource.Id(r.id), pathExtension:)`. ManagedAnimationNode's `resource._asResource()` becomes `resource.id`, which is the same id. |
| 2 `moveResourceData` | LegacyMediaPickers:912 (`fromTempPath:`), WallpaperUploadManager:98 (`from:to:`) | `moveResourceData(id:fromTempPath:)`, `moveResourceData(from:to:)` |
| 2 `cancelInteractiveResourceFetch` | PhotoResources: 2055, 2064 | `cancelInteractiveResourceFetch(id: EngineMediaResource.Id(r.id))` |

`FetchCachedRepresentations.swift:118` (`resourceRangesStatus`) sits inside `/* */` and was skipped.

**Equivalence.**
- MediaBox's resource-taking overloads (`completedResourcePath(_:)`, `cancelInteractiveResourceFetch(_:)`) forward to their id forms with `resource.id`.
- The facades call those id forms with `MediaResourceId(id.stringRepresentation)`. `MediaResourceId` is a single-string struct, so the round trip is exact.
- None of these calls returns a data value, so no consumer changed.

**Freed:** `LegacyMediaPickers.swift` and `ManagedAnimationNode.swift` left the access list.

**Report after the wave:** access files 251 → 249; `.postbox.mediaBox` sites 197 → 175.

**Verification:** full build green on the first pass; `//Tests/ComposerHarness:ComposerHarness` green.

### Wave P5: cached representations (2026-10-12)

**New facades** on `engine.resources`. Each takes `EngineMediaResourceRepresentation` from wave P2, and its defaults are copied from `MediaBox.swift`:
- `cachedRepresentation(resource:representation:pathExtension:complete:fetch:attemptSynchronously:)`, returning `ResourceData`;
- `cachedRepresentationCompletePath(id:representation:)`;
- `storeCachedRepresentation(resource:representation:data:)`;
- `cachedRepresentationPath(id:representationId:keepDuration:)`.

**Sites.**

| Decision | Sites |
|---|---|
| Converted (26 sites, 27 calls counting the 402 `resourceData` half) | `AttachmentController.swift`: 1798, 1801 |
| | `AttachmentPanel.swift`: 2164, 2167 |
| | `PhotoResources.swift`: 392, 393, 1069, 1070, 2667. In `svgIconImageFile` the local `Signal` annotation became `Signal<EngineMediaResource.ResourceData, NoError>`, and its bundled placeholder is built as `ResourceData(path:availableSize:isComplete:)` instead of `MediaResourceData(path:offset: 0, size:complete:)`. The only consumer reads `path` and `complete`. |
| | `ChatQrCodeScreen.swift:1072`, `ChatThemeScreen.swift:1346` |
| | `WallpaperUtils.swift`: 122, 155 |
| | `StoryChatContent.swift`: 1877, 2111 |
| | `StoryItemImageView.swift`: 145, 166. `fullSize` is `combineLatest`'d with a preview signal that was already `ResourceData`. |
| | `FetchCachedRepresentations.swift:440` (reads only `path`) |
| | `WallpaperUploadManager.swift`: 111, 136 |
| | `YoutubeEmbedImplementation.swift:498` |
| | `WallpaperResources.swift`: 130, and 402 with both halves of its ternary (the `resourceData` half carried over from P3) |
| | `LegacyInstantVideoController.swift:229`, `VideoMessageCameraScreen.swift:2070` |
| | `DirectMediaImageCache.swift:257` |
| Deferred (3) | `WallpaperResources.swift`: 25, 38, 47. They are part of the same raw `maybeFullSize: Signal<EngineRawMediaResourceData, NoError>` pipeline as P3's deferred 32 / 54 / 58, which merges `accountManager.mediaBox` signals and returns raw data. |

**Consumers.** Renames `.complete` → `.isComplete` and `.size` → `.availableSize`, on the lines that read each converted value:
- PhotoResources: 398, 435, 1075, 1101, 2681;
- ChatQrCodeScreen: 1077, 1079;
- ChatThemeScreen: 1351, 1353;
- StoryItemImageView: 178;
- Youtube: 499, 500;
- WallpaperResources: 132, 414, 423, 425.

WallpaperResources:402's `combineLatest(sharedResource, accountResource)` now pairs a raw shared value with an engine account value, and each is read through its own field names.

**Equivalence.**
- Each facade forwards to the same MediaBox call with the same arguments and defaults. The representation objects are the same instances.
- `cachedRepresentationCompletePath` and `cachedRepresentationPath` return the same `String`.
- No converted site compared data values.

**Freed** from the access list: AttachmentController, LegacyInstantVideoController, WallpaperUtils, VideoMessageCameraScreen, WallpaperUploadManager and YoutubeEmbedImplementation.

**Process note.** The edit script stopped once on a wrong rename line number (2680 instead of 2681). It had already written the two AttachmentUI files, which were checked by diff and kept; the rest ran after the fix.

**Report after the wave:** access files 249 → 243; `.postbox.mediaBox` sites 175 → 148.

**Verification:** full build green on the first pass; `//Tests/ComposerHarness:ComposerHarness` green.

### Wave P6: `fetchedMediaResource(mediaBox:)` → `engine.resources.fetch` (2026-10-12)

**Facade.** `engine.resources.fetch(reference:userLocation:userContentType:…)` replaces the three-argument form with two overloads that mirror `fetchedMediaResource`'s two (`FetchedMediaResource.swift:28` and `:73`).
- The first takes `range: (Range<Int64>, EngineMediaBoxFetchPriority)? = nil`. The second takes `ranges: […]?` with no default.
- Both take `statsCategory: MediaResourceStatsCategory = .generic`, and `reportResultStatus`, `preferBackgroundReferenceRevalidation` and `continueInBackground`, all `= false`. These defaults are the same as `fetchedMediaResource`'s.
- Existing three-argument callers resolve to the first overload with every default, which is the call they made before. The `ranges:` overload has no default, so no call is ambiguous.

**New alias:** `EngineMediaBoxFetchPriority = MediaBoxFetchPriority`, a plain alias (not `EngineRaw`), so the `.default` / `.elevated` / `.maximum` literals at call sites are unchanged.

**The 47 calls, all converted.** Every Account-rooted `fetchedMediaResource(mediaBox: X.postbox.mediaBox, …)` call became `<engine>.resources.fetch(reference:userLocation:userContentType:…)`.
- **Engine by receiver:**
  - 26 bare `account`, 2 `item.account` and 1 `self.account` use `TelegramEngine(account:)`;
  - 13 `context.account`, 3 `self.context.account` and 2 `component.context.account` use `….engine`.
- **Arguments.** A script dropped the `mediaBox:` argument and moved `reference:` to the front. It kept every other argument and its formatting, and refused any trailing argument outside the facade's six.
- **Shapes.** 23 calls pass only the four required arguments. The rest pass `statsCategory`, `range` or `ranges`, and the reporting flags.
- **Result type.** `Signal<FetchResourceSourceType, FetchResourceError>` is unchanged, so no consumer changed and nothing needed deferring.

**Equivalence.**
- The facade calls `fetchedMediaResource` with `self.account.postbox.mediaBox` and every argument passed through, so it is the same call.
- Moving `reference:` first changes the order in which arguments are evaluated. Every argument at these sites is a side-effect-free expression (a reference, a location, a content type, a literal), so the results are unchanged.

**Freed** from the access list: FetchMediaUtils, AttachmentPanel, BotCheckoutHeaderItem, BatchVideoRenderingContext, GroupStickerPackCurrentItem and StoryItemImageView. FetchMediaUtils still imports Postbox for its own handle-taking functions.

**Report after the wave:** access files 243 → 237; `.postbox.mediaBox` sites 148 → 101; `mediaBox.(handle)` 81 → 34 (the remaining 34 are handles passed to app-side functions, or the files' own handles).


**Verification:** full build green on the first pass; `//Tests/ComposerHarness:ComposerHarness` green.

### Wave P7: the stragglers (2026-10-12)

**New facades** on `engine.resources`:
- `fetchedResource(resource:)`, which forwards `mediaBox.fetchedResource(_:parameters: nil)` with MediaBox's own `implNext: false`;
- `storageTotalSize()` and `cacheStorageTotalSize()`;
- `resetStorageIndex()`, for `storageBox.reset()`;
- `mediaBasePath`;
- `resourcePath(resource:)`.

`storageBox`, `cacheStorageBox` and `basePath` are stored `let`s on `MediaBox`, so each facade reaches the same object the site reached before.

**Converted:**
- **`fetchedResource`:** `SecureIdDocumentImageGalleryItem.swift:134` and `PhotoResources.swift:3251`.
- **Storage boxes:**
  - `ChatListNode.swift:2017`, both totals;
  - `DataAndStorageSettingsController.swift:695–696`, both totals;
  - `DebugController.swift:1261`, the reset.
- **`basePath`:** `AccountContext.swift:388` reads `self.engine.resources.mediaBasePath`, which is assigned at line 321, before this read.
- **`resourcePath`:** `SpotlightContacts.swift:223`.
- **Local aliases.** In each file, `let mediaBox = <context>.account.postbox.mediaBox` became `let resources = <context>.engine.resources`, and each use was rewritten with the P3 / P4 / P6 recipes. The files and uses:
  - `LottieComponentEmojiContent.swift:39`: `resourceData` and `fetchedResource`;
  - `LottieComponentResourceContent.swift:52`: `completedResourcePath`, `resourceData` and `fetchedResource`;
  - `WalletCollectibleHeaderComponent.swift:61`: `resourceData` (`.size` → `.availableSize`, `.complete` → `.isComplete`) and `fetchedResource`;
  - `WalletConnectScreen.swift:93`: `resourceData` and `fetchedMediaResource(mediaBox: mediaBox, …)` → `resources.fetch(reference:…)`.

  These closures now capture the `Resources` object, which holds the `Account`, where they captured the `MediaBox` before. The capture lasts only while the load signal is subscribed, and the component's `AccountContext` holds the same account throughout.

**Deferred:** `AccountContext.swift:387`. Its `cacheStorageBox` is captured by `DCTAnimationCacheImpl`'s long-lived `updateStorageStats` closure. Routing it through `engine.resources` would make that closure retain the whole `Account` instead of only the `StorageBox`, which is a lifetime change. It is left for the handle sub-project, and the planned `updateCacheStorageEntry` facade was not added, because it would have no caller.

**Every Account-rooted MediaBox use left after P3–P7.** Each is deferred (with its reason) or out of scope by the spec:

| Sites | Why left |
|---|---|
| `WallpaperResources.swift`: 25, 32, 38, 47, 54, 58 | The raw `maybeFullSize: Signal<EngineRawMediaResourceData, NoError>` pipeline, merged with `accountManager.mediaBox` and returned raw. |
| `FetchCachedRepresentations.swift`: 44, 52, 131, 139, 181, 190, 200, 211, 219, 234 | Data handed to generator helpers whose parameter is `resourceData: MediaResourceData`. |
| `PhotoResources.swift:3252` | Feeds `decryptedResourceData(data:)`, which takes `MediaResourceData`. |
| `AccountContext.swift:387` | The lifetime change described above. |
| 18 `mediaBox` handle passes to app-side functions: `chatServiceBackgroundColor` ×7, `chatControllerBackgroundImage(Signal)` ×3, `UniversalSoftwareVideoSource` ×3, `chatMessageAnimationData` ×2, `storeImage`, `update` (bubble), `resource` (FetchCachedRepresentations) | Out of scope: these are app-side `mediaBox:` parameters, belonging to the handle sub-project. |
| `ReactionImageComponent.swift:82`, `FetchCachedRepresentations.swift:118` | Inside `/* */`. |

**Exit criteria.**
- No Account-rooted MediaBox call or `fetchedMediaResource(mediaBox:)` pass remains outside this table.
- 21 of the 31 MediaBox-only files at the phase baseline left the access list.

  The other ten each still have a deferred or out-of-scope site:
  - DirectMediaImageCache, WallpaperResources, ThemeAccentColorController(Node), TextSizeSelectionController, ThemePreviewControllerNode, ManagedDiceAnimationNode, ChatMessageBubbleItemNode and PeerInfoVisualMediaPaneNode, all through app-side `mediaBox:` parameters or a deferral;
  - ChunkMediaPlayerDirectFetchSourceImpl, through its own `resource.postbox` handle.
- Equivalence is recorded per wave above.

**Report after the wave:** importers 84; access files 237 → 231; `.postbox.mediaBox` sites 101 → 88; MediaBox-only files 10.

**Phase totals, P1–P7:**
- access files 252 → 231;
- `.postbox.mediaBox` sites 229 → 88;
- `mediaBox.(handle)` 81 → 30 (Account-rooted passes to app-side functions and the files' own handles);
- importers unchanged at 84. Every converted file still has other Postbox uses, or kept its import for handle types.

**Verification:** full build green on the first pass; `//Tests/ComposerHarness:ComposerHarness` green.

### Pre-merge review fixes (2026-10-12)

A fresh reviewer went over the whole branch (`8de02bc574..59bc9bd5de`) before merging and found nothing critical. Its one important item was that no release build had run. A `release_arm64` build then succeeded (8,178 actions, no undefined symbols), so the computed framework export lists cover every new public TelegramCore symbol. The user asked for all four of its minor items to be fixed:

1. **The guard cost 6.6 s per `Make.py build`/`test`; it is now 0.58 s.**
   - `strip_comments_and_strings` stepped through 17 MB of Swift one Python iteration per character, about 4 MB/s.
   - It now jumps between the places its state can change (comment, string and interpolation markers) with compiled regexes. The text between two stops is copied or blanked in one slice.
   - A test strips ~10 MB in under a second. It failed before the rewrite at 2.2 s.
   - A differential run over all 5,954 Swift files under `submodules/`, `Telegram/` and `Tests/` (111 MB) gave byte-identical output from the old and new strippers, and stripping took 0.61 s instead of 26.4 s.
2. **A guard against `EngineMedia` traps.**
   - `PostboxImportCheck.py` now also fails on any in-scope class, struct, enum, protocol or extension whose inheritance list names `Media`, `Postbox.Media` or `EngineRawMedia`, anywhere in the list, without naming `EngineCustomMedia`. That replaces the CLAUDE.md grep, which saw `Media` only as the first inherited type and was the gap behind the wave 455/458 trap.
   - The check is parsed from comment- and string-stripped code. Generic constraints (`<T: Media>`) and `where` clauses do not count.
   - The tree passes it: the only app-side media types are the three `EngineCustomMedia` previews.
   - `check()` now reads each file once for all three scans (`scan_tree`), so the guard takes 0.86 s with the new check.
   - CLAUDE.md's wrapper note no longer calls the wrappers value types: `EngineMessage`, `EngineRenderedPeer` and `EngineMediaResource` are classes.
   - Guard tests 37 → 44.
3. **The MediaBox-access spec's exit criteria are amended** to match the deferral rule the user approved with the plan. Every in-scope call is now required to be converted or recorded as deferred, with the reason in the log, rather than "none remains". The spec carries a dated note.
4. **Two small leftovers.**
   - **One `InstantPage.media` snapshot per layout pass.** `InstantPageControllerNode` and `BrowserInstantPageContent` used to build the computed dictionary twice: once for the mutable copy and once to iterate. Each now builds it once into `currentMediaById` and iterates that.
     - The getter is `rawMedia.mapValues(EngineMedia.init)`, so both old reads iterated in `rawMedia`'s order, and the single snapshot visits the same pairs in the same order.
     - Each key is updated independently, so the result is the same as before, with one dictionary build saved per pass.
   - **PeerInfoScreen's hidden media has no wrap round-trip.**
     - Since wave 460 the handler wrapped each media in `EngineMedia` and then unwrapped every value back with `mapValues { $0.map { $0._asMedia() } }` for `ChatControllerInteraction.hiddenMedia`.
     - The local now has that destination's own type, `[EngineMessage.Id: [EngineRawMedia]]`, its only consumer. That restores the pre-460 code with engine alias spellings, the same pattern wave 452 used in `ChatControllerLoadDisplayNode`.
     - The same objects land in the same keys, with one `EngineMedia.init` call site fewer.

**Verification:** guard tests 44/44; the guard is clean on the tree; full `debug_sim_arm64` build green; `InstantPageUITests` 191/191. A `release_arm64` build had already passed before these fixes.


### Where to pick up (at the squash onto master, 2026-10-12)

**Measures** (`python3 build-system/Make/PostboxImportCheck.py --report`):
- 84 in-scope files import Postbox;
- 231 files use `.postbox` (on `AllowedPostboxAccess.txt`);
- 88 `.postbox.mediaBox` sites;
- 379 handle sites, where `.postbox` is passed on with no member called.

The guard also fails on any app-side `Media` conformance without `EngineCustomMedia`.

**How the work ran, and what to keep doing:**
- Each sub-project is brainstormed into a spec, then a plan, then waves. The user approves the spec and the plan.
- One pattern per wave (one member family, one cluster). Inventory first, and check every facade default against its source.
- Behaviour must not change (rule 9). A call whose result must feed raw-typed code, or whose conversion changes a lifetime, is deferred and logged, not forced.
- Prefer real engine wrappers over `EngineRaw*` aliases, adding a new wrapper or protocol when none fits (user, 2026-10-12). UI-specific types stay out of TelegramCore: an engine protocol, adopted app-side, is the pattern (`EngineCustomMedia`, `EngineMediaResourceRepresentation`).
- Check the implicit-`self` reads of a retyped stored property (wave 458).
- A `SharedAccountContext` change needs the composer harness stub regenerated (`Tests/ComposerHarness/Tools/generate_harness_stubs.py`) and the harness built separately. Any TelegramCore API change needs the harness built.
- Run a fresh reviewer over each batch, and a `release_arm64` build before shipping.

**Open sub-projects:**
1. **Handles.** The `postbox: Postbox` and `mediaBox: MediaBox` handles held or taken by the media pipeline: about 45 files hold a `Postbox` handle and 12 a `MediaBox` (see the phase 2026-10 exit inventory). That includes:
   - the app-side functions that take `mediaBox:`: `chatServiceBackgroundColor`, `chatControllerBackgroundImage(Signal)`, `chatMessageAnimationData`, `UniversalSoftwareVideoSource`, `DirectMediaImageCache.storeImage`, the bubble's `update`;
   - FetchCachedRepresentations' generator inputs;
   - NotificationService.

   Every MediaBox site deferred in waves P3–P7 belongs here; wave P7 lists them.
2. **Views.** `peerView` (29 sites), `combinedView` (23), `itemCollectionsView` (11), the history views and `PostboxViewKey`. These are most of the class-R files. Do not split a multi-key `combinedView` into parallel subscriptions.
3. **`transaction` blocks** (49 sites).
4. **The remaining `.postbox` members:** `messagesAtIds`, `messageAtId`, `searchPeers`, `clearCaches`, `aroundMessageHistoryViewForLocation` and the others.
5. **The `EngineRaw*` sinks:**
   - `ChatControllerInteraction`'s `hiddenMedia`, `updateMessageReaction`, `playMessageEffect` and `openPeerContextMenu`;
   - the bubble `transitionNode` / `updateHiddenMedia`;
   - `ListMessageItem.message`;
   - the preview callers that build fake messages with `EngineRawMessage(...)` instead of the memberwise `EngineMessage` initializer;
   - the representation classes' raw `isEqual(to:)`.
6. **The heavy class-W files:** ChatRecentActionsHistoryTransition, UniversalVideoGalleryItem, ChatAnimationGalleryItem, ChatImageGalleryItem and InChatPrefetchManager. ChatControllerOpenAttachmentMenu stays raw by design (`RichTextDraft`).

**Known guard gaps:** the comment/string stripper does not model raw strings (`#"…"#`, `\#(…)`) or regex literals. A raw-string interpolation of `.postbox` could slip past it.

## Modules currently free of `import Postbox` (running tally)

**Stale since wave 105.** From wave 439 on, the authoritative state is `submodules/Postbox/AllowedImporters.txt` (files) and the `clients` / `test_clients` package groups in `submodules/Postbox/BUILD` (packages); each wave entry records the counts.

Consumer modules that no longer import Postbox, across all waves and standalone commits:

- `ChatInterfaceState` (wave 1)
- `ChatSendMessageActionUI` (wave 1)
- `ContactListUI` (wave 1)
- `DrawingUI` (wave 1)
- `StickerPeekUI` (standalone cleanup, 2026-04-17 — import was unused)
- `PromptUI` (standalone cleanup)
- `PresentationDataUtils` (standalone cleanup)
- `MapResourceToAvatarSizes` (wave 2)
- `SaveToCameraRoll` (wave 3)
- `SecureIdVerificationDocumentsContext` (wave 5)
- **Wave 6 batch: 189 additional modules** — see `git show 7b2b74e79b --stat` for the commit that swept unused `import Postbox` lines across 183 files in 16 consumer submodules. Not individually enumerated here for brevity.
- `StorageUsageScreen` (waves 8–10)
- `ActionSheetPeerItem` (wave 11; revisits wave-1 abandonment)
- `HorizontalPeerItem` (wave 12; applies wave-11 pattern)
- `SelectablePeerNode` (wave 15; applies wave-11 pattern; ShareExtension-boundary stateManager fallback)
- `ItemListAvatarAndNameInfoItem` (wave 17; applies wave-11 pattern; ShareExtension-boundary stateManager fallback)
- `ItemListStickerPackItem` (wave 18; mixed-shape — 3 narrow TelegramCore typealiases + wave-4 enum-payload migration + wave-3 facade swap)
- `AttachmentTextInputPanelNode` BUILD cleanup (wave 13; source was already clean from wave 6)
- **Wave 14 BUILD-dep sweep: 98 modules' BUILDs cleaned** — same modules as the wave-6 batch; this sweep fixed their leftover `//submodules/Postbox:Postbox` BUILD deps. Candidate list in `/tmp/postbox-dep-candidates.txt` at commit time; derivable by the script in "Wave 14 outcome".
