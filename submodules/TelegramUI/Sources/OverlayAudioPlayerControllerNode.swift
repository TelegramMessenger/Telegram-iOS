import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import Postbox
import TelegramCore
import TelegramPresentationData
import TelegramUIPreferences
import AccountContext
import DirectionalPanGesture
import ChatPresentationInterfaceState
import ChatControllerInteraction
import ContextUI
import UndoUI
import ChatHistoryEntry
import MultilineTextComponent
import GlassControls
import PhotoResources

final class OverlayAudioPlayerControllerNode: ViewControllerTracingNode, ASGestureRecognizerDelegate {
    let ready = Promise<Bool>()
    
    private let context: AccountContext
    
    private let source: ChatHistoryListSource
    private let chatLocation: ChatLocation
    private var presentationData: PresentationData
    private let type: MediaManagerPlayerType
    private let requestDismiss: () -> Void
    private let requestShare: (ShareControllerSubject) -> Void
    private let requestSearchByArtist: (String) -> Void
    private let requestAdd: () -> Void
    private let playlistLocation: SharedMediaPlaylistLocation?
    private let isGlobalSearch: Bool
    
    private let controllerInteraction: ChatControllerInteraction
    
    private var currentIsReversed: Bool
    
    private let dimNode: ASDisplayNode
    private let containerContainingNode: ASDisplayNode
    private let contentNode: ASDisplayNode
    private let controlsNode: OverlayAudioPlayerControlsNode
    private let historyBackgroundNode: ASDisplayNode
    private let historyBackgroundContentNode: ASDisplayNode
    private let historyFrameNode: SparseNode
    private let historyFrameLeftOverlayNode: ASDisplayNode
    private let historyFrameRightOverlayNode: ASDisplayNode
    private let historyFrameTopOverlayClipNode: ASDisplayNode
    private let historyFrameTopOverlayNode: ASDisplayNode
    private let historyFrameTopMaskNode: ASImageNode
    private let collapseNode: HighlightableButtonNode
    private let headerButtons = ComponentView<Empty>()
    private let title = ComponentView<Empty>()
    
    private var floatingHeaderOffset: CGFloat?
    private var historyContentOffset: CGFloat = 0.0
    private var hasAnyHistoryMessages: Bool?
    private var historyNode: ChatHistoryListNodeImpl
    private var replacementHistoryNode: ChatHistoryListNodeImpl?
    private var replacementHistoryNodeFloatingOffset: CGFloat?
    
    private var currentAlbumArt: (FileMediaReference, SharedMediaPlaybackAlbumArt)?
    private let albumArtBackground: UIVisualEffectView
    private let albumArtNode = TransformImageNode()
    
    private var saveMediaDisposable: MetaDisposable?
    
    private var validLayout: ContainerViewLayout?
    
    private var presentationDataDisposable: Disposable?
    private let replacementHistoryNodeReadyDisposable = MetaDisposable()
    
    private let getParentController: () -> ViewController?
        
    private var dataDisposable: Disposable?
    private var savedIdsPromise = Promise<Set<Int64>?>()
    private var savedIds: Set<Int64>?
    private var peer: EnginePeer?
    
    private var copyProtectionEnabled = false
        
