import SwiftUI
import TDShim

struct ChatListView: View {
    @Environment(TDClient.self) private var client
    let store: ChatListStore

    @State private var dismissedLastError: String? = nil
    @State private var opener = ChatOpener()
    /// Bound to the outer chat-list `List`. Re-asserted after every pill tap so the
    /// digital crown stays glued to the chat list, never the pill bar's horizontal
    /// ScrollView (where rotation has no useful effect). watchOS otherwise routes
    /// the crown to the most-recently-interacted scrollable.
    @FocusState private var listFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    if case .failed(let message) = store.loadState(for: store.currentFolder) {
                        banner(text: message, kind: .retry)
                    }
                    if let err = client.lastError, dismissedLastError != err {
                        banner(text: err, kind: .dismiss)
                    }
                    content(proxy: proxy)
                }
                .navigationDestination(item: $opener.target) { target in
                    MessageListView(row: target.row, store: target.store)
                }
                .navigationTitle("Chats")
                .navigationBarTitleDisplayMode(.inline)
                // `.toolbar(.visible)` forces the nav-bar container to
                // materialize on the chat list. Without it, watchOS-26 skips
                // chrome on a NavigationStack root view, leaving only the
                // status row (clock top-right). The push to MessageListView
                // then has to grow that minimal status row into a full glass
                // nav bar with back chevron + title + trailing avatar, which
                // glitches mid-reshape. With the bar present here, the push
                // only has to morph content, not allocate a new glass surface.
                .toolbar(.visible, for: .navigationBar)
                // Must live INSIDE the NavigationStack so the modifier's
                // .navigationDestination(isPresented:) attaches to it.
                .accountSwitcherSheet(presentation: .push, logoutAffordance: .allowed)
            }
        }
        .accessibilityIdentifier("chatListView")
    }

    @ViewBuilder
    private func content(proxy: ScrollViewProxy) -> some View {
        // One List for all states. Keeping the surrounding container stable across
        // loading/empty/populated transitions means the FolderPillBar row keeps its
        // SwiftUI identity — and its inner horizontal ScrollView keeps its offset —
        // across folder switches.
        let folderLoadState = store.loadState(for: store.currentFolder)
        List {
            if store.pills.count > 1 {
                FolderPillBar(pills: store.pills, onSelect: { pill in
                    switchTo(pill: pill, proxy: proxy)
                }, onUserInteraction: {
                    listFocused = true
                })
                .id("folderPillBarRow")
                // Negative bottom inset compresses the natural ~23pt gap between
                // the pill row and the first chat row down to ~8pt.
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: -15, trailing: 0))
                .listRowBackground(Color.clear)
                // Belt-and-suspenders: also catch tap-only cases (no scroll offset change)
                // via a simultaneous drag gesture. The onUserInteraction callback on
                // FolderPillBar handles the horizontal-pan case via onScrollGeometryChange.
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0).onEnded { _ in
                        listFocused = true
                    }
                )
            }
            if store.chats.isEmpty {
                emptyStateRow(loadState: folderLoadState)
            } else {
                ForEach(Array(store.chats.enumerated()), id: \.element.id) { idx, row in
                    Button {
                        opener.open(row, makeStore: makeHistoryStore)
                    } label: {
                        ChatRowView(
                            row: row,
                            onRequestDownload: { store.requestFileDownload(fileId: $0) },
                            onCancelDownload: { store.cancelFileDownload(fileId: $0) }
                        )
                    }
                    .buttonStyle(.plain)
                    .onAppear { store.ensureChatsLoaded(near: idx) }
                }
            }
        }
        .listStyle(.plain)
        .focused($listFocused)
        .onAppear { listFocused = true }
        // Bar is intentionally visible (forced by `.toolbar(.visible, for:
        // .navigationBar)` on the body chain). When folder pills are present,
        // pull the pill row up by 24pt to tuck it under the bar's bottom edge
        // — without that, the natural top-of-list inset leaves an awkward gap
        // between the bar and the pill row. Plain chat rows (no pills) sit at
        // the natural top.
        .padding(.top, store.pills.count > 1 ? -20 : 0)
    }

    private func makeHistoryStore(for row: ChatRow) -> ChatHistoryStore? {
        guard let loader = client.makeChatHistoryLoader() else { return nil }
        return ChatHistoryStore(
            chatId: row.id,
            chatType: row.chatType,
            lastReadInboxMessageId: row.lastReadInboxMessageId,
            lastReadOutboxMessageId: row.lastReadOutboxMessageId,
            unreadCount: row.unreadCount,
            lastMessageId: row.lastMessageId,
            loader: loader,
            selfUserId: client.me?.id,
            userNames: client.userNames,
            draftText: row.draftText,
            coalesceUpdates: true
        )
    }

    @ViewBuilder
    private func emptyStateRow(loadState: LoadState) -> some View {
        Group {
            if loadState == .loadingFirstPage {
                LoadingView(label: "Loading chats…")
            } else {
                Text(store.folders.isEmpty ? "No chats yet" : "No chats in this folder")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .listRowBackground(Color.clear)
    }

    private func switchTo(pill: FolderPill, proxy: ScrollViewProxy) {
        store.setCurrentFolder(pill.chatList)
        // Reset outer vertical scroll to the top. The pill bar row keeps its SwiftUI
        // identity (single List across all states + stable `.id("folderPillBarRow")`),
        // so the inner horizontal ScrollView's offset survives the folder switch.
        withAnimation {
            proxy.scrollTo("folderPillBarRow", anchor: .top)
        }
        // Re-claim crown focus for the outer List — otherwise the pill tap leaves
        // crown focus on the horizontal pill ScrollView.
        listFocused = true
    }

    private enum BannerKind { case retry, dismiss }

    @ViewBuilder
    private func banner(text: String, kind: BannerKind) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.caption2)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            switch kind {
            case .retry:
                Button("Retry") { store.retry() }
                    .font(.caption2)
                    .buttonStyle(.borderedProminent)
            case .dismiss:
                Button {
                    dismissedLastError = client.lastError
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.thinMaterial)
    }
}
