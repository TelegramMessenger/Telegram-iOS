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
                .toolbar(.visible, for: .navigationBar)
                // Must live INSIDE the NavigationStack so the modifier's
                // .navigationDestination(item:) attaches to it.
                .accountSwitcherSheet(presentation: .push, logoutAffordance: .allowed)
            }
        }
        .accessibilityIdentifier("chatListView")
    }

    @ViewBuilder
    private func content(proxy: ScrollViewProxy) -> some View {
        let folderLoadState = store.loadState(for: store.currentFolder)
        if #available(watchOS 26.0, *) {
            // Horizontal ScrollView inside a List row receives horizontal pans
            // correctly on watchOS-26+, so pills live inside the List and
            // scroll off with the chat content.
            List {
                pillBarSection(proxy: proxy, inList: true)
                chatRows(folderLoadState: folderLoadState, cardChrome: false)
            }
            .listStyle(.plain)
            .focused($listFocused)
            .onAppear { listFocused = true }
            .padding(.top, store.pills.count > 1 ? -20 : 0)
        } else {
            // watchOS-11: List swallows horizontal drags, so a nested horizontal
            // ScrollView can't pan. ScrollView + LazyVStack routes gestures to
            // the matching axis correctly.
            ScrollView {
                LazyVStack(spacing: 4) {
                    pillBarSection(proxy: proxy, inList: false)
                    chatRows(folderLoadState: folderLoadState, cardChrome: true)
                }
                .padding(.horizontal, 4)
            }
            .focused($listFocused)
            .onAppear { listFocused = true }
        }
    }

    @ViewBuilder
    private func pillBarSection(proxy: ScrollViewProxy, inList: Bool) -> some View {
        if store.pills.count > 1 {
            FolderPillBar(pills: store.pills, onSelect: { pill in
                switchTo(pill: pill, proxy: proxy)
            }, onUserInteraction: {
                listFocused = true
            })
            .id("folderPillBarRow")
            .modifier(PillBarRowLayout(inList: inList))
        }
    }

    @ViewBuilder
    private func chatRows(folderLoadState: LoadState, cardChrome: Bool) -> some View {
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
                    .modifier(ChatListRowChrome(card: cardChrome))
                }
                .accountSwitcherRowButtonStyle()
                .onAppear { store.ensureChatsLoaded(near: idx) }
            }
        }
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

/// List-row insets for the pill bar when embedded inside `List`.
private struct PillBarRowLayout: ViewModifier {
    let inList: Bool

    func body(content: Content) -> some View {
        if inList {
            content
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: -15, trailing: 0))
                .listRowBackground(Color.clear)
        } else {
            content.padding(.bottom, 4)
        }
    }
}

/// Explicit row chrome for the ScrollView path — `List` provides this on its own.
private struct ChatListRowChrome: ViewModifier {
    let card: Bool

    func body(content: Content) -> some View {
        if card {
            content
                .padding(.horizontal, 8)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.fill.tertiary)
                )
        } else {
            content
        }
    }
}
