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
import ChatMessageWidgetBubbleContentNode
import MessageWidget
import UnsupportedContentPill

/// The REAL chat bubbles (`ChatMessageItemImpl` → `ChatMessageBubbleItemNode` → `ChatMessageWidgetBubbleContentNode` and the
/// caption's text node) in a real `ListViewImpl`, rotated as the chat's history is, showing in-memory widget messages.
/// Synthetic: the list host itself and the interaction closures, which record what the bubble asks for in `events`.
public final class WidgetHarnessListHost {
    /// The other side of the chat (as the composer harness's), and the account's own peer for outgoing messages.
    public static let chatPeer = TelegramUser(
        id: EnginePeer.Id(namespace: Namespaces.Peer.CloudUser, id: EnginePeer.Id.Id._internalFromInt64Value(777001)),
        accessHash: nil, firstName: "Harness", lastName: "Chat", username: nil, phone: nil,
        photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [],
        storiesHidden: nil, nameColor: nil, backgroundEmojiId: nil, profileColor: nil,
        profileBackgroundEmojiId: nil, subscriberCount: nil, verificationIconFileId: nil)

    /// Stable ids never repeat in a process: the widget height cache and the registry are keyed by them.
    private static var nextStableId: UInt32 = 1

    public let listView: ListViewImpl
    private let context: AccountContext
    private var messages: [EngineRawMessage] = []
    private var paths: [EngineMessage.Id: String] = [:]
    private var items: [ListViewItem] = []
    private var controllerInteraction: ChatControllerInteraction?
    private var extractedMessageId: EngineMessage.Id?
    private var extractionEndTimer: SwiftSignalKit.Timer?

    /// What the bubbles asked for, in order: `openLink <url>`, `appStore`, `contextMenu <path>`, `contextMenuEnded <path>`.
    public private(set) var events: [String] = []

    public init(context: AccountContext) {
        self.context = context
        self.listView = ListViewImpl()
        // The chat's history is bottom-up: the list is rotated and its items are laid out rotated back.
        self.listView.transform = CATransform3DMakeRotation(CGFloat(Double.pi), 0.0, 0.0, 1.0)
        // A widget runs only from a layout pass on the main thread (the registry and its runtime are main-thread only).
        self.listView.useMainQueueTransactions = true
        self.controllerInteraction = self.makeControllerInteraction()
    }

    // MARK: - Content

