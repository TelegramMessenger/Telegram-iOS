import SwiftUI

private struct ScrollSnapshot: Equatable {
    let contentOffsetY: CGFloat
    let contentSizeH: CGFloat
    let containerSizeH: CGFloat
    let topInset: CGFloat
}

struct MessageListView: View {
    @Environment(TDClient.self) private var client
    let row: ChatRow

    @State private var store: ChatHistoryStore
    @State private var presentedPhoto: PhotoVisual?
    @State private var presentedVideo: VideoVisual?
    @State private var presentedVideoNote: VideoNoteVisual?
    @State private var presentedPoll: PollVoteTarget?
    @State private var showAttachment: Bool = false
    @State private var stickerPickerStore: StickerPickerStore?
    // True when the user is parked within slop of the bottom edge. Updated only on
    // user-driven scrolls (see .onScrollGeometryChange filter), so it reflects intent
    // rather than instantaneous viewport position. Drives auto-scroll for incoming:
    // stay-anchored-when-at-bottom, leave-alone-when-scrolled-up. Initial value depends
    // on whether the chat opens at the tail (no unreads → true) or at the unread divider
    // (unreads present → false, user is parked at the divider, not the bottom).
    @State private var isAtBottom: Bool
    @State private var didApplyInitialScroll: Bool = false
    // Live scroll-view content height, updated by a dedicated geometry observer
    // (see `.onScrollGeometryChange(for: CGFloat.self)` below). The initial-
    // position `.task` polls this to detect when bubbles have finished async-
    // sizing, rather than guessing a fixed settle delay.
    @State private var observedContentHeight: CGFloat = 0
    // Pagination triggers fire from `.onScrollVisibilityChange` on the top/bottom rows.
    // On initial layout — especially for all-unread chats where the divider lands at
    // row index 0 — the topmost rows are visible without any user gesture, which would
    // call loadOlder() repeatedly in a loop as each fetch prepends more content. Gate
    // pagination on having observed at least one user-driven scroll
    // (`.onScrollGeometryChange`'s contentSizeH-stable filter implies user-driven).
    @State private var userHasScrolled: Bool = false
    // Hard cool-down after each loadOlder/loadNewer. Without this, the row-visibility
    // callbacks for newly-prepended rows fire IMMEDIATELY after `reproject()` and re-
    // trigger pagination before SwiftUI can land the `.onChange`-driven scroll-preservation
    // animation. The cool-down lets the prepended rows settle off-screen before the
    // next pagination is allowed.
    @State private var canPaginate: Bool = true

    init(row: ChatRow, store: ChatHistoryStore) {
        self.row = row
        self._store = State(initialValue: store)
        // Opens at tail → starts at bottom. Opens at divider → user is NOT at bottom.
        self._isAtBottom = State(initialValue: row.unreadCount == 0)
    }