    init(
        context: AccountContext,
        chatLocation: ChatLocation,
        type: MediaManagerPlayerType,
        initialMessageId: MessageId,
        initialOrder: MusicPlaybackSettingsOrder,
        playlistLocation: SharedMediaPlaylistLocation?,
        requestDismiss: @escaping () -> Void,
        requestShare: @escaping (ShareControllerSubject) -> Void,
        requestSearchByArtist: @escaping (String) -> Void,
        requestAdd: @escaping () -> Void,
        getParentController: @escaping () -> ViewController?
    ) {
        self.context = context
        self.chatLocation = chatLocation
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.type = type
        self.requestDismiss = requestDismiss
        self.requestShare = requestShare
        self.requestSearchByArtist = requestSearchByArtist
        self.requestAdd = requestAdd
        self.playlistLocation = playlistLocation
        self.getParentController = getParentController
        
        if let playlistLocation = playlistLocation as? PeerMessagesPlaylistLocation, case let .custom(messages, canReorder, at, loadMore, _) = playlistLocation.effectiveLocation(context: context) {
            self.source = .custom(messages: messages, messageId: at, quote: nil, isSavedMusic: true, canReorder: canReorder, loadMore: loadMore)
            self.isGlobalSearch = false
        } else {
            self.source = .default
            self.isGlobalSearch = false
        }
        
        if case .regular = initialOrder {
            self.currentIsReversed = false
        } else {
            self.currentIsReversed = true
        }
        
        var openMessageImpl: ((MessageId) -> Bool)?
        var openMessageContextMenuImpl: ((Message, ASDisplayNode, CGRect, Any?) -> Void)?
        self.controllerInteraction = ChatControllerInteraction(openMessage: { message, _ in
            if let openMessageImpl = openMessageImpl {
                return openMessageImpl(message.id)
            } else {
                return false
            }
        }, openPeer: { _, _, _, _ in
        }, openPeerMention: { _, _ in
        }, openMessageContextMenu: { message, _, node, rect, gesture, _ in
            openMessageContextMenuImpl?(message, node, rect, gesture)
        }, openMessageReactionContextMenu: { _, _, _, _ in
        }, updateMessageReaction: { _, _, _, _ in
        }, activateMessagePinch: { _ in
        }, openMessageContextActions: { _, _, _, _ in
        }, navigateToMessage: { _, _, _ in
        }, navigateToMessageStandalone: { _ in
        }, navigateToThreadMessage: { _, _, _ in
        }, tapMessage: nil, clickThroughMessage: { _, _ in
        }, toggleMessagesSelection: { _, _ in
        }, sendCurrentMessage: { _, _ in
        }, sendMessage: { _ in
        }, sendSticker: { _, _, _, _, _, _, _, _, _ in
            return false
        }, sendEmoji: { _, _, _ in
        }, sendGif: { _, _, _, _, _ in
            return false
        }, sendBotContextResultAsGif: { _, _, _, _, _, _ in
            return false
        }, editGif: { _, _ in
        }, requestMessageActionCallback: { _, _, _, _, _ in
        }, requestMessageActionUrlAuth: { _, _ in
        }, activateSwitchInline: { _, _, _ in
        }, openUrl: { _ in
        }, shareCurrentLocation: {
        }, shareAccountContact: {
        }, sendBotCommand: { _, _ in
        }, openInstantPage: { _, _ in
        }, openWallpaper: { _ in
        }, openTheme: {_ in 
        }, openHashtag: { _, _ in
        }, updateInputState: { _ in
        }, updateInputMode: { _ in
        }, updatePresentationState: { _ in
        }, openMessageShareMenu: { _ in
        }, presentController: { _, _ in
        }, presentControllerInCurrent: { _, _ in
        }, navigationController: {
            return nil
        }, chatControllerNode: {
            return nil
        }, presentGlobalOverlayController: { _, _ in
        }, callPeer: { _, _ in
        }, openConferenceCall: { _ in
        }, longTap: { _, _ in
        }, todoItemLongTap: { _, _ in
        }, pollOptionLongTap: { _, _ in
        }, openCheckoutOrReceipt: { _, _ in
        }, openSearch: {
        }, setupReply: { _ in
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
        }, openAppStorePage: {
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
        }, openPollCreation: { _ in
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
        }, openWebView: { _, _, _, _ in
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
        }, requestMessageUpdate: { _, _ in
        }, cancelInteractiveKeyboardGestures: {
        }, dismissTextInput: {
        }, scrollToMessageId: { _ in
        }, navigateToStory: { _, _ in
        }, attemptedNavigationToPrivateQuote: { _ in
        }, forceUpdateWarpContents: {
        }, playShakeAnimation: {
        }, displayQuickShare: { _, _ ,_ in
        }, updateChatLocationThread: { _, _ in
        }, requestToggleTodoMessageItem: { _, _, _ in
        }, displayTodoToggleUnavailable: { _ in
        }, openStarsPurchase: { _ in
        }, openRankInfo: { _, _, _ in }, openSetPeerAvatar: {}, automaticMediaDownloadSettings: MediaAutoDownloadSettings.defaultSettings, pollActionState: ChatInterfacePollActionState(), stickerSettings: ChatInterfaceStickerSettings(), presentationContext: ChatPresentationContext(context: context, backgroundNode: nil))
        
        self.dimNode = ASDisplayNode()
        self.dimNode.backgroundColor = UIColor(white: 0.0, alpha: 0.5)
        
        self.containerContainingNode = ASDisplayNode()
        self.containerContainingNode.clipsToBounds = true
        
        self.contentNode = ASDisplayNode()
        
        self.controlsNode = OverlayAudioPlayerControlsNode(account: context.account, engine: context.engine, accountManager: context.sharedContext.accountManager, presentationData: self.presentationData, status: context.sharedContext.mediaManager.musicMediaPlayerState, chatLocation: self.chatLocation, source: self.source)
        self.controlsNode.getParentController = getParentController
        
        self.historyBackgroundNode = ASDisplayNode()
        self.historyBackgroundNode.isLayerBacked = true
        
        self.historyBackgroundContentNode = ASDisplayNode()
        self.historyBackgroundContentNode.isLayerBacked = true
        self.historyBackgroundContentNode.backgroundColor = self.presentationData.theme.list.itemModalBlocksBackgroundColor
        
        self.historyBackgroundNode.addSubnode(self.historyBackgroundContentNode)
        
        self.historyFrameNode = SparseNode()
        self.historyFrameLeftOverlayNode = ASDisplayNode()
        self.historyFrameLeftOverlayNode.backgroundColor = self.presentationData.theme.list.modalBlocksBackgroundColor
        
        self.historyFrameRightOverlayNode = ASDisplayNode()
        self.historyFrameRightOverlayNode.backgroundColor = self.presentationData.theme.list.modalBlocksBackgroundColor
        
        self.historyFrameTopOverlayClipNode = ASDisplayNode()
        self.historyFrameTopOverlayClipNode.clipsToBounds = true
        
        self.historyFrameTopOverlayNode = ASDisplayNode()
        self.historyFrameTopOverlayNode.cornerRadius = 38.0
        self.historyFrameTopOverlayNode.clipsToBounds = true
        self.historyFrameTopOverlayNode.backgroundColor = self.presentationData.theme.list.modalBlocksBackgroundColor
        self.historyFrameTopOverlayNode.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        
        self.historyFrameTopMaskNode = ASImageNode()
        self.historyFrameTopMaskNode.displaysAsynchronously = false
        self.historyFrameTopMaskNode.image = generateCornersImage(theme: self.presentationData.theme)
        self.historyFrameTopMaskNode.isUserInteractionEnabled = false
        
        let tagMask: MessageTags
        switch type {
            case .music:
                tagMask = .music
            case .voice:
                tagMask = .voiceOrInstantVideo
            case .file:
                tagMask = .file
        }
                
        let chatLocationContextHolder = Atomic<ChatLocationContextHolder?>(value: nil)
        self.historyNode = ChatHistoryListNodeImpl(
            context: context,
            updatedPresentationData: (context.sharedContext.currentPresentationData.with({ $0 }), context.sharedContext.presentationData),
            systemStyle: .glass,
            chatLocation: chatLocation,
            chatLocationContextHolder: chatLocationContextHolder,
            adMessagesContext: nil,
            tag: .tag(tagMask),
            source: self.source,
            subject: .message(id: .id(initialMessageId), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: nil, setupReply: false),
            controllerInteraction: self.controllerInteraction,
            selectedMessages: .single(nil),
            mode: .list(reversed: self.currentIsReversed, reverseGroups: !self.currentIsReversed, displayHeaders: .none, hintLinks: false, isGlobalSearch: self.isGlobalSearch, isMusicPlaylist: true),
            isChatPreview: false,
            messageTransitionNode: { return nil
            }
        )
        self.historyNode.clipsToBounds = true
        
        self.collapseNode = HighlightableButtonNode()
        self.collapseNode.displaysAsynchronously = false
        self.collapseNode.setImage(generateCollapseIcon(theme: self.presentationData.theme), for: [])
        
        self.albumArtBackground = UIVisualEffectView()
        self.albumArtBackground.contentView.addSubview(self.albumArtNode.view)
        self.albumArtNode.isUserInteractionEnabled = false
        
        super.init()
        
        self.backgroundColor = nil
        self.isOpaque = false
        
        self.historyNode.preloadPages = true
        self.historyNode.stackFromBottom = true
        self.historyNode.areContentAnimationsEnabled = true
        self.historyNode.contentPositionChanged = { [weak self] offset in
            self?.updateHistoryContentOffset(offset, transition: .immediate)
        }
        self.historyNode.updateFloatingHeaderOffset = { [weak self] offset, transition in
            if let strongSelf = self {
                strongSelf.updateFloatingHeaderOffset(offset: offset, transition: transition)
            }
        }
        
        self.historyNode.endedInteractiveDragging = { [weak self] _ in
            guard let self else {
                return
            }
            switch self.historyNode.visibleContentOffset() {
            case let .known(value):
                if let playlistLocation = self.playlistLocation as? PeerMessagesPlaylistLocation, case let .savedMusic(_, _, canReorder) = playlistLocation, canReorder {
                    
                } else {
                    if value <= -10.0 {
                        self.requestDismiss()
                    }
                }
            default:
                break
            }
        }
        
        self.controlsNode.updateIsExpanded = { [weak self] in
            if let strongSelf = self, let validLayout = strongSelf.validLayout {
                strongSelf.containerLayoutUpdated(validLayout, transition: .animated(duration: 0.5, curve: .spring))
            }
        }
        
        self.controlsNode.requestAlbumArtDisplay = { [weak self] fileReferenceAndAlbumArt in
            guard let self, let layout = self.validLayout else {
                return
            }
            self.currentAlbumArt = fileReferenceAndAlbumArt
            
            if let (fileReference, albumArt) = fileReferenceAndAlbumArt {
                self.albumArtNode.setSignal(playerAlbumArt(postbox: self.context.account.postbox, engine: self.context.engine, fileReference: fileReference, albumArt: albumArt, thumbnail: false))
            }
            
            self.containerLayoutUpdated(layout, transition: .animated(duration: 0.25, curve: .easeInOut))
        }
        
        self.controlsNode.requestCollapse = { [weak self] in
            self?.requestDismiss()
        }
        
        self.controlsNode.requestShare = { [weak self] subject in
            self?.requestShare(subject)
        }
        
        self.controlsNode.requestSearchByArtist = { [weak self] artist in
            self?.requestSearchByArtist(artist)
        }
        
        self.controlsNode.requestLayout = { [weak self] transition in
            if let self, let validLayout = self.validLayout {
                self.containerLayoutUpdated(validLayout, transition: transition)
            }
        }
        
        self.controlsNode.updateOrder = { [weak self] order in
            if let strongSelf = self {
                let reversed: Bool
                if case .regular = order {
                    reversed = false
                } else {
                    reversed = true
                }
                if reversed != strongSelf.currentIsReversed {
                    strongSelf.currentIsReversed = reversed
                    if let itemId = strongSelf.controlsNode.currentItemId as? PeerMessagesMediaPlaylistItemId {
                        strongSelf.transitionToUpdatedHistoryNode(atMessage: itemId.messageId)
                    }
                }
            }
        }
        
        self.controlsNode.control = { [weak self] action in
            if let strongSelf = self {
                strongSelf.context.sharedContext.mediaManager.playlistControl(action, type: strongSelf.type)
            }
        }
        
        self.controlsNode.requestSaveToProfile = { [weak self] file in
            if let self {
                self.addToSavedMusic(file: file)
            }
        }
        
        self.controlsNode.requestRemoveFromProfile = { [weak self] file in
            if let self {
                self.removeFromSavedMusic(file: file)
            }
        }
        
        self.addSubnode(self.dimNode)
        self.addSubnode(self.containerContainingNode)
        self.containerContainingNode.addSubnode(self.contentNode)
        self.contentNode.addSubnode(self.historyBackgroundNode)
        self.contentNode.addSubnode(self.historyNode)
        self.contentNode.addSubnode(self.historyFrameNode)
        self.contentNode.addSubnode(self.controlsNode)
        
        self.historyFrameNode.addSubnode(self.historyFrameLeftOverlayNode)
        self.historyFrameNode.addSubnode(self.historyFrameRightOverlayNode)
        self.historyFrameNode.addSubnode(self.historyFrameTopOverlayClipNode)
        self.historyFrameTopOverlayClipNode.addSubnode(self.historyFrameTopOverlayNode)
        self.historyFrameNode.addSubnode(self.historyFrameTopMaskNode)
        self.historyFrameNode.addSubnode(self.collapseNode)
        
        self.historyNode.beganInteractiveDragging = { [weak self] _ in
            self?.controlsNode.collapse()
        }
        
        openMessageImpl = { [weak self] id in
            if let strongSelf = self, strongSelf.isNodeLoaded, let message = strongSelf.historyNode.messageInCurrentHistoryView(id) {
                var playlistLocation: PeerMessagesPlaylistLocation?
                if let location = strongSelf.playlistLocation as? PeerMessagesPlaylistLocation {
                    if case let .custom(messages, canReorder, _, loadMore, hidePanel) = location {
                        playlistLocation = .custom(messages: messages, canReorder: canReorder, at: id, loadMore: loadMore, hidePanel: hidePanel)
                    } else if case let .savedMusic(context, _, canReorder) = location {
                        playlistLocation = .savedMusic(context: context, at: id.id, canReorder: canReorder)
                    }
                }
                return strongSelf.context.sharedContext.openChatMessage(OpenChatMessageParams(context: strongSelf.context, chatLocation: nil, chatFilterTag: nil, chatLocationContextHolder: nil, message: message, standalone: false, reverseMessageGalleryOrder: false, navigationController: nil, dismissInput: { }, present: { _, _, _ in }, transitionNode: { _, _, _ in return nil }, addToTransitionSurface: { _ in }, openUrl: { _ in }, openPeer: { _, _ in }, callPeer: { _, _ in }, openConferenceCall: { _ in
                }, enqueueMessage: { _ in }, sendSticker: nil, sendEmoji: nil, setupTemporaryHiddenMedia: { _, _, _ in }, chatAvatarHiddenMedia: { _, _ in }, playlistLocation: playlistLocation))
            }
            return false
        }
        
        openMessageContextMenuImpl = { [weak self] message, node, rect, gesture in
            guard let self else {
                return
            }
            self.openMessageContextMenu(message: message, node: node, frame: rect, gesture: gesture as? ContextGesture)
        }
        
        self.presentationDataDisposable = context.sharedContext.presentationData.startStrict(next: { [weak self] presentationData in
            if let strongSelf = self {
                if strongSelf.presentationData.theme !== presentationData.theme || strongSelf.presentationData.strings !== presentationData.strings {
                    strongSelf.updatePresentationData(presentationData)
                }
            }
        })
        
        let copyProtectionEnabled: Signal<Bool, NoError>
        if case let .peer(peerId) = self.chatLocation {
            if let playlistLocation = self.playlistLocation as? PeerMessagesPlaylistLocation, case .savedMusic = playlistLocation {
                copyProtectionEnabled = .single(false)
            } else if peerId.namespace == Namespaces.Peer.CloudUser {
                copyProtectionEnabled = context.engine.data.subscribe(
                    TelegramEngine.EngineData.Item.Peer.CopyProtectionEnabled(id: peerId),
                    TelegramEngine.EngineData.Item.Peer.MyCopyProtectionEnabled(id: peerId)
                ) |> map { copyProtectionEnabled, myCopyProtectionEnabled in
                    return copyProtectionEnabled || myCopyProtectionEnabled
                }
            } else {
                copyProtectionEnabled = context.engine.data.subscribe(TelegramEngine.EngineData.Item.Peer.CopyProtectionEnabled(id: peerId))
            }
        } else {
            copyProtectionEnabled = .single(false)
        }
        
        let peer: Signal<EnginePeer?, NoError>
        if let playlistLocation = self.playlistLocation as? PeerMessagesPlaylistLocation, case let .savedMusic(savedMusicContext, _, _) = playlistLocation {
            peer = context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: savedMusicContext.peerId))
        } else {
            peer = .single(nil)
        }
        
        self.dataDisposable = combineLatest(
            queue: Queue.mainQueue(),
            context.engine.peers.savedMusicIds(),
            copyProtectionEnabled,
            peer
        ).start(next: { [weak self] savedIds, copyProtectionEnabled, peer in
            guard let self else {
                return
            }
            let isFirstTime = self.savedIds == nil
            self.savedIds = savedIds
            self.savedIdsPromise.set(.single(savedIds))
            self.copyProtectionEnabled = copyProtectionEnabled
            self.controlsNode.forceCopyProtected.set(copyProtectionEnabled)
            self.peer = peer
            
            let transition: ContainedViewLayoutTransition = isFirstTime ? .immediate : .animated(duration: 0.5, curve: .spring)
            if let validLayout = self.validLayout {
                self.containerLayoutUpdated(validLayout, transition: transition)
            }
        })
        
        self.ready.set(
            combineLatest(
                self.historyNode.historyState.get()
                |> take(1),
                self.savedIdsPromise.get()
                |> filter {
                    $0 != nil
                }
                |> take(1)
            )
            |> map { _, _ -> Bool in
                return true
            }
        )
        
        self.setupReordering()
        
        self.albumArtBackground.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.albumArtTapped(_:))))
    }
    
    deinit {
        self.presentationDataDisposable?.dispose()
        self.replacementHistoryNodeReadyDisposable.dispose()
        self.dataDisposable?.dispose()
        self.saveMediaDisposable?.dispose()
    }
    
    override func didLoad() {
        super.didLoad()
        
        self.dimNode.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(self.dimTapGesture(_:))))
        
        let panRecognizer = DirectionalPanGestureRecognizer(target: self, action: #selector(self.panGesture(_:)))
        panRecognizer.delegate = self.wrappedGestureRecognizerDelegate
        panRecognizer.delaysTouchesBegan = false
        panRecognizer.cancelsTouchesInView = true
        panRecognizer.shouldBegin = { [weak self] point in
            guard let self else {
                return false
            }
            if self.historyFrameTopOverlayNode.bounds.contains(self.view.convert(point, to: self.historyFrameTopOverlayNode.view)) {
                return true
            }
            if self.controlsNode.bounds.contains(self.view.convert(point, to: self.controlsNode.view)) {
                return true
            }
            return false
        }
        self.view.addGestureRecognizer(panRecognizer)
    }
    
    private func setupReordering() {
        guard let playlistLocation = self.playlistLocation as? PeerMessagesPlaylistLocation, case let .savedMusic(savedMusicContext, _, canReorder) = playlistLocation, canReorder else {
            return
        }
        let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: savedMusicContext.peerId))
        |> deliverOnMainQueue).start(next: { [weak self] peer in
            guard let self, let peer = peer.flatMap({ PeerReference($0._asPeer()) }) else {
                return
            }

            self.historyNode.reorderItem = { fromIndex, toIndex, transactionOpaqueState -> Signal<Bool, NoError> in
                guard let filteredEntries = (transactionOpaqueState as? ChatHistoryTransactionOpaqueState)?.historyView.filteredEntries, !filteredEntries.isEmpty else {
                    return .single(false)
                }
                
                func mapIndex(_ uiIndex: Int) -> Int {
                    return filteredEntries.count - 1 - uiIndex
                }

                let mappedFromIndex = mapIndex(fromIndex)
                guard filteredEntries.indices.contains(mappedFromIndex), case let .MessageEntry(fromMessage, _, _, _, _, _) = filteredEntries[mappedFromIndex], let fromFile = fromMessage.media.first(where: { $0 is TelegramMediaFile }) as? TelegramMediaFile else {
                    return .single(false)
                }

                var afterFile: TelegramMediaFile?
                if toIndex > 0 {
                    let afterMappedIndex = mapIndex(toIndex - 1)
                    if filteredEntries.indices.contains(afterMappedIndex), case let .MessageEntry(afterMessage, _, _, _, _, _) = filteredEntries[afterMappedIndex], let file = afterMessage.media.first(where: { $0 is TelegramMediaFile }) as? TelegramMediaFile {
                        afterFile = file
                    }
                } else {
                    afterFile = nil
                }
                
                let _ = savedMusicContext.addMusic(
                    file: .savedMusic(peer: peer, media: fromFile),
                    afterFile: afterFile.flatMap { .savedMusic(peer: peer, media: $0) }
                ).start()

                return .single(true)
            }
        })
        self.historyNode.autoScrollWhenReordering = false
        self.historyNode.didEndScrollingWithOverscroll = { [weak self] in
            guard let self else {
                return
            }
            self.requestDismiss()
        }
    }

    
    func updatePresentationData(_ presentationData: PresentationData) {
        self.presentationData = presentationData
        
        self.historyBackgroundContentNode.backgroundColor = self.hasAnyHistoryMessages == true ? self.presentationData.theme.list.itemModalBlocksBackgroundColor : self.presentationData.theme.list.modalPlainBackgroundColor
        self.historyFrameLeftOverlayNode.backgroundColor = self.hasAnyHistoryMessages == true ? self.presentationData.theme.list.modalBlocksBackgroundColor : self.presentationData.theme.list.modalPlainBackgroundColor
        self.historyFrameRightOverlayNode.backgroundColor = self.hasAnyHistoryMessages == true ? self.presentationData.theme.list.modalBlocksBackgroundColor : self.presentationData.theme.list.modalPlainBackgroundColor
        self.historyFrameTopOverlayNode.backgroundColor = self.hasAnyHistoryMessages == true ? self.presentationData.theme.list.modalBlocksBackgroundColor : self.presentationData.theme.list.modalPlainBackgroundColor
        self.historyFrameTopMaskNode.image = generateCornersImage(theme: self.presentationData.theme)
        
        self.collapseNode.setImage(generateCollapseIcon(theme: self.presentationData.theme), for: [])
        
        self.controlsNode.updatePresentationData(self.presentationData)
    }
    
    private func dismissAllTooltips() {
        guard let controller = self.getParentController() else {
            return
        }
        controller.window?.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismissWithCommitAction()
            }
        })
        controller.forEachController({ controller in
            if let controller = controller as? UndoOverlayController {
                controller.dismissWithCommitAction()
            }
            return true
        })
    }
    
    func forwardToSavedMessages(file: FileMediaReference) {
        self.dismissAllTooltips()
        
        let _ = self.context.engine.messages.enqueueOutgoingMessage(to: self.context.account.peerId, replyTo: nil, content: .file(file)).start()
        
        let controller = UndoOverlayController(
            presentationData: self.presentationData,
            content: .forward(savedMessages: true, text: self.presentationData.strings.MediaPlayer_AudioForwardedToSavedMesagesTooltip),
            action: { _ in
                return true
            }
        )
        self.getParentController()?.present(controller, in: .current)
    }
    
    private func updateMusicSaved(file: FileMediaReference, isSaved: Bool) {
        if let playlistLocation = self.playlistLocation as? PeerMessagesPlaylistLocation, case let .savedMusic(savedMusicContext, _, _) = playlistLocation, savedMusicContext.peerId == self.context.account.peerId {
            if isSaved {
                let _ = savedMusicContext.addMusic(file: file).start()
            } else {
                let _ = savedMusicContext.removeMusic(file: file).start()
            }
        } else {
            if isSaved {
                let _ = self.context.engine.peers.addSavedMusic(file: file).start()
            } else {
                let _ = self.context.engine.peers.removeSavedMusic(file: file).start()
            }
        }
    }
    
    func addToSavedMusic(file: FileMediaReference) {
        self.dismissAllTooltips()
        
        var actionText: String? = self.presentationData.strings.MediaPlayer_SavedMusic_AddedToProfile_View
        if let itemId = self.controlsNode.currentItemId as? PeerMessagesMediaPlaylistItemId, itemId.messageId.namespace == Namespaces.Message.Local && itemId.messageId.peerId == self.context.account.peerId {
            actionText = nil
        }
        
        let controller = UndoOverlayController(
            presentationData: self.presentationData,
            content: .universalImage(
                image: generateTintedImage(image: UIImage(bundleImageName: "Peer Info/SavedMusic"), color: .white)!,
                size: nil,
                title: nil,
                text: self.presentationData.strings.MediaPlayer_SavedMusic_AddedToProfile,
                customUndoText: actionText,
                timeout: 3.0
            ),
            action: { [weak self] action in
                if let self, case .undo = action {
                    let _ = (self.context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: self.context.account.peerId))
                    |> deliverOnMainQueue).start(next: { [weak self] peer in
                        guard let self, let peer else {
                            return
                        }
                        if let controller = self.context.sharedContext.makePeerInfoController(
                            context: self.context,
                            updatedPresentationData: nil,
                            peer: peer._asPeer(),
                            mode: .myProfile,
                            avatarInitiallyExpanded: false,
                            fromChat: false,
                            requestsContext: nil
                        ) {
                            if let navigationController = (self.getParentController() as? OverlayAudioPlayerControllerImpl)?.parentNavigationController {
                                self.requestDismiss()
                                navigationController.pushViewController(controller)
                            }
                        }
                    })
                }
                return true
            }
        )
        self.getParentController()?.present(controller, in: .current)
        
        self.updateMusicSaved(file: file, isSaved: true)
    }
    
    func removeFromSavedMusic(file: FileMediaReference) {
        self.dismissAllTooltips()
                        
        let controller = UndoOverlayController(
            presentationData: self.presentationData,
            content: .universalImage(
                image: generateTintedImage(image: UIImage(bundleImageName: "Peer Info/SavedMusic"), color: .white)!,
                size: nil,
                title: nil,
                text: self.presentationData.strings.MediaPlayer_SavedMusic_RemovedFromProfile,
                customUndoText: nil,
                timeout: 3.0
            ),
            action: { _ in
                return true
            }
        )
        
        if let itemId = self.controlsNode.currentItemId as? PeerMessagesMediaPlaylistItemId, itemId.messageId.namespace == Namespaces.Message.Local && itemId.messageId.peerId == self.context.account.peerId, self.historyNode.originalHistoryView?.entries.count == 1 {
            if let navigationController = (self.getParentController() as? OverlayAudioPlayerControllerImpl)?.parentNavigationController {
                self.requestDismiss()
                navigationController.presentOverlay(controller: controller)
                
                self.context.sharedContext.mediaManager.setPlaylist(nil, type: self.type, control: .playback(.pause))
            }
        } else {
            self.getParentController()?.present(controller, in: .current)
        }
        
        self.updateMusicSaved(file: file, isSaved: false)
    }
    
    private var isSaved: Bool? {
        if self .copyProtectionEnabled {
            return nil
        }
        if case let .peer(peerId) = self.chatLocation, peerId.namespace == Namespaces.Peer.SecretChat {
            return nil
        }
        guard let fileReference = self.controlsNode.currentFileReference else {
            return nil
        }
        return self.savedIds?.contains(fileReference.media.fileId.id)
    }
    
    private func updateHistoryContentOffset(_ offset: ListViewVisibleContentOffset, transition: ContainedViewLayoutTransition) {
        switch offset {
        case let .known(value):
            self.historyContentOffset = value
        case .none:
            self.historyContentOffset = 0.0
        case .unknown:
            break
        }
        
        self.updateContainerContainingNodeTransform(transition: transition)
    }
    
    private func updateContainerContainingNodeTransform(transition: ContainedViewLayoutTransition) {
        guard let layout = self.validLayout else {
            return
        }
        
        if case .regular = layout.metrics.widthClass {
            transition.updateTransform(layer: self.containerContainingNode.layer, transform: CATransform3DIdentity)
            transition.updateCornerRadius(node: self.containerContainingNode, cornerRadius: 0.0)
            return
        }
        
        let expandDistance = self.effectiveHeaderHeight
        let topOffsetFraction = max(0.0, min(1.0, self.historyContentOffset / expandDistance))
        
        let minScale: CGFloat = (layout.size.width - 6.0 * 2.0) / layout.size.width
        let minScaledTranslation: CGFloat = (layout.size.height - layout.size.height * minScale) * 0.5 - 6.0
        
        let scale = minScale * (1.0 - topOffsetFraction) + topOffsetFraction
        let scaledTranslation = minScaledTranslation * (1.0 - topOffsetFraction)
        
        var containerTransform = CATransform3DIdentity
        containerTransform = CATransform3DTranslate(containerTransform, 0.0, scaledTranslation, 0.0)
        containerTransform = CATransform3DScale(containerTransform, scale, scale, scale)
        
        transition.updateTransform(layer: self.containerContainingNode.layer, transform: containerTransform)
        transition.updateCornerRadius(node: self.containerContainingNode, cornerRadius: layout.deviceMetrics.screenCornerRadius)
    }
    
    private var effectiveHeaderHeight: CGFloat {
        var headerHeight: CGFloat = 38.0
        if let playlistLocation = self.playlistLocation as? PeerMessagesPlaylistLocation, case .savedMusic = playlistLocation {
            headerHeight = 78.0
        }
        return headerHeight
    }
    
    func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        self.validLayout = layout
                
        transition.updateFrame(node: self.dimNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        transition.updateFrameAsPositionAndBounds(node: self.containerContainingNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        transition.updateFrame(node: self.contentNode, frame: CGRect(origin: CGPoint(), size: layout.size))
        
        let controlsHeight = self.controlsNode.updateLayout(width: layout.size.width, leftInset: 0.0, rightInset: 0.0, bottomInset: layout.intrinsicInsets.bottom, maxHeight: layout.size.height, savedMusic: self.isSaved, transition: transition)
        
        let controlsFrame = CGRect(origin: CGPoint(x: 0.0, y: layout.size.height - controlsHeight), size: CGSize(width: layout.size.width, height: controlsHeight))
        let controlsTransition = self.controlsNode.frame.width > 0.0 ? transition : .immediate
        controlsTransition.updateFrame(node: self.controlsNode, frame: controlsFrame)
        
        let layoutTopInset: CGFloat = max(layout.statusBarHeight ?? 0.0, layout.safeInsets.top)
        var insets = UIEdgeInsets()
        insets.left = 16.0
        insets.right = 16.0
        insets.bottom = 0.0
                        
        let headerHeight = self.effectiveHeaderHeight

        let listTopInset = layoutTopInset + headerHeight
        let listNodeSize = CGSize(width: layout.size.width, height: layout.size.height - listTopInset - controlsHeight)
        
        insets.top = max(0.0, listNodeSize.height - floor(62.0 * 3.5))
        
        var itemOffsetInsets = insets
        if let playlistLocation = self.playlistLocation as? PeerMessagesPlaylistLocation, case let .savedMusic(_, _, canReorder) = playlistLocation, canReorder {
            itemOffsetInsets.top = 0.0
            itemOffsetInsets.bottom = 0.0
            insets = itemOffsetInsets
        }
        transition.updateFrame(node: self.historyNode, frame: CGRect(origin: CGPoint(x: 0.0, y: listTopInset), size: listNodeSize))
        
        let (duration, curve) = listViewAnimationDurationAndCurve(transition: transition)
        let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: listNodeSize, insets: insets, itemOffsetInsets: itemOffsetInsets, duration: duration, curve: curve)
        self.historyNode.updateLayout(transition: transition, updateSizeAndInsets: updateSizeAndInsets)
        if let replacementHistoryNode = self.replacementHistoryNode {
            transition.updateFrame(node: replacementHistoryNode, frame: CGRect(origin: CGPoint(x: 0.0, y: listTopInset), size: listNodeSize))
            let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: listNodeSize, insets: insets, itemOffsetInsets: itemOffsetInsets, duration: 0.0, curve: .Default(duration: nil))
            replacementHistoryNode.updateLayout(transition: transition, updateSizeAndInsets: updateSizeAndInsets)
        }
        
        if let playlistLocation = self.playlistLocation as? PeerMessagesPlaylistLocation, case .savedMusic = playlistLocation {
            let leftControlItems: [GlassControlGroupComponent.Item] = [
                GlassControlGroupComponent.Item(
                    id: AnyHashable("close"),
                    content: .icon("Navigation/Close"),
                    action: { [weak self] in
                        guard let self else {
                            return
                        }
                        self.requestDismiss()
                    }
                )
            ]
            var rightControlItems: [GlassControlGroupComponent.Item] = []
            if let playlistLocation = self.playlistLocation as? PeerMessagesPlaylistLocation, case let .savedMusic(savedMusicContext, _, _) = playlistLocation, savedMusicContext.peerId == self.context.account.peerId {
                rightControlItems.append(
                    GlassControlGroupComponent.Item(
                        id: AnyHashable("add"),
                        content: .icon("Navigation/Add"),
                        action: { [weak self] in
                            guard let self else {
                                return
                            }
                            self.requestAdd()
                        }
                    )
                )
            }
            
            let headerInset: CGFloat = 16.0
            let headerButtonsSize = self.headerButtons.update(
                transition: ComponentTransition(transition),
                component: AnyComponent(
                    GlassControlPanelComponent(
                        theme: self.presentationData.theme,
                        leftItem: GlassControlPanelComponent.Item(
                            items: leftControlItems,
                            background: .panel
                        ),
                        centralItem: nil,
                        rightItem: rightControlItems.isEmpty ? nil : GlassControlPanelComponent.Item(
                            items: rightControlItems,
                            background: .panel
                        ),
                        centerAlignmentIfPossible: true,
                        isDark: self.presentationData.theme.overallDarkAppearance
                    )
                ),
                environment: {},
                containerSize: CGSize(width: layout.size.width - headerInset * 2.0, height: 44.0)
            )
            if let headerButtonsView = self.headerButtons.view {
                if headerButtonsView.superview == nil {
                    self.historyFrameNode.view.addSubview(headerButtonsView)
                }
                headerButtonsView.frame = CGRect(origin: CGPoint(x: headerInset, y: headerInset), size: headerButtonsSize)
            }
            
            let titleString: String
            if let peer = self.peer {
                if peer.id == self.context.account.peerId {
                    titleString = self.presentationData.strings.MediaPlayer_PlaylistYourTitle
                } else {
                    titleString = self.presentationData.strings.MediaPlayer_PlaylistTitle(peer.compactDisplayTitle).string
                }
            } else {
                titleString = ""
            }
            
            let titleSize = self.title.update(
                transition: ComponentTransition(transition),
                component: AnyComponent(
                    MultilineTextComponent(text: .plain(NSAttributedString(string: titleString, font: Font.semibold(17.0), textColor: self.presentationData.theme.list.itemPrimaryTextColor)))
                ),
                environment: {},
                containerSize: CGSize(width: layout.size.width - 70.0 * 2.0, height: headerHeight)
            )
            if let titleView = self.title.view {
                if titleView.superview == nil {
                    self.historyFrameNode.view.addSubview(titleView)
                }
                titleView.frame = CGRect(origin: CGPoint(x: floor((layout.size.width - titleSize.width) / 2.0), y: 29.0), size: titleSize)
            }
        }
        
        transition.updateFrame(node: self.collapseNode, frame: CGRect(origin: CGPoint(x: 0.0, y: -7.0), size: CGSize(width: layout.size.width, height: 30.0)))
        
        self.updateHistoryContentOffset(self.historyNode.visibleContentOffset(), transition: transition)
        
        self.albumArtBackground.frame = CGRect(origin: .zero, size: layout.size)
        
        if let _ = self.currentAlbumArt {
            var animateIn = false
            if self.albumArtBackground.superview == nil {
                self.view.addSubview(self.albumArtBackground)
                animateIn = true
            }
            let albumArtSide = min(360.0, layout.size.width - 32.0)
            let albumArtSize = CGSize(width: albumArtSide, height: albumArtSide)
            self.albumArtNode.frame = CGRect(origin: CGPoint(x: floorToScreenPixels((layout.size.width - albumArtSize.width) / 2.0), y: floorToScreenPixels((layout.size.height - albumArtSize.height) / 2.0)), size: albumArtSize)
            
            let makeLargeAlbumArtLayout = self.albumArtNode.asyncLayout()
            let applyLargeAlbumArt = makeLargeAlbumArtLayout(TransformImageArguments(corners: ImageCorners(radius: 4.0), imageSize: albumArtSize, boundingSize: albumArtSize, intrinsicInsets: UIEdgeInsets()))
            applyLargeAlbumArt()
            
            if animateIn {
                self.controlsNode.albumArtNode.alpha = 0.0
                
                let sourceFrame = self.controlsNode.albumArtNode.view.convert(self.controlsNode.albumArtNode.bounds, to: self.albumArtBackground.contentView)
                ContainedViewLayoutTransition.animated(duration: 0.4, curve: .spring).animateFrame(node: self.albumArtNode, from: sourceFrame)
                UIView.animate(withDuration: 0.2, animations: {
                    self.albumArtBackground.effect = UIBlurEffect(style: self.presentationData.theme.overallDarkAppearance ? .dark : .light)
                })
            }
        } else {
            self.controlsNode.albumArtNode.alpha = 1.0
            
            if self.albumArtBackground.superview != nil {
                let fadeTransition = ComponentTransition(transition)
                fadeTransition.setBlur(layer: self.albumArtNode.layer, radius: 10.0)
                fadeTransition.setAlpha(layer: self.albumArtNode.layer, alpha: 0.0)
                
                UIView.animate(withDuration: 0.2, animations: {
                    self.albumArtBackground.effect = nil
                }, completion: { _ in
                    self.albumArtBackground.removeFromSuperview()
                    ComponentTransition.immediate.setBlur(layer: self.albumArtNode.layer, radius: 0.0)
                    ComponentTransition.immediate.setAlpha(layer: self.albumArtNode.layer, alpha: 1.0)
                })
            }
        }
        
        var layout = layout
        layout.intrinsicInsets.bottom = controlsHeight + (self.historyNode.hasAnyMessages ? 0.0 : 8.0)
        self.getParentController()?.presentationContext.containerLayoutUpdated(layout, transition: transition)
    }
    
    func animateIn() {
        self.layer.animateBoundsOriginYAdditive(from: -self.bounds.size.height, to: 0.0, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring)
        self.dimNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
        self.dimNode.layer.animatePosition(from: CGPoint(x: 0.0, y: -self.bounds.size.height), to: CGPoint(), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: true, additive: true)
    }
    
    func animateOut(completion: (() -> Void)?) {
        self.dismissAllTooltips()
        
        self.layer.animateBoundsOriginYAdditive(from: self.bounds.origin.y, to: -self.bounds.size.height, duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, completion: { _ in
            completion?()
        })
        self.dimNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false)
        self.dimNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: -self.bounds.size.height), duration: 0.3, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: false, additive: true)
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let result = super.hitTest(point, with: event)
        if !self.bounds.contains(point) {
            return nil
        }
        if self.albumArtBackground.superview == nil &&  point.y < self.historyFrameNode.frame.minY {
            return self.dimNode.view
        }
        return result
    }
    
    @objc func dimTapGesture(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state {
            self.requestDismiss()
        }
    }
    
    @objc func albumArtTapped(_ recognizer: UITapGestureRecognizer) {
        if case .ended = recognizer.state, let layout = self.validLayout {
            self.currentAlbumArt = nil
            self.containerLayoutUpdated(layout, transition: .animated(duration: 0.3, curve: .easeInOut))
        }
    }
            
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if let recognizer = gestureRecognizer as? UIPanGestureRecognizer {
            let location = recognizer.location(in: self.view)
            if let view = super.hitTest(location, with: nil) {
                if let gestureRecognizers = view.gestureRecognizers, view != self.view {
                    for gestureRecognizer in gestureRecognizers {
                        if let panGestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer, gestureRecognizer.isEnabled {
                            if panGestureRecognizer.state != .began {
                                panGestureRecognizer.isEnabled = false
                                panGestureRecognizer.isEnabled = true
                            }
                        }
                    }
                }
            }
        }
        return true
    }
    
    @objc func panGesture(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
            case .began:
                self.dismissAllTooltips()
            case .changed:
                let translation = recognizer.translation(in: self.contentNode.view)
                var bounds = self.contentNode.bounds
                bounds.origin.y = -translation.y
                bounds.origin.y = min(0.0, bounds.origin.y)
                if bounds.origin.y < 0.0 {
                    //let delta = -bounds.origin.y
                    //bounds.origin.y = -((1.0 - (1.0 / (((delta) * 0.55 / (50.0)) + 1.0))) * 50.0)
                }
                
                self.contentNode.bounds = bounds
            case .ended:
                let translation = recognizer.translation(in: self.contentNode.view)
                var bounds = self.contentNode.bounds
                bounds.origin.y = -translation.y
                if bounds.origin.y < 0.0 {
                    //let delta = -bounds.origin.y
                    //bounds.origin.y = -((1.0 - (1.0 / (((delta) * 0.55 / (50.0)) + 1.0))) * 50.0)
                }
                
                let velocity = recognizer.velocity(in: self.contentNode.view)
                
                if (bounds.minY < -60.0 || velocity.y > 300.0) {
                    self.requestDismiss()
                } else {
                    let previousBounds = self.bounds
                    var bounds = self.bounds
                    bounds.origin.y = 0.0
                    self.contentNode.bounds = bounds
                    self.contentNode.layer.animateBounds(from: previousBounds, to: self.contentNode.bounds, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
                }
            case .cancelled:
                let previousBounds = self.contentNode.bounds
                var bounds = self.contentNode.bounds
                bounds.origin.y = 0.0
                self.contentNode.bounds = bounds
                self.contentNode.layer.animateBounds(from: previousBounds, to: self.contentNode.bounds, duration: 0.3, timingFunction: CAMediaTimingFunctionName.easeInEaseOut.rawValue)
            default:
                break
        }
    }
    
    private func updateFloatingHeaderOffset(offset: CGFloat, transition: ContainedViewLayoutTransition) {
        guard let layout = self.validLayout else {
            return
        }
        self.floatingHeaderOffset = offset
        let previousHasAnyHistoryMessages = self.hasAnyHistoryMessages
        self.hasAnyHistoryMessages = self.historyNode.hasAnyMessages
        self.controlsNode.hasPlainBackground = !self.historyNode.hasAnyMessages
        
        let sideInset: CGFloat = 16.0
        let headerHeight: CGFloat = self.effectiveHeaderHeight
        
        let layoutTopInset: CGFloat = max(layout.statusBarHeight ?? 0.0, layout.safeInsets.top)

        let rawControlsOffset = offset + layoutTopInset
        var backgroundOffset = max(layoutTopInset, rawControlsOffset)
        if !self.historyNode.hasAnyMessages {
            backgroundOffset += 25.0
        }
        
        let backgroundFrame = CGRect(origin: CGPoint(x: 0.0, y: backgroundOffset + headerHeight), size: CGSize(width: layout.size.width, height: layout.size.height))
        
        let frameFrame = CGRect(origin: CGPoint(x: 0.0, y: backgroundOffset), size: CGSize(width: layout.size.width, height: layout.size.height))
        let topOverlayFrame = CGRect(origin: CGPoint(x: 0.0, y: 0.0), size: CGSize(width: layout.size.width, height: headerHeight))
        let leftOverlayFrame = CGRect(origin: CGPoint(x: 0.0, y: topOverlayFrame.maxY - 1.0), size: CGSize(width: sideInset, height: layout.size.height))
        let rightOverlayFrame = CGRect(origin: CGPoint(x: layout.size.width - sideInset, y: topOverlayFrame.maxY - 1.0), size: CGSize(width: sideInset, height: layout.size.height))
        
        transition.updateFrame(node: self.historyFrameNode, frame: frameFrame)
        self.historyFrameTopOverlayClipNode.frame = topOverlayFrame
        self.historyFrameTopOverlayNode.frame = CGRect(origin: .zero, size: CGSize(width: topOverlayFrame.width, height: 78.0))
        self.historyFrameLeftOverlayNode.frame = leftOverlayFrame
        self.historyFrameRightOverlayNode.frame = rightOverlayFrame
        if let image = self.historyFrameTopMaskNode.image {
            self.historyFrameTopMaskNode.frame = CGRect(origin: CGPoint(x: sideInset, y: topOverlayFrame.maxY - 1.0), size: CGSize(width: layout.size.width - sideInset * 2.0, height: image.size.height))
        }
        self.historyFrameTopMaskNode.isHidden = self.controlsNode.hasPlainBackground
        
        let previousBackgroundFrame = self.historyBackgroundNode.frame
        if !backgroundFrame.equalTo(previousBackgroundFrame) {
            self.historyBackgroundNode.frame = backgroundFrame
            self.historyBackgroundContentNode.frame = CGRect(origin: CGPoint(), size: backgroundFrame.size)
            
            let positionDelta = CGPoint(x: backgroundFrame.minX - previousBackgroundFrame.minX, y: backgroundFrame.minY - previousBackgroundFrame.minY)
            
            transition.animateOffsetAdditive(node: self.historyBackgroundNode, offset: positionDelta.y)
        }
        
        if self.hasAnyHistoryMessages != previousHasAnyHistoryMessages {
            self.updatePresentationData(self.presentationData)
        }
    }
    
    private func transitionToUpdatedHistoryNode(atMessage messageId: MessageId) {
        let tagMask: MessageTags
        switch self.type {
            case .music:
                tagMask = .music
            case .voice:
                tagMask = .voiceOrInstantVideo
            case .file:
                tagMask = .file
        }
        
        let chatLocationContextHolder = Atomic<ChatLocationContextHolder?>(value: nil)
        let historyNode = ChatHistoryListNodeImpl(
            context: self.context,
            updatedPresentationData: (self.context.sharedContext.currentPresentationData.with({ $0 }), self.context.sharedContext.presentationData),
            systemStyle: .glass,
            chatLocation: self.chatLocation,
            chatLocationContextHolder: chatLocationContextHolder,
            adMessagesContext: nil,
            tag: .tag(tagMask),
            source: self.source,
            subject: .message(id: .id(messageId), highlight: ChatControllerSubject.MessageHighlight(quote: nil), timecode: nil, setupReply: false),
            controllerInteraction: self.controllerInteraction,
            selectedMessages: .single(nil),
            mode: .list(reversed: self.currentIsReversed, reverseGroups: !self.currentIsReversed, displayHeaders: .none, hintLinks: false, isGlobalSearch: self.isGlobalSearch, isMusicPlaylist: true),
            isChatPreview: false,
            messageTransitionNode: { return nil
            }
        )
        historyNode.clipsToBounds = true
        historyNode.preloadPages = true
        historyNode.stackFromBottom = true
        historyNode.areContentAnimationsEnabled = true
        historyNode.updateFloatingHeaderOffset = { [weak self] offset, _ in
            self?.replacementHistoryNodeFloatingOffset = offset
        }
        self.replacementHistoryNodeFloatingOffset = nil
        self.replacementHistoryNode = historyNode
        if let layout = self.validLayout {
            let layoutTopInset: CGFloat = max(layout.statusBarHeight ?? 0.0, layout.safeInsets.top)
            let controlsHeight = self.controlsNode.frame.height
            
            var insets = UIEdgeInsets()
            insets.left = 16.0
            insets.right = 16.0
            insets.bottom = 0.0

            let headerHeight = self.effectiveHeaderHeight
            let listTopInset = layoutTopInset + headerHeight
            let listNodeSize = CGSize(width: layout.size.width, height: layout.size.height - listTopInset - controlsHeight)
            
            insets.top = max(0.0, listNodeSize.height - floor(62.0 * 3.5))
            
            var itemOffsetInsets = insets
            if let playlistLocation = self.playlistLocation as? PeerMessagesPlaylistLocation, case let .savedMusic(_, _, canReorder) = playlistLocation, canReorder {
                itemOffsetInsets.top = 0.0
                itemOffsetInsets.bottom = 0.0
                insets = itemOffsetInsets
            }

            historyNode.frame = CGRect(origin: CGPoint(x: 0.0, y: listTopInset), size: listNodeSize)

            let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: listNodeSize, insets: insets, itemOffsetInsets: itemOffsetInsets, duration: 0.0, curve: .Default(duration: nil))
            historyNode.updateLayout(transition: .immediate, updateSizeAndInsets: updateSizeAndInsets)
        }
        self.replacementHistoryNodeReadyDisposable.set((historyNode.historyState.get() |> take(1) |> deliverOnMainQueue).startStrict(next: { [weak self] _ in
            if let strongSelf = self {
                strongSelf.replaceWithReadyUpdatedHistoryNode()
            }
        }))
    }
    
    private func replaceWithReadyUpdatedHistoryNode() {
        if let replacementHistoryNode = self.replacementHistoryNode {
            self.replacementHistoryNode = nil
            
            let previousHistoryNode = self.historyNode
            previousHistoryNode.disconnect()
            self.contentNode.insertSubnode(replacementHistoryNode, belowSubnode: self.historyNode)
            self.historyNode = replacementHistoryNode
            self.setupReordering()
            self.updateHistoryContentOffset(replacementHistoryNode.visibleContentOffset(), transition: .immediate)
            
            if let offset = self.replacementHistoryNodeFloatingOffset, let previousOffset = self.floatingHeaderOffset {
                let offsetDelta = offset - previousOffset
                 
                let previousBackgroundNode = ASDisplayNode()
                previousBackgroundNode.isLayerBacked = true
                previousBackgroundNode.backgroundColor = self.historyBackgroundContentNode.backgroundColor
                self.contentNode.insertSubnode(previousBackgroundNode, belowSubnode: previousHistoryNode)
                previousBackgroundNode.frame = self.historyBackgroundNode.frame
                
                self.updateFloatingHeaderOffset(offset: offset, transition: .animated(duration: 0.4, curve: .spring))
                previousHistoryNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak previousHistoryNode] _ in
                    previousHistoryNode?.removeFromSupernode()
                })
                previousHistoryNode.layer.animatePosition(from: CGPoint(), to: CGPoint(x: 0.0, y: offsetDelta), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: true, additive: true)
                previousBackgroundNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak previousBackgroundNode] _ in
                    previousBackgroundNode?.removeFromSupernode()
                })
                self.historyNode.layer.animatePosition(from: CGPoint(x: 0.0, y: -offsetDelta), to: CGPoint(), duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion: true, additive: true)
            } else {
                previousHistoryNode.removeFromSupernode()
            }
            
            self.historyNode.updateFloatingHeaderOffset = { [weak self] offset, transition in
                if let strongSelf = self {
                    strongSelf.updateFloatingHeaderOffset(offset: offset, transition: transition)
                }
            }
            self.historyNode.contentPositionChanged = { [weak self] offset in
                self?.updateHistoryContentOffset(offset, transition: .immediate)
            }
            
            self.historyNode.endedInteractiveDragging = { [weak self] _ in
                guard let strongSelf = self else {
                    return
                }
                switch strongSelf.historyNode.visibleContentOffset() {
                case let .known(value):
                    if let playlistLocation = strongSelf.playlistLocation as? PeerMessagesPlaylistLocation, case let .savedMusic(_, _, canReorder) = playlistLocation, canReorder {

                    } else {
                        if value <= -10.0 {
                            strongSelf.requestDismiss()
                        }
                    }
                default:
                    break
                }
            }
            
            self.historyNode.beganInteractiveDragging = { [weak self] _ in
                self?.controlsNode.collapse()
            }
            
            if let layout = self.validLayout {
                let layoutTopInset: CGFloat = max(layout.statusBarHeight ?? 0.0, layout.safeInsets.top)
                let controlsHeight = self.controlsNode.frame.height
                
                var insets = UIEdgeInsets()
                insets.left = 16.0
                insets.right = 16.0
                insets.bottom = 0.0
                
                let headerHeight = self.effectiveHeaderHeight
                let listTopInset = layoutTopInset + headerHeight
                let listNodeSize = CGSize(width: layout.size.width, height: layout.size.height - listTopInset - controlsHeight)
                
                insets.top = max(0.0, listNodeSize.height - floor(62.0 * 3.5))
                
                var itemOffsetInsets = insets
                if let playlistLocation = self.playlistLocation as? PeerMessagesPlaylistLocation, case let .savedMusic(_, _, canReorder) = playlistLocation, canReorder {
                    itemOffsetInsets.top = 0.0
                    itemOffsetInsets.bottom = 0.0
                    insets = itemOffsetInsets
                }
                
                self.historyNode.frame = CGRect(origin: CGPoint(x: 0.0, y: listTopInset), size: listNodeSize)
                
                let updateSizeAndInsets = ListViewUpdateSizeAndInsets(size: listNodeSize, insets: insets, itemOffsetInsets: itemOffsetInsets, duration: 0.0, curve: .Default(duration: nil))
                self.historyNode.updateLayout(transition: .immediate, updateSizeAndInsets: updateSizeAndInsets)
                
                self.historyNode.recursivelyEnsureDisplaySynchronously(true)
            }
            
            self.replacementHistoryNodeFloatingOffset = nil
            self.updateHistoryContentOffset(self.historyNode.visibleContentOffset(), transition: .immediate)
        }
    }
    
    private func openMessageContextMenu(message: Message, node: ASDisplayNode, frame: CGRect, recognizer: TapLongTapOrDoubleTapGestureRecognizer? = nil, gesture: ContextGesture? = nil, location: CGPoint? = nil) {
        guard let node = node as? ContextExtractedContentContainingNode, let peer = message.peers[message.id.peerId].flatMap({ PeerReference($0) }), let file = message.media.first(where: { $0 is TelegramMediaFile}) as? TelegramMediaFile else {
            return
        }
        let context = self.context
        let presentationData = self.presentationData
        let source: ContextContentSource = .extracted(OverlayAudioPlayerContextExtractedContentSource(contentNode: node))
        let fileReference: FileMediaReference = message.id.namespace == Namespaces.Message.Local ? .savedMusic(peer: peer, media: file) : .message(message: MessageReference(message), media: file)
        
        let canSaveToProfile = !(self.savedIds?.contains(file.fileId.id) == true)
        let canSaveToSavedMessages = message.id.peerId != self.context.account.peerId || message.id.namespace == Namespaces.Message.Local
        
        let _ = (context.sharedContext.chatAvailableMessageActions(engine: context.engine, accountPeerId: context.account.peerId, messageIds: [message.id], keepUpdated: false)
        |> deliverOnMainQueue).startStandalone(next: { [weak self] actions in
            guard let self else {
                return
            }
            
            var items: [ContextMenuItem] = []
            if canSaveToProfile || canSaveToSavedMessages {
                items.append(
                    .action(ContextMenuActionItem(text: presentationData.strings.MediaPlayer_ContextMenu_SaveTo, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/DownloadTone"), color: theme.contextMenu.primaryColor) }, action: { [weak self] c, _ in
                        if let self {
                            var subActions: [ContextMenuItem] = []
                            subActions.append(
                                .action(ContextMenuActionItem(text: presentationData.strings.Common_Back, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Back"), color: theme.contextMenu.primaryColor) }, iconPosition: .left, action: { c, _ in
                                    c?.popItems()
                                }))
                            )
                            subActions.append(.separator)
                            
                            if canSaveToProfile {
                                subActions.append(
                                    .action(ContextMenuActionItem(text: presentationData.strings.MediaPlayer_ContextMenu_SaveTo_Profile, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/User"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
                                        f(.default)
                                        
                                        if let self {
                                            self.addToSavedMusic(file: fileReference)
                                        }
                                    }))
                                )
                            }
                            
                            if canSaveToSavedMessages {
                                subActions.append(
                                    .action(ContextMenuActionItem(text: presentationData.strings.MediaPlayer_ContextMenu_SaveTo_SavedMessages, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Fave"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
                                        f(.default)
                                        
                                        if let self {
                                            self.forwardToSavedMessages(file: fileReference)
                                        }
                                    }))
                                )
                            }
                            
                            subActions.append(
                                .action(ContextMenuActionItem(text: presentationData.strings.MediaPlayer_ContextMenu_SaveTo_Files, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Save"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
                                    f(.default)
                                    
                                    if let self {
                                        let disposable: MetaDisposable
                                        if let current = self.saveMediaDisposable {
                                            disposable = current
                                        } else {
                                            disposable = MetaDisposable()
                                            self.saveMediaDisposable = disposable
                                        }
                                        disposable.set(
                                            saveMediaToFiles(context: context, fileReference: fileReference, present: { [weak self] c, a in
                                                if let self, let controller = (self.getParentController() as? OverlayAudioPlayerControllerImpl) {
                                                    controller.present(c, in: .window(.root), with: a)
                                                }
                                            })
                                        )
                                    }
                                }))
                            )
                            
                            let noAction: ((ContextMenuActionItem.Action) -> Void)? = nil
                            subActions.append(
                                .action(ContextMenuActionItem(text: presentationData.strings.MediaPlayer_ContextMenu_SaveTo_Info, textLayout: .multiline, textFont: .small, icon: { _ in return nil }, action: noAction))
                            )

                            c?.pushItems(items: .single(ContextController.Items(content: .list(subActions))))
                        }
                    }))
                )
            } else {
                items.append(.action(ContextMenuActionItem(text: presentationData.strings.MediaPlayer_ContextMenu_SaveToFiles, icon: { theme in
                    return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Save"), color: theme.actionSheet.primaryTextColor)
                }, action: { [weak self] _, f in
                    f(.default)
                    
                    if let self {
                        let disposable: MetaDisposable
                        if let current = self.saveMediaDisposable {
                            disposable = current
                        } else {
                            disposable = MetaDisposable()
                            self.saveMediaDisposable = disposable
                        }
                        disposable.set(
                            saveMediaToFiles(context: context, fileReference: fileReference, present: { [weak self] c, a in
                                if let self, let controller = (self.getParentController() as? OverlayAudioPlayerControllerImpl) {
                                    controller.present(c, in: .window(.root), with: a)
                                }
                            })
                        )
                    }
                })))
            }
            
            var addedSeparator = false
            
            if message.id.namespace == Namespaces.Message.Cloud {
                if !addedSeparator {
                    items.append(.separator)
                    addedSeparator = true
                }
                items.append(
                    .action(ContextMenuActionItem(text: presentationData.strings.MediaPlayer_ContextMenu_ShowInChat, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/GoToMessage"), color: theme.contextMenu.primaryColor) }, action: { [weak self] _, f in
                        f(.dismissWithoutContent)
                        
                        guard let self else {
                            return
                        }
                        context.sharedContext.navigateToChat(accountId: context.account.id, peerId: message.id.peerId, messageId: message.id)
                        self.requestDismiss()
                    }))
                )
            }
            
            var canDelete = false
            if case .custom = self.source {
                if self.savedIds?.contains(file.fileId.id) == true {
                    canDelete = true
                }
            } else if let peer = message.peers[message.id.peerId] {
                if peer is TelegramUser || peer is TelegramSecretChat {
                    canDelete = true
                } else if let _ = peer as? TelegramGroup {
                    canDelete = true
                } else if let channel = peer as? TelegramChannel {
                    if message.flags.contains(.Incoming) {
                        canDelete = channel.hasPermission(.deleteAllMessages)
                    } else {
                        canDelete = true
                    }
                } else {
                    canDelete = false
                }
            } else {
                canDelete = false
            }
            
            if canDelete {
                if !addedSeparator {
                    items.append(.separator)
                    addedSeparator = true
                }
                var actionTitle = presentationData.strings.MediaPlayer_ContextMenu_Delete
                if case .custom = self.source {
                    actionTitle = presentationData.strings.MediaPlayer_ContextMenu_Remove
                }
                items.append(
                    .action(ContextMenuActionItem(text: actionTitle, textColor: .destructive, icon: { theme in return generateTintedImage(image: UIImage(bundleImageName: "Chat/Context Menu/Delete"), color: theme.contextMenu.destructiveColor) }, action: { [weak self] c, f in
                        guard let self else {
                            return
                        }
                        if message.id.namespace == Namespaces.Message.Local {
                            f(.default)
                            self.removeFromSavedMusic(file: fileReference)
                        } else {
                            c?.setItems(context.engine.data.get(TelegramEngine.EngineData.Item.Peer.Peer(id: message.id.peerId))
                            |> map { peer -> ContextController.Items in
                                var items: [ContextMenuItem] = []
                                let messageIds = [message.id]
                                
                                if let peer {
                                    var personalPeerName: String?
                                    var isChannel = false
                                    if case let .user(user) = peer {
                                        personalPeerName = EnginePeer(user).compactDisplayTitle
                                    } else if case let .channel(channel) = peer, case .broadcast = channel.info {
                                        isChannel = true
                                    }
                                    
                                    if actions.options.contains(.deleteGlobally) {
                                        let globalTitle: String
                                        if isChannel {
                                            globalTitle = presentationData.strings.Conversation_DeleteMessagesForEveryone
                                        } else if let personalPeerName = personalPeerName {
                                            globalTitle = presentationData.strings.Conversation_DeleteMessagesFor(personalPeerName).string
                                        } else {
                                            globalTitle = presentationData.strings.Conversation_DeleteMessagesForEveryone
                                        }
                                        items.append(.action(ContextMenuActionItem(text: globalTitle, textColor: .destructive, icon: { _ in nil }, action: { c, f in
                                            c?.dismiss(completion: {
                                                let _ = context.engine.messages.deleteMessagesInteractively(messageIds: Array(messageIds), type: .forEveryone).startStandalone()
                                            })
                                        })))
                                    }
                                    
                                    if actions.options.contains(.deleteLocally) {
                                        var localOptionText = presentationData.strings.Conversation_DeleteMessagesForMe
                                        if context.account.peerId == message.id.peerId {
                                            if messageIds.count == 1 {
                                                localOptionText = presentationData.strings.Conversation_Moderate_Delete
                                            } else {
                                                localOptionText = presentationData.strings.Conversation_DeleteManyMessages
                                            }
                                        }
                                        items.append(.action(ContextMenuActionItem(text: localOptionText, textColor: .destructive, icon: { _ in nil }, action: { c, f in
                                            c?.dismiss(completion: {
                                                let _ = context.engine.messages.deleteMessagesInteractively(messageIds: Array(messageIds), type: .forLocalPeer).startStandalone()
                                            })
                                        })))
                                    }
                                }
                                
                                return ContextController.Items(content: .list(items))
                            }, minHeight: nil, animated: true)
                        }
                    }))
                )
            }
            
            guard !items.isEmpty else {
                return
            }
            
            let contextController = makeContextController(presentationData: presentationData, source: source, items: .single(ContextController.Items(content: .list(items))), recognizer: recognizer, gesture: gesture)
            self.getParentController()?.presentInGlobalOverlay(contextController)
        })
    }
}