    /// Replaces the list's messages with `posts`, oldest first, as the test channel posts them: each widget message
    /// (text = caption), then its reference pictures.
    public func load(posts: [WidgetHarnessPost]) {
        let accountPeer = TelegramUser(
            id: self.context.account.peerId, accessHash: nil, firstName: "Harness", lastName: "Account", username: nil, phone: nil,
            photo: [], botInfo: nil, restrictionInfo: nil, flags: [], emojiStatus: nil, usernames: [], storiesHidden: nil,
            nameColor: nil, backgroundEmojiId: nil, profileColor: nil, profileBackgroundEmojiId: nil, subscriberCount: nil,
            verificationIconFileId: nil)
        var peers = EngineSimpleDictionary<EnginePeer.Id, EngineRawPeer>()
        peers[WidgetHarnessListHost.chatPeer.id] = WidgetHarnessListHost.chatPeer
        peers[accountPeer.id] = accountPeer

        var messages: [EngineRawMessage] = []
        var paths: [EngineMessage.Id: String] = [:]
        var timestamp = Int32(Date().timeIntervalSince1970) - 10_000
        func append(text: String, media: EngineRawMedia, path: String) {
            let stableId = WidgetHarnessListHost.nextStableId
            WidgetHarnessListHost.nextStableId += 1
            let id = EngineMessage.Id(peerId: WidgetHarnessListHost.chatPeer.id, namespace: Namespaces.Message.Cloud, id: Int32(stableId))
            timestamp += 1
            messages.append(EngineRawMessage(stableId: stableId, stableVersion: 0, id: id, globallyUniqueId: nil, groupingKey: nil, groupInfo: nil, threadId: nil, timestamp: timestamp, flags: [], tags: [], globalTags: [], localTags: [], customTags: [], forwardInfo: nil, author: accountPeer, text: text, attributes: [], media: [media], peers: peers, associatedMessages: EngineSimpleDictionary(), associatedMessageIds: [], associatedMedia: [:], associatedThreadInfo: nil, associatedStories: [:]))
            paths[id] = path
        }
        for post in posts {
            guard let widget = TelegramMediaWidget(html: post.html, width: post.width, height: post.height) else {
                continue
            }
            append(text: post.caption, media: widget, path: post.path)
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
        self.listView.transaction(
            deleteIndices: (0 ..< previousCount).map { ListViewDeleteItem(index: $0, directionHint: nil) },
            insertIndicesAndItems: self.items.enumerated().map { ListViewInsertItem(index: $0.offset, previousIndex: nil, item: $0.element, directionHint: nil) },
            updateIndicesAndItems: [],
            options: [.Synchronous, .LowLatency],
            scrollToItem: ListViewScrollToItem(index: 0, position: .top(0.0), animated: false, curve: .Default(duration: nil), directionHint: .Up),
            updateSizeAndInsets: nil,
            stationaryItemRange: nil,
            updateOpaqueState: nil,
            completion: { _ in })
    }

    public func updateLayout(size: CGSize, topInset: CGFloat, bottomInset: CGFloat) {
        // Rotated: the list's top inset is the screen's bottom.
        let insets = UIEdgeInsets(top: bottomInset, left: 0.0, bottom: topInset, right: 0.0)
        self.listView.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: nil, additionalScrollDistance: 0.0, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: size, insets: insets, duration: 0.0, curve: .Default(duration: nil)), stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
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

    /// Scrolls so the message at `index` (0 = the first post, the top of the chat; past the end, the newest) is visible.
    public func scrollTo(messageIndex index: Int) {
        let listIndex = max(0, self.items.count - 1 - index)
        guard listIndex < self.items.count else {
            return
        }
        self.listView.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [], options: [.Synchronous, .LowLatency], scrollToItem: ListViewScrollToItem(index: listIndex, position: .center(.bottom), animated: false, curve: .Default(duration: nil), directionHint: .Up), updateSizeAndInsets: nil, stationaryItemRange: nil, updateOpaqueState: nil, completion: { _ in })
    }

    private func makeItem(_ message: EngineRawMessage) -> ListViewItem {
        let presentationData = self.context.sharedContext.currentPresentationData.with { $0 }
        let chatPresentationData = ChatPresentationData(
            theme: ChatPresentationThemeData(theme: presentationData.theme, wallpaper: presentationData.chatWallpaper),
            fontSize: presentationData.chatFontSize, strings: presentationData.strings, dateTimeFormat: presentationData.dateTimeFormat,
            nameDisplayOrder: presentationData.nameDisplayOrder, disableAnimations: false, largeEmoji: false,
            chatBubbleCorners: presentationData.chatBubbleCorners)
        let associatedData = ChatMessageItemAssociatedData(automaticDownloadPeerType: .contact, automaticDownloadPeerId: nil, automaticDownloadNetworkType: .wifi, isRecentActions: false, availableReactions: nil, availableMessageEffects: nil, savedMessageTags: nil, defaultReaction: nil, areStarReactionsEnabled: false, isPremium: false, accountPeer: nil)
        return ChatMessageItemImpl(presentationData: chatPresentationData, context: self.context, chatLocation: .peer(id: WidgetHarnessListHost.chatPeer.id), associatedData: associatedData, controllerInteraction: self.controllerInteraction!, content: .message(message: message, read: true, selection: .none, attributes: ChatMessageEntryAttributes(), location: nil))
    }

    // MARK: - What the bubbles ask for