    var body: some View {
        content(store: store)
        .navigationTitle(row.title)
        .accessibilityIdentifier("messageListView")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                AvatarView(
                    avatar: row.avatar,
                    onRequestDownload: { fileId in store.requestFileDownload(fileId: fileId) },
                    onCancelDownload:  { fileId in store.cancelFileDownload(fileId: fileId) },
                    size: 36
                )
                .glassEffect(in: Circle())
            }
        }
        .sheet(item: $presentedPhoto) { photo in
            PhotoViewerView(photo: photo)
        }
        .sheet(item: $presentedVideo) { video in
            VideoPlayerView(video: video).environment(store)
        }
        .sheet(item: $presentedVideoNote) { note in
            VideoNotePlayerView(note: note).environment(store)
        }
        .sheet(item: $presentedPoll) { target in
            PollVoteView(
                initialPoll: target.poll,
                currentPoll: { store.poll(forMessageId: target.id) },
                onVote: { await store.setPollAnswer(messageId: target.id, optionIds: $0) }
            )
        }
        .sheet(isPresented: $showAttachment) {
            AttachmentSheet(
                stickerPickerStore: stickerPickerStore,
                onSendSticker: { await store.sendSticker($0) },
                onSendVoiceNote: { await store.sendVoiceNote($0) },
                onPrepareVoice: {
                    store.voicePlayback.tearDown()
                    store.audioPlayback.tearDown()
                },
                onSendLocation: { latitude, longitude in
                    await store.sendLocation(latitude: latitude, longitude: longitude)
                }
            )
            .environment(client)
            // Inject the picker store at the sheet-content root (above
            // AttachmentSheet's NavigationStack), mirroring `client`. The
            // store must live above the stack so pushed destinations —
            // StickerSetDetailView and its StickerCellViews — inherit it;
            // injecting only inside StickerPickerView (below the stack)
            // left pushed set-detail views with no store and trapped on
            // the `@Environment(StickerPickerStore.self)` lookup.
            .environment(stickerPickerStore)
        }
        .task {
            client.setActiveHistory(store)
            // Defer openChat to here (the store was warmed without it). Independent
            // of warm: if the window is still loading, openChat proceeds anyway.
            await store.activate()
            // Build the picker store HERE (not lazily in the attachment-tap closure):
            // creating an @State and flipping a sheet-present flag in the same closure
            // races the .sheet's `if let pickerStore` against a nil snapshot.
            if stickerPickerStore == nil, let pl = client.makeStickerPickerLoader() {
                stickerPickerStore = StickerPickerStore(loader: pl)
            }
        }
        .onDisappear {
            let s = self.store
            client.setActiveHistory(nil)
            Task { await s.stop() }
        }
    }

    @ViewBuilder
    private func content(store: ChatHistoryStore) -> some View {
        switch store.loadState {
        case .loadingFirstPage:
            // Keep the spinner up for the entire initial load. TDLib's cold cache
            // routinely splits `getChatHistory` into multiple round-trips (iter=1
            // returns 1 message, iter=2 returns the rest). If we fall through to
            // the ScrollView mid-load, the user sees: brief render with iter=1's
            // content → iter=2 prepends 29 messages (content jumps) → final scroll
            // fires. Showing the spinner until `.loaded` collapses that into one
            // clean transition.
            LoadingView(label: "Loading messages…")
        case .failed(let message):
            VStack(spacing: 6) {
                Text(message)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                Button("Retry") {
                    Task { await store.start() }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        default:
            // ScrollViewReader wraps the VStack so the initial-position `.task`,
            // loadOlder scroll-preservation, and tail auto-scroll handlers can capture
            // `proxy` and call `proxy.scrollTo(...)`.
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    if let err = store.lastSendError {
                        HStack(spacing: 4) {
                            Text(err)
                                .font(.caption2)
                                .lineLimit(2)
                            Spacer(minLength: 0)
                            Button {
                                store.dismissSendError()
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 10))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(6)
                        .background(Capsule().fill(.red.opacity(0.2)))
                        .padding(.horizontal, 4)
                        .padding(.top, 2)
                    }
                    if let err = store.lastPaginationError {
                        HStack(spacing: 4) {
                            Text(err).font(.caption2).lineLimit(2)
                            Spacer(minLength: 0)
                            Button { store.dismissPaginationError() } label: {
                                Image(systemName: "xmark").font(.system(size: 10))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(6)
                        .background(Capsule().fill(.orange.opacity(0.2)))
                        .padding(.horizontal, 4)
                        .padding(.top, 2)
                    }
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(store.rows.enumerated()), id: \.element.id) { idx, messageRow in
                                MessageRowView(
                                    row: messageRow,
                                    onPhotoTap: { presentedPhoto = $0 },
                                    onVideoTap: { presentedVideo = $0 },
                                    onVideoNoteTap: { presentedVideoNote = $0 },
                                    onPollTap: { id, poll in presentedPoll = PollVoteTarget(id: id, poll: poll) },
                                    index: idx,
                                    count: store.rows.count,
                                    onEnterTopEdge: {
                                        guard userHasScrolled, canPaginate else { return }
                                        canPaginate = false
                                        Task {
                                            await store.loadOlder()
                                            try? await Task.sleep(nanoseconds: 800_000_000)
                                            canPaginate = true
                                        }
                                    },
                                    onEnterBottomEdge: {
                                        guard userHasScrolled, canPaginate, !store.window.reachesChatTail else { return }
                                        canPaginate = false
                                        Task {
                                            await store.loadNewer()
                                            try? await Task.sleep(nanoseconds: 800_000_000)
                                            canPaginate = true
                                        }
                                    },
                                    onIncomingBubbleVisible: { id in
                                        guard id > store.unreadDividerAfterIdSnapshot else { return }
                                        store.markVisible(messageId: id)
                                    }
                                )
                                .id(messageRow.id)
                            }
                            if row.canSend {
                                ReplyBar(
                                    onAttachTap: { showAttachment = true },
                                    onSend: { snapshot in
                                        Task { await store.sendText(snapshot) }
                                    }
                                )
                                .padding(.top, 8)
                            }
                            // 19pt bottom content inset so the ReplyBar's "+" and pill sit
                            // 19pt above the *physical* screen edge when the chat is scrolled
                            // to the tail. Combined with .ignoresSafeArea(edges: .bottom) on
                            // the ScrollView below — without that, the system bottom safe-area
                            // adds extra space and the total inset overshoots. Carried as an
                            // id'd zero-content spacer (not `.padding(.bottom, 19)` on the
                            // VStack) so it's part of the scrollable content and
                            // `proxy.scrollTo("bottomAnchor", .bottom)` reaches the TRUE
                            // content bottom — anchoring to the ReplyBar instead stops 19pt
                            // short, landing the chat just above the real tail.
                            Color.clear
                                .frame(height: 19)
                                .id("bottomAnchor")
                        }
                        .padding(.horizontal, 4)
                        .padding(.top, 4)
                    }
                    .ignoresSafeArea(edges: .bottom)
                    .scrollContentBackground(.hidden)
                    .background {
                        Image("ChatBG")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .clipped()
                            .ignoresSafeArea()
                    }
                    .environment(store)
                    .onScrollGeometryChange(for: ScrollSnapshot.self) { geometry in
                        ScrollSnapshot(
                            contentOffsetY: geometry.contentOffset.y,
                            contentSizeH: geometry.contentSize.height,
                            containerSizeH: geometry.containerSize.height,
                            topInset: geometry.contentInsets.top
                        )
                    } action: { old, new in
                        // isAtBottom means "user intends to be parked at bottom", NOT "the
                        // bottom edge is visible right now". When a new message arrives while
                        // the user is at the bottom, contentSize grows but contentOffset stays
                        // — a naive "is the bottom edge visible" check would flip false even
                        // though the user hasn't moved. Skipping callbacks where contentSize
                        // changed preserves the last user-driven state.
                        //
                        // The .top inset (translucent nav bar overlay, ~62pt on the 46mm sim)
                        // shrinks the maximum scroll offset; subtract it from bottomOffset or
                        // the check is off by ~62pt and isAtBottom never reaches true. Verified
                        // empirically — when at the bottom, contentOffset.y ==
                        // contentSize.height - containerSize.height - contentInsets.top.
                        guard old.contentSizeH == new.contentSizeH else { return }
                        let bottomOffset = new.contentSizeH - new.containerSizeH - new.topInset
                        isAtBottom = new.contentOffsetY >= bottomOffset - 8
                        // contentSize-stable changes imply user-driven scroll; arm
                        // pagination so it only fires after the user actually moved.
                        userHasScrolled = true
                    }
                    // Dedicated content-height tracker for the initial-position
                    // settle loop. The ScrollSnapshot observer above bails early on
                    // contentSize changes (to preserve user-driven isAtBottom), so it
                    // can't be used to watch growth; this one records height on every
                    // change, including the async bubble-sizing growth we wait out.
                    .onScrollGeometryChange(for: CGFloat.self) { $0.contentSize.height } action: { _, newValue in
                        observedContentHeight = newValue
                    }
                    .task {
                        // Initial positioning. This `default` branch only renders once the
                        // store is `.loaded` (the `.loadingFirstPage` case keeps the spinner
                        // up), so `store.rows` is fully populated — true for BOTH the fast
                        // path (warmed before push) and the slow path (warm finished after
                        // push, swapping this branch in).
                        //
                        // We drive BOTH the unread (→ divider, `.top`) and the read (→ tail,
                        // `.bottom`) cases imperatively. We do NOT use
                        // `.defaultScrollAnchor(.bottom)`: on a non-lazy `VStack` it latches
                        // the bottom offset at the first, too-short layout and reverts to that
                        // stale offset as content grows — landing ~1 screen above the true
                        // tail. We use `proxy.scrollTo` rather than `scrollPosition(id:)`
                        // because the content is a plain (non-lazy) `VStack` —
                        // `scrollPosition(id:)` only positions reliably inside lazy stacks, and
                        // switching to `LazyVStack` reintroduces the over-scroll gotcha.
                        //
                        // The hard part is TIMING: bubble heights settle a few frames AFTER
                        // first layout — media (photos, videos, maps, stickers) async-size well
                        // past any fixed delay. A guessed sleep fires the scroll while
                        // contentSize is still too short; as bubbles above the anchor then
                        // grow, `bottomAnchor` is pushed down and we're left parked ~1 screen
                        // above the tail (the original regression — a fixed 50ms sleep was not
                        // enough for media-heavy chats). So instead of guessing, re-pin every
                        // frame until contentSize stops changing (stable for a few consecutive
                        // frames), capped so a never-settling chat still reveals. The `.overlay`
                        // cover (gated on `!didApplyInitialScroll`) hides the whole settle so
                        // there's no visible movement.
                        guard !didApplyInitialScroll else { return }
                        let applyInitialPosition: @MainActor () -> Void = {
                            if let target = store.window.initialScrollTargetId {
                                proxy.scrollTo(target, anchor: .top)
                            } else {
                                proxy.scrollTo("bottomAnchor", anchor: .bottom)
                            }
                        }
                        var lastHeight: CGFloat = -1
                        var stableFrames = 0
                        for _ in 0..<90 {                       // ~1.5s cap at one frame each
                            applyInitialPosition()
                            try? await Task.sleep(nanoseconds: 16_000_000)
                            let height = observedContentHeight
                            if height == lastHeight {
                                stableFrames += 1
                                if stableFrames >= 3 { break }  // settled for ~3 frames
                            } else {
                                stableFrames = 0
                                lastHeight = height
                            }
                        }
                        // Final pin once content has settled, plus one runloop pass to catch
                        // any last residual growth between the final sleep and reveal.
                        applyInitialPosition()
                        await Task.yield()
                        applyInitialPosition()
                        didApplyInitialScroll = true
                    }
                    .onChange(of: store.rows.first?.id) { oldId, newId in
                        // Scroll preservation across `loadOlder`. When older content is
                        // prepended, SwiftUI keeps the absolute scroll offset where it was
                        // — meaning the user was at pixel 0 (top of old content) and is
                        // now at pixel 0 of the new (longer) content, which exposes the
                        // newly-prepended top rows. Those rows' `index <= 2` triggers a
                        // fresh `loadOlder` and the chat enters a paginate-forever loop.
                        // Snap the user back to the previously-first row so the prepended
                        // content lands above the viewport (off-screen until the user
                        // chooses to scroll there).
                        guard didApplyInitialScroll,
                              let oldId, let newId, oldId != newId else { return }
                        proxy.scrollTo(oldId, anchor: .top)
                    }
                    .onChange(of: store.rows.last?.id) { _, newId in
                        // Telegram convention: outgoing always pulls to bottom; incoming only
                        // pulls if the user was already parked there. Only auto-scroll when we
                        // actually have the chat tail loaded — otherwise rows.last is just the
                        // bottom of the current window, not the latest message. Also gate on
                        // didApplyInitialScroll so the initial fill (where rows.last?.id
                        // transitions from nil → some-id mid-load) doesn't double-fire with
                        // the .task initial-scroll handler.
                        guard didApplyInitialScroll,
                              newId != nil,
                              store.window.reachesChatTail,
                              case .bubble(let bubble) = store.rows.last else { return }
                        guard bubble.isOutgoing || isAtBottom else { return }
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo("bottomAnchor", anchor: .bottom)
                        }
                    }
                }
            }
            // Cover the first-layout→settle window (the `.task` above re-pins to the final
            // position until contentSize stabilizes) so the user never sees the jump.
            // Covers BOTH cases: the unread divider (`.top`) and the read tail (`.bottom`)
            // are both placed imperatively after the content settles, because there is no
            // `.defaultScrollAnchor(.bottom)` to hold position while bubbles async-grow
            // (it reverts to a stale first-layout offset — see the `.task` comment).
            .overlay {
                if !didApplyInitialScroll {
                    LoadingView(label: "Loading messages…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.ignoresSafeArea())
                }
            }
        }
    }
}