private final class OverlayAudioPlayerContextExtractedContentSource: ContextExtractedContentSource {
    let keepInPlace: Bool = false
    let ignoreContentTouches: Bool = false
    let blurBackground: Bool = true
    let additionalInsets = UIEdgeInsets(top: 0.0, left: 0.0, bottom: 80.0, right: 0.0)
    
    private let contentNode: ContextExtractedContentContainingNode
    
    init(contentNode: ContextExtractedContentContainingNode) {
        self.contentNode = contentNode
    }
    
    func takeView() -> ContextControllerTakeViewInfo? {
        return ContextControllerTakeViewInfo(containingItem: .node(self.contentNode), contentAreaInScreenSpace: UIScreen.main.bounds)
    }
    
    func putBack() -> ContextControllerPutBackViewInfo? {
        return ContextControllerPutBackViewInfo(contentAreaInScreenSpace: UIScreen.main.bounds)
    }
}

private func generateCollapseIcon(theme: PresentationTheme) -> UIImage? {
    return generateImage(CGSize(width: 36.0, height: 6.0), rotatedContext: { size, context in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.clear(bounds)
        
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: 3.0)
        context.setFillColor(theme.list.controlSecondaryColor.cgColor)
        context.addPath(path.cgPath)
        context.fillPath()
    })
}

private func generateCornersImage(theme: PresentationTheme) -> UIImage? {
    return generateImage(CGSize(width: 56.0, height: 56.0), rotatedContext: { (size, context) in
        let bounds = CGRect(origin: CGPoint(), size: size)
        context.setFillColor(theme.list.modalBlocksBackgroundColor.cgColor)
        context.fill(bounds)
        
        context.setBlendMode(.clear)
        
        var corners: UIRectCorner = []
        corners.insert(.topLeft)
        corners.insert(.topRight)
        
        let cornerRadius: CGFloat = 26.0
        let path = UIBezierPath(roundedRect: bounds.offsetBy(dx: 0.0, dy: 1.0), byRoundingCorners: corners, cornerRadii: CGSize(width: cornerRadius, height: cornerRadius))
        context.addPath(path.cgPath)
        context.fillPath()
    })?.stretchableImage(withLeftCapWidth: 28, topCapHeight: 28)
}
