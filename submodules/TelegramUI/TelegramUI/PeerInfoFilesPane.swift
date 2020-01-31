import AsyncDisplayKit
import Display
import TelegramCore
import SyncCore
import SwiftSignalKit
import Postbox
import TelegramPresentationData
import AccountContext
import ContextUI
import PhotoResources
import TelegramUIPreferences

final class PeerInfoListPaneNode: ASDisplayNode, PeerInfoPaneNode {
    private let context: AccountContext
    private let peerId: PeerId
    
    private let listNode: ChatHistoryListNode
    
    private var currentParams: (size: CGSize, isScrollingLockedAtTop: Bool, presentationData: PresentationData)?
    
    private let ready = Promise<Bool>()
    private var didSetReady: Bool = false
    var isReady: Signal<Bool, NoError> {
        return self.ready.get()
    }
    
    private var hiddenMediaDisposable: Disposable?
    
    init(context: AccountContext, openMessage: @escaping (MessageId) -> Bool, peerId: PeerId, tagMask: MessageTags) {
        self.context = context
        self.peerId = peerId
        
        var openMessageImpl: ((MessageId) -> Bool)?
        let controllerInteraction = ChatControllerInteraction(openMessage: { message, _ in
            return openMessageImpl?(message.id) ?? false
        }, openPeer: { _, _, _ in
        }, openPeerMention: { _ in
        }, openMessageContextMenu: { _, _, _, _, _ in
        }, openMessageContextActions: { _, _, _, _ in
        }, navigateToMessage: { _, _ in
        }, tapMessage: nil, clickThroughMessage: {
        }, toggleMessagesSelection: { _, _ in
        }, sendCurrentMessage: { _ in
        }, sendMessage: { _ in
        }, sendSticker: { _, _, _, _ in
            return false
        }, sendGif: { _, _, _ in
            return false
        }, requestMessageActionCallback: { _, _, _ in
        }, requestMessageActionUrlAuth: { _, _, _ in
        }, activateSwitchInline: { _, _ in
        }, openUrl: { _, _, _, _ in
        }, shareCurrentLocation: {
        }, shareAccountContact: {
        }, sendBotCommand: { _, _ in
        }, openInstantPage: { _, _ in
        }, openWallpaper: { _ in
        }, openTheme: {_ in
        }, openHashtag: { _, _ in
        }, updateInputState: { _ in
        }, updateInputMode: { _ in
        }, openMessageShareMenu: { _ in
        }, presentController: { _, _ in
        }, navigationController: {
            return nil
        }, chatControllerNode: {
            return nil
        }, reactionContainerNode: {
            return nil
        }, presentGlobalOverlayController: { _, _ in
        }, callPeer: { _ in
        }, longTap: { _, _ in
        }, openCheckoutOrReceipt: { _ in
        }, openSearch: {
        }, setupReply: { _ in
        }, canSetupReply: { _ in
            return false
        }, navigateToFirstDateMessage: { _ in
        }, requestRedeliveryOfFailedMessages: { _ in
        }, addContact: { _ in
        }, rateCall: { _, _ in
        }, requestSelectMessagePollOptions: { _, _ in
        }, requestOpenMessagePollResults: { _, _ in
        }, openAppStorePage: {
        }, displayMessageTooltip: { _, _, _, _ in
        }, seekToTimecode: { _, _, _ in
        }, scheduleCurrentMessage: {
        }, sendScheduledMessagesNow: { _ in
        }, editScheduledMessagesTime: { _ in
        }, performTextSelectionAction: { _, _, _ in
        }, updateMessageReaction: { _, _ in
        }, openMessageReactions: { _ in
        }, displaySwipeToReplyHint: {
        }, dismissReplyMarkupMessage: { _ in
        }, openMessagePollResults: { _, _ in
        }, openPollCreation: { _ in
        }, requestMessageUpdate: { _ in
        }, cancelInteractiveKeyboardGestures: {
        }, automaticMediaDownloadSettings: MediaAutoDownloadSettings.defaultSettings, pollActionState: ChatInterfacePollActionState(), stickerSettings: ChatInterfaceStickerSettings(loopAnimatedStickers: false))
        
        self.listNode = ChatHistoryListNode(context: context, chatLocation: .peer(peerId), tagMask: tagMask, subject: nil, controllerInteraction: controllerInteraction, selectedMessages: .single(nil), mode: .list(search: false, reversed: false))
        
        super.init()
        
        openMessageImpl = { id in
            return openMessage(id)
        }
        
        self.hiddenMediaDisposable = context.sharedContext.mediaManager.galleryHiddenMediaManager.hiddenIds().start(next: { [weak self] ids in
            guard let strongSelf = self else {
                return
            }
            var hiddenMedia: [MessageId: [Media]] = [:]
            for id in ids {
                if case let .chat(accountId, messageId, media) = id, accountId == strongSelf.context.account.id {
                    hiddenMedia[messageId] = [media]
                }
            }
            controllerInteraction.hiddenMedia = hiddenMedia
            strongSelf.listNode.forEachItemNode { itemNode in
                if let itemNode = itemNode as? ListMessageNode {
                    itemNode.updateHiddenMedia()
                }
            }
        })
        
        self.listNode.preloadPages = true
        self.addSubnode(self.listNode)
        
        self.ready.set(self.listNode.historyState.get()
        |> take(1)
        |> map { _ -> Bool in true })
    }
    
    deinit {
        self.hiddenMediaDisposable?.dispose()
    }
    
    func scrollToTop() -> Bool {
        let offset = self.listNode.visibleContentOffset()
        switch offset {
        case let .known(value) where value <= CGFloat.ulpOfOne:
            return false
        default:
            self.listNode.scrollToEndOfHistory()
            return true
        }
    }
    
    func update(size: CGSize, isScrollingLockedAtTop: Bool, presentationData: PresentationData, synchronous: Bool, transition: ContainedViewLayoutTransition) {
        self.currentParams = (size, isScrollingLockedAtTop, presentationData)
        
        transition.updateFrame(node: self.listNode, frame: CGRect(origin: CGPoint(), size: size))
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        self.listNode.updateLayout(transition: transition, updateSizeAndInsets: ListViewUpdateSizeAndInsets(size: size, insets: UIEdgeInsets(), duration: duration, curve: curve))
        self.listNode.scrollEnabled = !isScrollingLockedAtTop
    }
    
    func findLoadedMessage(id: MessageId) -> Message? {
        self.listNode.messageInCurrentHistoryView(id)
    }
    
    func transitionNodeForGallery(messageId: MessageId, media: Media) -> (ASDisplayNode, CGRect, () -> (UIView?, UIView?))? {
        var transitionNode: (ASDisplayNode, CGRect, () -> (UIView?, UIView?))?
        self.listNode.forEachItemNode { itemNode in
            if let itemNode = itemNode as? ListMessageNode {
                if let result = itemNode.transitionNode(id: messageId, media: media) {
                    transitionNode = result
                }
            }
        }
        return transitionNode
    }
}
