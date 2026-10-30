import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import ChatPresentationInterfaceState
import ChatControllerInteraction
import ChatHistoryEntry
import ChatMessageItem
import ChatMessageItemCommon
import ChatMessageItemImpl
import ChatMessageBubbleContentNode
import ChatMessageBubbleItemNode
import ChatHistoryListViewBackend
import ChatMessageShareButton
import ChatMessageWidgetBubbleContentNode
import MessageWidget
import TextSelectionNode
import UndoUI
import UnsupportedContentPill

/// The REAL chat bubbles (`ChatMessageItemImpl` → `ChatMessageBubbleItemNode` → `ChatMessageWidgetBubbleContentNode` and the
/// caption's text node) in the chat's own history backend (`makeCoreListChatHistoryBackend`), rotated as the chat's history
/// is, showing in-memory widget messages. Synthetic: the rotated wrapper (`ChatHistoryListNodeImpl` in the chat) and the
/// interaction closures, which record what the bubble asks for in `events`.
public final class WidgetHarnessListHost {
    /// The other side of the chat (as the composer harness's), and the account's own peer for outgoing messages.
    public static let chatPeer = TelegramUser(
        id: EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(777001)),
        accessHash: nil, firstName: "Harness", lastName: "Chat", username: nil, phone: nil,
        photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [],
        storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil,
        profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)

    /// `-harness-chat bot`: the same chat with a bot, as widgets mostly come from (a bot's incoming media gets the
    /// chat's share button beside its bubble).
    public static let botChatPeer = TelegramUser(
        id: WidgetHarnessListHost.chatPeer.id,
        accessHash: nil, firstName: "Harness", lastName: "Bot", username: "harness_bot", phone: nil,
        photo: [], botInfo: BotUserInfo(flags: [], inlinePlaceholder: nil), restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [],
        storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil,
        profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)

    /// Stable ids never repeat in a process: the widget height cache and the registry are keyed by them.
    private static var nextStableId: UInt32 = 1

    /// The rotated surface the root view hosts, as `ChatHistoryListNodeImpl` is in the chat: the π rotation is the
    /// wrapper's, the backend stays at identity with `rotated` set.
    public let node: ASDisplayNode
    /// Internal for the tests that reach the backend's scroll engine through `@testable` imports.
    let listView: ChatHistoryListViewBackend
    private let context: AccountContext
    private var messages: [EngineRawMessage] = []
    private var paths: [EngineMessage.Id: String] = [:]
    private var items: [ListViewItem] = []
    private var controllerInteraction: ChatControllerInteraction?
    /// The account's own peer, as the chat's history passes it to its items (a widget's viewer).
    private var accountPeer: EnginePeer?
    /// Where the last message tooltip shown would point, in window coordinates (`displayMessageTooltip`).
    public private(set) var lastTooltipRect: CGRect?
    private var extractedMessageId: EngineMessage.Id?
    /// Settings ▸ Appearance ▸ Text Size, when set after the context's (`setFontSize`).
    private var fontSize: PresentationFontSize?
    /// The posts pinned to the top of the screen (`pinToTop(path:)`).
    private var pinnedToTop = Set<EngineMessage.Id>()
    private var extractionEndTimer: SwiftSignalKit.Timer?
    /// The bubble's own recognizers, off while the stand-in menu holds it (`openContextMenu`).
    private var disabledRecognizers: [UIGestureRecognizer] = []

    /// What the bubbles asked for, in order: `openLink <url>`, `appStore`, `contextMenu <path>`, `contextMenuEnded <path>`,
    /// `reply <path>` (a completed swipe-to-reply), `reaction <path>` (the quick reaction, a double tap), `selectionMenu
    /// <titles>` / `selectionMenuDismissed` (a text selection's menu), `copy <text>` (its Copy, `\n` for a newline); and
    /// `back` (the root's stand-in back swipe began).
    public private(set) var events: [String] = []
    /// When the list's last drag ended, until its scrolling ends (the `scrollEnded` event).
    private var dragEndedAt: CFTimeInterval?
    /// When each bubble's press (its context gesture's shrink) was first seen, for the `pressed` event.
    private var pressedSince: [EngineMessage.Id: CFTimeInterval] = [:]

    /// `-harness-menu hold`: the stand-in context menu stays open until `endContextMenu()` (else it ends after 2 s).
    public var holdsMenu = false
    /// `-harness-copy-protected on`: the chat forbids copying (`isCopyProtectionEnabled`). Set before `load`.
    public var copyProtected = false
    /// `-harness-can-query on`: every widget message has the server's can_query. Set before `load`.
    public var canQuery = false
    /// `-harness-background-query on`: every widget message also has the server's background_query. Set before `load`.
    public var backgroundQuery = false
    /// `-harness-chat bot`: the chat is with a bot (`botChatPeer`). Set before `load`.
    public var botChat = false
    /// The other side of the chat: `chatPeer`, or `botChatPeer` under `botChat`.
    private var otherPeer: TelegramUser {
        return self.botChat ? WidgetHarnessListHost.botChatPeer : WidgetHarnessListHost.chatPeer
    }
    /// The stand-in context menu opened (true) or ended.
    public var onContextMenuChange: ((Bool) -> Void)?
    /// A text selection asked to show its menu: the root shows its actions as buttons.
    public var onSelectionMenu: ((WidgetHarnessContextMenuController) -> Void)?

    /// Records what the screen around the list saw (the root's back swipe).
    public func record(_ event: String) {
        self.events.append(event)
    }

    public init(context: AccountContext) {
        self.context = context
        self.node = ASDisplayNode()
        // The chat's history is bottom-up: the wrapper is rotated and the items are laid out rotated back.
        self.node.transform = CATransform3DMakeRotation(CGFloat(Double.pi), 0.0, 0.0, 1.0)
        self.listView = makeCoreListChatHistoryBackend(rotated: true)
        self.node.addSubnode(self.listView)
        self.controllerInteraction = self.makeControllerInteraction()
        // The `listDrag` event: the list's pan began, the chat scrolls (one post only rubber-bands, so no position shows it).
        self.listView.beganInteractiveDragging = { [weak self] _ in
            self?.events.append("listDrag")
        }
        // The `scrollEnded <seconds>` event: the list came to rest that long after the finger lifted (its momentum's
        // length; 0 without momentum).
        self.listView.endedInteractiveDragging = { [weak self] _ in
            self?.dragEndedAt = CACurrentMediaTime()
        }
        self.listView.didEndScrolling = { [weak self] _ in
            guard let self, let since = self.dragEndedAt else {
                return
            }
            self.dragEndedAt = nil
            self.events.append("scrollEnded " + String(format: "%.2f", CACurrentMediaTime() - since))
        }
    }

    // MARK: - Content

    /// Replaces the list's messages with `posts`, oldest first, as the test channel posts them: each widget message
    /// (text = caption), then its reference pictures; the account's own (outgoing), or the other side's when `incoming`.
    /// A post's message id: a 30-bit FNV-1a hash of its path, never 0.
    static func messageId(forPath path: String) -> Int32 {
        var hash: UInt32 = 2166136261
        for byte in path.utf8 {
            hash = (hash ^ UInt32(byte)) &* 16777619
        }
        return Int32(hash & 0x3fffffff) | 1
    }

    /// The account's own user id, a widget's `TelegramWidget.viewer.id` (widget-sandbox v0.2).
    public var accountPeerIdValue: Int64 {
        return self.context.account.peerId.id._internalGetInt64Value()
    }

    /// Replaces the widget media of the post at `path` with the same widget carrying `canQuery` and the bot's state
    /// (widget-sandbox v0.2), and updates its bubble as the chat does a message's edit (`updateMessageWidgetData`, or a
    /// supergroup's channel edit).
    public func replaceWidgetState(path: String, canQuery: Bool, chatData: String?, publicData: String?, widgetId: Int64? = nil) {
        guard let id = self.paths.first(where: { $0.value == path })?.key, let index = self.messages.firstIndex(where: { $0.id == id }) else {
            return
        }
        let message = self.messages[index]
        guard let widget = message.media.first(where: { $0 is TelegramMediaWidget }) as? TelegramMediaWidget else {
            return
        }
        let updated = TelegramMediaWidget(width: widget.width, height: widget.height, payload: widget.payload, isCopy: widget.isCopy, canQuery: canQuery, backgroundQuery: widget.backgroundQuery, chatData: chatData.map { Data($0.utf8) }, publicData: publicData.map { Data($0.utf8) }, widgetId: widgetId ?? widget.widgetId)
        self.messages[index] = message.withUpdatedMedia([updated])
        self.requestUpdate(id)
    }

    /// Replaces the caption of the post at `path`, its text and whether it shows above the widget
    /// (`InvertMediaMessageAttribute`, widget-sandbox v0.4.0; every other attribute goes, and no "edited" is added), and
    /// updates its bubble as the chat does a message's edit.
    public func replaceCaption(path: String, text: String, captionAbove: Bool) {
        guard let id = self.paths.first(where: { $0.value == path })?.key, let index = self.messages.firstIndex(where: { $0.id == id }) else {
            return
        }
        self.messages[index] = self.messages[index].withUpdatedText(text).withUpdatedAttributes(captionAbove ? [InvertMediaMessageAttribute()] : [])
        self.requestUpdate(id)
    }

    public func load(posts: [WidgetHarnessPost], incoming: Bool = false) {
        self.pinnedToTop = []
        let accountPeer = TelegramUser(
            id: self.context.account.peerId, accessHash: nil, firstName: "Harness", lastName: "Account", username: nil, phone: nil,
            photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil,
            nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil,
            verificationIconFileId: nil)
        self.accountPeer = EnginePeer(accountPeer)
        var peers = EngineSimpleDictionary<EnginePeer.Id, EngineRawPeer>()
        peers[self.otherPeer.id] = self.otherPeer
        peers[accountPeer.id] = accountPeer

        var messages: [EngineRawMessage] = []
        var paths: [EngineMessage.Id: String] = [:]
        var timestamp = Int32(Date().timeIntervalSince1970) - 10_000
        var takenIds = Set<Int32>()
        func append(text: String, media: EngineRawMedia, path: String, captionAbove: Bool = false) {
            let stableId = WidgetHarnessListHost.nextStableId
            WidgetHarnessListHost.nextStableId += 1
            // The message id is the post's, the same in every load as a real message's is (a widget's storage is kept
            // per message id); the stable id is new per load, so every load lays out new bubbles.
            var messageId = WidgetHarnessListHost.messageId(forPath: path)
            if takenIds.contains(messageId) {
                messageId = Int32(truncatingIfNeeded: stableId)
            }
            takenIds.insert(messageId)
            let id = EngineMessage.Id(peerId: WidgetHarnessListHost.chatPeer.id, namespace: Namespaces.Message.Cloud, id: messageId)
            timestamp += 1
            messages.append(EngineRawMessage(stableId: stableId, stableVersion: 0, id: id, globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: timestamp, flags: incoming ? [.Incoming] : [], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: incoming ? self.otherPeer : accountPeer, text: text, attributes: captionAbove ? [InvertMediaMessageAttribute()] : [], media: [media], peers: peers, associatedMessages: EngineSimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:]))
            paths[id] = path
        }
        for post in posts {
            guard let compressed = TelegramMediaWidget(html: post.html, width: post.width, height: post.height) else {
                continue
            }
            let widget = TelegramMediaWidget(width: compressed.width, height: compressed.height, payload: compressed.payload, isCopy: false, canQuery: self.canQuery, backgroundQuery: self.backgroundQuery, chatData: nil, publicData: nil, widgetId: nil)
            append(text: post.caption, media: widget, path: post.path, captionAbove: post.captionAbove)
            for photo in post.photos {
                let resource = LocalFileMediaResource(fileId: Int64.random(in: 1 ... Int64.max), size: Int64(photo.png.count))
                self.context.engine.resources.storeResourceData(id: EngineMediaResource.Id(resource.id), data: photo.png, synchronous: true)
                let representation = TelegramMediaImageRepresentation(dimensions: PixelDimensions(width: photo.width, height: photo.height), resource: resource, progressiveSizes: [], immediateThumbnailData: nil, hasVideo: false, isPersonal: false)
                let image = TelegramMediaImage(imageId: EngineMedia.Id(namespace: Namespaces.Media.LocalImage, id: Int64.random(in: 1 ... Int64.max)), representations: [representation], immediateThumbnailData: nil, reference: nil, partialReference: nil, flags: [])
                append(text: "", media: image, path: post.path + "#picture")
            }
        }
        self.messages = messages
        self.paths = paths
        self.events = []

        let previousCount = self.items.count
        // Index 0 is the bottom of the rotated list: the newest message.
        self.items = messages.reversed().map(self.makeItem)
        self.listView.chatHistoryTransaction(
            deleteIndices: (0 ..< previousCount).map { ListViewDeleteItem(index: $0, directionHint: nil) },
            insertIndicesAndItems: self.items.enumerated().map { ChatHistoryListViewInsertItem(index: $0.offset, previousIndex: nil, stableId: self.stableId(atListIndex: $0.offset), item: $0.element, directionHint: nil) },
            updateIndicesAndItems: [],
            options: [.Synchronous, .LowLatency],
            scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: false, curve: .Default(duration: nil), directionHint: .Up),
            updateOpaqueState: nil)
    }

    public func updateLayout(size: CGSize, topInset: CGFloat, bottomInset: CGFloat) {
        // Rotated: the list's top inset is the screen's bottom.
        let insets = UIEdgeInsets(top: bottomInset, left: 0.0, bottom: topInset, right: 0.0)
        self.listView.frame = CGRect(origin: CGPoint(), size: size)
        self.listView.chatHistoryTransaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: size, insets: insets, duration: 0.0, curve: .Default(duration: nil)), updateOpaqueState: nil)
    }

    /// Settings ▸ Appearance ▸ Text Size changed in the open chat: every item again with the new presentation data, in
    /// place, as the chat updates its history on a presentation-data change (the same messages, so the same widgets).
    public func setFontSize(_ fontSize: PresentationFontSize) {
        self.fontSize = fontSize
        self.items = self.messages.reversed().map(self.makeItem)
        self.listView.chatHistoryTransaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: self.items.enumerated().map { ChatHistoryListViewUpdateItem(index: $0.offset, previousIndex: $0.offset, stableId: self.stableId(atListIndex: $0.offset), item: $0.element, directionHint: nil) }, options: [.Synchronous, .LowLatency], updateOpaqueState: nil)
    }

    /// The indices (0 = the first message, the top of the chat) of the widget messages whose path contains `part`.
    public func messageIndices(pathContaining part: String) -> [Int] {
        return self.messages.enumerated().compactMap { index, message in
            guard let path = self.paths[message.id], path.contains(part), !path.hasSuffix("#picture") else {
                return nil
            }
            return index
        }
    }

    /// Scrolls so the message at `index` (0 = the first post, the top of the chat; past the end, the newest) is visible;
    /// `hold` keeps it there as the chat's jump to a message does (`.always`), until a drag.
    public func scrollTo(messageIndex index: Int, hold: ListViewScrollHold = .none) {
        let listIndex = max(0, self.items.count - 1 - index)
        guard listIndex < self.items.count else {
            return
        }
        self.listView.chatHistoryTransaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: listIndex, position: .center(.bottom), animated: false, curve: .Default(duration: nil), directionHint: .Up, hold: hold), updateOpaqueState: nil)
    }

    /// Pins the post at `path` to the top of the screen as the chat does while a bot streams its reply under the user's
    /// message (`ChatHistoryListNode`'s `pinToTopStableId`): its item declares `pinToEdgeWithInset`, and the list
    /// scrolls to it with `.top(0.0)` in the same pass, which engages CoreList's pinned-row latch until a drag or a held
    /// jump to another post.
    public func pinToTop(path: String) {
        guard let id = self.paths.first(where: { $0.value == path })?.key, let messageIndex = self.messages.firstIndex(where: { $0.id == id }) else {
            return
        }
        self.pinnedToTop.insert(id)
        let listIndex = self.messages.count - 1 - messageIndex
        let item = self.makeItem(self.messages[messageIndex])
        self.items[listIndex] = item
        let update = ChatHistoryListViewUpdateItem(index: listIndex, previousIndex: listIndex, stableId: self.stableId(atListIndex: listIndex), item: item, directionHint: nil)
        self.listView.chatHistoryTransaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [update], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: listIndex, position: .top(0.0), animated: false, curve: .Default(duration: nil), directionHint: .Up), updateOpaqueState: nil)
    }

    /// Every message update the bubbles asked for, in order: the post's path and the edge the update carried.
    public private(set) var updateAnchors: [(path: String, anchor: ListViewItemResizeAnchor?)] = []
    /// The number of messages each update transaction carried, in order.
    public private(set) var updateTransactions: [Int] = []
    /// While true, the bubbles' update requests wait for `flushUpdates()`, which sends them as one transaction (one list
    /// pass), as the chat's history does when several messages change in one view update.
    public var holdsUpdates = false
    private var heldUpdates: [EngineMessage.Id] = []
    /// The number of messages whose update requests wait for `flushUpdates()`.
    public var heldUpdateCount: Int {
        return self.heldUpdates.count
    }

    /// Sends the update requests held since `holdsUpdates` was set, in one transaction.
    public func flushUpdates() {
        let ids = self.heldUpdates
        self.heldUpdates = []
        self.sendUpdates(ids)
    }

    /// Updates the post at `path` as its bubble asking would (`requestMessageUpdate`).
    public func updateMessage(path: String) {
        if let id = self.paths.first(where: { $0.value == path })?.key {
            self.requestUpdate(id)
        }
    }

    /// Holds the chat's newest edge `distance` beyond its resting place, as an overscroll action does (the next
    /// channel's pull), the content moving with it; 0 releases it.
    public func holdOverscroll(distance: CGFloat) {
        self.listView.holdOverscrollAction(distance: distance, movesContent: true)
    }

    /// Whether the list holds a scrolled-to row (`scrollTo(messageIndex:hold:)`) until a drag.
    public var isHoldingScrollTarget: Bool {
        return self.listView.isHoldingScrollTarget
    }

    /// The live widget view of the post at `path`, while its bubble is loaded.
    public func widgetView(path: String) -> MessageWidgetView? {
        guard let id = self.paths.first(where: { $0.value == path })?.key, let node = self.bubbleNode(for: id) else {
            return nil
        }
        func find(_ view: UIView) -> MessageWidgetView? {
            if let view = view as? MessageWidgetView {
                return view
            }
            return view.subviews.lazy.compactMap(find).first
        }
        return find(node.view)
    }

    /// The message id of the post at `path`.
    public func messageId(path: String) -> EngineMessage.Id? {
        return self.paths.first(where: { $0.value == path })?.key
    }

    /// What the widget content node of the post at `path` answers the bubble at `point` (its own coordinates), as the
    /// bubble's tap recognizer asks at a touch's down (`isEstimating`) and its swipes ask before they begin: whether
    /// the bubble's tap is ignored, whether the press claims its hold, and whether a horizontal drag is claimed.
    public func widgetContentAnswers(path: String, at point: CGPoint) -> (ignoresTap: Bool, claimsHold: Bool, claimsHorizontalDrag: Bool)? {
        guard let id = self.paths.first(where: { $0.value == path })?.key, let node = self.bubbleNode(for: id), let widgetNode = node.contentNodes.first(where: { $0 is ChatMessageWidgetBubbleContentNode }) else {
            return nil
        }
        let action = widgetNode.tapActionAtPoint(point, gesture: .tap, isEstimating: true)
        let ignoresTap: Bool
        if case .ignore = action.content {
            ignoresTap = true
        } else {
            ignoresTap = false
        }
        return (ignoresTap, action.hasLongTapAction, widgetNode.claimsHorizontalDrag(at: point))
    }

    /// The list item's stable id, the backend's identity: its message's (index 0 is the newest message).
    private func stableId(atListIndex index: Int) -> UInt64 {
        return UInt64(self.messages[self.messages.count - 1 - index].stableId)
    }

    private func makeItem(_ message: EngineRawMessage) -> ListViewItem {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let chatPresentationData = ChatPresentationData(
            theme: ChatPresentationThemeData(theme: presentationData.theme, wallpaper: presentationData.chatWallpaper),
            fontSize: self.fontSize ?? presentationData.chatFontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat,
            nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: false, largeEmoji: false,
            chatBubbleCorners: presentationData.chatBubbleCorners)
        let associatedData = ChatMessageItemAssociatedData(automaticDownloadPeerType: .contact, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .wifi, isRecentActions: false, isCopyProtectionEnabled: self.copyProtected, availableReactions: nil, availableMessageEffects: nil, savedMessageTags: nil, defaultReaction: nil, areStarReactionsEnabled: false, isPremium: false, accountPeer: self.accountPeer)
        var attributes = ChatMessageEntryAttributes()
        attributes.pinToTop = self.pinnedToTop.contains(message.id)
        return ChatMessageItemImpl(presentationData: chatPresentationData, context: self.context, chatLocation: .peer(id: WidgetHarnessListHost.chatPeer.id), associatedData: associatedData, controllerInteraction: self.controllerInteraction!, content: .message(message: message, read: true, selection: .none, attributes: attributes, location: nil))
    }

    // MARK: - What the bubbles ask for

    private func requestUpdate(_ id: EngineMessage.Id) {
        if self.holdsUpdates {
            if !self.heldUpdates.contains(id) {
                self.heldUpdates.append(id)
            }
            return
        }
        self.sendUpdates([id])
    }

    private func sendUpdates(_ ids: [EngineMessage.Id]) {
        var updates: [ChatHistoryListViewUpdateItem] = []
        for id in ids {
            guard let messageIndex = self.messages.firstIndex(where: { $0.id == id }) else {
                continue
            }
            let listIndex = self.messages.count - 1 - messageIndex
            let item = self.makeItem(self.messages[messageIndex])
            self.items[listIndex] = item
            // As the chat's history updates a message (`ChatHistoryListNode.requestMessageUpdate`): animated, keeping
            // the edge the message asks for (a widget's resize anchor).
            let resizeAnchor = self.bubbleNode(for: id)?.resizeAnchor
            self.updateAnchors.append((self.paths[id] ?? "?", resizeAnchor))
            updates.append(ChatHistoryListViewUpdateItem(index: listIndex, previousIndex: listIndex, stableId: self.stableId(atListIndex: listIndex), item: item, directionHint: nil, resizeAnchor: resizeAnchor))
        }
        guard !updates.isEmpty else {
            return
        }
        self.updateTransactions.append(updates.count)
        self.listView.chatHistoryTransaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: updates, options: [.AnimateInsertion, .Synchronous], updateOpaqueState: nil)
    }

    private func bubbleNode(for id: EngineMessage.Id) -> ChatMessageBubbleItemNode? {
        var result: ChatMessageBubbleItemNode?
        self.listView.forEachItemNode { node in
            if let node = node as? ChatMessageBubbleItemNode, node.item?.message.id == id {
                result = node
            }
        }
        return result
    }

    /// The chat's long press opens its context menu, which extracts the bubble; the harness stands in for the menu by
    /// telling the content nodes what the extraction tells them (both hooks, as the chat's context source does), and ends
    /// it 2 s later unless it `holdsMenu`.
    private func openContextMenu(_ message: EngineRawMessage) {
        let path = self.paths[message.id] ?? "?"
        self.events.append("contextMenu \(path)")
        self.endContextMenu()
        if let node = self.bubbleNode(for: message.id) {
            for contentNode in node.contentNodes {
                contentNode.willUpdateIsExtractedToContextPreview(true)
                contentNode.updateIsExtractedToContextPreview(true)
            }
        }
        self.extractedMessageId = message.id
        // In the chat the menu moves the bubble's content out from under the bubble's own recognizers (its long press,
        // taps, swipe to reply); here it stays in place, so they are switched off until the menu ends.
        if let node = self.bubbleNode(for: message.id), let contentView = node.contentNodes.first?.view {
            var view = contentView.superview
            while let current = view {
                for recognizer in current.gestureRecognizers ?? [] where recognizer.isEnabled {
                    recognizer.isEnabled = false
                    self.disabledRecognizers.append(recognizer)
                }
                if current === node.view {
                    break
                }
                view = current.superview
            }
        }
        self.onContextMenuChange?(true)
        if !self.holdsMenu {
            let timer = SwiftSignalKit.Timer(timeout: 2.0, repeat: false, completion: { [weak self] in
                self?.endContextMenu()
            }, queue: Queue.mainQueue())
            self.extractionEndTimer = timer
            timer.start()
        }
    }

    /// Opens the stand-in context menu on the newest widget message, as its long press would: what a test that is about
    /// the lifted bubble, not the long press, starts from.
    public func openContextMenuOnNewestWidget() {
        guard let message = self.messages.last(where: { message in
            message.media.contains(where: { $0 is TelegramMediaWidget })
        }) else {
            return
        }
        self.openContextMenu(message)
    }

    /// Ends the stand-in context menu, if one is open.
    public func endContextMenu() {
        self.extractionEndTimer?.invalidate()
        self.extractionEndTimer = nil
        guard let id = self.extractedMessageId else {
            return
        }
        self.extractedMessageId = nil
        for recognizer in self.disabledRecognizers {
            recognizer.isEnabled = true
        }
        self.disabledRecognizers.removeAll()
        if let node = self.bubbleNode(for: id) {
            for contentNode in node.contentNodes {
                contentNode.willUpdateIsExtractedToContextPreview(false)
                contentNode.updateIsExtractedToContextPreview(false)
            }
        }
        self.events.append("contextMenuEnded \(self.paths[id] ?? "?")")
        self.onContextMenuChange?(false)
    }

    /// The selection menus shown and not yet dismissed. Presenting is what keeps a menu alive in the chat
    /// (`TextSelectionNode` holds its menu weakly), so the harness, which presents nothing, keeps them until dismissed.
    private var shownMenus: [WidgetHarnessContextMenuController] = []

    /// A text selection's menu: recorded with its actions' titles, shown by the root as buttons.
    private func presentOverlay(_ controller: ViewController) {
        guard let menu = controller as? WidgetHarnessContextMenuController else {
            return
        }
        self.shownMenus.append(menu)
        menu.dismissed = { [weak self, weak menu] in
            self?.shownMenus.removeAll { $0 === menu }
        }
        self.events.append("selectionMenu " + menu.actions.map(WidgetHarnessContextMenuController.title(of:)).joined(separator: ","))
        self.onSelectionMenu?(menu)
    }

    /// The root's selection-menu buttons went away because the menu was dismissed.
    public func recordSelectionMenuDismissed() {
        self.events.append("selectionMenuDismissed")
    }

    // MARK: - The readout

    /// One line per laid-out bubble, top of the screen first: `bubble <i> <path> <w>x<h> @<x>,<y> widget|pill|placeholder
    /// [+caption]`, the widget area's size and its centre in `view`'s coordinates; then the events.
    public func readoutLines(in view: UIView) -> [String] {
        var bubbles: [(y: CGFloat, line: (Int) -> String)] = []
        var logs: [(y: CGFloat, line: String)] = []
        self.listView.forEachItemNode { node in
            guard let node = node as? ChatMessageBubbleItemNode, let message = node.item?.message, let path = self.paths[message.id] else {
                return
            }
            guard let widgetNode = node.contentNodes.first(where: { $0 is ChatMessageWidgetBubbleContentNode }) else {
                return
            }
            var state = "placeholder"
            var area = widgetNode.view.bounds
            var widgetView: MessageWidgetView?
            for subview in widgetNode.view.subviews {
                if let pill = subview as? UnsupportedContentPillView, !pill.isHidden {
                    state = "pill"
                    area = pill.frame
                } else if !subview.isHidden, subview.layer.mask != nil {
                    area = subview.frame
                    if let widget = subview.subviews.first(where: { $0 is MessageWidgetView }) as? MessageWidgetView {
                        state = "widget"
                        widgetView = widget
                    }
                }
            }
            let frame = widgetNode.view.convert(area, to: view)
            // The harness's own fixtures only: each read waits for the widget's queue.
            if path.hasPrefix("fixture/"), let widgetView, let log = widgetView.documentElementAttribute("data-log"), !log.isEmpty {
                logs.append((frame.minY, "log \(path) \(log)"))
            }
            // An automatic conformance test's own result, for a Tier 2 run of it through the real bubble.
            if path.hasPrefix("auto/"), let widgetView, let result = widgetView.documentElementAttribute("data-conformance"), !result.isEmpty {
                logs.append((frame.minY, "conformance \(path) \(result)"))
            }
            // Another content node in the bubble is the caption's text.
            let caption = node.contentNodes.count > 1 ? " +caption" : ""
            // The chat's share button beside the bubble.
            let share = (node.subnodes ?? []).contains { $0 is ChatMessageShareButton && !$0.isHidden } ? " +share" : ""
            // The bubble's context gesture shrinks its content while it waits for a long press (ContextControllerSourceNode).
            // A Tier 2 query does not return while synthesized fingers play, so how long a press lasted is an event.
            let isPressed = node.mainContextSourceNode.contentNode.layer.sublayerTransform.m11 < 0.999
            let pressed = isPressed ? " pressed" : ""
            if isPressed, self.pressedSince[message.id] == nil {
                self.pressedSince[message.id] = CACurrentMediaTime()
            } else if !isPressed, let since = self.pressedSince.removeValue(forKey: message.id) {
                self.events.append("pressed \(path) " + String(format: "%.1f", CACurrentMediaTime() - since))
            }
            bubbles.append((frame.minY, { index in
                return "bubble \(index) \(path) \(Int(frame.width.rounded()))x\(Int(frame.height.rounded())) @\(Int(frame.midX.rounded())),\(Int(frame.midY.rounded())) \(state)\(caption)\(share)\(pressed)"
            }))
        }
        bubbles.sort { $0.y < $1.y }
        logs.sort { $0.y < $1.y }
        return bubbles.enumerated().map { $0.element.line($0.offset) } + logs.map(\.line) + self.events
    }

    /// Each laid-out widget bubble's widget content node, by its post's path.
    public func widgetContentNodes() -> [(path: String, node: ChatMessageWidgetBubbleContentNode)] {
        var out: [(path: String, node: ChatMessageWidgetBubbleContentNode)] = []
        self.listView.forEachItemNode { node in
            guard let node = node as? ChatMessageBubbleItemNode, let message = node.item?.message, let path = self.paths[message.id],
                  let widgetNode = node.contentNodes.first(where: { $0 is ChatMessageWidgetBubbleContentNode }) as? ChatMessageWidgetBubbleContentNode else {
                return
            }
            out.append((path, widgetNode))
        }
        return out
    }

    /// Each laid-out widget bubble's widget area (the clip view, or the pill) and its content node's bounds, in `view`'s
    /// coordinates, top of the screen first: the widget fills its content node when the bubble adds no padding of its own.
    public func widgetAreas(in view: UIView) -> [(path: String, area: CGRect, content: CGRect)] {
        var out: [(path: String, area: CGRect, content: CGRect)] = []
        self.listView.forEachItemNode { node in
            guard let node = node as? ChatMessageBubbleItemNode, let message = node.item?.message, let path = self.paths[message.id] else {
                return
            }
            guard let widgetNode = node.contentNodes.first(where: { $0 is ChatMessageWidgetBubbleContentNode }) else {
                return
            }
            for subview in widgetNode.view.subviews where !subview.isHidden && (subview is UnsupportedContentPillView || subview.layer.mask != nil) {
                out.append((path, widgetNode.view.convert(subview.frame, to: view), widgetNode.view.convert(widgetNode.view.bounds, to: view)))
            }
        }
        return out.sorted { $0.area.minY < $1.area.minY }
    }

    // MARK: - The interaction

    private func makeControllerInteraction() -> ChatControllerInteraction {
        return ChatControllerInteraction(openMessage: { _, _ in
            return false }, openPeer: { _, _, _, _ in }, openPeerMention: { _, _ in }, openMessageContextMenu: { [weak self] message, _, _, _, _, _ in
                self?.openContextMenu(message)
            }, openMessageReactionContextMenu: { _, _, _, _ in
            }, updateMessageReaction: { [weak self] message, _, _, _ in
                // The quick reaction: the bubble's double tap (sdk-v1 §5.5).
                guard let self else {
                    return
                }
                self.events.append("reaction \(self.paths[message.id] ?? "?")")
            }, activateMessagePinch: { _ in
            }, openMessageContextActions: { _, _, _, _ in }, navigateToMessage: { _, _, _ in }, navigateToMessageStandalone: { _ in
            }, navigateToThreadMessage: { _, _, _ in
            }, tapMessage: nil, clickThroughMessage: { _, _ in
        }, toggleMessagesSelection: { _, _ in }, sendCurrentMessage: { _, _ in }, sendMessage: { _, _ in }, sendSticker: { _, _, _, _, _, _, _, _, _ in return false }, sendEmoji: { _, _, _ in }, sendGif: { _, _, _, _, _ in return false }, sendBotContextResultAsGif: { _, _, _, _, _, _ in
            return false
        }, editGif: { _, _ in
        }, requestMessageActionCallback: { _, _, _, _, _ in }, requestMessageActionUrlAuth: { _, _ in }, activateSwitchInline: { _, _, _ in }, openUrl: { [weak self] url in
            // The chat would show "Open link?" (`forceConcealed`); the harness records the request and opens nothing.
            self?.events.append("openLink \(url.url)\(url.forceConcealed ? "" : " (not concealed)")")
        }, openExternalInstantPage: { _ in
        }, shareCurrentLocation: { _ in }, shareAccountContact: { _ in }, sendBotCommand: { _, _ in }, openInstantPage: { _, _ in  }, openWallpaper: { _ in  }, openTheme: { _ in  }, openHashtag: { _, _ in }, updateInputState: { _ in }, updateInputMode: { _ in }, updatePresentationState: { _ in }, openMessageShareMenu: { _ in
        }, presentController: { _, _ in
        }, presentControllerInCurrent: { _, _ in
        }, navigationController: {
            return nil
        }, chatControllerNode: { [weak self] in
            // A text selection needs a root to present its menu over; the harness's menu is synthetic, so any node will do.
            return self?.node
        }, presentGlobalOverlayController: { [weak self] controller, _ in
            self?.presentOverlay(controller)
        }, callPeer: { _, _ in }, openConferenceCall: { _ in
        }, longTap: { _, _ in }, todoItemLongTap: { _, _ in }, pollOptionLongTap: { _, _ in
        }, openCheckoutOrReceipt: { _, _ in }, openSearch: { }, setupReply: { [weak self] messageId in
            // Swipe-to-reply completed on a bubble (sdk-v1 §5.5: the chat's gesture, unless the widget claimed x).
            guard let self else {
                return
            }
            self.events.append("reply \(self.paths[messageId] ?? "?")")
        }, canSetupReply: { _ in
            return .reply
        }, canSendMessages: {
            return false
        }, navigateToFirstDateMessage: { _, _ in
        }, requestRedeliveryOfFailedMessages: { _ in
        }, addContact: { _ in
        }, rateCall: { _, _, _ in
        }, requestSelectMessagePollOptions: { _, _ in
        }, requestAddMessagePollOption: { _, _, _, _, _ in
        }, requestOpenMessagePollResults: { _, _ in
        }, openAppStorePage: { [weak self] in
            self?.events.append("appStore")
        }, displayMessageTooltip: { [weak self] _, text, _, node, nodeRect in
            // As ChatController: no tooltip without a node, and the anchor is `nodeRect` inside the node.
            guard let self, let node else {
                self?.events.append("tooltip " + text + " (not shown)")
                return
            }
            var rect = node.view.convert(node.view.bounds, to: nil)
            if let nodeRect {
                rect = CGRect(origin: rect.origin.offsetBy(dx: nodeRect.minX, dy: nodeRect.minY - node.bounds.minY), size: nodeRect.size)
            }
            self.lastTooltipRect = rect
            self.events.append("tooltip " + text)
        }, seekToTimecode: { _, _, _ in
        }, scheduleCurrentMessage: { _ in
        }, sendScheduledMessagesNow: { _ in
        }, editScheduledMessagesTime: { _ in
        }, performTextSelectionAction: { [weak self] _, _, text, _, action in
            if case .copy = action {
                self?.events.append("copy " + text.string.replacingOccurrences(of: "\n", with: "\\n"))
            }
        }, displayImportedMessageTooltip: { _ in
        }, displaySwipeToReplyHint: {
        }, dismissReplyMarkupMessage: { _ in
        }, openMessagePollResults: { _, _ in
        }, openPollCreation: { _, _ in
        }, openPollMedia: { _, _ in
        }, displayPollSolution: { _, _ in
        }, displayPsa: { _, _ in
        }, displayDiceTooltip: { _ in
        }, animateDiceSuccess: { _, _ in
        }, displayPremiumStickerTooltip: { _, _ in
        }, displayEmojiPackTooltip: { _, _ in
        }, openPeerContextMenu: { _, _, _, _, _ in
        }, openMessageReplies: { _, _, _ in
        }, openReplyThreadOriginalMessage: { _ in
        }, openMessageStats: { _ in
        }, editMessageMedia: { _, _ in
        }, copyText: { _ in
        }, displayUndo: { [weak self] content in
            // A widget's copyText toast (sdk-v1 §2.15) and the copy-protection notice, as `toast <text>`.
            switch content {
            case let .copy(text), let .info(_, text, _, _):
                self?.events.append("toast " + text.replacingOccurrences(of: "\n", with: "\\n"))
            default:
                break
            }
        }, isAnimatingMessage: { _ in
            return false
        }, getMessageTransitionNode: {
            return nil
        }, updateChoosingSticker: { _ in
        }, commitEmojiInteraction: { _, _, _, _ in
        }, openLargeEmojiInfo: { _, _, _ in
        }, openJoinLink: { _ in
        }, openWebView: { _, _, _, _, _ in
        }, activateAdAction: { _, _, _, _ in
        }, adContextAction: { _, _, _ in
        }, removeAd: { _ in
        }, openRequestedPeerSelection: { _, _, _, _ in
        }, saveMediaToFiles: { _ in
        }, openNoAdsDemo: {
        }, openAdsInfo: {
        }, displayGiveawayParticipationStatus: { _ in
        }, openPremiumStatusInfo: { _, _, _, _ in
        }, openRecommendedChannelContextMenu: { _, _, _ in
        }, openGroupBoostInfo: { _, _ in
        }, openStickerEditor: {
        }, openAgeRestrictedMessageMedia: { _, _ in
        }, playMessageEffect: { _ in
        }, editMessageFactCheck: { _ in
        }, sendGift: { _ in
        }, openUniqueGift: { _ in
        }, openMessageFeeException: {
        }, requestMessageUpdate: { [weak self] id, _, _ in
            self?.requestUpdate(id)
        }, cancelInteractiveKeyboardGestures: {
        }, dismissTextInput: {
        }, scrollToMessageId: { _, _ in
        }, scrollToMessageIdWithAnchor: { _, _ in
        }, navigateToStory: { _, _ in
        }, attemptedNavigationToPrivateQuote: { _ in
        }, forceUpdateWarpContents: {
        }, playShakeAnimation: {
        }, displayQuickShare: { _, _ ,_ in
        }, updateChatLocationThread: { _, _ in
        }, requestToggleTodoMessageItem: { _, _, _ in
        }, displayTodoToggleUnavailable: { _ in
        }, openStarsPurchase: { _ in
        }, openRankInfo: { _, _, _ in
        }, openSetPeerAvatar: {
        }, displayPollRestrictedToast: { _ in
        }, automaticMediaDownloadSettings: MediaAutoDownloadSettings.defaultSettings,
        pollActionState: ChatInterfacePollActionState(), stickerSettings: ChatInterfaceStickerSettings(), presentationContext: ChatPresentationContext(context: self.context, backgroundNode: nil))
    }
}