    private func requestUpdate(_ id: EngineMessage.Id) {
        guard let messageIndex = self.messages.firstIndex(where: { $0.id == id }) else {
            return
        }
        let listIndex = self.messages.count - 1 - messageIndex
        let item = self.makeItem(self.messages[messageIndex])
        self.items[listIndex] = item
        self.listView.transaction(deleteIndices: [], insertIndicesAndItems: [], updateIndicesAndItems: [ListViewUpdateItem(index: listIndex, previousIndex: listIndex, item: item, directionHint: nil)], options: [.Synchronous, .LowLatency], updateSizeAndInsets: nil, updateOpaqueState: nil, completion: { _ in })
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
    /// telling the content nodes what the extraction tells them, and ends it 2 s later.
    private func openContextMenu(_ message: EngineRawMessage) {
        let path = self.paths[message.id] ?? "?"
        self.events.append("contextMenu \(path)")
        self.endExtraction()
        if let node = self.bubbleNode(for: message.id) {
            for contentNode in node.contentNodes {
                contentNode.willUpdateIsExtractedToContextPreview(true)
            }
        }
        self.extractedMessageId = message.id
        let timer = SwiftSignalKit.Timer(timeout: 2.0, repeat: false, completion: { [weak self] in
            self?.endExtraction()
        }, queue: Queue.mainQueue())
        self.extractionEndTimer = timer
        timer.start()
    }

    private func endExtraction() {
        self.extractionEndTimer?.invalidate()
        self.extractionEndTimer = nil
        guard let id = self.extractedMessageId else {
            return
        }
        self.extractedMessageId = nil
        if let node = self.bubbleNode(for: id) {
            for contentNode in node.contentNodes {
                contentNode.willUpdateIsExtractedToContextPreview(false)
            }
        }
        self.events.append("contextMenuEnded \(self.paths[id] ?? "?")")
    }

    // MARK: - The readout

    /// One line per laid-out bubble, top of the screen first: `bubble <i> <path> <w>x<h> @<x>,<y> widget|pill|placeholder
    /// [+caption]`, the widget area's size and its centre in `view`'s coordinates; then the events.
    public func readoutLines(in view: UIView) -> [String] {
        var bubbles: [(y: CGFloat, line: (Int) -> String)] = []
        self.listView.forEachItemNode { node in
            guard let node = node as? ChatMessageBubbleItemNode, let message = node.item?.message, let path = self.paths[message.id] else {
                return
            }
            guard let widgetNode = node.contentNodes.first(where: { $0 is ChatMessageWidgetBubbleContentNode }) else {
                return
            }
            var state = "placeholder"
            var area = widgetNode.view.bounds
            for subview in widgetNode.view.subviews {
                if let pill = subview as? UnsupportedContentPillView, !pill.isHidden {
                    state = "pill"
                    area = pill.frame
                } else if !subview.isHidden, subview.layer.mask != nil {
                    area = subview.frame
                    if subview.subviews.contains(where: { $0 is MessageWidgetView }) {
                        state = "widget"
                    }
                }
            }
            let frame = widgetNode.view.convert(area, to: view)
            // Another content node in the bubble is the caption's text.
            let caption = node.contentNodes.count > 1 ? " +caption" : ""
            bubbles.append((frame.minY, { index in
                return "bubble \(index) \(path) \(Int(frame.width.rounded()))x\(Int(frame.height.rounded())) @\(Int(frame.midX.rounded())),\(Int(frame.midY.rounded())) \(state)\(caption)"
            }))
        }
        bubbles.sort { $0.y < $1.y }
        return bubbles.enumerated().map { $0.element.line($0.offset) } + self.events
    }

    // MARK: - The interaction

    private func makeControllerInteraction() -> ChatControllerInteraction {
        return ChatControllerInteraction(openMessage: { _, _ in
            return false }, openPeer: { _, _, _, _ in }, openPeerMention: { _, _ in }, openMessageContextMenu: { [weak self] message, _, _, _, _, _ in
                self?.openContextMenu(message)
            }, openMessageReactionContextMenu: { _, _, _, _ in
            }, updateMessageReaction: { _, _, _, _ in }, activateMessagePinch: { _ in
            }, openMessageContextActions: { _, _, _, _ in }, navigateToMessage: { _, _, _ in }, navigateToMessageStandalone: { _ in
            }, navigateToThreadMessage: { _, _, _ in
            }, tapMessage: { _ in
        }, clickThroughMessage: { _, _ in
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
        }, chatControllerNode: {
            return nil
        }, presentGlobalOverlayController: { _, _ in }, callPeer: { _, _ in }, openConferenceCall: { _ in
        }, longTap: { _, _ in }, todoItemLongTap: { _, _ in }, pollOptionLongTap: { _, _ in
        }, openCheckoutOrReceipt: { _, _ in }, openSearch: { }, setupReply: { _ in
        }, canSetupReply: { _ in
            return .none
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
        }, displayMessageTooltip: { _, _, _, _, _ in
        }, seekToTimecode: { _, _, _ in
        }, scheduleCurrentMessage: { _ in
        }, sendScheduledMessagesNow: { _ in
        }, editScheduledMessagesTime: { _ in
        }, performTextSelectionAction: { _, _, _, _, _ in
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
        }, displayUndo: { _ in
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
